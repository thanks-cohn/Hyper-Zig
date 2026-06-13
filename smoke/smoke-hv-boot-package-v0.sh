#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT/logs/latest"
SMOKE_LOG="$LOG_DIR/smoke-hv-boot-package-v0.log"
QEMU_LOG="$LOG_DIR/qemu-hv-boot-package-v0.log"
TRANSCRIPT="$ROOT/smoke/transcripts/latest-hv-boot-package-v0.txt"
TRANSCRIPT_COPY="$LOG_DIR/qemu-smoke-hv-boot-package-v0-transcript.txt"
ELF="$ROOT/zig-out/bin/zign01d-v0"
mkdir -p "$LOG_DIR" "$ROOT/smoke/transcripts"
: > "$SMOKE_LOG"; : > "$QEMU_LOG"; : > "$TRANSCRIPT"
stamp() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }
log() { printf '[%s][ZIGN01D][INFO][SMOKE][SMOKEHV13] %s\n' "$(stamp)" "$*" | tee -a "$SMOKE_LOG"; }
fail() { printf 'FAIL %s\n' "$*" | tee -a "$SMOKE_LOG" >&2; printf 'inspect: %s %s %s\n' "$SMOKE_LOG" "$QEMU_LOG" "$TRANSCRIPT" | tee -a "$SMOKE_LOG" >&2; exit 1; }

log "checking Zig 0.14.x"; "$ROOT/scripts/check-zig-version.sh" >>"$SMOKE_LOG" 2>&1 || fail "Zig 0.14.x check failed"
log "running build"; "$ROOT/scripts/build.sh" >>"$SMOKE_LOG" 2>&1 || fail "build failed"
[[ -f "$ELF" ]] || fail "missing kernel ELF: $ELF"
command -v qemu-system-riscv64 >/dev/null 2>&1 || fail "qemu-system-riscv64 not found"

QEMU_CMD=(qemu-system-riscv64 -machine virt -cpu rv64 -smp 1 -m 128M -nographic -monitor none -serial stdio -kernel "$ELF")
printf '[%s][ZIGN01D][INFO][QEMU][QEMUHV13] command:' "$(stamp)" | tee -a "$QEMU_LOG" "$SMOKE_LOG"; printf ' %q' "${QEMU_CMD[@]}" | tee -a "$QEMU_LOG" "$SMOKE_LOG"; printf '\n' | tee -a "$QEMU_LOG" "$SMOKE_LOG"

set +e
python3 - "$TRANSCRIPT" "${QEMU_CMD[@]}" <<'PYSMOKE'
import os, selectors, subprocess, sys, time
transcript=sys.argv[1]; cmd=sys.argv[2:]
commands=[
 "hv bootpkg", "hv bootpkg blockers", "hv bootpkg validate", "hv bootpkg attach-kernel",
 "hv bootpkg set-cmdline root=/dev/ram0 console=hvc0 earlycon", "hv bootpkg set-cmdline " + ("x"*120),
 "hv bootpkg set-entry", "hv bootpkg attach-initrd", "hv bootpkg attach-dtb", "hv bootpkg validate",
 "hv-bootpkg", "hv bootpkg overlap-test", "hv bootpkg bounds-test", "hv bootpkg reset", "hv bootpkg", "shutdown"]
proc=subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
os.set_blocking(proc.stdout.fileno(), False)
sel=selectors.DefaultSelector(); sel.register(proc.stdout, selectors.EVENT_READ)
seen=bytearray(); ready=False; status=124; deadline=time.monotonic()+45
with open(transcript,'wb') as out:
    try:
        while time.monotonic()<deadline:
            if proc.poll() is not None: status=proc.returncode; break
            for key,_ in sel.select(timeout=0.05):
                chunk=key.fileobj.read()
                if chunk: out.write(chunk); out.flush(); seen.extend(chunk)
            if not ready and b'zign01d> ' in seen:
                ready=True
                for c in commands:
                    proc.stdin.write((c+'\n').encode()); proc.stdin.flush(); time.sleep(0.12)
            if ready and proc.poll() is not None: status=proc.returncode; break
    finally:
        if proc.poll() is None:
            proc.terminate()
            try: proc.wait(timeout=2)
            except subprocess.TimeoutExpired: proc.kill()
        while True:
            chunk=proc.stdout.read()
            if not chunk: break
            out.write(chunk)
