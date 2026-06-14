#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT/logs/latest"; SMOKE_LOG="$LOG_DIR/smoke-hv-sbi-dispatch-v0.log"; QEMU_LOG="$LOG_DIR/qemu-hv-sbi-dispatch-v0.log"
TRANSCRIPT="$ROOT/smoke/transcripts/latest-hv-sbi-dispatch-v0.txt"; TRANSCRIPT_COPY="$LOG_DIR/qemu-smoke-hv-sbi-dispatch-v0-transcript.txt"; ELF="$ROOT/zig-out/bin/zign01d-v0"
mkdir -p "$LOG_DIR" "$ROOT/smoke/transcripts"; : > "$SMOKE_LOG"; : > "$QEMU_LOG"; : > "$TRANSCRIPT"
stamp(){ date -u '+%Y-%m-%dT%H:%M:%SZ'; }
log(){ printf '[%s][ZIGN01D][INFO][SMOKE][SMOKEHV20] %s\n' "$(stamp)" "$*" | tee -a "$SMOKE_LOG"; }
fail(){ printf 'FAIL %s\n' "$*" | tee -a "$SMOKE_LOG" >&2; printf 'inspect: %s %s %s\n' "$SMOKE_LOG" "$QEMU_LOG" "$TRANSCRIPT" | tee -a "$SMOKE_LOG" >&2; exit 1; }
log "checking Zig 0.14.x"; "$ROOT/scripts/check-zig-version.sh" >>"$SMOKE_LOG" 2>&1 || fail "Zig 0.14.x check failed"
log "running build"; "$ROOT/scripts/build.sh" >>"$SMOKE_LOG" 2>&1 || fail "build failed"
[[ -f "$ELF" ]] || fail "missing kernel ELF: $ELF"; command -v qemu-system-riscv64 >/dev/null 2>&1 || fail "qemu-system-riscv64 not found"
QEMU_CMD=(qemu-system-riscv64 -machine virt -cpu rv64 -smp 1 -m 128M -nographic -monitor none -serial stdio -kernel "$ELF")
printf '[%s][ZIGN01D][INFO][QEMU][QEMUHV20] command:' "$(stamp)" | tee -a "$QEMU_LOG" "$SMOKE_LOG"; printf ' %q' "${QEMU_CMD[@]}" | tee -a "$QEMU_LOG" "$SMOKE_LOG"; printf '\n' | tee -a "$QEMU_LOG" "$SMOKE_LOG"
set +e
python3 - "$TRANSCRIPT" "${QEMU_CMD[@]}" <<'PYSMOKE'
import os,selectors,subprocess,sys,time
transcript=sys.argv[1]; cmd=sys.argv[2:]
commands=["hv sbi-dispatch","hv sbi-dispatch validate","hv sbi-dispatch base-test","hv sbi-dispatch timer-test","hv sbi-dispatch console-putchar-test","hv sbi-dispatch console-getchar-test","hv sbi-dispatch unknown-test","hv sbi-dispatch unsupported-function-test","hv sbi-dispatch blockers","hv sbi-dispatch reset","hv-dispatch","shutdown"]
proc=subprocess.Popen(cmd,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.STDOUT); os.set_blocking(proc.stdout.fileno(),False)
sel=selectors.DefaultSelector(); sel.register(proc.stdout,selectors.EVENT_READ); seen=bytearray(); ready=False; status=124; deadline=time.monotonic()+60
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
import re,sys
from pathlib import Path
text=Path(sys.argv[1]).read_text(errors='replace')
cmds=["hv sbi-dispatch","hv sbi-dispatch validate","hv sbi-dispatch base-test","hv sbi-dispatch timer-test","hv sbi-dispatch console-putchar-test","hv sbi-dispatch console-getchar-test","hv sbi-dispatch unknown-test","hv sbi-dispatch unsupported-function-test","hv sbi-dispatch blockers","hv sbi-dispatch reset","hv-dispatch"]
blocks=[]; cursor=0
for c in cmds:
    marker='zign01d> '+c; start=text.find(marker,cursor)
    if start<0: raise SystemExit(f'missing command echo: {c}')
    end=text.find('zign01d> ',start+len(marker)); blocks.append(text[start:] if end<0 else text[start:end]); cursor=len(text) if end<0 else end
def need(i,m):
    if m not in blocks[i]: raise SystemExit(f'missing in {cmds[i]}: {m}\n---block---\n{blocks[i]}')
    print(f'PASS {cmds[i]} contains {m}')
def num(i,key):
    m=re.search(re.escape(key)+r'(-?[0-9]+|0x[0-9a-fA-F]+)', blocks[i])
    if not m: raise SystemExit(f'missing numeric {key} in {cmds[i]}')
    v=m.group(1); return int(v,16) if v.startswith('0x') else int(v)
