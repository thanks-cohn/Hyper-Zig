#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$ROOT/kernel/hypervisor/hgatp_activation_readiness.zig" ]] || { echo "missing hgatp_activation_readiness.zig" >&2; exit 1; }
TRANSCRIPT="$ROOT/smoke/transcripts/latest-hv26-hgatp-readiness-negative-v0.txt"; ELF="$ROOT/zig-out/bin/zign01d-v0"
mkdir -p "$ROOT/smoke/transcripts"; : > "$TRANSCRIPT"
"$ROOT/scripts/check-zig-version.sh" >/dev/null
"$ROOT/scripts/build.sh" >/dev/null
command -v qemu-system-riscv64 >/dev/null
QEMU=(qemu-system-riscv64 -machine virt -cpu rv64 -smp 1 -m 128M -nographic -monitor none -serial stdio -kernel "$ELF")
python3 - "$TRANSCRIPT" "${QEMU[@]}" <<'PY'
import os,selectors,subprocess,sys,time
tr=sys.argv[1]; cmd=sys.argv[2:]
cmds=["hv hgatp build","hv hgatp validate","hv hgatp-readiness require-candidate-test","hv hgatp-readiness invalid-candidate-test","hv hgatp-readiness require-stage2-test","hv hgatp-readiness require-table-test","hv hgatp-readiness require-hext-test","hv hgatp-readiness require-csr-safety-test","hv hgatp-readiness write-attempt-test","hv hgatp-readiness active-stage2-test","hv hgatp-readiness source-integrity-test","hv hgatp-readiness invariant-corruption-test","shutdown"]
p=subprocess.Popen(cmd,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.STDOUT); os.set_blocking(p.stdout.fileno(),False); sel=selectors.DefaultSelector(); sel.register(p.stdout,selectors.EVENT_READ); seen=bytearray(); ready=False; deadline=time.monotonic()+60
with open(tr,'wb') as out:
  while time.monotonic()<deadline and p.poll() is None:
    for k,_ in sel.select(.05):
      b=k.fileobj.read()
      if b: out.write(b); out.flush(); seen.extend(b)
    if not ready and b'zign01d> ' in seen:
      ready=True
      for c in cmds: p.stdin.write((c+'\n').encode()); p.stdin.flush(); time.sleep(.15)
  if p.poll() is None: p.terminate(); time.sleep(.2)
  while True:
    b=p.stdout.read()
    if not b: break
    out.write(b)
sys.exit(0 if ready else 125)
PY
python3 - "$TRANSCRIPT" <<'PY'
import re,sys
text=open(sys.argv[1],errors='replace').read(); cmds=["hv hgatp build","hv hgatp validate","hv hgatp-readiness require-candidate-test","hv hgatp-readiness invalid-candidate-test","hv hgatp-readiness require-stage2-test","hv hgatp-readiness require-table-test","hv hgatp-readiness require-hext-test","hv hgatp-readiness require-csr-safety-test","hv hgatp-readiness write-attempt-test","hv hgatp-readiness active-stage2-test","hv hgatp-readiness source-integrity-test","hv hgatp-readiness invariant-corruption-test"]
blocks=[]; pos=0
for c in cmds:
 m=re.search(re.escape('zign01d> '+c)+r'\r?\n', text[pos:]); assert m, 'missing '+c
 start=pos+m.end(); end=text.find('zign01d> ', start); end=len(text) if end<0 else end; blocks.append(text[start:end]); pos=end
pairs=[(2,'missing-hgatp-candidate'),(3,'invalid-hgatp-candidate'),(4,'missing-stage2-metadata'),(5,'missing-stage2-table'),(6,'missing-h-extension-discovery'),(7,'missing-csr-safety'),(8,'hgatp-write-attempted'),(9,'active-stage2-forbidden'),(10,'source-mutated')]
for i,b in pairs:
 assert f'hv: hgatp_readiness.result_blocker={b}' in blocks[i], f'missing result {b}'
 assert f'hv: hgatp_readiness.blocker={b}' in blocks[i], f'missing blocker {b}'
assert 'hv: hgatp_readiness.invariant_corruption_result=ok' in blocks[11]
for bad in ['linux_boot=ok','busybox_boot=ok','alpine_boot=ok','guest_entered=yes','first_guest_instruction=executed','trap_return=executed','hgatp=written','hgatp_write=ok','hgatp=active','second_stage_translation=ACTIVE','active_stage2=true']:
 assert bad not in text, bad
PY
