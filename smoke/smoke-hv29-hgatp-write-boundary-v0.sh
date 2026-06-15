#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$ROOT/kernel/hypervisor/hgatp_write_boundary.zig" ]] || { echo "missing hgatp_write_boundary.zig" >&2; exit 1; }
TRANSCRIPT="$ROOT/smoke/transcripts/latest-hv29-hgatp-write-boundary-v0.txt"; ELF="$ROOT/zig-out/bin/zign01d-v0"
mkdir -p "$ROOT/smoke/transcripts"; : > "$TRANSCRIPT"
"$ROOT/scripts/check-zig-version.sh" >/dev/null
"$ROOT/scripts/build.sh" >/dev/null
command -v qemu-system-riscv64 >/dev/null
QEMU=(qemu-system-riscv64 -machine virt -cpu rv64 -smp 1 -m 128M -nographic -monitor none -serial stdio -kernel "$ELF")
python3 - "$TRANSCRIPT" "${QEMU[@]}" <<'PY'
import os,selectors,subprocess,sys,time
tr=sys.argv[1]; q=sys.argv[2:]
cmds=['hv hgatp-write-boundary reset','hv hgatp-write-boundary build','hv hgatp build','hv hgatp validate','hv hgatp-readiness build','hv hgatp-readiness validate','hv hgatp-write-plan build','hv hgatp-write-plan validate','hv hgatp-write-gate build','hv hgatp-write-gate validate','hv hgatp-write-gate fields','hv hgatp-write-boundary build','hv hgatp-write-boundary validate','hv hgatp-write-boundary fields','hv hgatp-write-boundary request','hv hgatp-write-gate reset','hv hgatp-write-boundary build','shutdown']
p=subprocess.Popen(q,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.STDOUT); os.set_blocking(p.stdout.fileno(),False); sel=selectors.DefaultSelector(); sel.register(p.stdout,selectors.EVENT_READ); seen=bytearray(); ready=False; deadline=time.monotonic()+90
with open(tr,'wb') as out:
 while time.monotonic()<deadline and p.poll() is None:
  for k,_ in sel.select(.05):
   b=k.fileobj.read()
   if b: out.write(b); out.flush(); seen.extend(b)
  if not ready and b'zign01d> ' in seen:
   ready=True
   for c in cmds: p.stdin.write((c+'\n').encode()); p.stdin.flush(); time.sleep(.14)
 if p.poll() is None: p.terminate(); time.sleep(.2)
 while True:
  b=p.stdout.read()
  if not b: break
  out.write(b)
sys.exit(0 if ready else 125)
PY
python3 - "$TRANSCRIPT" <<'PY'
import re,sys
text=open(sys.argv[1],errors='replace').read(); cmds=['hv hgatp-write-boundary reset','hv hgatp-write-boundary build','hv hgatp build','hv hgatp validate','hv hgatp-readiness build','hv hgatp-readiness validate','hv hgatp-write-plan build','hv hgatp-write-plan validate','hv hgatp-write-gate build','hv hgatp-write-gate validate','hv hgatp-write-gate fields','hv hgatp-write-boundary build','hv hgatp-write-boundary validate','hv hgatp-write-boundary fields','hv hgatp-write-boundary request','hv hgatp-write-gate reset','hv hgatp-write-boundary build']
blocks=[]; pos=0
for c in cmds:
 m=re.search(re.escape('zign01d> '+c)+r'\r?\n', text[pos:]); assert m, 'missing '+c
 start=pos+m.end(); end=text.find('zign01d> ', start); end=len(text) if end<0 else end; blocks.append(text[start:end]); pos=end
need=[(0,'hv: hgatp_write_boundary.reset_result=ok'),(1,'hv: hgatp_write_boundary.build_result=rejected'),(2,'hv: hgatp_candidate.build_result=ok'),(3,'hv: hgatp_candidate.validate_result=ok'),(4,'hv: hgatp_readiness.build_result=ok'),(5,'hv: hgatp_readiness.validate_result=ok'),(6,'hv: hgatp_write_plan.build_result=ok'),(7,'hv: hgatp_write_plan.validate_result=ok'),(8,'hv: hgatp_write_gate.build_result=ok'),(9,'hv: hgatp_write_gate.validate_result=ok'),(11,'hv: hgatp_write_boundary.build_result=ok'),(11,'hv: hgatp_write_boundary.source_fingerprint_unchanged=yes'),(12,'hv: hgatp_write_boundary.validate_result=ok'),(14,'hv: hgatp_write_boundary.boundary_request_denied=true'),(14,'hv: hgatp_write_boundary.boundary_request_allowed=false'),(14,'hv: hgatp_write_boundary.hardware_boundary_reached=false'),(14,'hv: hgatp_write_boundary.hgatp_write_attempted=false'),(14,'hv: hgatp_write_boundary.hgatp_write_performed=false'),(14,'hv: hgatp_write_boundary.active_stage2=false'),(15,'hv: hgatp_write_gate.reset_result=ok'),(16,'hv: hgatp_write_boundary.build_result=rejected')]
for i,m in need: assert m in blocks[i], f'missing {m} in {cmds[i]}'
assert ('hv: hgatp_write_boundary.blocker=missing-write-gate' in blocks[1] or 'hv: hgatp_write_boundary.blocker=invalid-write-gate' in blocks[1])
gate=re.search(r'hv: hgatp_write_gate.planned_hgatp_value=(0x[0-9a-f]+)', blocks[10], re.I); req=re.search(r'hv: hgatp_write_boundary.request_value=(0x[0-9a-f]+)', blocks[14], re.I)
assert gate and req and gate.group(1).lower()==req.group(1).lower(), 'boundary request did not consume HV28 planned value'
assert 'hv: hgatp_write_boundary.write_gate_checksum=0x0' not in blocks[11], 'boundary did not consume write-gate checksum'
assert ('hv: hgatp_write_boundary.blocker=missing-write-gate' in blocks[16] or 'hv: hgatp_write_boundary.blocker=invalid-write-gate' in blocks[16])
for bad in ['linux_boot='+'ok','busybox_boot='+'ok','alpine_boot='+'ok','guest_entered='+'yes','first_guest_instruction='+'executed','trap_return='+'executed','hgatp='+'written','hgatp_write='+'ok','hgatp='+'active','second_stage_translation='+'ACTIVE','active_stage2='+'true','hardware_boundary_reached='+'true','hgatp_write_performed='+'true']:
 assert bad not in text, bad
PY
