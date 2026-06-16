#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$ROOT/kernel/hypervisor/hgatp_trap_capture_prep.zig" ]] || { echo missing; exit 1; }
TRANSCRIPT="$ROOT/smoke/transcripts/latest-hv37-hgatp-trap-capture-prep-v0.txt"; ELF="$ROOT/zig-out/bin/zign01d-v0"
mkdir -p "$ROOT/smoke/transcripts"; : > "$TRANSCRIPT"
"$ROOT/scripts/check-zig-version.sh" >/dev/null
"$ROOT/scripts/build.sh" >/dev/null
command -v qemu-system-riscv64 >/dev/null
QEMU=(qemu-system-riscv64 -machine virt -cpu rv64 -smp 1 -m 128M -nographic -monitor none -serial stdio -kernel "$ELF")
python3 - "$TRANSCRIPT" "${QEMU[@]}" <<'PYQ'
import os,selectors,subprocess,sys,time
chain=['hv hgatp build','hv hgatp validate','hv hgatp-readiness build','hv hgatp-readiness validate','hv hgatp-write-plan build','hv hgatp-write-plan validate','hv hgatp-write-gate build','hv hgatp-write-gate validate','hv hgatp-write-boundary build','hv hgatp-write-boundary validate','hv hgatp-write-attempt build','hv hgatp-write-attempt validate','hv hgatp-csr-interface build','hv hgatp-csr-interface validate','hv hgatp-csr-result build','hv hgatp-csr-result validate','hv hgatp-hardware-write-prep build','hv hgatp-hardware-write-prep validate','hv hgatp-hardware-write-operation build','hv hgatp-hardware-write-operation validate','hv hgatp-execution-dry-run build','hv hgatp-execution-dry-run validate','hv hgatp-execution-dry-run execute','hv hgatp-hardware-executor build','hv hgatp-hardware-executor validate','hv hgatp-hardware-executor execute','hv hgatp-hardware-executor fields','hv hgatp-hardware-executor result']
cmds=['hv hgatp-trap-capture-prep reset','hv hgatp-trap-capture-prep build']+chain+['hv hgatp-trap-capture-prep build','hv hgatp-trap-capture-prep validate','hv hgatp-trap-capture-prep fields','hv hgatp-trap-capture-prep trap-slot','hv hgatp-trap-capture-prep fault-slot','hv hgatp-trap-capture-prep prepare','hv hgatp-trap-capture-prep fields','hv hgatp-trap-capture-prep trap-slot','hv hgatp-trap-capture-prep fault-slot','hv hgatp-trap-capture-prep result','hv hgatp-trap-capture-prep decision','shutdown']
tr=sys.argv[1]; q=sys.argv[2:]; p=subprocess.Popen(q,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.STDOUT); os.set_blocking(p.stdout.fileno(),False); sel=selectors.DefaultSelector(); sel.register(p.stdout,selectors.EVENT_READ); seen=bytearray(); ready=False; deadline=time.monotonic()+160
with open(tr,'wb') as out:
 while time.monotonic()<deadline and p.poll() is None:
  for k,_ in sel.select(.05):
   data=k.fileobj.read()
   if data: out.write(data); out.flush(); seen.extend(data)
  if not ready and b'zign01d> ' in seen:
   ready=True
   for c in cmds: p.stdin.write((c+'\n').encode()); p.stdin.flush(); time.sleep(.12)
 if p.poll() is None: p.terminate(); time.sleep(.2)
 while True:
  data=p.stdout.read()
  if not data: break
  out.write(data)
sys.exit(0 if ready else 125)
PYQ
python3 - "$TRANSCRIPT" <<'PYC'
import re,sys
text=open(sys.argv[1],errors='replace').read()
def block(cmd,nth=0):
 p=0; c=0
 while True:
  m=re.search(re.escape('zign01d> '+cmd)+r'\r?\n',text[p:]); assert m,'missing '+cmd
  s=p+m.end(); e=text.find('zign01d> ',s); e=len(text) if e<0 else e
  if c==nth: return text[s:e]
  p=e; c+=1
b0=block('hv hgatp-trap-capture-prep build',0); assert ('blocker=missing_executor' in b0 or 'blocker=invalid_executor' in b0); assert 'prepare_entered=false' in b0 and 'prepare_count=0' in b0
pre=block('hv hgatp-trap-capture-prep fields',0)+block('hv hgatp-trap-capture-prep trap-slot',0)+block('hv hgatp-trap-capture-prep fault-slot',0)
for m in ['executor_present=true','executor_valid=true','capture_request_present=true','prepare_entered=false','prepare_returned=false','prepare_count=0','trap_slot_present=true','trap_observed=false','fault_slot_present=true','fault_observed=false']: assert 'hgatp_trap_capture_prep.'+m in pre,m
post=block('hv hgatp-trap-capture-prep fields',1)+block('hv hgatp-trap-capture-prep trap-slot',1)+block('hv hgatp-trap-capture-prep fault-slot',1)+block('hv hgatp-trap-capture-prep result')+block('hv hgatp-trap-capture-prep decision')
for m in ['prepare_entered=true','prepare_returned=true','prepare_count=1','step_source_loaded=true','step_executor_checked=true','step_trap_slot_prepared=true','step_fault_slot_prepared=true','step_csr_guard_checked=true','step_raw_guard_checked=true','step_no_trap_observed=true','step_no_fault_observed=true','step_result_recorded=true','step_safe_return_recorded=true','csr_write_function_called=false','raw_write_function_called=false','trap_slot_present=true','trap_capture_armed=false','trap_observed=false','trap_scause=0','trap_stval=0','trap_sepc=0','fault_slot_present=true','fault_capture_armed=false','fault_observed=false','fault_scause=0','fault_stval=0','fault_sepc=0','readback_attempted=false','readback_valid=false','hgatp_write_attempted=false','hgatp_write_performed=false','active_stage2=false','guest_entered=false','first_guest_instruction_executed=false','safe_denied_before_csr=true']:
 assert 'hgatp_trap_capture_prep.'+m in post,m
assert re.search(r'hgatp_trap_capture_prep.prepare_step_count=([1-9][0-9]*)',post)
for bad in ['linux_boot=ok','busybox_boot=ok','alpine_boot=ok','guest_entered=yes','trap_return=executed','hgatp=written','hgatp_write=ok','hgatp=active','second_stage_translation=ACTIVE']: assert bad not in text,bad
PYC
