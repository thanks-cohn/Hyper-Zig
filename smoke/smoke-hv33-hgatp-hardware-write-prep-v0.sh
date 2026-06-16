#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$ROOT/kernel/hypervisor/hgatp_hardware_write_prep.zig" ]] || { echo "missing hgatp_hardware_write_prep.zig" >&2; exit 1; }
TRANSCRIPT="$ROOT/smoke/transcripts/latest-hv33-hgatp-hardware-write-prep-v0.txt"; ELF="$ROOT/zig-out/bin/zign01d-v0"
mkdir -p "$ROOT/smoke/transcripts"; : > "$TRANSCRIPT"
"$ROOT/scripts/check-zig-version.sh" >/dev/null
"$ROOT/scripts/build.sh" >/dev/null
command -v qemu-system-riscv64 >/dev/null
QEMU=(qemu-system-riscv64 -machine virt -cpu rv64 -smp 1 -m 128M -nographic -monitor none -serial stdio -kernel "$ELF")
python3 - "$TRANSCRIPT" "${QEMU[@]}" <<'PY'
import os,selectors,subprocess,sys,time
tr=sys.argv[1]; q=sys.argv[2:]
cmds=['hv hgatp-hardware-write-prep reset','hv hgatp-hardware-write-prep build','hv hgatp build','hv hgatp validate','hv hgatp-readiness build','hv hgatp-readiness validate','hv hgatp-write-plan build','hv hgatp-write-plan validate','hv hgatp-write-gate build','hv hgatp-write-gate validate','hv hgatp-write-boundary build','hv hgatp-write-boundary validate','hv hgatp-write-attempt build','hv hgatp-write-attempt validate','hv hgatp-csr-interface build','hv hgatp-csr-interface validate','hv hgatp-csr-interface request','hv hgatp-csr-interface result','hv hgatp-csr-interface decision','hv hgatp-csr-result build','hv hgatp-csr-result validate','hv hgatp-csr-result fields','hv hgatp-hardware-write-prep build','hv hgatp-hardware-write-prep validate','hv hgatp-hardware-write-prep fields','hv hgatp-hardware-write-prep envelope','hv hgatp-hardware-write-prep trap-envelope','hv hgatp-hardware-write-prep readback-envelope','hv hgatp-hardware-write-prep decision','hv hgatp-csr-result reset','hv hgatp-hardware-write-prep build','shutdown']
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
text=open(sys.argv[1],errors='replace').read(); cmds=['hv hgatp-hardware-write-prep reset','hv hgatp-hardware-write-prep build','hv hgatp build','hv hgatp validate','hv hgatp-readiness build','hv hgatp-readiness validate','hv hgatp-write-plan build','hv hgatp-write-plan validate','hv hgatp-write-gate build','hv hgatp-write-gate validate','hv hgatp-write-boundary build','hv hgatp-write-boundary validate','hv hgatp-write-attempt build','hv hgatp-write-attempt validate','hv hgatp-csr-interface build','hv hgatp-csr-interface validate','hv hgatp-csr-interface request','hv hgatp-csr-interface result','hv hgatp-csr-interface decision','hv hgatp-csr-result build','hv hgatp-csr-result validate','hv hgatp-csr-result fields','hv hgatp-hardware-write-prep build','hv hgatp-hardware-write-prep validate','hv hgatp-hardware-write-prep fields','hv hgatp-hardware-write-prep envelope','hv hgatp-hardware-write-prep trap-envelope','hv hgatp-hardware-write-prep readback-envelope','hv hgatp-hardware-write-prep decision','hv hgatp-csr-result reset','hv hgatp-hardware-write-prep build']
blocks=[]; pos=0
for c in cmds:
 m=re.search(re.escape('zign01d> '+c)+r'\r?\n', text[pos:]); assert m, 'missing '+c
 start=pos+m.end(); end=text.find('zign01d> ', start); end=len(text) if end<0 else end; blocks.append(text[start:end]); pos=end
assert 'hv: hgatp_hardware_write_prep.build_result=rejected' in blocks[1]
assert 'hv: hgatp_hardware_write_prep.blocker=missing-csr-result' in blocks[1] or 'hv: hgatp_hardware_write_prep.blocker=invalid-csr-result' in blocks[1]
assert 'hv: hgatp_hardware_write_prep.build_result=ok' in blocks[22]
assert 'hv: hgatp_hardware_write_prep.validate_result=ok' in blocks[23]
for m in ['csr_result_present=true','csr_result_valid=true','hardware_write_envelope_present=true','hardware_write_policy_allows=false','hardware_write_policy_denies=true','hardware_write_blocked_before_call=true','hardware_write_call_reachable=false','hardware_write_call_called=false','raw_write_function_known=true','raw_write_function_allowed=false','raw_write_function_called=false','hardware_write_call_returned=false','prior_denied_before_csr=true','prior_blocked_before_asm=true','prior_not_called=true','prior_unsafe_to_call=true','hgatp_write_attempted=false','hgatp_write_performed=false','active_stage2=false','guest_entered=false','first_guest_instruction_executed=false']:
 assert 'hv: hgatp_hardware_write_prep.'+m in blocks[24], m
for m in ['trap_envelope_present=true','trap_capture_armed=false','trap_capture_observed=false','trap_scause=0','trap_stval=0','trap_sepc=0']:
 assert 'hv: hgatp_hardware_write_prep.'+m in blocks[26], m
for m in ['readback_envelope_present=true','readback_allowed=false','readback_attempted=false','readback_value=0x0','readback_valid=false']:
 assert 'hv: hgatp_hardware_write_prep.'+m in blocks[27], m
assert 'hv: hgatp_hardware_write_prep.decision=hardware_write_blocked' in blocks[28]
ic=re.search(r'hv: hgatp_csr_interface.request_checksum=(0x[0-9a-f]+)', blocks[16], re.I); iv=re.search(r'hv: hgatp_csr_interface.request_value=(0x[0-9a-f]+)', blocks[16], re.I)
rc=re.search(r'hv: hgatp_hardware_write_prep.csr_result_request_checksum=(0x[0-9a-f]+)', blocks[24], re.I); rv=re.search(r'hv: hgatp_hardware_write_prep.csr_result_request_value=(0x[0-9a-f]+)', blocks[24], re.I)
assert ic and rc and ic.group(1).lower()==rc.group(1).lower(), 'checksum propagation failed'
assert iv and rv and iv.group(1).lower()==rv.group(1).lower(), 'request propagation failed'
assert 'hv: hgatp_hardware_write_prep.build_result=rejected' in blocks[30]
assert 'hv: hgatp_hardware_write_prep.blocker=missing-csr-result' in blocks[30] or 'hv: hgatp_hardware_write_prep.blocker=invalid-csr-result' in blocks[30]
for bad in ['linux_boot=ok','busybox_boot=ok','alpine_boot=ok','guest_entered=yes','trap_return=executed','hgatp=written','hgatp_write=ok','second_stage_translation=ACTIVE','active_stage2=true','hgatp_write_performed=true','raw_write_function_called=true','hardware_write_call_called=true','trap_capture_observed=true','readback_valid=true']:
 assert bad not in text, bad
PY
