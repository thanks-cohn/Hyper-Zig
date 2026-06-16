#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$ROOT/kernel/hypervisor/hgatp_hardware_write_operation.zig" ]] || { echo "missing hgatp_hardware_write_operation.zig" >&2; exit 1; }
TRANSCRIPT="$ROOT/smoke/transcripts/latest-hv34-hgatp-hardware-write-operation-v0.txt"; ELF="$ROOT/zig-out/bin/zign01d-v0"
mkdir -p "$ROOT/smoke/transcripts"; : > "$TRANSCRIPT"
"$ROOT/scripts/check-zig-version.sh" >/dev/null
"$ROOT/scripts/build.sh" >/dev/null
command -v qemu-system-riscv64 >/dev/null
QEMU=(qemu-system-riscv64 -machine virt -cpu rv64 -smp 1 -m 128M -nographic -monitor none -serial stdio -kernel "$ELF")
python3 - "$TRANSCRIPT" "${QEMU[@]}" <<'PY'
import os,selectors,subprocess,sys,time
tr=sys.argv[1]; q=sys.argv[2:]
cmds=['hv hgatp-hardware-write-operation reset','hv hgatp-hardware-write-operation build','hv hgatp build','hv hgatp validate','hv hgatp-readiness build','hv hgatp-readiness validate','hv hgatp-write-plan build','hv hgatp-write-plan validate','hv hgatp-write-gate build','hv hgatp-write-gate validate','hv hgatp-write-boundary build','hv hgatp-write-boundary validate','hv hgatp-write-attempt build','hv hgatp-write-attempt validate','hv hgatp-csr-interface build','hv hgatp-csr-interface validate','hv hgatp-csr-result build','hv hgatp-csr-result validate','hv hgatp-hardware-write-prep build','hv hgatp-hardware-write-prep validate','hv hgatp-hardware-write-prep fields','hv hgatp-hardware-write-prep envelope','hv hgatp-hardware-write-operation build','hv hgatp-hardware-write-operation validate','hv hgatp-hardware-write-operation fields','hv hgatp-hardware-write-operation request','hv hgatp-hardware-write-operation preflight','hv hgatp-hardware-write-operation result','hv hgatp-hardware-write-operation trap-slot','hv hgatp-hardware-write-operation readback','hv hgatp-hardware-write-operation decision','hv hgatp-hardware-write-prep reset','hv hgatp-hardware-write-operation build','shutdown']
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
text=open(sys.argv[1],errors='replace').read(); cmds=['hv hgatp-hardware-write-operation reset','hv hgatp-hardware-write-operation build','hv hgatp build','hv hgatp validate','hv hgatp-readiness build','hv hgatp-readiness validate','hv hgatp-write-plan build','hv hgatp-write-plan validate','hv hgatp-write-gate build','hv hgatp-write-gate validate','hv hgatp-write-boundary build','hv hgatp-write-boundary validate','hv hgatp-write-attempt build','hv hgatp-write-attempt validate','hv hgatp-csr-interface build','hv hgatp-csr-interface validate','hv hgatp-csr-result build','hv hgatp-csr-result validate','hv hgatp-hardware-write-prep build','hv hgatp-hardware-write-prep validate','hv hgatp-hardware-write-prep fields','hv hgatp-hardware-write-prep envelope','hv hgatp-hardware-write-operation build','hv hgatp-hardware-write-operation validate','hv hgatp-hardware-write-operation fields','hv hgatp-hardware-write-operation request','hv hgatp-hardware-write-operation preflight','hv hgatp-hardware-write-operation result','hv hgatp-hardware-write-operation trap-slot','hv hgatp-hardware-write-operation readback','hv hgatp-hardware-write-operation decision','hv hgatp-hardware-write-prep reset','hv hgatp-hardware-write-operation build']
blocks=[]; pos=0
for c in cmds:
 m=re.search(re.escape('zign01d> '+c)+r'\r?\n', text[pos:]); assert m, 'missing '+c
 start=pos+m.end(); end=text.find('zign01d> ', start); end=len(text) if end<0 else end; blocks.append(text[start:end]); pos=end
assert 'hv: hgatp_hardware_write_operation.build_result=rejected' in blocks[1]
assert 'blocker=missing-prep' in blocks[1] or 'blocker=invalid-prep' in blocks[1]
assert 'hv: hgatp_hardware_write_operation.build_result=denied-before-csr' in blocks[22]
assert 'hv: hgatp_hardware_write_operation.validate_result=denied-before-csr' in blocks[23]
for m in ['prep_present=true','prep_valid=true','operation_request_present=true','operation_explicit_opt_in=false','operation_opt_in_required=true','operation_opt_in_default_false=true','operation_policy_allows=false','operation_policy_denies=true','operation_denied_before_csr=true','operation_blocked_before_raw_write=true','operation_call_reachable=false','operation_call_called=false','operation_call_returned=false','raw_write_function_known=true','raw_write_function_allowed=false','raw_write_function_called=false','preflight_present=true','preflight_passed=false','preflight_failed=true','trap_slot_present=true','trap_capture_armed=false','trap_observed=false','trap_scause=0','trap_stval=0','trap_sepc=0','readback_slot_present=true','readback_allowed=false','readback_attempted=false','readback_value=0x0','readback_valid=false','hgatp_write_attempted=false','hgatp_write_performed=false','active_stage2=false','guest_entered=false','first_guest_instruction_executed=false']:
 assert 'hv: hgatp_hardware_write_operation.'+m in blocks[24], m
assert 'hv: hgatp_hardware_write_operation.preflight_present=true' in blocks[26]
assert 'hv: hgatp_hardware_write_operation.result_code=operation_denied_before_csr' in blocks[27]
assert 'hv: hgatp_hardware_write_operation.trap_observed=false' in blocks[28]
assert 'hv: hgatp_hardware_write_operation.readback_attempted=false' in blocks[29]
assert 'hv: hgatp_hardware_write_operation.decision=operation_denied_before_csr' in blocks[30]
pc=re.search(r'hv: hgatp_hardware_write_prep.hardware_write_checksum=(0x[0-9a-f]+)', blocks[20], re.I); oc=re.search(r'hv: hgatp_hardware_write_operation.operation_request_checksum=(0x[0-9a-f]+)', blocks[25], re.I)
pv=re.search(r'hv: hgatp_hardware_write_prep.hardware_write_value=(0x[0-9a-f]+)', blocks[21], re.I) or re.search(r'hv: hgatp_hardware_write_prep.csr_result_request_value=(0x[0-9a-f]+)', blocks[20], re.I); ov=re.search(r'hv: hgatp_hardware_write_operation.operation_request_value=(0x[0-9a-f]+)', blocks[25], re.I)
assert pc and oc and pc.group(1).lower()==oc.group(1).lower(), 'checksum propagation failed'
assert pv and ov and pv.group(1).lower()==ov.group(1).lower(), 'request propagation failed'
assert 'blocker=missing-prep' in blocks[32] or 'blocker=invalid-prep' in blocks[32]
for bad in ['linux_boot=ok','busybox_boot=ok','alpine_boot=ok','guest_entered=yes','trap_return=executed','hgatp=written','hgatp_write=ok','hgatp=active','second_stage_translation=ACTIVE','active_stage2=true','hgatp_write_performed=true','raw_write_function_called=true','operation_call_called=true','operation_call_returned=true','trap_observed=true','readback_valid=true']:
 assert bad not in text, bad
PY
