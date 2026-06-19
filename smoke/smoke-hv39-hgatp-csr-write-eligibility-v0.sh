#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$ROOT/kernel/hypervisor/hgatp_csr_write_eligibility.zig" ]] || { echo missing; exit 1; }
TRANSCRIPT="$ROOT/smoke/transcripts/latest-hv39-hgatp-csr-write-eligibility-v0.txt"; ELF="$ROOT/zig-out/bin/zign01d-v0"
mkdir -p "$ROOT/smoke/transcripts"; : > "$TRANSCRIPT"
"$ROOT/scripts/check-zig-version.sh" >/dev/null
"$ROOT/scripts/build.sh" >/dev/null
command -v qemu-system-riscv64 >/dev/null
QEMU=(qemu-system-riscv64 -machine virt -cpu rv64 -smp 1 -m 128M -nographic -monitor none -serial stdio -kernel "$ELF")
python3 - "$TRANSCRIPT" "${QEMU[@]}" <<'PYQ'
import os,selectors,subprocess,sys,time
chain=['hv hgatp build','hv hgatp validate','hv hgatp-readiness build','hv hgatp-readiness validate','hv hgatp-write-plan build','hv hgatp-write-plan validate','hv hgatp-write-gate build','hv hgatp-write-gate validate','hv hgatp-write-boundary build','hv hgatp-write-boundary validate','hv hgatp-write-attempt build','hv hgatp-write-attempt validate','hv hgatp-csr-interface build','hv hgatp-csr-interface validate','hv hgatp-csr-result build','hv hgatp-csr-result validate','hv hgatp-hardware-write-prep build','hv hgatp-hardware-write-prep validate','hv hgatp-hardware-write-operation build','hv hgatp-hardware-write-operation validate','hv hgatp-execution-dry-run build','hv hgatp-execution-dry-run validate','hv hgatp-execution-dry-run execute','hv hgatp-hardware-executor build','hv hgatp-hardware-executor validate','hv hgatp-hardware-executor execute','hv hgatp-trap-capture-prep build','hv hgatp-trap-capture-prep validate','hv hgatp-trap-capture-prep prepare','hv hgatp-csr-boundary build','hv hgatp-csr-boundary validate','hv hgatp-csr-boundary execute','hv hgatp-csr-boundary fields','hv hgatp-csr-boundary request']
cmds=['hv hgatp-csr-write-eligibility reset','hv hgatp-csr-write-eligibility build']+chain+['hv hgatp-csr-write-eligibility build','hv hgatp-csr-write-eligibility validate','hv hgatp-csr-write-eligibility fields','hv hgatp-csr-write-eligibility request','hv hgatp-csr-write-eligibility steps','hv hgatp-csr-write-eligibility evaluate','hv hgatp-csr-write-eligibility fields','hv hgatp-csr-write-eligibility steps','hv hgatp-csr-write-eligibility result','hv hgatp-csr-write-eligibility trap-slot','hv hgatp-csr-write-eligibility readback','hv hgatp-csr-write-eligibility decision','hv hgatp-csr-boundary reset','hv hgatp-csr-write-eligibility build','shutdown']
tr=sys.argv[1]; q=sys.argv[2:]; p=subprocess.Popen(q,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.STDOUT); os.set_blocking(p.stdout.fileno(),False); sel=selectors.DefaultSelector(); sel.register(p.stdout,selectors.EVENT_READ); seen=bytearray(); ready=False; deadline=time.monotonic()+240
with open(tr,'wb') as out:
 while time.monotonic()<deadline and p.poll() is None:
  for k,_ in sel.select(.05):
   data=k.fileobj.read()
   if data: out.write(data); out.flush(); seen.extend(data)
  if not ready and b'zign01d> ' in seen:
   ready=True
   for c in cmds: p.stdin.write((c+'\n').encode()); p.stdin.flush(); time.sleep(.08)
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
early=block('hv hgatp-csr-write-eligibility build',0)
assert 'blocker=boundary_missing' in early or 'blocker=boundary_invalid' in early
assert 'evaluator_entered=false' in early and 'evaluate_count=0' in early
pre=block('hv hgatp-csr-write-eligibility fields',0)+block('hv hgatp-csr-write-eligibility request')
for m in ['boundary_present=true','boundary_valid=true','eligibility_request_present=true','evaluator_built=true','evaluator_entered=false','evaluator_returned=false','evaluate_count=0']:
 assert 'hgatp_csr_write_eligibility.'+m in pre,m
assert re.search(r'boundary_request_value=0x[0-9a-f]+',pre) and re.search(r'eligibility_request_value=0x[0-9a-f]+',pre)
evalb=block('hv hgatp-csr-write-eligibility evaluate')+block('hv hgatp-csr-write-eligibility fields',1)+block('hv hgatp-csr-write-eligibility steps',1)+block('hv hgatp-csr-write-eligibility result')+block('hv hgatp-csr-write-eligibility trap-slot')+block('hv hgatp-csr-write-eligibility readback')+block('hv hgatp-csr-write-eligibility decision')
for m in ['evaluator_entered=true','evaluator_returned=true','evaluate_count=1','step_source_loaded=true','step_boundary_checked=true','step_request_checked=true','step_policy_checked=true','step_csr_guard_checked=true','step_raw_guard_checked=true','step_denied_before_hardware=true','step_csr_write_skipped=true','step_raw_write_skipped=true','step_result_recorded=true','step_safe_return_recorded=true','eligibility_policy_allows=false','eligibility_policy_denies=true','csr_write_eligible=false','csr_write_ineligible=true','csr_write_denied_before_hardware=true','csr_write_reached=false','csr_write_called=false','csr_write_returned=false','raw_write_reached=false','raw_write_called=false','raw_write_returned=false','trap_slot_present=true','trap_capture_armed=false','trap_observed=false','trap_scause=0','trap_stval=0','trap_sepc=0','readback_slot_present=true','readback_allowed=false','readback_attempted=false','readback_value=0x0','readback_valid=false','hgatp_write_attempted=false','hgatp_write_performed=false','active_stage2=false','guest_entered=false','first_guest_instruction_executed=false']:
 assert 'hgatp_csr_write_eligibility.'+m in evalb,m
assert re.search(r'evaluator_step_count=([1-9][0-9]*)',evalb)
late=block('hv hgatp-csr-write-eligibility build',2); assert 'blocker=boundary_missing' in late or 'blocker=boundary_invalid' in late
for bad in ['linux_boot=ok','busybox_boot=ok','alpine_boot=ok','guest_entered=yes','hgatp=written','hgatp_write=ok','second_stage_translation=ACTIVE','trap_return=executed']:
 assert bad not in text,bad
PYC
