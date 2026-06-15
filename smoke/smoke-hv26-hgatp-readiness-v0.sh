#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$ROOT/kernel/hypervisor/hgatp_activation_readiness.zig" ]] || { echo "missing hgatp_activation_readiness.zig" >&2; exit 1; }
LOG_DIR="$ROOT/logs/latest"; TRANSCRIPT="$ROOT/smoke/transcripts/latest-hv26-hgatp-readiness-v0.txt"; ELF="$ROOT/zig-out/bin/zign01d-v0"
mkdir -p "$LOG_DIR" "$ROOT/smoke/transcripts"; : > "$TRANSCRIPT"
"$ROOT/scripts/check-zig-version.sh" >/dev/null
"$ROOT/scripts/build.sh" >/dev/null
command -v qemu-system-riscv64 >/dev/null
QEMU=(qemu-system-riscv64 -machine virt -cpu rv64 -smp 1 -m 128M -nographic -monitor none -serial stdio -kernel "$ELF")
python3 - "$TRANSCRIPT" "${QEMU[@]}" <<'PY'
import os,selectors,subprocess,sys,time
tr=sys.argv[1]; cmd=sys.argv[2:]
cmds=["hv hgatp-readiness reset","hv hgatp-readiness build","hv hgatp build","hv hgatp validate","hv hgatp-readiness build","hv hgatp-readiness validate","hv hgatp-readiness checksum","hv hgatp reset","hv hgatp-readiness build","hv hgatp-readiness blockers","hv hgatp-readiness next","shutdown"]
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
text=open(sys.argv[1],errors='replace').read(); cmds=["hv hgatp-readiness reset","hv hgatp-readiness build","hv hgatp build","hv hgatp validate","hv hgatp-readiness build","hv hgatp-readiness validate","hv hgatp-readiness checksum","hv hgatp reset","hv hgatp-readiness build","hv hgatp-readiness blockers","hv hgatp-readiness next"]
blocks=[]; pos=0
for c in cmds:
 m=re.search(re.escape('zign01d> '+c)+r'\r?\n', text[pos:]); assert m, 'missing '+c
 start=pos+m.end(); end=text.find('zign01d> ', start); end=len(text) if end<0 else end; blocks.append(text[start:end]); pos=end
need=[(0,'hv: hgatp_readiness.reset_result=ok'),(1,'hv: hgatp_readiness.build_result=rejected'),(1,'hv: hgatp_readiness.blocker=missing-hgatp-candidate'),(1,'hv: hgatp_readiness.source_fingerprint_unchanged=yes'),(2,'hv: hgatp_candidate.build_result=ok'),(3,'hv: hgatp_candidate.validate_result=ok'),(4,'hv: hgatp_readiness.build_result=ok'),(4,'hv: hgatp_readiness.hgatp_candidate_present=yes'),(4,'hv: hgatp_readiness.hgatp_candidate_valid=yes'),(4,'hv: hgatp_readiness.source_fingerprint_unchanged=yes'),(5,'hv: hgatp_readiness.validate_result=ok'),(6,'hv: hgatp_readiness.checksum=0x'),(7,'hv: hgatp_candidate.reset_result=ok'),(8,'hv: hgatp_readiness.build_result=rejected'),(8,'hv: hgatp_readiness.blocker=missing-hgatp-candidate'),(9,'hv: hgatp_readiness.blocker=missing-hgatp-candidate'),(10,'hv: hgatp_readiness.next_action=build-hgatp-candidate-externally')]
for i,m in need: assert m in blocks[i], f'missing {m} in command {cmds[i]}'
assert 'hv: hgatp_readiness.checksum=0x0' not in blocks[6], 'fixed zero checksum'
assert re.search(r'hv: hgatp_readiness.hgatp_candidate_checksum=0x[1-9a-f]', blocks[4], re.I), 'candidate checksum not consumed after external build'
assert 'hv: hgatp_readiness.hgatp_candidate_checksum=0x0' in blocks[8], 'reset candidate not reflected'
for bad in ['linux_boot=ok','busybox_boot=ok','alpine_boot=ok','guest_entered=yes','first_guest_instruction=executed','trap_return=executed','hgatp=written','hgatp_write=ok','hgatp=active','second_stage_translation=ACTIVE','active_stage2=true']:
 assert bad not in text, bad
PY
