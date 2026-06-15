#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$ROOT/kernel/hypervisor/hgatp_write_attempt.zig" ]] || { echo "missing hgatp_write_attempt.zig" >&2; exit 1; }
TRANSCRIPT="$ROOT/smoke/transcripts/latest-hv30-hgatp-write-attempt-negative-v0.txt"; ELF="$ROOT/zig-out/bin/zign01d-v0"
mkdir -p "$ROOT/smoke/transcripts"; : > "$TRANSCRIPT"
"$ROOT/scripts/check-zig-version.sh" >/dev/null
"$ROOT/scripts/build.sh" >/dev/null
command -v qemu-system-riscv64 >/dev/null
QEMU=(qemu-system-riscv64 -machine virt -cpu rv64 -smp 1 -m 128M -nographic -monitor none -serial stdio -kernel "$ELF")
python3 - "$TRANSCRIPT" "${QEMU[@]}" <<'PY'
import os,selectors,subprocess,sys,time
tr=sys.argv[1]; q=sys.argv[2:]
cmds=['hv hgatp build','hv hgatp validate','hv hgatp-readiness build','hv hgatp-readiness validate','hv hgatp-write-plan build','hv hgatp-write-plan validate','hv hgatp-write-gate build','hv hgatp-write-gate validate','hv hgatp-write-boundary build','hv hgatp-write-boundary validate','hv hgatp-write-attempt require-boundary-test','hv hgatp-write-attempt source-integrity-test','hv hgatp-write-attempt request-value-test','hv hgatp-write-attempt invariant-consumption-test','hv hgatp-write-attempt invariant-corruption-test','shutdown']
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
text=open(sys.argv[1],errors='replace').read(); cmds=['hv hgatp build','hv hgatp validate','hv hgatp-readiness build','hv hgatp-readiness validate','hv hgatp-write-plan build','hv hgatp-write-plan validate','hv hgatp-write-gate build','hv hgatp-write-gate validate','hv hgatp-write-boundary build','hv hgatp-write-boundary validate','hv hgatp-write-attempt require-boundary-test','hv hgatp-write-attempt source-integrity-test','hv hgatp-write-attempt request-value-test','hv hgatp-write-attempt invariant-consumption-test','hv hgatp-write-attempt invariant-corruption-test']
blocks=[]; pos=0
for c in cmds:
 m=re.search(re.escape('zign01d> '+c)+r'\r?\n', text[pos:]); assert m, 'missing '+c
 start=pos+m.end(); end=text.find('zign01d> ', start); end=len(text) if end<0 else end; blocks.append(text[start:end]); pos=end
for i,b in [(10,'missing-write-boundary'),(11,'source-mutated'),(12,'request-value-mismatch')]: assert 'hv: hgatp_write_attempt.result_blocker='+b in blocks[i], b
assert 'hv: hgatp_write_attempt.invariant_consumption_result=ok' in blocks[13]
assert 'hv: hgatp_write_attempt.invariant_corruption_result=ok' in blocks[14]
for bad in ['linux_boot=ok','busybox_boot=ok','alpine_boot=ok','guest_entered=yes','trap_return=executed','hgatp=written','hgatp_write=ok','second_stage_translation=ACTIVE','active_stage2=true','hgatp_write_performed=true']:
 assert bad not in text, bad
PY
