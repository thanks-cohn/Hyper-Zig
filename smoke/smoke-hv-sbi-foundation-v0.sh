#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT/logs/latest"; SMOKE_LOG="$LOG_DIR/smoke-hv-sbi-foundation-v0.log"; QEMU_LOG="$LOG_DIR/qemu-hv-sbi-foundation-v0.log"
TRANSCRIPT="$ROOT/smoke/transcripts/latest-hv-sbi-foundation-v0.txt"; TRANSCRIPT_COPY="$LOG_DIR/qemu-smoke-hv-sbi-foundation-v0-transcript.txt"; ELF="$ROOT/zig-out/bin/zign01d-v0"
mkdir -p "$LOG_DIR" "$ROOT/smoke/transcripts"; : > "$SMOKE_LOG"; : > "$QEMU_LOG"; : > "$TRANSCRIPT"
stamp(){ date -u '+%Y-%m-%dT%H:%M:%SZ'; }
log(){ printf '[%s][ZIGN01D][INFO][SMOKE][SMOKEHV15] %s\n' "$(stamp)" "$*" | tee -a "$SMOKE_LOG"; }
fail(){ printf 'FAIL %s\n' "$*" | tee -a "$SMOKE_LOG" >&2; printf 'inspect: %s %s %s\n' "$SMOKE_LOG" "$QEMU_LOG" "$TRANSCRIPT" | tee -a "$SMOKE_LOG" >&2; exit 1; }
log "checking Zig 0.14.x"; "$ROOT/scripts/check-zig-version.sh" >>"$SMOKE_LOG" 2>&1 || fail "Zig 0.14.x check failed"
log "running build"; "$ROOT/scripts/build.sh" >>"$SMOKE_LOG" 2>&1 || fail "build failed"
[[ -f "$ELF" ]] || fail "missing kernel ELF: $ELF"; command -v qemu-system-riscv64 >/dev/null 2>&1 || fail "qemu-system-riscv64 not found"
QEMU_CMD=(qemu-system-riscv64 -machine virt -cpu rv64 -smp 1 -m 128M -nographic -monitor none -serial stdio -kernel "$ELF")
printf '[%s][ZIGN01D][INFO][QEMU][QEMUHV15] command:' "$(stamp)" | tee -a "$QEMU_LOG" "$SMOKE_LOG"; printf ' %q' "${QEMU_CMD[@]}" | tee -a "$QEMU_LOG" "$SMOKE_LOG"; printf '\n' | tee -a "$QEMU_LOG" "$SMOKE_LOG"
set +e
python3 - "$TRANSCRIPT" "${QEMU_CMD[@]}" <<'PYSMOKE'
import os,selectors,subprocess,sys,time
transcript=sys.argv[1]; cmd=sys.argv[2:]
commands=["hv sbi","hv sbi validate","hv sbi blockers","hv sbi base-test","hv sbi validate","hv sbi timer-test","hv sbi console-test","hv-sbi","hv sbi reset","hv sbi status","shutdown"]
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
cmds=["hv sbi","hv sbi validate","hv sbi blockers","hv sbi base-test","hv sbi validate","hv sbi timer-test","hv sbi console-test","hv-sbi","hv sbi reset","hv sbi status"]
blocks=[]; cursor=0
for c in cmds:
    marker='zign01d> '+c; start=text.find(marker,cursor)
    if start<0: raise SystemExit(f'missing command echo: {c}')
    end=text.find('zign01d> ',start+len(marker)); blocks.append(text[start:] if end<0 else text[start:end]); cursor=len(text) if end<0 else end
def need(i,m):
    if m not in blocks[i]: raise SystemExit(f'missing in {cmds[i]}: {m}\n---block---\n{blocks[i]}')
    print(f'PASS {cmds[i]} contains {m}')
need(0,'hv: sbi_foundation=implemented'); need(0,'hv: sbi.owner_vm_id=0'); need(0,'hv: sbi.owner_vcpu_id=0'); need(0,'hv: sbi.has_request=false')
need(0,'hv: sbi.extension.base.id=0x10'); need(0,'hv: sbi.extension.timer.id=0x54494d45'); need(0,'hv: sbi.extension.legacy-console.id=0x1')
need(1,'hv: sbi.validate_result=rejected'); need(1,'hv: sbi.last_error=no-request'); need(1,'hv: sbi.reject_count=1')
need(2,'hv: sbi.blocker=no-request')
need(3,'hv: sbi.base_test=ok'); need(3,'hv: sbi.has_request=true'); need(3,'hv: sbi.last_extension=base'); need(3,'hv: sbi.record_count=1'); need(3,'hv: sbi.base_request_count=1')
need(4,'hv: sbi.validate_result=ok'); need(4,'hv: sbi.last_error=none')
need(5,'hv: sbi.timer_test=ok'); need(5,'hv: sbi.last_extension=timer'); need(5,'hv: sbi.arg0=0x1'); need(5,'hv: sbi.timer_request_count=1')
need(6,'hv: sbi.console_test=ok'); need(6,'hv: sbi.last_extension=legacy-console'); need(6,'hv: sbi.arg0=0x41'); need(6,'hv: sbi.console_request_count=1')
need(7,'hv: sbi.record_count=3'); need(7,'hv: sbi.validate_count=6'); need(7,'hv: sbi.reject_count=2')
need(8,'hv: sbi.reset_result=ok'); need(8,'hv: sbi.has_request=false'); need(8,'hv: sbi.record_count=0'); need(8,'hv: sbi.reset_count=1')
need(9,'hv: sbi.has_request=false'); need(9,'hv: sbi.reset_count=1')
for forbidden in ['linux_guest=supported','guest_execution=supported','sbi_services=implemented','hgatp']:
    if forbidden in text: raise SystemExit(f'forbidden marker found: {forbidden}')
print('PASS HV15 SBI foundation behavior checks')
PYCHECK
log "HV15 SBI foundation smoke passed transcript=$TRANSCRIPT"; printf 'PASS HV15 SBI foundation smoke\n' | tee -a "$SMOKE_LOG"
