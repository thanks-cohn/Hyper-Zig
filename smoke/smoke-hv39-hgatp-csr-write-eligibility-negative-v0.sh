#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TRANSCRIPT="$ROOT/smoke/transcripts/latest-hv39-hgatp-csr-write-eligibility-negative-v0.txt"; ELF="$ROOT/zig-out/bin/zign01d-v0"
mkdir -p "$ROOT/smoke/transcripts"; : > "$TRANSCRIPT"
"$ROOT/scripts/check-zig-version.sh" >/dev/null
"$ROOT/scripts/build.sh" >/dev/null
command -v qemu-system-riscv64 >/dev/null
QEMU=(qemu-system-riscv64 -machine virt -cpu rv64 -smp 1 -m 128M -nographic -monitor none -serial stdio -kernel "$ELF")
python3 - "$TRANSCRIPT" "${QEMU[@]}" <<'PYQ'
import os,selectors,subprocess,sys,time
cmds=['hv hgatp-csr-write-eligibility require-boundary-test','hv hgatp-csr-write-eligibility invalid-boundary-test','hv hgatp-csr-write-eligibility source-integrity-test','hv hgatp-csr-write-eligibility request-value-test','hv hgatp-csr-write-eligibility policy-allows-test','hv hgatp-csr-write-eligibility csr-eligible-test','hv hgatp-csr-write-eligibility csr-reached-test','hv hgatp-csr-write-eligibility csr-called-test','hv hgatp-csr-write-eligibility raw-reached-test','hv hgatp-csr-write-eligibility raw-called-test','hv hgatp-csr-write-eligibility fake-trap-test','hv hgatp-csr-write-eligibility fake-fault-test','hv hgatp-csr-write-eligibility fake-readback-test','hv hgatp-csr-write-eligibility write-attempted-test','hv hgatp-csr-write-eligibility write-performed-test','hv hgatp-csr-write-eligibility active-stage2-test','hv hgatp-csr-write-eligibility guest-entered-test','hv hgatp-csr-write-eligibility first-instruction-test','hv hgatp-csr-write-eligibility invariant-consumption-test','hv hgatp-csr-write-eligibility invariant-corruption-test','shutdown']
tr=sys.argv[1]; q=sys.argv[2:]; p=subprocess.Popen(q,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.STDOUT); os.set_blocking(p.stdout.fileno(),False); sel=selectors.DefaultSelector(); sel.register(p.stdout,selectors.EVENT_READ); seen=bytearray(); ready=False; deadline=time.monotonic()+180
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
def block(cmd):
 m=re.search(re.escape('zign01d> '+cmd)+r'\r?\n',text); assert m,'missing '+cmd
 s=m.end(); e=text.find('zign01d> ',s); return text[s: len(text) if e<0 else e]
pairs={'require-boundary-test':'boundary_missing','invalid-boundary-test':'boundary_invalid','source-integrity-test':'source_mutated','request-value-test':'request_value_mismatch','policy-allows-test':'policy_allows_hardware_write','csr-eligible-test':'csr_write_eligible','csr-reached-test':'csr_write_reached','csr-called-test':'csr_write_called','raw-reached-test':'raw_write_reached','raw-called-test':'raw_write_called','fake-trap-test':'fake_trap_observed','fake-fault-test':'fake_fault_observed','fake-readback-test':'fake_readback_observed','write-attempted-test':'hgatp_write_attempted','write-performed-test':'hgatp_write_performed','active-stage2-test':'active_stage2_forbidden','guest-entered-test':'guest_entered_forbidden','first-instruction-test':'first_instruction_forbidden','invariant-corruption-test':'source_mutated'}
for cmd,blk in pairs.items():
 b=block('hv hgatp-csr-write-eligibility '+cmd); assert 'blocker='+blk in b,(cmd,blk,b)
assert 'invariant_consumption_test=' in block('hv hgatp-csr-write-eligibility invariant-consumption-test')
for bad in ['linux_boot=ok','busybox_boot=ok','alpine_boot=ok','guest_entered=yes','hgatp=written','hgatp_write=ok','second_stage_translation=ACTIVE','trap_return=executed']:
 assert bad not in text,bad
PYC
