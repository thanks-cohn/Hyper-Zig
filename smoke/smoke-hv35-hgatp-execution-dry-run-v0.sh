#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -f "$ROOT/kernel/hypervisor/hgatp_execution_dry_run.zig" ]] || { echo "missing hgatp_execution_dry_run.zig" >&2; exit 1; }
TRANSCRIPT="$ROOT/smoke/transcripts/latest-hv35-hgatp-execution-dry-run-v0.txt"; ELF="$ROOT/zig-out/bin/zign01d-v0"
mkdir -p "$ROOT/smoke/transcripts"; : > "$TRANSCRIPT"
"$ROOT/scripts/check-zig-version.sh" >/dev/null
"$ROOT/scripts/build.sh" >/dev/null
command -v qemu-system-riscv64 >/dev/null
QEMU=(qemu-system-riscv64 -machine virt -cpu rv64 -smp 1 -m 128M -nographic -monitor none -serial stdio -kernel "$ELF")
python3 - "$TRANSCRIPT" "${QEMU[@]}" <<'PY'
import os,selectors,subprocess,sys,time
cmds=['hv hgatp-execution-dry-run reset','hv hgatp-execution-dry-run build','hv hgatp build','hv hgatp validate','hv hgatp-readiness build','hv hgatp-readiness validate','hv hgatp-write-plan build','hv hgatp-write-plan validate','hv hgatp-write-gate build','hv hgatp-write-gate validate','hv hgatp-write-boundary build','hv hgatp-write-boundary validate','hv hgatp-write-attempt build','hv hgatp-write-attempt validate','hv hgatp-csr-interface build','hv hgatp-csr-interface validate','hv hgatp-csr-result build','hv hgatp-csr-result validate','hv hgatp-hardware-write-prep build','hv hgatp-hardware-write-prep validate','hv hgatp-hardware-write-operation build','hv hgatp-hardware-write-operation validate','hv hgatp-hardware-write-operation fields','hv hgatp-hardware-write-operation request','hv hgatp-execution-dry-run build','hv hgatp-execution-dry-run validate','hv hgatp-execution-dry-run fields','hv hgatp-execution-dry-run request','hv hgatp-execution-dry-run steps','hv hgatp-execution-dry-run execute','hv hgatp-execution-dry-run fields','hv hgatp-execution-dry-run steps','hv hgatp-execution-dry-run result','hv hgatp-execution-dry-run trap-slot','hv hgatp-execution-dry-run readback','hv hgatp-execution-dry-run decision','hv hgatp-hardware-write-operation reset','hv hgatp-execution-dry-run build','shutdown']
tr=sys.argv[1]; q=sys.argv[2:]; p=subprocess.Popen(q,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.STDOUT); os.set_blocking(p.stdout.fileno(),False); sel=selectors.DefaultSelector(); sel.register(p.stdout,selectors.EVENT_READ); seen=bytearray(); ready=False; deadline=time.monotonic()+100
with open(tr,'wb') as out:
 while time.monotonic()<deadline and p.poll() is None:
  for k,_ in sel.select(.05):
   data=k.fileobj.read()
   if data: out.write(data); out.flush(); seen.extend(data)
  if not ready and b'zign01d> ' in seen:
   ready=True
   for c in cmds: p.stdin.write((c+'\n').encode()); p.stdin.flush(); time.sleep(.13)
 if p.poll() is None: p.terminate(); time.sleep(.2)
 while True:
  data=p.stdout.read()
  if not data: break
  out.write(data)
