#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$ROOT/kernel/hypervisor/hgatp_write_plan.zig" ]] || { echo "missing hgatp_write_plan.zig" >&2; exit 1; }
TRANSCRIPT="$ROOT/smoke/transcripts/latest-hv27-hgatp-write-plan-negative-v0.txt"; ELF="$ROOT/zig-out/bin/zign01d-v0"
mkdir -p "$ROOT/smoke/transcripts"; : > "$TRANSCRIPT"
"$ROOT/scripts/check-zig-version.sh" >/dev/null
"$ROOT/scripts/build.sh" >/dev/null
command -v qemu-system-riscv64 >/dev/null
QEMU=(qemu-system-riscv64 -machine virt -cpu rv64 -smp 1 -m 128M -nographic -monitor none -serial stdio -kernel "$ELF")
python3 - "$TRANSCRIPT" "${QEMU[@]}" <<'PY'
import os,selectors,subprocess,sys,time
tr=sys.argv[1]; q=sys.argv[2:]
cmds=['hv hgatp build','hv hgatp validate','hv hgatp-readiness build','hv hgatp-readiness validate','hv hgatp-write-plan require-candidate-test','hv hgatp-write-plan invalid-candidate-test','hv hgatp-write-plan require-readiness-test','hv hgatp-write-plan invalid-readiness-test','hv hgatp-write-plan readiness-not-ready-test','hv hgatp-write-plan require-hext-test','hv hgatp-write-plan require-csr-safety-test','hv hgatp-write-plan require-stage2-metadata-test','hv hgatp-write-plan require-stage2-table-test','hv hgatp-write-plan source-integrity-test','hv hgatp-write-plan write-allowed-test','hv hgatp-write-plan write-attempt-test','hv hgatp-write-plan active-stage2-test','shutdown']
p=subprocess.Popen(q,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.STDOUT); os.set_blocking(p.stdout.fileno(),False); sel=selectors.DefaultSelector(); sel.register(p.stdout,selectors.EVENT_READ); seen=bytearray(); ready=False; deadline=time.monotonic()+70
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
text=open(sys.argv[1],errors='replace').read(); cmds=['hv hgatp build','hv hgatp validate','hv hgatp-readiness build','hv hgatp-readiness validate','hv hgatp-write-plan require-candidate-test','hv hgatp-write-plan invalid-candidate-test','hv hgatp-write-plan require-readiness-test','hv hgatp-write-plan invalid-readiness-test','hv hgatp-write-plan readiness-not-ready-test','hv hgatp-write-plan require-hext-test','hv hgatp-write-plan require-csr-safety-test','hv hgatp-write-plan require-stage2-metadata-test','hv hgatp-write-plan require-stage2-table-test','hv hgatp-write-plan source-integrity-test','hv hgatp-write-plan write-allowed-test','hv hgatp-write-plan write-attempt-test','hv hgatp-write-plan active-stage2-test']
blocks=[]; pos=0
for c in cmds:
 m=re.search(re.escape('zign01d> '+c)+r'\r?\n', text[pos:]); assert m, 'missing '+c
 start=pos+m.end(); end=text.find('zign01d> ', start); end=len(text) if end<0 else end; blocks.append(text[start:end]); pos=end
expected=['missing-hgatp-candidate','invalid-hgatp-candidate','missing-readiness','invalid-readiness','readiness-not-ready','missing-h-extension-discovery','missing-csr-safety','missing-stage2-metadata','missing-stage2-table','source-mutated','write-allowed-now','hgatp-write-attempted','active-stage2-forbidden']
for off, blocker in enumerate(expected,4):
 assert 'hv: hgatp_write_plan.result_blocker='+blocker in blocks[off], f'missing blocker {blocker}'
for bad in ['linux_boot='+'ok','busybox_boot='+'ok','alpine_boot='+'ok','guest_entered='+'yes','first_guest_instruction='+'executed','trap_return='+'executed','hgatp='+'written','hgatp_write='+'ok','hgatp='+'active','second_stage_translation='+'ACTIVE','active_stage2='+'true']:
 assert bad not in text, bad
PY
