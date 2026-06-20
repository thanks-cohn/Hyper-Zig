#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TRANSCRIPT="$ROOT/smoke/transcripts/latest-hv40-guest-entry-contract-v0.txt"; ELF="$ROOT/zig-out/bin/zign01d-v0"
mkdir -p "$ROOT/smoke/transcripts"; : > "$TRANSCRIPT"
"$ROOT/scripts/check-zig-version.sh" >/dev/null
"$ROOT/scripts/build.sh" >/dev/null
command -v qemu-system-riscv64 >/dev/null
QEMU=(qemu-system-riscv64 -machine virt -cpu rv64 -smp 1 -m 128M -nographic -monitor none -serial stdio -kernel "$ELF")
python3 - "$TRANSCRIPT" "${QEMU[@]}" <<'PYQ'
import os,selectors,subprocess,sys,time
chain=['hv guest-image load-tiny','hv guest-entry prepare','hv guest-exit record-instruction','hv guest-run arm-no-execute','hv exec arm','hv second-stage configure','hv second-stage validate','hv stage2-table build','hv stage2-table validate','hv bootpkg attach-kernel','hv bootpkg set-entry','hv bootpkg set-cmdline','hv bootpkg attach-initrd','hv bootpkg attach-dtb','hv bootpkg validate','hv dtb build','hv dtb validate','hv fdt build','hv fdt validate','hv handoff prepare','hv handoff validate','hv sbi validate','hv timer arm','hv timer validate','hv sbi-dispatch base-test','hv sbi-dispatch validate','hv context prepare','hv context validate','hv trap-plan prepare','hv trap-plan validate','hv entry-stub prepare','hv entry-stub validate','hv hgatp build','hv hgatp validate','hv hgatp-readiness build','hv hgatp-readiness validate','hv hgatp-write-plan build','hv hgatp-write-plan validate','hv hgatp-write-gate build','hv hgatp-write-gate validate','hv hgatp-write-boundary build','hv hgatp-write-boundary validate','hv hgatp-write-attempt build','hv hgatp-write-attempt validate','hv hgatp-csr-interface build','hv hgatp-csr-interface validate','hv hgatp-csr-result build','hv hgatp-csr-result validate','hv hgatp-hardware-write-prep build','hv hgatp-hardware-write-prep validate','hv hgatp-hardware-write-operation build','hv hgatp-hardware-write-operation validate','hv hgatp-execution-dry-run build','hv hgatp-execution-dry-run validate','hv hgatp-execution-dry-run execute','hv hgatp-hardware-executor build','hv hgatp-hardware-executor validate','hv hgatp-hardware-executor execute','hv hgatp-trap-capture-prep build','hv hgatp-trap-capture-prep validate','hv hgatp-trap-capture-prep prepare','hv hgatp-csr-boundary build','hv hgatp-csr-boundary validate','hv hgatp-csr-boundary execute','hv hgatp-csr-write-eligibility build','hv hgatp-csr-write-eligibility validate','hv hgatp-csr-write-eligibility evaluate']
cmds=['hv guest-entry-contract reset','hv guest-entry-contract build']+chain+['hv guest-entry-contract build','hv guest-entry-contract validate','hv guest-entry-contract fields','hv guest-entry-contract source','hv guest-entry-contract register-frame','hv guest-entry-contract execution-frame','hv guest-entry-contract trap-return-target','hv guest-entry-contract boot-sources','hv guest-entry-contract linux-handoff','hv guest-entry-contract safety','hv hgatp-csr-write-eligibility reset','hv guest-entry-contract build','shutdown']
tr=sys.argv[1]; p=subprocess.Popen(sys.argv[2:],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.STDOUT); os.set_blocking(p.stdout.fileno(),False); sel=selectors.DefaultSelector(); sel.register(p.stdout,selectors.EVENT_READ); seen=bytearray(); ready=False; deadline=time.monotonic()+300
with open(tr,'wb') as out:
 while time.monotonic()<deadline and p.poll() is None:
  for k,_ in sel.select(.05):
   d=k.fileobj.read()
   if d: out.write(d); out.flush(); seen.extend(d)
  if not ready and b'zign01d> ' in seen:
   ready=True
   for c in cmds: p.stdin.write((c+'\n').encode()); p.stdin.flush(); time.sleep(.06)
 if p.poll() is None: p.terminate(); time.sleep(.2)
 while True:
  d=p.stdout.read()
  if not d: break
  out.write(d)