sys.exit(0 if ready else 125)
PY
python3 - "$TRANSCRIPT" <<'PY'
import re,sys
text=open(sys.argv[1],errors='replace').read(); cmds=['hv hgatp-execution-dry-run reset','hv hgatp-execution-dry-run build','hv hgatp build','hv hgatp validate','hv hgatp-readiness build','hv hgatp-readiness validate','hv hgatp-write-plan build','hv hgatp-write-plan validate','hv hgatp-write-gate build','hv hgatp-write-gate validate','hv hgatp-write-boundary build','hv hgatp-write-boundary validate','hv hgatp-write-attempt build','hv hgatp-write-attempt validate','hv hgatp-csr-interface build','hv hgatp-csr-interface validate','hv hgatp-csr-result build','hv hgatp-csr-result validate','hv hgatp-hardware-write-prep build','hv hgatp-hardware-write-prep validate','hv hgatp-hardware-write-operation build','hv hgatp-hardware-write-operation validate','hv hgatp-hardware-write-operation fields','hv hgatp-hardware-write-operation request','hv hgatp-execution-dry-run build','hv hgatp-execution-dry-run validate','hv hgatp-execution-dry-run fields','hv hgatp-execution-dry-run request','hv hgatp-execution-dry-run steps','hv hgatp-execution-dry-run execute','hv hgatp-execution-dry-run fields','hv hgatp-execution-dry-run steps','hv hgatp-execution-dry-run result','hv hgatp-execution-dry-run trap-slot','hv hgatp-execution-dry-run readback','hv hgatp-execution-dry-run decision','hv hgatp-hardware-write-operation reset','hv hgatp-execution-dry-run build']
blocks=[]; pos=0
for c in cmds:
 m=re.search(re.escape('zign01d> '+c)+r'\r?\n', text[pos:]); assert m, 'missing '+c
 start=pos+m.end(); end=text.find('zign01d> ', start); end=len(text) if end<0 else end; blocks.append(text[start:end]); pos=end
assert 'blocker=missing_operation' in blocks[1] or 'blocker=invalid_operation' in blocks[1]
assert 'hv: hgatp_execution_dry_run.executor_entered=false' in blocks[1]
assert 'hv: hgatp_execution_dry_run.execute_count=0' in blocks[1]
for m in ['operation_present=true','operation_valid=true','dry_run_request_present=true','executor_entered=false','executor_returned=false','execute_count=0']:
 assert 'hv: hgatp_execution_dry_run.'+m in blocks[26], m
oc=re.search(r'operation_request_checksum=(0x[0-9a-f]+)', blocks[23], re.I); dc=re.search(r'dry_run_request_checksum=(0x[0-9a-f]+)', blocks[27], re.I); ov=re.search(r'operation_request_value=(0x[0-9a-f]+)', blocks[23], re.I); dv=re.search(r'dry_run_request_value=(0x[0-9a-f]+)', blocks[27], re.I)
assert oc and dc and oc.group(1).lower()==dc.group(1).lower(); assert ov and dv and ov.group(1).lower()==dv.group(1).lower()
for m in ['executor_entered=true','executor_returned=true','execute_count=1','step_source_loaded=true','step_preflight_checked=true','step_policy_checked=true','step_opt_in_checked=true','step_denied_before_csr=true','step_blocked_before_raw_write=true','step_raw_write_skipped=true','step_result_recorded=true','step_safe_return_recorded=true','execution_policy_allows=false','execution_policy_denies=true','execution_denied_before_csr=true','execution_blocked_before_raw_write=true','execution_reached_raw_write=false','execution_called_raw_write=false','execution_returned_from_raw_write=false','raw_write_function_known=true','raw_write_function_allowed=false','raw_write_function_called=false','hgatp_write_attempted=false','hgatp_write_performed=false','active_stage2=false','guest_entered=false','first_guest_instruction_executed=false']:
 assert 'hv: hgatp_execution_dry_run.'+m in blocks[30], m
assert re.search(r'executor_step_count=([1-9][0-9]*)', blocks[31])
for m in ['trap_slot_present=true','trap_capture_armed=false','trap_observed=false','trap_scause=0','trap_stval=0','trap_sepc=0']:
 assert 'hv: hgatp_execution_dry_run.'+m in blocks[33], m
for m in ['readback_slot_present=true','readback_allowed=false','readback_attempted=false','readback_value=0x0','readback_valid=false']:
 assert 'hv: hgatp_execution_dry_run.'+m in blocks[34], m
assert 'decision=execution_denied_before_csr' in blocks[35]
assert 'blocker=missing_operation' in blocks[37] or 'blocker=invalid_operation' in blocks[37]
for bad in ['linux_boot=ok','busybox_boot=ok','alpine_boot=ok','guest_entered=yes','trap_return=executed','hgatp=written','hgatp_write=ok','hgatp=active','second_stage_translation=ACTIVE']:
 assert bad not in text, bad
PY
