#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$ROOT/kernel/hypervisor/hgatp_csr_write_boundary.zig" ]] || { echo missing; exit 1; }
TRANSCRIPT="$ROOT/smoke/transcripts/latest-hv38-csr-boundary-v0.txt"; ELF="$ROOT/zig-out/bin/zign01d-v0"
mkdir -p "$ROOT/smoke/transcripts"; : > "$TRANSCRIPT"
"$ROOT/scripts/check-zig-version.sh" >/dev/null
"$ROOT/scripts/build.sh" >/dev/null
command -v qemu-system-riscv64 >/dev/null
QEMU=(qemu-system-riscv64 -machine virt -cpu rv64 -smp 1 -m 128M -nographic -monitor none -serial stdio -kernel "$ELF")
python3 - "$TRANSCRIPT" "${QEMU[@]}" <<'PYQ'
import os,selectors,subprocess,sys,time
chain=['hv hgatp build','hv hgatp validate','hv hgatp-readiness build','hv hgatp-readiness validate','hv hgatp-write-plan build','hv hgatp-write-plan validate','hv hgatp-write-gate build','hv hgatp-write-gate validate','hv hgatp-write-boundary build','hv hgatp-write-boundary validate','hv hgatp-write-attempt build','hv hgatp-write-attempt validate','hv hgatp-csr-interface build','hv hgatp-csr-interface validate','hv hgatp-csr-result build','hv hgatp-csr-result validate','hv hgatp-hardware-write-prep build','hv hgatp-hardware-write-prep validate','hv hgatp-hardware-write-operation build','hv hgatp-hardware-write-operation validate','hv hgatp-execution-dry-run build','hv hgatp-execution-dry-run validate','hv hgatp-execution-dry-run execute','hv hgatp-hardware-executor build','hv hgatp-hardware-executor validate','hv hgatp-hardware-executor execute','hv hgatp-trap-capture-prep build','hv hgatp-trap-capture-prep validate','hv hgatp-trap-capture-prep prepare']
cmds=['hv csr-boundary reset','hv csr-boundary create']+chain+['hv csr-boundary create','hv csr-boundary validate','hv csr-boundary inspect','hv csr-boundary execute','hv csr-boundary inspect','hv csr-boundary denial-test','hv csr-boundary replay-test','hv csr-boundary no-write-invariant-test','hv csr-boundary reset','hv csr-boundary inspect','shutdown']
tr=sys.argv[1]; q=sys.argv[2:]; p=subprocess.Popen(q,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.STDOUT); os.set_blocking(p.stdout.fileno(),False); sel=selectors.DefaultSelector(); sel.register(p.stdout,selectors.EVENT_READ); seen=bytearray(); ready=False; deadline=time.monotonic()+180
with open(tr,'wb') as out:
 while time.monotonic()<deadline and p.poll() is None:
  for k,_ in sel.select(.05):
   data=k.fileobj.read()
   if data: out.write(data); out.flush(); seen.extend(data)
  if not ready and b'zign01d> ' in seen:
   ready=True
   for c in cmds: p.stdin.write((c+'\n').encode()); p.stdin.flush(); time.sleep(.1)
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
early=block('hv csr-boundary create',0); assert 'blocker=missing_trap_capture' in early or 'blocker=invalid_trap_capture' in early
created=block('hv csr-boundary create',1)+block('hv csr-boundary validate')+block('hv csr-boundary inspect',0)
for m in ['source_present=true','source_valid=true','fingerprint_unchanged=true','authorization_evaluated=true','authorized_to_prepare=true','authorized_to_write=false','denied_before_csr=true','create_count=2','validate_count=1','hgatp_write_attempted=false','hgatp_write_performed=false','active_stage2=false','guest_entered=false','first_guest_instruction_executed=false']:
 assert 'csr_boundary.'+m in created,m
exe=block('hv csr-boundary execute')+block('hv csr-boundary inspect',1)
for m in ['execute_count=1','record_present=true','record_sequence=1','record_denied_before_csr=true','record_ready_without_write=true','record_hgatp_write_attempted=false','record_hgatp_write_performed=false','hgatp_write_attempted=false','hgatp_write_performed=false','active_stage2=false','guest_entered=false','first_guest_instruction_executed=false']:
 assert 'csr_boundary.'+m in exe,m
assert 'execute_result=execution_ready_without_write blocker=none' in exe
denial=block('hv csr-boundary denial-test'); assert 'denial_test=rejected blocker=csr_called' in denial and 'csr_boundary.denial_count=' in denial
replay=block('hv csr-boundary replay-test'); assert 'replay_test=rejected blocker=replay_detected' in replay
inv=block('hv csr-boundary no-write-invariant-test')
assert 'csr_boundary.no_write_invariant_result=ok' in inv
reset=block('hv csr-boundary inspect',2)
for m in ['state=empty','create_count=0','validate_count=0','execute_count=0','record_present=false','hgatp_write_attempted=false','hgatp_write_performed=false','active_stage2=false','guest_entered=false','first_guest_instruction_executed=false']:
 assert m in reset,m
for bad in ['hgatp=written','hgatp_write=ok','second_stage_translation=ACTIVE','guest_entered=yes','trap_return=executed','linux_boot=ok','busybox_boot=ok','alpine_boot=ok']:
 assert bad not in text,bad
PYC
