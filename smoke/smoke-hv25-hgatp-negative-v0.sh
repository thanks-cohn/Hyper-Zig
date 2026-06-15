#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$ROOT/kernel/hypervisor/hgatp_candidate.zig" ]] || { echo "missing hgatp_candidate.zig" >&2; exit 1; }
TRANSCRIPT="$ROOT/smoke/transcripts/latest-hv25-hgatp-negative-v0.txt"; ELF="$ROOT/zig-out/bin/zign01d-v0"; mkdir -p "$ROOT/smoke/transcripts"; : > "$TRANSCRIPT"
"$ROOT/scripts/check-zig-version.sh" >/dev/null; "$ROOT/scripts/build.sh" >/dev/null; command -v qemu-system-riscv64 >/dev/null
CMDS=("hv hgatp mode-test" "hv hgatp ppn-alignment-test" "hv hgatp vmid-bounds-test" "hv hgatp require-hext-test" "hv hgatp write-attempt-test" "hv hgatp active-stage2-test" "hv hgatp invariant-lifecycle-test" "hv hgatp invariant-derivation-test" "hv hgatp invariant-corruption-test" "shutdown")
QEMU=(qemu-system-riscv64 -machine virt -cpu rv64 -smp 1 -m 128M -nographic -monitor none -serial stdio -kernel "$ELF")
python3 - "$TRANSCRIPT" "${QEMU[@]}" <<'PY'
import os,selectors,subprocess,sys,time
tr=sys.argv[1]; cmd=sys.argv[2:]; cmds=["hv hgatp mode-test","hv hgatp ppn-alignment-test","hv hgatp vmid-bounds-test","hv hgatp require-hext-test","hv hgatp write-attempt-test","hv hgatp active-stage2-test","hv hgatp invariant-lifecycle-test","hv hgatp invariant-derivation-test","hv hgatp invariant-corruption-test","shutdown"]
p=subprocess.Popen(cmd,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.STDOUT); os.set_blocking(p.stdout.fileno(),False); sel=selectors.DefaultSelector(); sel.register(p.stdout,selectors.EVENT_READ); seen=bytearray(); ready=False; deadline=time.monotonic()+45
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
text=open(sys.argv[1],errors='replace').read(); cmds=["hv hgatp mode-test","hv hgatp ppn-alignment-test","hv hgatp vmid-bounds-test","hv hgatp require-hext-test","hv hgatp write-attempt-test","hv hgatp active-stage2-test","hv hgatp invariant-lifecycle-test","hv hgatp invariant-derivation-test","hv hgatp invariant-corruption-test"]
blocks=[]; pos=0
for c in cmds:
 m=re.search(re.escape('zign01d> '+c)+r'\r?\n', text[pos:]); assert m, 'missing '+c
 start=pos+m.end(); end=text.find('zign01d> ', start); end=len(text) if end<0 else end; blocks.append(text[start:end]); pos=end
need=[(0,'hv: hgatp_candidate.blocker=invalid-mode'),(1,'hv: hgatp_candidate.blocker=root-ppn-misaligned'),(2,'hv: hgatp_candidate.blocker=vmid-out-of-bounds'),(3,'hv: hgatp_candidate.blocker=missing-h-extension-discovery-source'),(4,'hv: hgatp_candidate.blocker=hgatp-write-attempted'),(5,'hv: hgatp_candidate.blocker=active-stage2-forbidden'),(6,'hv: hgatp_candidate.invariant_lifecycle_result=ok'),(7,'hv: hgatp_candidate.invariant_derivation_result=ok'),(8,'hv: hgatp_candidate.invariant_corruption_result=ok')]
for i,m in need: assert m in blocks[i], f'missing {m}'
for bad in ['linux_boot=ok','busybox_boot=ok','guest_entered=yes','first_guest_instruction=executed','trap_return=executed','hgatp=written','hgatp_write=ok','hgatp=active','second_stage_translation=ACTIVE','active_stage2=true']:
 assert bad not in text, bad
PY
