#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$ROOT/kernel/hypervisor/hgatp_hardware_executor.zig" ]] || { echo missing; exit 1; }
TRANSCRIPT="$ROOT/smoke/transcripts/latest-hv36-hgatp-hardware-executor-v0.txt"; ELF="$ROOT/zig-out/bin/zign01d-v0"
mkdir -p "$ROOT/smoke/transcripts"; : > "$TRANSCRIPT"
"$ROOT/scripts/check-zig-version.sh" >/dev/null
"$ROOT/scripts/build.sh" >/dev/null
command -v qemu-system-riscv64 >/dev/null
QEMU=(qemu-system-riscv64 -machine virt -cpu rv64 -smp 1 -m 128M -nographic -monitor none -serial stdio -kernel "$ELF")
python3 - "$TRANSCRIPT" "${QEMU[@]}" <<'PY'
import os,selectors,subprocess,sys,time
chain=['hv hgatp build','hv hgatp validate','hv hgatp-readiness build','hv hgatp-readiness validate','hv hgatp-write-plan build','hv hgatp-write-plan validate','hv hgatp-write-gate build','hv hgatp-write-gate validate','hv hgatp-write-boundary build','hv hgatp-write-boundary validate','hv hgatp-write-attempt build','hv hgatp-write-attempt validate','hv hgatp-csr-interface build','hv hgatp-csr-interface validate','hv hgatp-csr-result build','hv hgatp-csr-result validate','hv hgatp-hardware-write-prep build','hv hgatp-hardware-write-prep validate','hv hgatp-hardware-write-operation build','hv hgatp-hardware-write-operation validate','hv hgatp-execution-dry-run build','hv hgatp-execution-dry-run validate','hv hgatp-execution-dry-run execute','hv hgatp-execution-dry-run fields','hv hgatp-execution-dry-run request']
cmds=['hv hgatp-hardware-executor reset','hv hgatp-hardware-executor build']+chain+['hv hgatp-hardware-executor build','hv hgatp-hardware-executor validate','hv hgatp-hardware-executor fields','hv hgatp-hardware-executor request','hv hgatp-hardware-executor steps','hv hgatp-hardware-executor execute','hv hgatp-hardware-executor fields','hv hgatp-hardware-executor steps','hv hgatp-hardware-executor result','hv hgatp-hardware-executor trap-slot','hv hgatp-hardware-executor readback','hv hgatp-hardware-executor decision','hv hgatp-execution-dry-run reset','hv hgatp-hardware-executor build','shutdown']
tr=sys.argv[1]; q=sys.argv[2:]; p=subprocess.Popen(q,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.STDOUT); os.set_blocking(p.stdout.fileno(),False); sel=selectors.DefaultSelector(); sel.register(p.stdout,selectors.EVENT_READ); seen=bytearray(); ready=False; deadline=time.monotonic()+120
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
PY
python3 - "$TRANSCRIPT" <<'PY'
import re,sys
text=open(sys.argv[1],errors='replace').read(); cmds=[m.group(1) for m in re.finditer(r'zign01d> (hv[^\r\n]+)', text)]
def block(cmd, nth=0):
 p=0; count=0
 while True:
  m=re.search(re.escape('zign01d> '+cmd)+r'\r?\n', text[p:]); assert m, 'missing '+cmd
  s=p+m.end(); e=text.find('zign01d> ', s); e=len(text) if e<0 else e
  if count==nth: return text[s:e]
  p=e; count+=1
b0=block('hv hgatp-hardware-executor build',0); assert ('blocker=dry_run_missing' in b0 or 'blocker=dry_run_invalid' in b0); assert 'executor_entered=false' in b0 and 'execute_count=0' in b0
hv35f=block('hv hgatp-execution-dry-run fields'); hv35r=block('hv hgatp-execution-dry-run request')
b=block('hv hgatp-hardware-executor fields',0)
for m in ['dry_run_present=true','dry_run_valid=true','hardware_request_present=true','executor_built=true','executor_entered=false','executor_returned=false','execute_count=0']: assert 'hgatp_hardware_executor.'+m in b, m
req=block('hv hgatp-hardware-executor request')
for name in ['request_value','request_checksum']:
 d=re.search('dry_run_'+name+'=(0x[0-9a-f]+)', req, re.I); h=re.search('hardware_'+name+'=(0x[0-9a-f]+)', req, re.I); assert d and h and d.group(1).lower()==h.group(1).lower()
a=block('hv hgatp-hardware-executor fields',1)+block('hv hgatp-hardware-executor steps',1)+block('hv hgatp-hardware-executor result')+block('hv hgatp-hardware-executor trap-slot')+block('hv hgatp-hardware-executor readback')
for m in ['executor_entered=true','executor_returned=true','execute_count=1','step_source_loaded=true','step_boundary_checked=true','step_policy_checked=true','step_csr_guard_checked=true','step_raw_write_guard_checked=true','step_denied_before_csr=true','step_blocked_before_raw_write=true','step_csr_write_skipped=true','step_raw_write_skipped=true','step_result_recorded=true','step_safe_return_recorded=true','hardware_policy_allows=false','hardware_policy_denies=true','hardware_denied_before_csr=true','hardware_blocked_before_raw_write=true','hardware_reached_csr_write=false','hardware_called_csr_write=false','hardware_reached_raw_write=false','hardware_called_raw_write=false','hardware_returned_from_raw_write=false','csr_write_function_known=true','csr_write_function_allowed=false','csr_write_function_called=false','raw_write_function_known=true','raw_write_function_allowed=false','raw_write_function_called=false','trap_slot_present=true','trap_capture_armed=false','trap_observed=false','trap_scause=0','trap_stval=0','trap_sepc=0','readback_slot_present=true','readback_allowed=false','readback_attempted=false','readback_value=0x0','readback_valid=false','hgatp_write_attempted=false','hgatp_write_performed=false','active_stage2=false','guest_entered=false','first_guest_instruction_executed=false']: assert 'hgatp_hardware_executor.'+m in a, m
assert re.search(r'executor_step_count=([1-9][0-9]*)', a); assert 'result_code=hardware_executor_denied_before_csr' in a; assert 'decision=hardware_executor_denied_before_csr' in block('hv hgatp-hardware-executor decision')
last=block('hv hgatp-hardware-executor build',2); assert ('blocker=dry_run_missing' in last or 'blocker=dry_run_invalid' in last)
for bad in ['linux_boot=ok','busybox_boot=ok','alpine_boot=ok','guest_entered=yes','trap_return=executed','hgatp=written','hgatp_write=ok','hgatp=active','second_stage_translation=ACTIVE']:
 assert bad not in text, bad
PY
