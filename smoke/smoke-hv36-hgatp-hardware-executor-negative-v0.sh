#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TRANSCRIPT="$ROOT/smoke/transcripts/latest-hv36-hgatp-hardware-executor-negative-v0.txt"; ELF="$ROOT/zig-out/bin/zign01d-v0"
mkdir -p "$ROOT/smoke/transcripts"; : > "$TRANSCRIPT"
"$ROOT/scripts/check-zig-version.sh" >/dev/null
"$ROOT/scripts/build.sh" >/dev/null
command -v qemu-system-riscv64 >/dev/null
QEMU=(qemu-system-riscv64 -machine virt -cpu rv64 -smp 1 -m 128M -nographic -monitor none -serial stdio -kernel "$ELF")
python3 - "$TRANSCRIPT" "${QEMU[@]}" <<'PY'
import os,selectors,subprocess,sys,time
base=['hv hgatp build','hv hgatp validate','hv hgatp-readiness build','hv hgatp-readiness validate','hv hgatp-write-plan build','hv hgatp-write-plan validate','hv hgatp-write-gate build','hv hgatp-write-gate validate','hv hgatp-write-boundary build','hv hgatp-write-boundary validate','hv hgatp-write-attempt build','hv hgatp-write-attempt validate','hv hgatp-csr-interface build','hv hgatp-csr-interface validate','hv hgatp-csr-result build','hv hgatp-csr-result validate','hv hgatp-hardware-write-prep build','hv hgatp-hardware-write-prep validate','hv hgatp-hardware-write-operation build','hv hgatp-hardware-write-operation validate','hv hgatp-execution-dry-run build','hv hgatp-execution-dry-run validate','hv hgatp-execution-dry-run execute']
tests=['require-dry-run-test','invalid-dry-run-test','source-integrity-test','request-value-test','policy-allows-test','boundary-bypass-test','csr-reached-test','csr-called-test','raw-reached-test','raw-called-test','fake-trap-test','fake-readback-test','write-attempted-test','write-performed-test','active-stage2-test','guest-entered-test','first-instruction-test','invariant-consumption-test','invariant-corruption-test']
cmds=base+['hv hgatp-hardware-executor '+t for t in tests]+['shutdown']
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
text=open(sys.argv[1],errors='replace').read()
expect={'require-dry-run-test':'dry_run_missing','invalid-dry-run-test':'dry_run_invalid','source-integrity-test':'source_mutated','request-value-test':'request_value_mismatch','policy-allows-test':'policy_allows_hardware_write','boundary-bypass-test':'boundary_bypassed','csr-reached-test':'csr_write_reached','csr-called-test':'csr_write_called','raw-reached-test':'raw_write_reached','raw-called-test':'raw_write_called','fake-trap-test':'fake_trap_observed','fake-readback-test':'fake_readback_observed','write-attempted-test':'hgatp_write_attempted','write-performed-test':'hgatp_write_performed','active-stage2-test':'active_stage2_forbidden','guest-entered-test':'guest_entered_forbidden','first-instruction-test':'first_instruction_forbidden'}
for t,b in expect.items():
 m=re.search(re.escape('zign01d> hv hgatp-hardware-executor '+t)+r'\r?\n', text); assert m, 'missing '+t
 e=text.find('zign01d> ', m.end()); blk=text[m.end(): len(text) if e<0 else e]; assert 'blocker='+b in blk, (t,b,blk)
for t in ['invariant-consumption-test','invariant-corruption-test']:
 m=re.search(re.escape('zign01d> hv hgatp-hardware-executor '+t)+r'\r?\n', text); assert m, 'missing '+t
 e=text.find('zign01d> ', m.end()); blk=text[m.end(): len(text) if e<0 else e]; assert 'result=ok' in blk, blk
for bad in ['linux_boot=ok','busybox_boot=ok','alpine_boot=ok','guest_entered=yes','trap_return=executed','hgatp=written','hgatp_write=ok','hgatp=active','second_stage_translation=ACTIVE']:
 assert bad not in text, bad
PY
