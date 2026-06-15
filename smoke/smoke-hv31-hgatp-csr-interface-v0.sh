#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$ROOT/kernel/hypervisor/hgatp_csr_interface.zig" ]] || { echo "missing hgatp_csr_interface.zig" >&2; exit 1; }
TRANSCRIPT="$ROOT/smoke/transcripts/latest-hv31-hgatp-csr-interface-v0.txt"; ELF="$ROOT/zig-out/bin/zign01d-v0"
mkdir -p "$ROOT/smoke/transcripts"; : > "$TRANSCRIPT"
"$ROOT/scripts/check-zig-version.sh" >/dev/null
"$ROOT/scripts/build.sh" >/dev/null
command -v qemu-system-riscv64 >/dev/null
QEMU=(qemu-system-riscv64 -machine virt -cpu rv64 -smp 1 -m 128M -nographic -monitor none -serial stdio -kernel "$ELF")
python3 - "$TRANSCRIPT" "${QEMU[@]}" <<'PY'
import os,selectors,subprocess,sys,time
tr=sys.argv[1]; q=sys.argv[2:]
cmds=['hv hgatp-csr-interface reset','hv hgatp-csr-interface build','hv hgatp build','hv hgatp validate','hv hgatp-readiness build','hv hgatp-readiness validate','hv hgatp-write-plan build','hv hgatp-write-plan validate','hv hgatp-write-gate build','hv hgatp-write-gate validate','hv hgatp-write-boundary build','hv hgatp-write-boundary validate','hv hgatp-write-attempt build','hv hgatp-write-attempt validate','hv hgatp-write-attempt request','hv hgatp-csr-interface build','hv hgatp-csr-interface validate','hv hgatp-csr-interface fields','hv hgatp-csr-interface request','hv hgatp-csr-interface result','hv hgatp-csr-interface decision','hv hgatp-write-attempt reset','hv hgatp-csr-interface build','shutdown']
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
text=open(sys.argv[1],errors='replace').read(); cmds=['hv hgatp-csr-interface reset','hv hgatp-csr-interface build','hv hgatp build','hv hgatp validate','hv hgatp-readiness build','hv hgatp-readiness validate','hv hgatp-write-plan build','hv hgatp-write-plan validate','hv hgatp-write-gate build','hv hgatp-write-gate validate','hv hgatp-write-boundary build','hv hgatp-write-boundary validate','hv hgatp-write-attempt build','hv hgatp-write-attempt validate','hv hgatp-write-attempt request','hv hgatp-csr-interface build','hv hgatp-csr-interface validate','hv hgatp-csr-interface fields','hv hgatp-csr-interface request','hv hgatp-csr-interface result','hv hgatp-csr-interface decision','hv hgatp-write-attempt reset','hv hgatp-csr-interface build']
blocks=[]; pos=0
for c in cmds:
 m=re.search(re.escape('zign01d> '+c)+r'\r?\n', text[pos:]); assert m, 'missing '+c
 start=pos+m.end(); end=text.find('zign01d> ', start); end=len(text) if end<0 else end; blocks.append(text[start:end]); pos=end
assert 'hv: hgatp_csr_interface.build_result=rejected' in blocks[1]
assert 'hv: hgatp_csr_interface.blocker=missing-write-attempt' in blocks[1] or 'hv: hgatp_csr_interface.blocker=invalid-write-attempt' in blocks[1]
for m in ['write_attempt_present=true','write_attempt_valid=true','csr_write_function_present=true','csr_write_function_called=false','csr_write_call_denied_by_policy=true','csr_write_call_allowed_by_policy=false','csr_write_call_blocked_before_asm=true','raw_asm_called=false','hgatp_write_attempted=false','hgatp_write_performed=false','active_stage2=false','guest_entered=false','first_guest_instruction_executed=false']:
 assert 'hv: hgatp_csr_interface.'+m in blocks[17], m
assert 'hv: hgatp_csr_interface.validate_result=ok' in blocks[16]
areq=re.search(r'hv: hgatp_write_attempt.attempt_request_checksum=(0x[0-9a-f]+)', blocks[14], re.I); aval=re.search(r'hv: hgatp_write_attempt.planned_hgatp_value=(0x[0-9a-f]+)', blocks[14], re.I)
creq=re.search(r'hv: hgatp_csr_interface.write_attempt_request_checksum=(0x[0-9a-f]+)', blocks[17], re.I); cval=re.search(r'hv: hgatp_csr_interface.request_value=(0x[0-9a-f]+)', blocks[18], re.I)
assert areq and creq and areq.group(1).lower()==creq.group(1).lower(), 'checksum propagation failed'
assert aval and cval and aval.group(1).lower()==cval.group(1).lower(), 'request propagation failed'
assert 'hv: hgatp_csr_interface.decision=deny_before_csr' in blocks[20]
assert 'hv: hgatp_csr_interface.build_result=rejected' in blocks[22]
assert 'hv: hgatp_csr_interface.blocker=missing-write-attempt' in blocks[22] or 'hv: hgatp_csr_interface.blocker=invalid-write-attempt' in blocks[22]
for bad in ['linux_boot=ok','busybox_boot=ok','alpine_boot=ok','guest_entered=yes','trap_return=executed','hgatp=written','hgatp_write=ok','second_stage_translation=ACTIVE','active_stage2=true','hgatp_write_performed=true','raw_asm_called=true','csr_write_function_called=true']:
 assert bad not in text, bad
PY
