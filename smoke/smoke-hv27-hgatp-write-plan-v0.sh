#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$ROOT/kernel/hypervisor/hgatp_write_plan.zig" ]] || { echo "missing hgatp_write_plan.zig" >&2; exit 1; }
TRANSCRIPT="$ROOT/smoke/transcripts/latest-hv27-hgatp-write-plan-v0.txt"; ELF="$ROOT/zig-out/bin/zign01d-v0"
mkdir -p "$ROOT/smoke/transcripts"; : > "$TRANSCRIPT"
"$ROOT/scripts/check-zig-version.sh" >/dev/null
"$ROOT/scripts/build.sh" >/dev/null
command -v qemu-system-riscv64 >/dev/null
QEMU=(qemu-system-riscv64 -machine virt -cpu rv64 -smp 1 -m 128M -nographic -monitor none -serial stdio -kernel "$ELF")
python3 - "$TRANSCRIPT" "${QEMU[@]}" <<'PY'
import os,selectors,subprocess,sys,time
tr=sys.argv[1]; q=sys.argv[2:]
cmds=['hv hgatp-write-plan reset','hv hgatp-write-plan build','hv hgatp build','hv hgatp validate','hv hgatp-readiness build','hv hgatp-readiness validate','hv hgatp fields','hv hgatp-write-plan build','hv hgatp-write-plan validate','hv hgatp-write-plan fields','hv hgatp reset','hv hgatp-write-plan build','shutdown']
p=subprocess.Popen(q,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.STDOUT); os.set_blocking(p.stdout.fileno(),False); sel=selectors.DefaultSelector(); sel.register(p.stdout,selectors.EVENT_READ); seen=bytearray(); ready=False; deadline=time.monotonic()+70
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
text=open(sys.argv[1],errors='replace').read(); cmds=['hv hgatp-write-plan reset','hv hgatp-write-plan build','hv hgatp build','hv hgatp validate','hv hgatp-readiness build','hv hgatp-readiness validate','hv hgatp fields','hv hgatp-write-plan build','hv hgatp-write-plan validate','hv hgatp-write-plan fields','hv hgatp reset','hv hgatp-write-plan build']
blocks=[]; pos=0
for c in cmds:
 m=re.search(re.escape('zign01d> '+c)+r'\r?\n', text[pos:]); assert m, 'missing '+c
 start=pos+m.end(); end=text.find('zign01d> ', start); end=len(text) if end<0 else end; blocks.append(text[start:end]); pos=end
need=[(0,'hv: hgatp_write_plan.reset_result=ok'),(1,'hv: hgatp_write_plan.build_result=rejected'),(1,'hv: hgatp_write_plan.blocker=missing-hgatp-candidate'),(2,'hv: hgatp_candidate.build_result=ok'),(3,'hv: hgatp_candidate.validate_result=ok'),(4,'hv: hgatp_readiness.build_result=ok'),(5,'hv: hgatp_readiness.validate_result=ok'),(7,'hv: hgatp_write_plan.build_result=ok'),(7,'hv: hgatp_write_plan.source_fingerprint_unchanged=yes'),(8,'hv: hgatp_write_plan.validate_result=ok'),(9,'hv: hgatp_write_plan.write_allowed_now=false'),(9,'hv: hgatp_write_plan.write_attempted=false'),(9,'hv: hgatp_write_plan.active_stage2=false'),(11,'hv: hgatp_write_plan.build_result=rejected')]
for i,m in need: assert m in blocks[i], f'missing {m} in {cmds[i]}'
cand=re.search(r'hv: hgatp_candidate.candidate_value=(0x[0-9a-f]+)', blocks[6], re.I); plan=re.search(r'hv: hgatp_write_plan.planned_hgatp_value=(0x[0-9a-f]+)', blocks[9], re.I)
assert cand and plan and cand.group(1).lower()==plan.group(1).lower(), 'planned value does not match candidate'
assert 'hv: hgatp_write_plan.hgatp_candidate_checksum=0x0' not in blocks[7], 'plan did not consume candidate'
assert ('hv: hgatp_write_plan.blocker=missing-hgatp-candidate' in blocks[11] or 'hv: hgatp_write_plan.blocker=invalid-hgatp-candidate' in blocks[11])
for bad in ['linux_boot='+'ok','busybox_boot='+'ok','alpine_boot='+'ok','guest_entered='+'yes','first_guest_instruction='+'executed','trap_return='+'executed','hgatp='+'written','hgatp_write='+'ok','hgatp='+'active','second_stage_translation='+'ACTIVE','active_stage2='+'true']:
 assert bad not in text, bad
PY