sys.exit(0 if ready else 125)
PYQ
python3 - "$TRANSCRIPT" <<'PYC'
import re,sys
text=open(sys.argv[1],errors='replace').read()
def block(cmd,nth=0):
 p=0; c=0
 while True:
  m=re.search(re.escape('zign01d> '+cmd)+r'\r?\n',text[p:]); assert m,'missing '+cmd
  s=p+m.end(); e=text.find('zign01d> ',s); e=len(text) if e<0 else e
  if c==nth: return text[s:e]
  p=e; c+=1
early=block('hv guest-entry-contract build',0); assert 'blocker=missing-hv39-source' in early or 'blocker=invalid-hv39-source' in early
src=block('hv guest-entry-contract source'); fields=block('hv guest-entry-contract fields'); rf=block('hv guest-entry-contract register-frame'); ef=block('hv guest-entry-contract execution-frame'); tt=block('hv guest-entry-contract trap-return-target'); boot=block('hv guest-entry-contract boot-sources'); lin=block('hv guest-entry-contract linux-handoff'); safe=block('hv guest-entry-contract safety')
for m in ['source_hv39_present=true','source_hv39_valid=true','source_hv39_denied_before_hardware=true','owner_vm_id=0','owner_vcpu_id=0']: assert 'guest_entry_contract.'+m in src,m
assert re.search(r'source_hv39_checksum=0x[1-9a-f][0-9a-f]*',src)
for m in ['guest_pc_present=true','guest_sp_present=true','guest_a0_present=true','guest_a1_present=true','register_frame_present=true','register_frame_valid=true']: assert 'guest_entry_contract.'+m in rf,m
assert re.search(r'guest_pc_value=0x[1-9a-f][0-9a-f]*',rf) and re.search(r'guest_sp_value=0x[1-9a-f][0-9a-f]*',rf)
for m in ['execution_frame_present=true','execution_frame_valid=true']: assert 'guest_entry_contract.'+m in ef,m
for m in ['trap_return_target_present=true','trap_return_target_valid=true']: assert 'guest_entry_contract.'+m in tt,m
for m in ['guest_image_present=true','guest_image_valid=true','boot_package_present=true','boot_package_valid=true','boot_kernel_present=true','boot_initrd_present=true','boot_dtb_present=true','fdt_present=true','fdt_valid=true']: assert 'guest_entry_contract.'+m in boot,m
for m in ['linux_handoff_present=true','linux_handoff_valid=true']: assert 'guest_entry_contract.'+m in lin,m
for m in ['guest_entry_contract_present=true','guest_entry_contract_valid=true','guest_entry_ready=false','trap_return_ready=false','guest_entry_blocked=true','trap_return_blocked=true','source_fingerprint_unchanged=true']: assert 'guest_entry_contract.'+m in fields,m
for m in ['guest_entered=false','first_guest_instruction_executed=false','trap_return_executed=false','active_stage2=false','hgatp_write_performed=false','hgatp_write_attempted=false']: assert 'guest_entry_contract.'+m in safe,m
late=block('hv guest-entry-contract build',2); assert 'blocker=missing-hv39-source' in late or 'blocker=invalid-hv39-source' in late
for bad in ['linux_boot=ok','busybox_boot=ok','alpine_boot=ok','guest_entered=yes','guest_entered=true','first_guest_instruction=executed','first_guest_instruction_executed=true','trap_return=executed','trap_return_executed=true','hgatp=written','hgatp_write=ok','hgatp=active','second_stage_translation=ACTIVE','active_stage2=true','hgatp_write_performed=true']:
 assert bad not in text,bad
PYC
