#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT/logs/latest"; SMOKE_LOG="$LOG_DIR/smoke-hv-sbi-console-v0.log"; QEMU_LOG="$LOG_DIR/qemu-hv-sbi-console-v0.log"
TRANSCRIPT="$ROOT/smoke/transcripts/latest-hv-sbi-console-v0.txt"; TRANSCRIPT_COPY="$LOG_DIR/qemu-smoke-hv-sbi-console-v0-transcript.txt"; ELF="$ROOT/zig-out/bin/zign01d-v0"
mkdir -p "$LOG_DIR" "$ROOT/smoke/transcripts"; : > "$SMOKE_LOG"; : > "$QEMU_LOG"; : > "$TRANSCRIPT"
stamp(){ date -u '+%Y-%m-%dT%H:%M:%SZ'; }
log(){ printf '[%s][ZIGN01D][INFO][SMOKE][SMOKEHV19] %s\n' "$(stamp)" "$*" | tee -a "$SMOKE_LOG"; }
fail(){ printf 'FAIL %s\n' "$*" | tee -a "$SMOKE_LOG" >&2; printf 'inspect: %s %s %s\n' "$SMOKE_LOG" "$QEMU_LOG" "$TRANSCRIPT" | tee -a "$SMOKE_LOG" >&2; exit 1; }
log "checking Zig 0.14.x"; "$ROOT/scripts/check-zig-version.sh" >>"$SMOKE_LOG" 2>&1 || fail "Zig 0.14.x check failed"
log "running build"; "$ROOT/scripts/build.sh" >>"$SMOKE_LOG" 2>&1 || fail "build failed"
[[ -f "$ELF" ]] || fail "missing kernel ELF: $ELF"; command -v qemu-system-riscv64 >/dev/null 2>&1 || fail "qemu-system-riscv64 not found"
QEMU_CMD=(qemu-system-riscv64 -machine virt -cpu rv64 -smp 1 -m 128M -nographic -monitor none -serial stdio -kernel "$ELF")
printf '[%s][ZIGN01D][INFO][QEMU][QEMUHV19] command:' "$(stamp)" | tee -a "$QEMU_LOG" "$SMOKE_LOG"; printf ' %q' "${QEMU_CMD[@]}" | tee -a "$QEMU_LOG" "$SMOKE_LOG"; printf '\n' | tee -a "$QEMU_LOG" "$SMOKE_LOG"
set +e
python3 - "$TRANSCRIPT" "${QEMU_CMD[@]}" <<'PYSMOKE'
import os,selectors,subprocess,sys,time
transcript=sys.argv[1]; cmd=sys.argv[2:]
commands=["hv console","hv console validate","hv console blockers","hv console putchar-test","hv console buffer","hv console putstring-test","hv console buffer","hv console getchar-test","hv console invalid-test","hv console overflow-test","hv console blockers","hv console reset","hv-console","shutdown"]
proc=subprocess.Popen(cmd,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.STDOUT); os.set_blocking(proc.stdout.fileno(),False)
sel=selectors.DefaultSelector(); sel.register(proc.stdout,selectors.EVENT_READ); seen=bytearray(); ready=False; status=124; deadline=time.monotonic()+55
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
cmds=["hv console","hv console validate","hv console blockers","hv console putchar-test","hv console buffer","hv console putstring-test","hv console buffer","hv console getchar-test","hv console invalid-test","hv console overflow-test","hv console blockers","hv console reset","hv-console"]
blocks=[]; cursor=0
for c in cmds:
    marker='zign01d> '+c; start=text.find(marker,cursor)
    if start<0: raise SystemExit(f'missing command echo: {c}')
    end=text.find('zign01d> ',start+len(marker)); blocks.append(text[start:] if end<0 else text[start:end]); cursor=len(text) if end<0 else end
def need(i,m):
    if m not in blocks[i]: raise SystemExit(f'missing in {cmds[i]}: {m}\n---block---\n{blocks[i]}')
    print(f'PASS {cmds[i]} contains {m}')