if not ready and status==0: status=125
sys.exit(status)
PYSMOKE
QEMU_STATUS=$?
set -e
cat "$TRANSCRIPT" >> "$QEMU_LOG"; cp "$TRANSCRIPT" "$TRANSCRIPT_COPY"
[[ $QEMU_STATUS -eq 0 ]] || fail "qemu exited with status $QEMU_STATUS"
[[ -s "$TRANSCRIPT" ]] || fail "boot transcript missing or empty"

python3 - "$TRANSCRIPT" <<'PYCHECK' | tee -a "$SMOKE_LOG"
import sys
from pathlib import Path
text=Path(sys.argv[1]).read_text(errors='replace')
cmds=["hv bootpkg", "hv bootpkg blockers", "hv bootpkg validate", "hv bootpkg attach-kernel", "hv bootpkg set-cmdline root=/dev/ram0 console=hvc0 earlycon", "hv bootpkg set-cmdline " + ("x"*120), "hv bootpkg set-entry", "hv bootpkg attach-initrd", "hv bootpkg attach-dtb", "hv bootpkg validate", "hv-bootpkg", "hv bootpkg overlap-test", "hv bootpkg bounds-test", "hv bootpkg reset", "hv bootpkg"]
blocks=[]
for i,c in enumerate(cmds):
    marker="zign01d> "+c
    start=text.find(marker)
    if start<0: raise SystemExit(f"missing command echo: {c}")
    end=text.find("zign01d> ", start+len(marker))
    blocks.append(text[start:] if end<0 else text[start:end])
def need(i, marker):
    if marker not in blocks[i]: raise SystemExit(f"missing in {cmds[i]}: {marker}\n---block---\n{blocks[i]}")
    print(f"PASS {cmds[i]} contains {marker}")
need(0,"hv: boot_package=implemented"); need(0,"hv: boot_package.state=empty"); need(0,"hv: boot_package.ready=false")
need(1,"hv: boot_package.blocker=kernel-image-missing"); need(1,"hv: boot_package.blocker=entry-gpa-missing")
need(2,"hv: boot_package.validate_result=rejected"); need(2,"hv: boot_package.last_error=guest-memory-missing")
need(3,"hv: boot_package.attach_kernel_result=ok"); need(3,"hv: boot_package.kernel_present=true"); need(3,"hv: boot_package.kernel_load_gpa=0x0"); need(3,"hv: boot_package.kernel_start=0x0"); need(3,"hv: boot_package.kernel_size_bytes=32")
need(4,"hv: boot_package.set_cmdline_result=ok"); need(4,"hv: boot_package.cmdline=root=/dev/ram0 console=hvc0 earlycon")
need(5,"hv: boot_package.set_cmdline_result=rejected"); need(5,"hv: boot_package.last_error=cmdline-too-long")
need(6,"hv: boot_package.set_entry_result=ok"); need(6,"hv: boot_package.entry_present=true"); need(6,"hv: boot_package.entry_gpa=0x0")
need(7,"hv: boot_package.attach_initrd_result=ok"); need(7,"hv: boot_package.initrd_present=true"); need(7,"hv: boot_package.initrd_start=0x1000")
need(8,"hv: boot_package.attach_dtb_result=ok"); need(8,"hv: boot_package.dtb_present=true"); need(8,"hv: boot_package.dtb_start=0x1800")
need(9,"hv: boot_package.validate_result=ok"); need(9,"hv: boot_package.state=ready"); need(9,"hv: boot_package.ready=true"); need(9,"hv: boot_package.blocker=none")
need(10,"hv: boot_package.state=ready")
need(11,"hv: boot_package.overlap_test=rejected"); need(11,"hv: boot_package.last_error=range-overlap")
need(12,"hv: boot_package.bounds_test=rejected"); need(12,"hv: boot_package.last_error=range-out-of-bounds")
need(13,"hv: boot_package.reset_result=ok"); need(13,"hv: boot_package.state=empty"); need(13,"hv: boot_package.kernel_present=false")
need(14,"hv: boot_package.state=empty"); need(14,"hv: boot_package.ready=false"); need(14,"hv: boot_package.blocker=kernel-image-missing")
for forbidden in ["linux_guest=supported", "guest_execution=supported", "stage2_table.active=true", "hgatp"]:
    if forbidden in text: raise SystemExit(f"forbidden marker found: {forbidden}")
print("PASS HV13 boot package behavior checks")
PYCHECK

log "HV13 guest boot package smoke passed transcript=$TRANSCRIPT"
printf 'PASS HV13 guest boot package smoke\n' | tee -a "$SMOKE_LOG"
