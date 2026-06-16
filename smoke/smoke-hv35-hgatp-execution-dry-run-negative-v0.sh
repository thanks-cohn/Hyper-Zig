#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TRANSCRIPT="$ROOT/smoke/transcripts/latest-hv35-hgatp-execution-dry-run-negative-v0.txt"; ELF="$ROOT/zig-out/bin/zign01d-v0"
mkdir -p "$ROOT/smoke/transcripts"; : > "$TRANSCRIPT"
"$ROOT/scripts/check-zig-version.sh" >/dev/null
"$ROOT/scripts/build.sh" >/dev/null
command -v qemu-system-riscv64 >/dev/null
QEMU=(qemu-system-riscv64 -machine virt -cpu rv64 -smp 1 -m 128M -nographic -monitor none -serial stdio -kernel "$ELF")
python3 - "$TRANSCRIPT" "${QEMU[@]}" <<'PY'
import os,selectors,subprocess,sys,time
base=['hv hgatp build','hv hgatp validate','hv hgatp-readiness build','hv hgatp-readiness validate','hv hgatp-write-plan build','hv hgatp-write-plan validate','hv hgatp-write-gate build','hv hgatp-write-gate validate','hv hgatp-write-boundary build','hv hgatp-write-boundary validate','hv hgatp-write-attempt build','hv hgatp-write-attempt validate','hv hgatp-csr-interface build','hv hgatp-csr-interface validate','hv hgatp-csr-result build','hv hgatp-csr-result validate','hv hgatp-hardware-write-prep build','hv hgatp-hardware-write-prep validate','hv hgatp-hardware-write-operation build','hv hgatp-hardware-write-operation validate']
tests=['require-operation-test','invalid-operation-test','source-integrity-test','request-value-test','opt-in-test','policy-allows-test','operation-call-reachable-test','operation-call-called-test','raw-write-called-test','execution-reached-raw-write-test','execution-called-raw-write-test','fake-trap-test','fake-readback-test','write-attempted-test','write-performed-test','active-stage2-test','guest-entered-test','first-instruction-test','invariant-consumption-test','invariant-corruption-test']
cmds=base+['hv hgatp-execution-dry-run '+t for t in tests]+['shutdown']
tr=sys.argv[1]; q=sys.argv[2:]; p=subprocess.Popen(q,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.STDOUT); os.set_blocking(p.stdout.fileno(),False); sel=selectors.DefaultSelector(); sel.register(p.stdout,selectors.EVENT_READ); seen=bytearray(); ready=False; deadline=time.monotonic()+100
with open(tr,'wb') as out:
 while time.monotonic()<deadline and p.poll() is None:
  for k,_ in sel.select(.05):
   data=k.fileobj.read()
   if data: out.write(data); out.flush(); seen.extend(data)
  if not ready and b'zign01d> ' in seen:
   ready=True
   for c in cmds: p.stdin.write((c+'\n').encode()); p.stdin.flush(); time.sleep(.13)
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
expect={'require-operation-test':'missing_operation','invalid-operation-test':'invalid_operation','source-integrity-test':'source_mutated','request-value-test':'request_value_mismatch','opt-in-test':'explicit_opt_in_enabled','policy-allows-test':'policy_allows_hardware_write','operation-call-reachable-test':'operation_call_reachable','operation-call-called-test':'operation_call_called','raw-write-called-test':'raw_write_called','execution-reached-raw-write-test':'execution_reached_raw_write','execution-called-raw-write-test':'execution_called_raw_write','fake-trap-test':'fake_trap_observed','fake-readback-test':'fake_readback_observed','write-attempted-test':'hgatp_write_attempted','write-performed-test':'hgatp_write_performed','active-stage2-test':'active_stage2_forbidden','guest-entered-test':'guest_entered_forbidden','first-instruction-test':'first_instruction_forbidden'}
for t,b in expect.items():
 m=re.search(re.escape('zign01d> hv hgatp-execution-dry-run '+t)+r'\r?\n', text); assert m, 'missing '+t
 end=text.find('zign01d> ', m.end()); block=text[m.end(): len(text) if end<0 else end]
 assert 'blocker='+b in block, (t,b,block)
for t in ['invariant-consumption-test','invariant-corruption-test']:
 m=re.search(re.escape('zign01d> hv hgatp-execution-dry-run '+t)+r'\r?\n', text); assert m, 'missing '+t
 end=text.find('zign01d> ', m.end()); block=text[m.end(): len(text) if end<0 else end]
 assert 'result=ok' in block, block
for bad in ['linux_boot=ok','busybox_boot=ok','alpine_boot=ok','guest_entered=yes','trap_return=executed','hgatp=written','hgatp_write=ok','hgatp=active','second_stage_translation=ACTIVE']:
 assert bad not in text, bad
PY