def num(i,key):
    m=re.search(re.escape(key)+r'(0x[0-9a-fA-F]+|[0-9]+)', blocks[i])
    if not m: raise SystemExit(f'missing numeric {key} in {cmds[i]}')
    return int(m.group(1),16) if m.group(1).startswith('0x') else int(m.group(1))
need(0,'hv: sbi_console=foundation-mediation-only'); need(0,'hv: console.state=empty'); need(0,'hv: console.output_buffer_length=0'); need(0,'hv: console.putchar_request_count=0'); need(0,'hv: console.getchar_request_count=0'); need(0,'hv: console.invalid_request_count=0')
need(1,'hv: console.validate_result=rejected'); need(1,'hv: console.last_error=no-request'); need(2,'hv: console.blocker=no-request')
need(3,'hv: console.putchar_test=ok'); need(3,'hv: sbi.has_request=true'); need(3,'hv: sbi.last_extension=legacy-console'); need(3,'hv: console.last_operation=putchar'); need(3,'hv: console.last_character=0x41'); need(3,'hv: console.output_buffer=A')
assert num(3,'hv: console.output_buffer_length=') == 1; assert num(3,'hv: console.output_buffer_bytesum=') == 65; assert num(3,'hv: console.putchar_request_count=') == 1
need(4,'hv: console.output_buffer=A')
need(5,'hv: console.putstring_test=ok'); need(5,'hv: console.output_buffer=AHi!')
assert num(5,'hv: console.output_buffer_length=') == 4; assert num(5,'hv: console.output_buffer_bytesum=') == 65+72+105+33; assert num(5,'hv: console.putchar_request_count=') == 4
need(6,'hv: console.output_buffer=AHi!')
need(7,'hv: console.getchar_test=ok'); need(7,'hv: console.getchar_result=no-input'); assert num(7,'hv: console.getchar_request_count=') == 1; assert num(7,'hv: console.input_unavailable_count=') == 1
need(8,'hv: console.invalid_test=rejected'); assert num(8,'hv: console.invalid_request_count=') == 2; assert num(8,'hv: console.reject_count=') >= 3
need(9,'hv: console.overflow_test=rejected'); need(9,'hv: console.overflow_rejected=true'); assert num(9,'hv: console.output_buffer_length=') == num(9,'hv: console.output_buffer_capacity=')
need(10,'hv: console.blocker=output-overflow')
need(11,'hv: console.reset_result=ok'); need(11,'hv: console.state=empty'); need(11,'hv: console.output_buffer_length=0'); need(11,'hv: console.putchar_request_count=0'); need(11,'hv: console.getchar_request_count=0'); need(11,'hv: console.invalid_request_count=0'); assert num(11,'hv: console.reset_count=') >= 1
need(12,'hv: console.state=empty'); assert num(12,'hv: console.reset_count=') >= 1
for forbidden in ['linux_guest=supported','linux_guest=booted','linux_boot=ok','buildroot_boot=ok','ubuntu_boot=ok','guest_execution=supported','guest_entered=yes','first_guest_instruction=executed','second_stage_translation=ACTIVE','hgatp=written','hgatp_write=ok','hgatp=active','printk=works','early_printk=works','linux_console=working','sbi_services=implemented','dbcn=implemented']:
    if forbidden in text: raise SystemExit(f'forbidden marker found: {forbidden}')
for ok in ['linux_guest=not-supported-yet','guest_execution=not-supported-yet','second_stage_translation=MISSING','printk=not-proven-yet','console_guest_integration=not-attempted','guest_entered=no']:
    if ok not in text: raise SystemExit(f'missing non-claim: {ok}')
print('PASS HV19 SBI console mediation behavior checks')
PYCHECK
log "HV19 SBI console mediation smoke passed transcript=$TRANSCRIPT"; printf 'PASS HV19 SBI console mediation smoke\n' | tee -a "$SMOKE_LOG"
