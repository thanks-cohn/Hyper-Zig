#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TRANSCRIPT="$ROOT/smoke/transcripts/latest-hv33-hgatp-hardware-write-prep-negative-v0.txt"; ELF="$ROOT/zig-out/bin/zign01d-v0"
mkdir -p "$ROOT/smoke/transcripts"; : > "$TRANSCRIPT"
"$ROOT/scripts/check-zig-version.sh" >/dev/null
"$ROOT/scripts/build.sh" >/dev/null
command -v qemu-system-riscv64 >/dev/null
QEMU=(qemu-system-riscv64 -machine virt -cpu rv64 -smp 1 -m 128M -nographic -monitor none -serial stdio -kernel "$ELF")
python3 - "$TRANSCRIPT" "${QEMU[@]}" <<'PY'
import os,selectors,subprocess,sys,time
tr=sys.argv[1]; q=sys.argv[2:]
base=['hv hgatp build','hv hgatp validate','hv hgatp-readiness build','hv hgatp-readiness validate','hv hgatp-write-plan build','hv hgatp-write-plan validate','hv hgatp-write-gate build','hv hgatp-write-gate validate','hv hgatp-write-boundary build','hv hgatp-write-boundary validate','hv hgatp-write-attempt build','hv hgatp-write-attempt validate','hv hgatp-csr-interface build','hv hgatp-csr-interface validate']
tests=['require-result-test','invalid-result-test','source-integrity-test','request-value-test','policy-allows-test','call-reachable-test','call-called-test','raw-write-called-test','write-attempted-test','write-performed-test','fake-trap-test','fake-readback-test','active-stage2-test','guest-entered-test','first-instruction-test','invariant-consumption-test','invariant-corruption-test']
cmds=base+['hv hgatp-hardware-write-prep '+t for t in tests]+['shutdown']
p=subprocess.Popen(q,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.STDOUT); os.set_blocking(p.stdout.fileno(),False); sel=selectors.DefaultSelector(); sel.register(p.stdout,selectors.EVENT_READ); seen=bytearray(); ready=False; deadline=time.monotonic()+90
with open(tr,'wb') as out:
 while time.monotonic()<deadline and p.poll() is None:
  for k,_ in sel.select(.05):
   b=k.fileobj.read()
   if b: out.write(b); out.flush(); seen.extend(b)
  if not ready and b'zign01d> ' in seen:
   ready=True
   for c in cmds: p.stdin.write((c+'\n').encode()); p.stdin.flush(); time.sleep(.12)
 if p.poll() is None: p.terminate(); time.sleep(.2)
 while True:
  b=p.stdout.read()
  if not b: break
  out.write(b)
sys.exit(0 if ready else 125)
PY
python3 - "$TRANSCRIPT" <<'PY'
import re,sys
text=open(sys.argv[1],errors='replace').read(); tests=[('require-result-test','missing-csr-result'),('invalid-result-test','invalid-csr-result'),('source-integrity-test','source-mutated'),('request-value-test','request-value-mismatch'),('policy-allows-test','policy-allows-hardware-write'),('call-reachable-test','hardware-call-reachable'),('call-called-test','hardware-call-called'),('raw-write-called-test','raw-write-called'),('write-attempted-test','hgatp-write-attempted'),('write-performed-test','hgatp-write-performed'),('fake-trap-test','fake-trap-observed'),('fake-readback-test','fake-readback-observed'),('active-stage2-test','active-stage2-forbidden'),('guest-entered-test','guest-entered-forbidden'),('first-instruction-test','first-instruction-forbidden')]
for t,b in tests:
 m=re.search(re.escape('zign01d> hv hgatp-hardware-write-prep '+t)+r'\r?\n', text); assert m, 'missing '+t
 end=text.find('zign01d> ', m.end()); block=text[m.end(): len(text) if end<0 else end]
 assert 'hv: hgatp_hardware_write_prep.result_blocker='+b in block, t
 assert 'hv: hgatp_hardware_write_prep.blocker='+b in block, t
for t in ['invariant-consumption-test','invariant-corruption-test']:
 m=re.search(re.escape('zign01d> hv hgatp-hardware-write-prep '+t)+r'\r?\n', text); assert m, 'missing '+t
 end=text.find('zign01d> ', m.end()); block=text[m.end(): len(text) if end<0 else end]
 assert 'result=ok' in block, t
for bad in ['linux_boot=ok','busybox_boot=ok','alpine_boot=ok','guest_entered=yes','trap_return=executed','hgatp=written','hgatp_write=ok','second_stage_translation=ACTIVE']:
 assert bad not in text, bad
PY
