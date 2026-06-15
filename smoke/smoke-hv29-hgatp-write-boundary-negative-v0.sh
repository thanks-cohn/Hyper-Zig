#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$ROOT/kernel/hypervisor/hgatp_write_boundary.zig" ]] || { echo "missing hgatp_write_boundary.zig" >&2; exit 1; }
TRANSCRIPT="$ROOT/smoke/transcripts/latest-hv29-hgatp-write-boundary-negative-v0.txt"; ELF="$ROOT/zig-out/bin/zign01d-v0"
mkdir -p "$ROOT/smoke/transcripts"; : > "$TRANSCRIPT"
"$ROOT/scripts/check-zig-version.sh" >/dev/null
"$ROOT/scripts/build.sh" >/dev/null
command -v qemu-system-riscv64 >/dev/null
QEMU=(qemu-system-riscv64 -machine virt -cpu rv64 -smp 1 -m 128M -nographic -monitor none -serial stdio -kernel "$ELF")
python3 - "$TRANSCRIPT" "${QEMU[@]}" <<'PY'
import os,selectors,subprocess,sys,time
tr=sys.argv[1]; q=sys.argv[2:]
cmds=['hv hgatp build','hv hgatp validate','hv hgatp-readiness build','hv hgatp-readiness validate','hv hgatp-write-plan build','hv hgatp-write-plan validate','hv hgatp-write-gate build','hv hgatp-write-gate validate','hv hgatp-write-boundary require-gate-test','hv hgatp-write-boundary invalid-gate-test','hv hgatp-write-boundary gate-allows-boundary-test','hv hgatp-write-boundary source-integrity-test','hv hgatp-write-boundary request-value-test','hv hgatp-write-boundary boundary-allowed-test','hv hgatp-write-boundary boundary-reached-test','hv hgatp-write-boundary write-attempt-test','hv hgatp-write-boundary write-performed-test','hv hgatp-write-boundary active-stage2-test','shutdown']
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
text=open(sys.argv[1],errors='replace').read(); cmds=['hv hgatp build','hv hgatp validate','hv hgatp-readiness build','hv hgatp-readiness validate','hv hgatp-write-plan build','hv hgatp-write-plan validate','hv hgatp-write-gate build','hv hgatp-write-gate validate','hv hgatp-write-boundary require-gate-test','hv hgatp-write-boundary invalid-gate-test','hv hgatp-write-boundary gate-allows-boundary-test','hv hgatp-write-boundary source-integrity-test','hv hgatp-write-boundary request-value-test','hv hgatp-write-boundary boundary-allowed-test','hv hgatp-write-boundary boundary-reached-test','hv hgatp-write-boundary write-attempt-test','hv hgatp-write-boundary write-performed-test','hv hgatp-write-boundary active-stage2-test']
blocks=[]; pos=0
for c in cmds:
 m=re.search(re.escape('zign01d> '+c)+r'\r?\n', text[pos:]); assert m, 'missing '+c
 start=pos+m.end(); end=text.find('zign01d> ', start); end=len(text) if end<0 else end; blocks.append(text[start:end]); pos=end
expected=['missing-write-gate','invalid-write-gate','gate-allows-hardware-boundary','source-mutated','request-value-mismatch','boundary-request-allowed','hardware-boundary-reached','hgatp-write-attempted','hgatp-write-performed','active-stage2-forbidden']
for off, blocker in enumerate(expected,8):
 assert 'hv: hgatp_write_boundary.result_blocker='+blocker in blocks[off], f'missing blocker {blocker}'
for bad in ['linux_boot='+'ok','busybox_boot='+'ok','alpine_boot='+'ok','guest_entered='+'yes','first_guest_instruction='+'executed','trap_return='+'executed','hgatp='+'written','hgatp_write='+'ok','hgatp='+'active','second_stage_translation='+'ACTIVE','active_stage2='+'true','hardware_boundary_reached='+'true','hgatp_write_performed='+'true']:
 assert bad not in text, bad
PY
