#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$ROOT/kernel/hypervisor/hgatp_write_gate.zig" ]] || { echo "missing hgatp_write_gate.zig" >&2; exit 1; }
TRANSCRIPT="$ROOT/smoke/transcripts/latest-hv28-hgatp-write-gate-v0.txt"; ELF="$ROOT/zig-out/bin/zign01d-v0"
mkdir -p "$ROOT/smoke/transcripts"; : > "$TRANSCRIPT"
"$ROOT/scripts/check-zig-version.sh" >/dev/null
"$ROOT/scripts/build.sh" >/dev/null
command -v qemu-system-riscv64 >/dev/null
QEMU=(qemu-system-riscv64 -machine virt -cpu rv64 -smp 1 -m 128M -nographic -monitor none -serial stdio -kernel "$ELF")
python3 - "$TRANSCRIPT" "${QEMU[@]}" <<'PY'
import os,selectors,subprocess,sys,time
tr=sys.argv[1]; q=sys.argv[2:]
cmds=['hv hgatp-write-gate reset','hv hgatp-write-gate build','hv hgatp build','hv hgatp validate','hv hgatp-readiness build','hv hgatp-readiness validate','hv hgatp-write-plan build','hv hgatp-write-plan validate','hv hgatp-write-plan fields','hv hgatp-write-gate build','hv hgatp-write-gate validate','hv hgatp-write-gate fields','hv hgatp-write-plan reset','hv hgatp-write-gate build','shutdown']
p=subprocess.Popen(q,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.STDOUT); os.set_blocking(p.stdout.fileno(),False); sel=selectors.DefaultSelector(); sel.register(p.stdout,selectors.EVENT_READ); seen=bytearray(); ready=False; deadline=time.monotonic()+80
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
text=open(sys.argv[1],errors='replace').read(); cmds=['hv hgatp-write-gate reset','hv hgatp-write-gate build','hv hgatp build','hv hgatp validate','hv hgatp-readiness build','hv hgatp-readiness validate','hv hgatp-write-plan build','hv hgatp-write-plan validate','hv hgatp-write-plan fields','hv hgatp-write-gate build','hv hgatp-write-gate validate','hv hgatp-write-gate fields','hv hgatp-write-plan reset','hv hgatp-write-gate build']
blocks=[]; pos=0
for c in cmds:
 m=re.search(re.escape('zign01d> '+c)+r'\r?\n', text[pos:]); assert m, 'missing '+c
 start=pos+m.end(); end=text.find('zign01d> ', start); end=len(text) if end<0 else end; blocks.append(text[start:end]); pos=end
need=[(0,'hv: hgatp_write_gate.reset_result=ok'),(1,'hv: hgatp_write_gate.build_result=rejected'),(2,'hv: hgatp_candidate.build_result=ok'),(3,'hv: hgatp_candidate.validate_result=ok'),(4,'hv: hgatp_readiness.build_result=ok'),(5,'hv: hgatp_readiness.validate_result=ok'),(6,'hv: hgatp_write_plan.build_result=ok'),(7,'hv: hgatp_write_plan.validate_result=ok'),(9,'hv: hgatp_write_gate.build_result=ok'),(9,'hv: hgatp_write_gate.source_fingerprint_unchanged=yes'),(10,'hv: hgatp_write_gate.validate_result=ok'),(11,'hv: hgatp_write_gate.request_blocked_before_hardware=true'),(11,'hv: hgatp_write_gate.request_allowed_to_reach_hardware_boundary=false'),(11,'hv: hgatp_write_gate.hgatp_write_attempted=false'),(11,'hv: hgatp_write_gate.hgatp_write_performed=false'),(11,'hv: hgatp_write_gate.hardware_write_boundary_reached=false'),(11,'hv: hgatp_write_gate.active_stage2=false'),(12,'hv: hgatp_write_plan.reset_result=ok'),(13,'hv: hgatp_write_gate.build_result=rejected')]
for i,m in need: assert m in blocks[i], f'missing {m} in {cmds[i]}'
assert ('hv: hgatp_write_gate.blocker=missing-write-plan' in blocks[1] or 'hv: hgatp_write_gate.blocker=invalid-write-plan' in blocks[1])
plan=re.search(r'hv: hgatp_write_plan.planned_hgatp_value=(0x[0-9a-f]+)', blocks[8], re.I); gate=re.search(r'hv: hgatp_write_gate.planned_hgatp_value=(0x[0-9a-f]+)', blocks[11], re.I)
assert plan and gate and plan.group(1).lower()==gate.group(1).lower(), 'gate did not consume HV27 planned value'
assert 'hv: hgatp_write_gate.write_plan_checksum=0x0' not in blocks[9], 'gate did not consume write-plan checksum'
assert ('hv: hgatp_write_gate.blocker=missing-write-plan' in blocks[13] or 'hv: hgatp_write_gate.blocker=invalid-write-plan' in blocks[13])
for bad in ['linux_boot='+'ok','busybox_boot='+'ok','alpine_boot='+'ok','guest_entered='+'yes','first_guest_instruction='+'executed','trap_return='+'executed','hgatp='+'written','hgatp_write='+'ok','hgatp='+'active','second_stage_translation='+'ACTIVE','active_stage2='+'true']:
 assert bad not in text, bad
PY
