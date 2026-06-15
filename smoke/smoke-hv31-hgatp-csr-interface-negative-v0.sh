#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$ROOT/kernel/hypervisor/hgatp_csr_interface.zig" ]] || { echo "missing hgatp_csr_interface.zig" >&2; exit 1; }
TRANSCRIPT="$ROOT/smoke/transcripts/latest-hv31-hgatp-csr-interface-negative-v0.txt"; ELF="$ROOT/zig-out/bin/zign01d-v0"
mkdir -p "$ROOT/smoke/transcripts"; : > "$TRANSCRIPT"
"$ROOT/scripts/check-zig-version.sh" >/dev/null
"$ROOT/scripts/build.sh" >/dev/null
command -v qemu-system-riscv64 >/dev/null
QEMU=(qemu-system-riscv64 -machine virt -cpu rv64 -smp 1 -m 128M -nographic -monitor none -serial stdio -kernel "$ELF")
python3 - "$TRANSCRIPT" "${QEMU[@]}" <<'PY'
import os,selectors,subprocess,sys,time
tr=sys.argv[1]; q=sys.argv[2:]
cmds=['hv hgatp-csr-interface require-attempt-test','hv hgatp build','hv hgatp validate','hv hgatp-readiness build','hv hgatp-readiness validate','hv hgatp-write-plan build','hv hgatp-write-plan validate','hv hgatp-write-gate build','hv hgatp-write-gate validate','hv hgatp-write-boundary build','hv hgatp-write-boundary validate','hv hgatp-write-attempt build','hv hgatp-write-attempt validate','hv hgatp-csr-interface invalid-attempt-test','hv hgatp-csr-interface source-integrity-test','hv hgatp-csr-interface request-value-test','hv hgatp-csr-interface csr-called-test','hv hgatp-csr-interface raw-asm-called-test','hv hgatp-csr-interface write-attempted-test','hv hgatp-csr-interface write-performed-test','hv hgatp-csr-interface active-stage2-test','hv hgatp-csr-interface invariant-consumption-test','hv hgatp-csr-interface invariant-corruption-test','shutdown']
p=subprocess.Popen(q,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.STDOUT); os.set_blocking(p.stdout.fileno(),False); sel=selectors.DefaultSelector(); sel.register(p.stdout,selectors.EVENT_READ); seen=bytearray(); ready=False; deadline=time.monotonic()+90
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
text=open(sys.argv[1],errors='replace').read(); cmds=['hv hgatp-csr-interface require-attempt-test','hv hgatp build','hv hgatp validate','hv hgatp-readiness build','hv hgatp-readiness validate','hv hgatp-write-plan build','hv hgatp-write-plan validate','hv hgatp-write-gate build','hv hgatp-write-gate validate','hv hgatp-write-boundary build','hv hgatp-write-boundary validate','hv hgatp-write-attempt build','hv hgatp-write-attempt validate','hv hgatp-csr-interface invalid-attempt-test','hv hgatp-csr-interface source-integrity-test','hv hgatp-csr-interface request-value-test','hv hgatp-csr-interface csr-called-test','hv hgatp-csr-interface raw-asm-called-test','hv hgatp-csr-interface write-attempted-test','hv hgatp-csr-interface write-performed-test','hv hgatp-csr-interface active-stage2-test','hv hgatp-csr-interface invariant-consumption-test','hv hgatp-csr-interface invariant-corruption-test']
blocks=[]; pos=0
for c in cmds:
 m=re.search(re.escape('zign01d> '+c)+r'\r?\n', text[pos:]); assert m, 'missing '+c
 start=pos+m.end(); end=text.find('zign01d> ', start); end=len(text) if end<0 else end; blocks.append(text[start:end]); pos=end
for i,b in [(0,'missing-write-attempt'),(13,'invalid-write-attempt'),(14,'source-mutated'),(15,'request-value-mismatch'),(16,'csr-write-called'),(17,'raw-asm-called'),(18,'hgatp-write-attempted'),(19,'hgatp-write-performed'),(20,'active-stage2-forbidden')]: assert 'hv: hgatp_csr_interface.result_blocker='+b in blocks[i], b
assert 'hv: hgatp_csr_interface.invariant_consumption_result=ok' in blocks[21]
assert 'hv: hgatp_csr_interface.invariant_corruption_result=ok' in blocks[22]
for bad in ['linux_boot=ok','busybox_boot=ok','alpine_boot=ok','guest_entered=yes','trap_return=executed','hgatp=written','hgatp_write=ok','second_stage_translation=ACTIVE','active_stage2=true','hgatp_write_performed=true','raw_asm_called=true','csr_write_function_called=true']:
 assert bad not in text, bad
PY
