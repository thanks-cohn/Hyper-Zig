#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT/logs/latest"; SMOKE_LOG="$LOG_DIR/smoke-hv-guest-context-v0.log"; QEMU_LOG="$LOG_DIR/qemu-hv-guest-context-v0.log"
TRANSCRIPT="$ROOT/smoke/transcripts/latest-hv-guest-context-v0.txt"; TRANSCRIPT_COPY="$LOG_DIR/qemu-smoke-hv-guest-context-v0-transcript.txt"; ELF="$ROOT/zig-out/bin/zign01d-v0"
mkdir -p "$LOG_DIR" "$ROOT/smoke/transcripts"; : > "$SMOKE_LOG"; : > "$QEMU_LOG"; : > "$TRANSCRIPT"
stamp(){ date -u '+%Y-%m-%dT%H:%M:%SZ'; }
log(){ printf '[%s][ZIGN01D][INFO][SMOKE][SMOKEHV21] %s\n' "$(stamp)" "$*" | tee -a "$SMOKE_LOG"; }
fail(){ printf 'FAIL %s\n' "$*" | tee -a "$SMOKE_LOG" >&2; printf 'inspect: %s %s %s\n' "$SMOKE_LOG" "$QEMU_LOG" "$TRANSCRIPT" | tee -a "$SMOKE_LOG" >&2; exit 1; }
log "checking Zig 0.14.x"; "$ROOT/scripts/check-zig-version.sh" >>"$SMOKE_LOG" 2>&1 || fail "Zig 0.14.x check failed"
log "running build"; "$ROOT/scripts/build.sh" >>"$SMOKE_LOG" 2>&1 || fail "build failed"
[[ -f "$ELF" ]] || fail "missing kernel ELF: $ELF"; command -v qemu-system-riscv64 >/dev/null 2>&1 || fail "qemu-system-riscv64 not found"
QEMU_CMD=(qemu-system-riscv64 -machine virt -cpu rv64 -smp 1 -m 128M -nographic -monitor none -serial stdio -kernel "$ELF")
printf '[%s][ZIGN01D][INFO][QEMU][QEMUHV21] command:' "$(stamp)" | tee -a "$QEMU_LOG" "$SMOKE_LOG"; printf ' %q' "${QEMU_CMD[@]}" | tee -a "$QEMU_LOG" "$SMOKE_LOG"; printf '\n' | tee -a "$QEMU_LOG" "$SMOKE_LOG"
set +e
python3 - "$TRANSCRIPT" "${QEMU_CMD[@]}" <<'PYSMOKE'
import os,selectors,subprocess,sys,time
transcript=sys.argv[1]; cmd=sys.argv[2:]
commands=["hv context","hv context validate","hv context blockers","hv context prepare","hv context registers","hv context ranges","hv context validate","hv context require-handoff-test","hv context prepare","hv context require-fdt-test","hv context prepare","hv context bounds-test","hv context reset","hv-context","shutdown"]
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
cmds=["hv context","hv context validate","hv context blockers","hv context prepare","hv context registers","hv context ranges","hv context validate","hv context require-handoff-test","hv context prepare","hv context require-fdt-test","hv context prepare","hv context bounds-test","hv context reset","hv-context"]
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
need(0,'hv: guest_context=empty'); need(0,'hv: context.ready=false'); need(0,'hv: context.blocker=context-empty')
need(1,'hv: context.validate_result=rejected'); need(1,'hv: context.last_error=context-empty'); assert num(1,'hv: context.reject_count=') == 1
need(2,'hv: context.blockers=deterministic-from-context-state')
need(3,'hv: context.prepare_result=ok'); need(3,'hv: guest_context=prepared'); need(3,'hv: context.ready=true'); need(3,'hv: context.blocker=none')
need(3,'hv: context.a0_boot_hart_id=0'); need(3,'hv: context.a2_reserved=0x0'); need(3,'hv: context.stage2_metadata_ready=true'); need(3,'hv: context.stage2_table_ready=true'); need(3,'hv: context.sbi_dispatch_ready=true')
pc=num(3,'hv: context.pc='); entry=num(3,'hv: context.kernel_entry_gpa='); assert pc == entry
sp=num(3,'hv: context.sp='); base=num(3,'hv: context.guest_memory.base='); size=num(3,'hv: context.guest_memory.size='); assert base <= sp < base+size
fdt=num(3,'hv: context.fdt.gpa='); a1=num(3,'hv: context.a1_fdt_gpa='); assert fdt == a1 and base <= fdt < base+size
ird0=num(3,'hv: context.initrd.start='); ird1=num(3,'hv: context.initrd.end='); assert base <= ird0 <= ird1 <= base+size
need(4,'hv: context.a1_fdt_gpa='); need(4,'hv: context.privilege_metadata=supervisor-mode-metadata-only')
need(5,'hv: context.guest_memory.base='); need(5,'hv: context.initrd.end=')
need(6,'hv: context.validate_result=ok')
need(7,'hv: context.require_handoff_test=rejected'); need(7,'hv: context.last_error=handoff-missing')
need(9,'hv: context.require_fdt_test=rejected'); need(9,'hv: context.last_error=binary-fdt-missing')
need(11,'hv: context.bounds_test=rejected'); need(11,'hv: context.last_error=sp-bounds')
assert num(11,'hv: context.reject_count=') >= 1
need(12,'hv: context.reset_result=ok'); need(12,'hv: guest_context=empty'); need(12,'hv: context.ready=false')
for forbidden in ['linux_guest=supported','linux_guest=booted','linux_boot=ok','buildroot_boot=ok','busybox_boot=ok','alpine_boot=ok','ubuntu_boot=ok','guest_execution=supported','guest_entered=yes','first_guest_instruction=executed','context_switch=executed','trap_return=executed','sret=executed','hret=executed','mret=executed','second_stage_translation=ACTIVE','hgatp=written','hgatp_write=ok','hgatp=active','printk=works','early_printk=works','linux_console=working']:
    if forbidden in text: raise SystemExit(f'forbidden marker found: {forbidden}')
for ok in ['context_switch=not-attempted','trap_return=not-attempted','guest_entered=no','first_guest_instruction=not-executed','linux_guest=not-supported-yet','guest_execution=not-supported-yet','second_stage_translation=MISSING','hgatp_write=not-attempted','printk=not-proven-yet']:
    if ok not in text: raise SystemExit(f'missing non-claim: {ok}')
print('PASS HV21 guest context preparation behavior checks')
PYCHECK
log "HV21 guest context smoke passed transcript=$TRANSCRIPT"; printf 'PASS HV21 guest context smoke\n' | tee -a "$SMOKE_LOG"