need(0,'hv: sbi_dispatch=foundation-routing-only'); need(0,'hv: sbi_dispatch.state=empty'); need(0,'hv: sbi_dispatch.has_request=false')
for key in ['base_dispatch_count','timer_dispatch_count','console_dispatch_count','unknown_dispatch_count','validation_count','rejection_count']:
    assert num(0,f'hv: sbi_dispatch.{key}=') == 0, key
need(1,'hv: sbi_dispatch.validate_result=rejected'); need(1,'hv: sbi_dispatch.last_error=no-request'); assert num(1,'hv: sbi_dispatch.rejection_count=') == 1
need(2,'hv: sbi_dispatch.base_test=ok'); need(2,'hv: sbi_dispatch.last_target=base'); need(2,'hv: sbi.last_extension=base'); assert num(2,'hv: sbi_dispatch.base_dispatch_count=') == 1; assert num(2,'hv: sbi.record_count=') >= 1
need(3,'hv: sbi_dispatch.timer_test=ok'); need(3,'hv: sbi_dispatch.last_target=timer'); need(3,'hv: virtual_timer.state=armed'); assert num(3,'hv: sbi_dispatch.timer_dispatch_count=') == 1; assert num(3,'hv: virtual_timer.set_request_count=') >= 1; assert num(3,'hv: virtual_timer.guest_compare_value=') == 100
need(4,'hv: sbi_dispatch.console_putchar_test=ok'); need(4,'hv: sbi_dispatch.last_target=console-putchar'); need(4,'hv: console.last_operation=putchar'); need(4,'hv: console.output_buffer=Z'); assert num(4,'hv: sbi_dispatch.console_dispatch_count=') == 1; assert num(4,'hv: console.output_buffer_length=') >= 1; assert num(4,'hv: console.output_buffer_bytesum=') >= 90
need(5,'hv: sbi_dispatch.console_getchar_test=ok'); need(5,'hv: sbi_dispatch.last_target=console-getchar'); need(5,'hv: sbi_dispatch.getchar_result=no-input'); need(5,'hv: console.getchar_result=no-input'); assert num(5,'hv: sbi_dispatch.console_dispatch_count=') == 2; assert num(5,'hv: console.input_unavailable_count=') == 1
need(6,'hv: sbi_dispatch.unknown_test=rejected'); need(6,'hv: sbi_dispatch.last_target=unknown'); need(6,'hv: sbi_dispatch.last_error=unknown-extension'); assert num(6,'hv: sbi_dispatch.unknown_dispatch_count=') == 1
need(7,'hv: sbi_dispatch.unsupported_function_test=rejected'); need(7,'hv: sbi_dispatch.last_error=unsupported-function'); assert num(7,'hv: sbi_dispatch.rejection_count=') >= 3
need(8,'hv: sbi_dispatch.blockers=deterministic-from-dispatcher-state')
need(9,'hv: sbi_dispatch.reset_result=ok'); need(9,'hv: sbi_dispatch.state=empty'); need(9,'hv: sbi_dispatch.has_request=false'); assert num(9,'hv: sbi_dispatch.base_dispatch_count=') == 0; assert num(9,'hv: sbi_dispatch.timer_dispatch_count=') == 0; assert num(9,'hv: sbi_dispatch.console_dispatch_count=') == 0; assert num(9,'hv: sbi_dispatch.unknown_dispatch_count=') == 0
need(10,'hv: sbi_dispatch.state=empty'); assert num(10,'hv: sbi_dispatch.reset_count=') >= 1
for forbidden in ['linux_guest=supported','linux_guest=booted','linux_boot=ok','buildroot_boot=ok','ubuntu_boot=ok','alpine_boot=ok','guest_execution=supported','guest_entered=yes','first_guest_instruction=executed','second_stage_translation=ACTIVE','hgatp=written','hgatp_write=ok','hgatp=active','printk=works','early_printk=works','linux_console=working','sbi_services=implemented','timer_interrupt_injection=implemented']:
    if forbidden in text: raise SystemExit(f'forbidden marker found: {forbidden}')
for ok in ['sbi_dispatch=foundation-routing-only','sbi_dispatch.base=metadata-only','sbi_dispatch.timer=mediated-metadata-only','sbi_dispatch.console=mediated-buffer-only','linux_guest=not-supported-yet','guest_execution=not-supported-yet','second_stage_translation=MISSING','printk=not-proven-yet','console_guest_integration=not-attempted','guest_entered=no']:
    if ok not in text: raise SystemExit(f'missing non-claim: {ok}')
print('PASS HV20 SBI dispatch integration behavior checks')
PYCHECK
log "HV20 SBI dispatch integration smoke passed transcript=$TRANSCRIPT"; printf 'PASS HV20 SBI dispatch integration smoke\n' | tee -a "$SMOKE_LOG"
