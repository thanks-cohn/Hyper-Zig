#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; mkdir -p "$ROOT/smoke/transcripts" "$ROOT/logs/latest"
TRANSCRIPT="$ROOT/smoke/transcripts/latest-smoke-hv26-entry-infrastructure-v0.txt"; : > "$TRANSCRIPT"; ELF="$ROOT/zig-out/bin/zign01d-v0"
fail(){ echo "FAIL $*" >&2; exit 1; }
"$ROOT/scripts/check-zig-version.sh" >/dev/null || fail "zig version"; "$ROOT/scripts/build.sh" >/dev/null || fail "build"; command -v qemu-system-riscv64 >/dev/null || fail "qemu"
python3 - "$TRANSCRIPT" qemu-system-riscv64 -machine virt -cpu rv64 -smp 1 -m 128M -nographic -monitor none -serial stdio -kernel "$ELF" <<'PYRUN'
import os,selectors,subprocess,sys,time
transcript=sys.argv[1]; cmd=sys.argv[2:]; commands=['hv guest-entry build', 'hv trap-return build', 'hv first-instruction build', 'hv hv26 invariant-hv25-consumption-test', 'shutdown']
proc=subprocess.Popen(cmd,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.STDOUT); os.set_blocking(proc.stdout.fileno(),False); sel=selectors.DefaultSelector(); sel.register(proc.stdout,selectors.EVENT_READ); seen=bytearray(); ready=False; deadline=time.monotonic()+75; status=124
with open(transcript,'wb') as out:
  while time.monotonic()<deadline:
    if proc.poll() is not None: status=proc.returncode; break
    for k,_ in sel.select(timeout=.05):
      chunk=k.fileobj.read()
      if chunk: out.write(chunk); out.flush(); seen.extend(chunk)
    if not ready and b'zign01d> ' in seen:
      ready=True
      for c in commands: proc.stdin.write((c+'
').encode()); proc.stdin.flush(); time.sleep(.12)
  if proc.poll() is None: proc.terminate(); proc.wait(timeout=3)
sys.exit(status if ready else 125)
PYRUN
python3 - "$TRANSCRIPT" <<'PYCHECK'
import sys
from pathlib import Path
text=Path(sys.argv[1]).read_text(errors='replace')
for n in ['guest_entry_frame.build_result=ok', 'trap_return_frame.build_result=ok', 'first_instruction_plan.build_result=ok', 'hv26.hv25.consumption_invariant=ok']:
  if n not in text: raise SystemExit('missing '+n)
for f in ['SUCCESS','success','implemented=true','complete=true','linux_boot=ok','busybox_boot=ok','guest_entered=yes','guest_entered=true','guest_instruction_executed=true','first_guest_instruction=executed','trap_return=executed','trap_return_executed=true','sret=executed','hret=executed','mret=executed','hgatp=written','hgatp_written=true','hgatp_write=ok','hgatp=active','second_stage_translation=ACTIVE','active_stage2=true']:
  if f in text: raise SystemExit('forbidden '+f)
print('PASS smoke-hv26-entry-infrastructure-v0.sh')
PYCHECK
