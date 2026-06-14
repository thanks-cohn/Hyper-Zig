#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT/logs/latest"; SMOKE_LOG="$LOG_DIR/smoke-hv-entry-stub-v0.log"; QEMU_LOG="$LOG_DIR/qemu-hv-entry-stub-v0.log"
TRANSCRIPT="$ROOT/smoke/transcripts/latest-hv-entry-stub-v0.txt"; TRANSCRIPT_COPY="$LOG_DIR/qemu-smoke-hv-entry-stub-v0-transcript.txt"; ELF="$ROOT/zig-out/bin/zign01d-v0"
mkdir -p "$LOG_DIR" "$ROOT/smoke/transcripts"; : > "$SMOKE_LOG"; : > "$QEMU_LOG"; : > "$TRANSCRIPT"
stamp(){ date -u '+%Y-%m-%dT%H:%M:%SZ'; }
log(){ printf '[%s][ZIGN01D][INFO][SMOKE][SMOKEHV23] %s\n' "$(stamp)" "$*" | tee -a "$SMOKE_LOG"; }
fail(){ printf 'FAIL %s\n' "$*" | tee -a "$SMOKE_LOG" >&2; printf 'inspect: %s %s %s\n' "$SMOKE_LOG" "$QEMU_LOG" "$TRANSCRIPT" | tee -a "$SMOKE_LOG" >&2; exit 1; }
log "checking Zig 0.14.x"; "$ROOT/scripts/check-zig-version.sh" >>"$SMOKE_LOG" 2>&1 || fail "Zig 0.14.x check failed"
log "running build"; "$ROOT/scripts/build.sh" >>"$SMOKE_LOG" 2>&1 || fail "build failed"
[[ -f "$ELF" ]] || fail "missing kernel ELF: $ELF"; command -v qemu-system-riscv64 >/dev/null 2>&1 || fail "qemu-system-riscv64 not found"
QEMU_CMD=(qemu-system-riscv64 -machine virt -cpu rv64 -smp 1 -m 128M -nographic -monitor none -serial stdio -kernel "$ELF")
printf '[%s][ZIGN01D][INFO][QEMU][QEMUHV23] command:' "$(stamp)" | tee -a "$QEMU_LOG" "$SMOKE_LOG"; printf ' %q' "${QEMU_CMD[@]}" | tee -a "$QEMU_LOG" "$SMOKE_LOG"; printf '\n' | tee -a "$QEMU_LOG" "$SMOKE_LOG"
set +e
python3 - "$TRANSCRIPT" "${QEMU_CMD[@]}" <<'PYSMOKE'
import os,selectors,subprocess,sys,time
transcript=sys.argv[1]; cmd=sys.argv[2:]
commands=["hv entry-stub","hv entry-stub validate","hv entry-stub blockers","hv entry-stub prepare","hv trap-plan registers","hv entry-stub registers","hv entry-stub gates","hv entry-stub descriptor","hv entry-stub checksum","hv entry-stub validate","hv entry-stub attempt","hv entry-stub require-plan-test","hv entry-stub prepare","hv entry-stub pc-bounds-test","hv entry-stub prepare","hv entry-stub sp-bounds-test","hv entry-stub prepare","hv entry-stub fdt-bounds-test","hv entry-stub prepare","hv entry-stub active-stage2-test","hv entry-stub reset","hv-entry-stub","shutdown"]
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
                    proc.stdin.write((c+'\n').encode()); proc.stdin.flush(); time.sleep(0.14)
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
cmds=["hv entry-stub","hv entry-stub validate","hv entry-stub blockers","hv entry-stub prepare","hv trap-plan registers","hv entry-stub registers","hv entry-stub gates","hv entry-stub descriptor","hv entry-stub checksum","hv entry-stub validate","hv entry-stub attempt","hv entry-stub require-plan-test","hv entry-stub prepare","hv entry-stub pc-bounds-test","hv entry-stub prepare","hv entry-stub sp-bounds-test","hv entry-stub prepare","hv entry-stub fdt-bounds-test","hv entry-stub prepare","hv entry-stub active-stage2-test","hv entry-stub reset","hv-entry-stub"]
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
need(0,'hv: entry_stub=empty'); need(0,'hv: entry_stub.ready=false')
need(1,'hv: entry_stub.validate_result=rejected'); need(1,'hv: entry_stub.last_error=stub-empty'); assert num(1,'hv: entry_stub.reject_count=') == 1
need(2,'hv: entry_stub.blockers=deterministic-from-entry-stub-state')
need(3,'hv: entry_stub.prepare_result=ok'); need(3,'hv: entry_stub=prepared'); need(3,'hv: entry_stub.ready=true'); need(3,'hv: entry_stub.source_trap_plan_state=validated')
need(3,'hv: entry_stub.stage2_metadata_ready=true'); need(3,'hv: entry_stub.stage2_table_ready=true'); need(3,'hv: entry_stub.active_stage2=false'); need(3,'hv: hgatp_write=not-attempted'); need(3,'hv: h_extension=unknown reason=no-safe-detection-yet')
pc=num(3,'hv: entry_stub.pc='); sp=num(3,'hv: entry_stub.sp='); a0=num(3,'hv: entry_stub.a0_boot_hart_id='); a1=num(3,'hv: entry_stub.a1_fdt_gpa=')
base=num(3,'hv: entry_stub.guest_memory.base='); size=num(3,'hv: entry_stub.guest_memory.size=')
assert base <= pc < base+size and base <= sp < base+size and base <= a1 < base+size and a0 == 0
cpc=num(4,'hv: trap_plan.pc='); csp=num(4,'hv: trap_plan.sp='); ca1=num(4,'hv: trap_plan.a1_fdt_gpa=')
assert pc == cpc and sp == csp and a1 == ca1
need(5,'hv: entry_stub.a2_reserved=0x0'); need(5,'hv: entry_stub.trap_return_kind=software-entry-stub-only')
need(7,'hv: entry_stub.descriptor.address='); need(7,'hv: entry_stub.descriptor.kind=software-only-not-executable')
chk1=num(7,'hv: entry_stub.descriptor.checksum='); chk2=num(8,'hv: entry_stub.checksum='); assert chk1 == chk2 and chk1 != 0
need(9,'hv: entry_stub.validate_result=ok')
before=num(9,'hv: entry_stub.reject_count=')
need(10,'hv: guarded_entry_attempt=blocked'); need(10,'hv: guarded_entry_attempt_result=safe-denied'); assert num(10,'hv: entry_stub.attempt_count=') >= 1
need(11,'hv: entry_stub.require_plan_test=rejected'); need(11,'hv: entry_stub.last_error=trap-plan-missing')
need(13,'hv: entry_stub.pc_bounds_test=rejected'); need(13,'hv: entry_stub.last_error=pc-bounds')
need(15,'hv: entry_stub.sp_bounds_test=rejected'); need(15,'hv: entry_stub.last_error=sp-bounds')
need(17,'hv: entry_stub.fdt_bounds_test=rejected'); need(17,'hv: entry_stub.last_error=fdt-bounds')
need(19,'hv: entry_stub.active_stage2_test=rejected'); need(19,'hv: entry_stub.last_error=active-stage2-forbidden')
after=num(19,'hv: entry_stub.reject_count='); assert after > before
need(20,'hv: entry_stub.reset_result=ok'); need(20,'hv: entry_stub=empty'); need(20,'hv: entry_stub.ready=false')
for forbidden in ['linux_guest=supported','linux_guest=booted','linux_boot=ok','buildroot_boot=ok','busybox_boot=ok','alpine_boot=ok','ubuntu_boot=ok','guest_execution=supported','guest_entered=yes','first_guest_instruction=executed','context_switch=executed','entry_stub=executed','trap_return=executed','trap_return=ok','sret=executed','hret=executed','mret=executed','second_stage_translation=ACTIVE','hgatp=written','hgatp_write=ok','hgatp=active','printk=works','early_printk=works','linux_console=working']:
    if forbidden in text: raise SystemExit(f'forbidden marker found: {forbidden}')
for ok in ['trap_return=not-executed','guest_entered=no','first_guest_instruction=not-executed','linux_guest=not-supported-yet','guest_execution=not-supported-yet','second_stage_translation=MISSING','hgatp_write=not-attempted','printk=not-proven-yet']:
    if ok not in text: raise SystemExit(f'missing non-claim: {ok}')
print('PASS HV23 guest entry assembly preparation behavior checks')
PYCHECK
log "HV23 entry stub smoke passed transcript=$TRANSCRIPT"; printf 'PASS HV23 guest entry assembly preparation smoke\n' | tee -a "$SMOKE_LOG"
