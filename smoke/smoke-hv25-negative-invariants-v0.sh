#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; LOG_DIR="$ROOT/logs/latest"; mkdir -p "$LOG_DIR" "$ROOT/smoke/transcripts"
TRANSCRIPT="$ROOT/smoke/transcripts/latest-smoke-hv25-negative-invariants-v0.txt"; : > "$TRANSCRIPT"; ELF="$ROOT/zig-out/bin/zign01d-v0"
fail(){ echo "FAIL $*" >&2; exit 1; }
"$ROOT/scripts/check-zig-version.sh" >/dev/null || fail "zig version"; "$ROOT/scripts/build.sh" >/dev/null || fail "build"; command -v qemu-system-riscv64 >/dev/null || fail "qemu"
python3 - "$TRANSCRIPT" qemu-system-riscv64 -machine virt -cpu rv64 -smp 1 -m 128M -nographic -monitor none -serial stdio -kernel "$ELF" <<'PYRUN'
import os,selectors,subprocess,sys,time
transcript=sys.argv[1]; cmd=sys.argv[2:]; commands=['hv hgatp require-hext-test', 'hv hgatp mode-test', 'hv hgatp ppn-alignment-test', 'hv hgatp vmid-bounds-test', 'hv hgatp write-attempt-test', 'hv hgatp active-stage2-test', 'hv stage2-plan require-hgatp-test', 'hv stage2-plan require-stage2-test', 'hv stage2-plan require-table-test', 'hv stage2-plan require-csr-safety-test', 'hv stage2-plan active-stage2-test', 'hv stage2-plan write-attempt-test', 'hv hv25 invariant-all']+["shutdown"]
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
text=Path(sys.argv[1]).read_text(errors='replace'); cmds=['hv hgatp require-hext-test', 'hv hgatp mode-test', 'hv hgatp ppn-alignment-test', 'hv hgatp vmid-bounds-test', 'hv hgatp write-attempt-test', 'hv hgatp active-stage2-test', 'hv stage2-plan require-hgatp-test', 'hv stage2-plan require-stage2-test', 'hv stage2-plan require-table-test', 'hv stage2-plan require-csr-safety-test', 'hv stage2-plan active-stage2-test', 'hv stage2-plan write-attempt-test', 'hv hv25 invariant-all']; blocks={}; cur=0
for c in cmds:
 m='zign01d> '+c; s=text.find(m,cur)
 if s<0: raise SystemExit('missing command '+c)
 e=text.find('zign01d> ',s+len(m)); blocks[c]=text[s:] if e<0 else text[s:e]; cur=len(text) if e<0 else e
for c,needles in {'hv hgatp require-hext-test': ['hv: hgatp.require_hext_test=rejected', 'hv: hgatp.blocker=h-extension-missing'], 'hv hgatp mode-test': ['hv: hgatp.mode_test=rejected', 'hv: hgatp.blocker=invalid-mode'], 'hv hgatp ppn-alignment-test': ['hv: hgatp.ppn_alignment_test=rejected', 'hv: hgatp.blocker=ppn-misaligned'], 'hv hgatp vmid-bounds-test': ['hv: hgatp.vmid_bounds_test=rejected', 'hv: hgatp.blocker=invalid-vmid'], 'hv hgatp write-attempt-test': ['hv: hgatp.write_attempt_test=rejected', 'hv: hgatp.blocker=hgatp-write-attempted'], 'hv hgatp active-stage2-test': ['hv: hgatp.active_stage2_test=rejected', 'hv: hgatp.blocker=active-stage2-forbidden'], 'hv stage2-plan require-hgatp-test': ['hv: stage2_plan.require_hgatp_test=rejected', 'hv: stage2_plan.blocker=require-hgatp'], 'hv stage2-plan require-stage2-test': ['hv: stage2_plan.require_stage2_test=rejected', 'hv: stage2_plan.blocker=require-stage2'], 'hv stage2-plan require-table-test': ['hv: stage2_plan.require_table_test=rejected', 'hv: stage2_plan.blocker=require-table'], 'hv stage2-plan require-csr-safety-test': ['hv: stage2_plan.require_csr_safety_test=rejected', 'hv: stage2_plan.blocker=require-csr-safety'], 'hv stage2-plan active-stage2-test': ['hv: stage2_plan.active_stage2_test=rejected', 'hv: stage2_plan.blocker=active-stage2-forbidden'], 'hv stage2-plan write-attempt-test': ['hv: stage2_plan.write_attempt_test=rejected', 'hv: stage2_plan.blocker=hgatp-write-attempted'], 'hv hv25 invariant-all': ['hv: hv25.hgatp.lifecycle_invariant=ok', 'hv: hv25.stage2_plan.corruption_invariant=ok']}.items():
 for n in needles:
  if n not in blocks[c]: raise SystemExit(f'missing {n} in {c}\n{blocks[c]}')
for f in ['linux_guest=supported','guest_entered=yes','first_guest_instruction=executed','trap_return=executed','hgatp_write=ok','second_stage_translation=ACTIVE']:
 if f in text: raise SystemExit('forbidden '+f)
print('PASS smoke-hv25-negative-invariants-v0.sh')
PYCHECK
