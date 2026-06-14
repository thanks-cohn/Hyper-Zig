#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; LOG_DIR="$ROOT/logs/latest"; mkdir -p "$LOG_DIR" "$ROOT/smoke/transcripts"
TRANSCRIPT="$ROOT/smoke/transcripts/latest-smoke-hv25-hgatp-lifecycle-v0.txt"; : > "$TRANSCRIPT"; ELF="$ROOT/zig-out/bin/zign01d-v0"
fail(){ echo "FAIL $*" >&2; exit 1; }
"$ROOT/scripts/check-zig-version.sh" >/dev/null || fail "zig version"; "$ROOT/scripts/build.sh" >/dev/null || fail "build"; command -v qemu-system-riscv64 >/dev/null || fail "qemu"
python3 - "$TRANSCRIPT" qemu-system-riscv64 -machine virt -cpu rv64 -smp 1 -m 128M -nographic -monitor none -serial stdio -kernel "$ELF" <<'PYRUN'
import os,selectors,subprocess,sys,time
transcript=sys.argv[1]; cmd=sys.argv[2:]; commands=['hv hgatp reset', 'hv hgatp validate', 'hv hgatp build', 'hv hgatp validate', 'hv hgatp fields', 'hv hgatp invariant-lifecycle-test']+["shutdown"]
proc=subprocess.Popen(cmd,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.STDOUT); os.set_blocking(proc.stdout.fileno(),False); sel=selectors.DefaultSelector(); sel.register(proc.stdout,selectors.EVENT_READ); seen=bytearray(); ready=False; deadline=time.monotonic()+60; status=124
with open(transcript,'wb') as out:
  while time.monotonic()<deadline:
    if proc.poll() is not None: status=proc.returncode; break
    for k,_ in sel.select(timeout=.05):
      chunk=k.fileobj.read()
      if chunk: out.write(chunk); out.flush(); seen.extend(chunk)
    if not ready and b'zign01d> ' in seen:
      ready=True
      for c in commands: proc.stdin.write((c+'\n').encode()); proc.stdin.flush(); time.sleep(.12)
  if proc.poll() is None: proc.terminate(); proc.wait(timeout=3)
sys.exit(status if ready else 125)
PYRUN
python3 - "$TRANSCRIPT" <<'PYCHECK'
import sys
from pathlib import Path
text=Path(sys.argv[1]).read_text(errors='replace'); cmds=['hv hgatp reset', 'hv hgatp validate', 'hv hgatp build', 'hv hgatp validate', 'hv hgatp fields', 'hv hgatp invariant-lifecycle-test']; blocks={}; cur=0
for c in cmds:
 m='zign01d> '+c; s=text.find(m,cur)
 if s<0: raise SystemExit('missing command '+c)
 e=text.find('zign01d> ',s+len(m)); blocks[c]=text[s:] if e<0 else text[s:e]; cur=len(text) if e<0 else e
for c,needles in {'hv hgatp reset': ['hv: hgatp_candidate.state=empty'], 'hv hgatp validate': ['hv: hgatp.validate_result=ok', 'hv: hgatp_candidate.ready=true'], 'hv hgatp build': ['hv: hgatp.build_result=ok', 'hv: hgatp.checksum=0x'], 'hv hgatp invariant-lifecycle-test': ['hv: hv25.hgatp.lifecycle_invariant=ok']}.items():
 for n in needles:
  if n not in blocks[c]: raise SystemExit(f'missing {n} in {c}\n{blocks[c]}')
for f in ['linux_guest=supported','guest_entered=yes','first_guest_instruction=executed','trap_return=executed','hgatp_write=ok','second_stage_translation=ACTIVE']:
 if f in text: raise SystemExit('forbidden '+f)
print('PASS smoke-hv25-hgatp-lifecycle-v0.sh')
PYCHECK
