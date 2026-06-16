#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TRANSCRIPT="$ROOT/smoke/transcripts/latest-hv34-hgatp-hardware-write-operation-negative-v0.txt"; ELF="$ROOT/zig-out/bin/zign01d-v0"
mkdir -p "$ROOT/smoke/transcripts"; : > "$TRANSCRIPT"
"$ROOT/scripts/check-zig-version.sh" >/dev/null
"$ROOT/scripts/build.sh" >/dev/null
command -v qemu-system-riscv64 >/dev/null
QEMU=(qemu-system-riscv64 -machine virt -cpu rv64 -smp 1 -m 128M -nographic -monitor none -serial stdio -kernel "$ELF")
python3 - "$TRANSCRIPT" "${QEMU[@]}" <<'PY'
import os,selectors,subprocess,sys,time
base=['hv hgatp build','hv hgatp validate','hv hgatp-readiness build','hv hgatp-readiness validate','hv hgatp-write-plan build','hv hgatp-write-plan validate','hv hgatp-write-gate build','hv hgatp-write-gate validate','hv hgatp-write-boundary build','hv hgatp-write-boundary validate','hv hgatp-write-attempt build','hv hgatp-write-attempt validate','hv hgatp-csr-interface build','hv hgatp-csr-interface validate','hv hgatp-csr-result build','hv hgatp-csr-result validate','hv hgatp-hardware-write-prep build','hv hgatp-hardware-write-prep validate']
tests=['require-prep-test','invalid-prep-test','source-integrity-test','request-value-test','opt-in-test','policy-allows-test','call-reachable-test','call-called-test','raw-write-called-test','fake-trap-test','fake-readback-test','write-attempted-test','write-performed-test','active-stage2-test','guest-entered-test','first-instruction-test','invariant-consumption-test','invariant-corruption-test']
cmds=base+['hv hgatp-hardware-write-operation '+t for t in tests]+['shutdown']
tr=sys.argv[1]; q=sys.argv[2:]; p=subprocess.Popen(q,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.STDOUT); os.set_blocking(p.stdout.fileno(),False); sel=selectors.DefaultSelector(); sel.register(p.stdout,selectors.EVENT_READ); seen=bytearray(); ready=False; deadline=time.monotonic()+90
with open(tr,'wb') as out:
 while time.monotonic()<deadline and p.poll() is None:
  for k,_ in sel.select(.05):
   b=k.fileobj.read()
   if b: out.write(b); out.flush(); seen.extend(b)
  if not ready and b'zign01d> ' in seen:
   ready=True
   for c in cmds: p.stdin.write((c+'\n').encode()); p.stdin.flush(); time.sleep(.13)
 if p.poll() is None: p.terminate(); time.sleep(.2)
 while True:
  b=p.stdout.read()
  if not b: break
  out.write(b)
sys.exit(0 if ready else 125)
PY
python3 - "$TRANSCRIPT" <<'PY'
import re,sys
text=open(sys.argv[1],errors='replace').read()
expect={'require-prep-test':'missing-prep','invalid-prep-test':'invalid-prep','source-integrity-test':'source-mutated','request-value-test':'request-value-mismatch','opt-in-test':'explicit-opt-in-forbidden','policy-allows-test':'policy-allows-hardware-write','call-reachable-test':'operation-call-reachable','call-called-test':'operation-call-called','raw-write-called-test':'raw-write-called','fake-trap-test':'fake-trap-observed','fake-readback-test':'fake-readback-observed','write-attempted-test':'hgatp-write-attempted','write-performed-test':'hgatp-write-performed','active-stage2-test':'active-stage2-forbidden','guest-entered-test':'guest-entered-forbidden','first-instruction-test':'first-instruction-forbidden'}
for t,b in expect.items():
 m=re.search(re.escape('zign01d> hv hgatp-hardware-write-operation '+t)+r'\r?\n', text); assert m, 'missing '+t
 end=text.find('zign01d> ', m.end()); block=text[m.end(): len(text) if end<0 else end]
 assert 'result_blocker='+b in block and 'blocker='+b in block, (t,b,block)
for t in ['invariant-consumption-test','invariant-corruption-test']:
 m=re.search(re.escape('zign01d> hv hgatp-hardware-write-operation '+t)+r'\r?\n', text); assert m, 'missing '+t
 end=text.find('zign01d> ', m.end()); block=text[m.end(): len(text) if end<0 else end]
 assert 'invariant_' in block and 'result=ok' in block, block
for bad in ['linux_boot=ok','busybox_boot=ok','alpine_boot=ok','guest_entered=yes','trap_return=executed','hgatp=written','hgatp_write=ok','hgatp=active','second_stage_translation=ACTIVE']:
 assert bad not in text, bad
PY
