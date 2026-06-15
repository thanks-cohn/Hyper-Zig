#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$ROOT/kernel/hypervisor/hgatp_csr_result.zig" ]] || { echo "missing hgatp_csr_result.zig" >&2; exit 1; }
TRANSCRIPT="$ROOT/smoke/transcripts/latest-hv32-hgatp-csr-result-v0.txt"; ELF="$ROOT/zig-out/bin/zign01d-v0"
mkdir -p "$ROOT/smoke/transcripts"; : > "$TRANSCRIPT"
"$ROOT/scripts/check-zig-version.sh" >/dev/null
"$ROOT/scripts/build.sh" >/dev/null
command -v qemu-system-riscv64 >/dev/null
QEMU=(qemu-system-riscv64 -machine virt -cpu rv64 -smp 1 -m 128M -nographic -monitor none -serial stdio -kernel "$ELF")
python3 - "$TRANSCRIPT" "${QEMU[@]}" <<'PY'
import os,selectors,subprocess,sys,time
tr=sys.argv[1]; q=sys.argv[2:]
cmds=['hv hgatp-csr-result reset','hv hgatp-csr-result build','hv hgatp build','hv hgatp validate','hv hgatp-readiness build','hv hgatp-readiness validate','hv hgatp-write-plan build','hv hgatp-write-plan validate','hv hgatp-write-gate build','hv hgatp-write-gate validate','hv hgatp-write-boundary build','hv hgatp-write-boundary validate','hv hgatp-write-attempt build','hv hgatp-write-attempt validate','hv hgatp-csr-interface build','hv hgatp-csr-interface validate','hv hgatp-csr-interface request','hv hgatp-csr-interface result','hv hgatp-csr-interface decision','hv hgatp-csr-result build','hv hgatp-csr-result validate','hv hgatp-csr-result fields','hv hgatp-csr-result observation','hv hgatp-csr-result trap-slot','hv hgatp-csr-result readback','hv hgatp-csr-result decision','hv hgatp-csr-interface reset','hv hgatp-csr-result build','shutdown']
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
text=open(sys.argv[1],errors='replace').read(); cmds=['hv hgatp-csr-result reset','hv hgatp-csr-result build','hv hgatp build','hv hgatp validate','hv hgatp-readiness build','hv hgatp-readiness validate','hv hgatp-write-plan build','hv hgatp-write-plan validate','hv hgatp-write-gate build','hv hgatp-write-gate validate','hv hgatp-write-boundary build','hv hgatp-write-boundary validate','hv hgatp-write-attempt build','hv hgatp-write-attempt validate','hv hgatp-csr-interface build','hv hgatp-csr-interface validate','hv hgatp-csr-interface request','hv hgatp-csr-interface result','hv hgatp-csr-interface decision','hv hgatp-csr-result build','hv hgatp-csr-result validate','hv hgatp-csr-result fields','hv hgatp-csr-result observation','hv hgatp-csr-result trap-slot','hv hgatp-csr-result readback','hv hgatp-csr-result decision','hv hgatp-csr-interface reset','hv hgatp-csr-result build']
blocks=[]; pos=0
for c in cmds:
 m=re.search(re.escape('zign01d> '+c)+r'\r?\n', text[pos:]); assert m, 'missing '+c
 start=pos+m.end(); end=text.find('zign01d> ', start); end=len(text) if end<0 else end; blocks.append(text[start:end]); pos=end
assert 'hv: hgatp_csr_result.build_result=rejected' in blocks[1]
assert 'hv: hgatp_csr_result.blocker=missing-csr-interface' in blocks[1] or 'hv: hgatp_csr_result.blocker=invalid-csr-interface' in blocks[1]
assert 'hv: hgatp_csr_result.build_result=ok' in blocks[19]
assert 'hv: hgatp_csr_result.validate_result=ok' in blocks[20]
for m in ['csr_interface_present=true','csr_interface_valid=true','csr_write_function_called=false','raw_asm_called=false','raw_asm_returned=false','denied_before_csr=true','blocked_before_asm=true','not_called=true','unsafe_to_call=true','hgatp_write_attempted=false','hgatp_write_performed=false','active_stage2=false','guest_entered=false','first_guest_instruction_executed=false']:
 assert 'hv: hgatp_csr_result.'+m in blocks[21], m
for m in ['fault_slot_present=true','fault_observed=false','fault_scause=0','fault_stval=0','fault_sepc=0']:
 assert 'hv: hgatp_csr_result.'+m in blocks[23], m
for m in ['readback_slot_present=true','readback_attempted=false','readback_value=0x0','readback_valid=false']:
 assert 'hv: hgatp_csr_result.'+m in blocks[24], m
assert 'hv: hgatp_csr_result.decision=denied_not_called_accounted' in blocks[25]
ic=re.search(r'hv: hgatp_csr_interface.request_checksum=(0x[0-9a-f]+)', blocks[16], re.I); iv=re.search(r'hv: hgatp_csr_interface.request_value=(0x[0-9a-f]+)', blocks[16], re.I)
rc=re.search(r'hv: hgatp_csr_result.csr_interface_request_checksum=(0x[0-9a-f]+)', blocks[21], re.I); rv=re.search(r'hv: hgatp_csr_result.csr_interface_request_value=(0x[0-9a-f]+)', blocks[21], re.I)
assert ic and rc and ic.group(1).lower()==rc.group(1).lower(), 'checksum propagation failed'
assert iv and rv and iv.group(1).lower()==rv.group(1).lower(), 'request propagation failed'
assert 'hv: hgatp_csr_result.build_result=rejected' in blocks[27]
assert 'hv: hgatp_csr_result.blocker=missing-csr-interface' in blocks[27] or 'hv: hgatp_csr_result.blocker=invalid-csr-interface' in blocks[27]
for bad in ['linux_boot=ok','busybox_boot=ok','alpine_boot=ok','guest_entered=yes','trap_return=executed','hgatp=written','hgatp_write=ok','second_stage_translation=ACTIVE','active_stage2=true','hgatp_write_performed=true','raw_asm_called=true','csr_write_function_called=true','fault_observed=true','readback_valid=true']:
 assert bad not in text, bad
PY
