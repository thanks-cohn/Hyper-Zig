#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT/logs/latest"; SMOKE_LOG="$LOG_DIR/smoke-hv-dtb-contract-v0.log"; QEMU_LOG="$LOG_DIR/qemu-hv-dtb-contract-v0.log"
TRANSCRIPT="$ROOT/smoke/transcripts/latest-hv-dtb-contract-v0.txt"; TRANSCRIPT_COPY="$LOG_DIR/qemu-smoke-hv-dtb-contract-v0-transcript.txt"; ELF="$ROOT/zig-out/bin/zign01d-v0"
mkdir -p "$LOG_DIR" "$ROOT/smoke/transcripts"; : > "$SMOKE_LOG"; : > "$QEMU_LOG"; : > "$TRANSCRIPT"
stamp(){ date -u '+%Y-%m-%dT%H:%M:%SZ'; }
log(){ printf '[%s][ZIGN01D][INFO][SMOKE][SMOKEHV14] %s\n' "$(stamp)" "$*" | tee -a "$SMOKE_LOG"; }
fail(){ printf 'FAIL %s\n' "$*" | tee -a "$SMOKE_LOG" >&2; printf 'inspect: %s %s %s\n' "$SMOKE_LOG" "$QEMU_LOG" "$TRANSCRIPT" | tee -a "$SMOKE_LOG" >&2; exit 1; }
log "checking Zig 0.14.x"; "$ROOT/scripts/check-zig-version.sh" >>"$SMOKE_LOG" 2>&1 || fail "Zig 0.14.x check failed"
log "running build"; "$ROOT/scripts/build.sh" >>"$SMOKE_LOG" 2>&1 || fail "build failed"
[[ -f "$ELF" ]] || fail "missing kernel ELF: $ELF"; command -v qemu-system-riscv64 >/dev/null 2>&1 || fail "qemu-system-riscv64 not found"
QEMU_CMD=(qemu-system-riscv64 -machine virt -cpu rv64 -smp 1 -m 128M -nographic -monitor none -serial stdio -kernel "$ELF")
printf '[%s][ZIGN01D][INFO][QEMU][QEMUHV14] command:' "$(stamp)" | tee -a "$QEMU_LOG" "$SMOKE_LOG"; printf ' %q' "${QEMU_CMD[@]}" | tee -a "$QEMU_LOG" "$SMOKE_LOG"; printf '\n' | tee -a "$QEMU_LOG" "$SMOKE_LOG"
set +e
python3 - "$TRANSCRIPT" "${QEMU_CMD[@]}" <<'PYSMOKE'
import os,selectors,subprocess,sys,time
transcript=sys.argv[1]; cmd=sys.argv[2:]
commands=["hv dtb","hv dtb blockers","hv dtb validate","hv bootpkg reset","hv bootpkg attach-kernel","hv bootpkg set-cmdline root=/dev/ram0 console=hvc0 earlycon","hv bootpkg set-entry","hv bootpkg attach-initrd","hv bootpkg validate","hv dtb build","hv dtb nodes","hv dtb validate","hv-dtb","hv dtb bounds-test","hv dtb overlap-test","hv dtb reset","hv dtb","shutdown"]
proc=subprocess.Popen(cmd,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.STDOUT); os.set_blocking(proc.stdout.fileno(),False)
sel=selectors.DefaultSelector(); sel.register(proc.stdout,selectors.EVENT_READ); seen=bytearray(); ready=False; status=124; deadline=time.monotonic()+45
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
QEMU_STATUS=$?; set -e
cat "$TRANSCRIPT" >> "$QEMU_LOG"; cp "$TRANSCRIPT" "$TRANSCRIPT_COPY"
[[ $QEMU_STATUS -eq 0 ]] || fail "qemu exited with status $QEMU_STATUS"; [[ -s "$TRANSCRIPT" ]] || fail "boot transcript missing or empty"
python3 - "$TRANSCRIPT" <<'PYCHECK' | tee -a "$SMOKE_LOG"
import sys
from pathlib import Path
text=Path(sys.argv[1]).read_text(errors='replace')
cmds=["hv dtb","hv dtb blockers","hv dtb validate","hv bootpkg reset","hv bootpkg attach-kernel","hv bootpkg set-cmdline root=/dev/ram0 console=hvc0 earlycon","hv bootpkg set-entry","hv bootpkg attach-initrd","hv bootpkg validate","hv dtb build","hv dtb nodes","hv dtb validate","hv-dtb","hv dtb bounds-test","hv dtb overlap-test","hv dtb reset","hv dtb"]
blocks=[]; cursor=0
for c in cmds:
    marker='zign01d> '+c; start=text.find(marker,cursor)
    if start<0: raise SystemExit(f'missing command echo: {c}')
    end=text.find('zign01d> ',start+len(marker)); blocks.append(text[start:] if end<0 else text[start:end]); cursor=len(text) if end<0 else end
def need(i,m):
    if m not in blocks[i]: raise SystemExit(f'missing in {cmds[i]}: {m}\n---block---\n{blocks[i]}')
    print(f'PASS {cmds[i]} contains {m}')
need(0,'hv: dtb_contract=implemented'); need(0,'hv: dtb.state=empty'); need(0,'hv: dtb.ready=false')
need(1,'hv: dtb.blocker=boot-package-not-ready'); need(1,'hv: dtb.blocker=payload-missing')
need(2,'hv: dtb.validate_result=rejected'); need(2,'hv: dtb.last_error=boot-package-not-ready')
need(8,'hv: boot_package.validate_result=ok'); need(8,'hv: boot_package.ready=true')
need(9,'hv: dtb.build_result=ok'); need(9,'hv: dtb.state=built'); need(9,'hv: dtb.ready=true'); need(9,'hv: dtb.gpa=0x1c00')
need(9,'hv: dtb.bootargs=root=/dev/ram0 console=hvc0 earlycon'); need(9,'hv: dtb.guest_base=0x0'); need(9,'hv: dtb.guest_size_bytes=8192')
need(9,'hv: dtb.initrd_present=true'); need(9,'hv: dtb.initrd_start=0x1000'); need(9,'hv: dtb.initrd_end=0x1200')
need(10,'hv: dtb.node=/memory present=true'); need(10,'hv: dtb.node=/cpus/cpu@0 present=true'); need(10,'hv: dtb.node=/chosen present=true'); need(10,'hv: dtb.interrupt_controller=missing-not-claimed'); need(10,'hv: dtb.timer=missing-not-claimed')
need(11,'hv: dtb.validate_result=ok'); need(11,'hv: dtb.blocker=none')
need(12,'hv: dtb.state=built'); need(12,'hv: dtb.ready=true')
need(13,'hv: dtb.bounds_test=rejected'); need(13,'hv: dtb.last_error=range-out-of-bounds')
need(14,'hv: dtb.overlap_test=rejected'); need(14,'hv: dtb.last_error=kernel-overlap')
need(15,'hv: dtb.reset_result=ok'); need(15,'hv: dtb.state=empty'); need(15,'hv: dtb.payload_present=false')
need(16,'hv: dtb.state=empty'); need(16,'hv: dtb.ready=false')
for forbidden in ['linux_guest=supported','guest_execution=supported','stage2_table.active=true','hgatp','sbi_layer=implemented']:
    if forbidden in text: raise SystemExit(f'forbidden marker found: {forbidden}')
print('PASS HV14 DTB contract behavior checks')
PYCHECK
log "HV14 DTB contract smoke passed transcript=$TRANSCRIPT"; printf 'PASS HV14 DTB contract smoke\n' | tee -a "$SMOKE_LOG"
