#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT/logs/latest"; SMOKE_LOG="$LOG_DIR/smoke-hv-linux-handoff-v0.log"; QEMU_LOG="$LOG_DIR/qemu-hv-linux-handoff-v0.log"
TRANSCRIPT="$ROOT/smoke/transcripts/latest-hv-linux-handoff-v0.txt"; TRANSCRIPT_COPY="$LOG_DIR/qemu-smoke-hv-linux-handoff-v0-transcript.txt"; ELF="$ROOT/zig-out/bin/zign01d-v0"
mkdir -p "$LOG_DIR" "$ROOT/smoke/transcripts"; : > "$SMOKE_LOG"; : > "$QEMU_LOG"; : > "$TRANSCRIPT"
stamp(){ date -u '+%Y-%m-%dT%H:%M:%SZ'; }
log(){ printf '[%s][ZIGN01D][INFO][SMOKE][SMOKEHV18] %s\n' "$(stamp)" "$*" | tee -a "$SMOKE_LOG"; }
fail(){ printf 'FAIL %s\n' "$*" | tee -a "$SMOKE_LOG" >&2; printf 'inspect: %s %s %s\n' "$SMOKE_LOG" "$QEMU_LOG" "$TRANSCRIPT" | tee -a "$SMOKE_LOG" >&2; exit 1; }
log "checking Zig 0.14.x"; "$ROOT/scripts/check-zig-version.sh" >>"$SMOKE_LOG" 2>&1 || fail "Zig 0.14.x check failed"
log "running build"; "$ROOT/scripts/build.sh" >>"$SMOKE_LOG" 2>&1 || fail "build failed"
[[ -f "$ELF" ]] || fail "missing kernel ELF: $ELF"; command -v qemu-system-riscv64 >/dev/null 2>&1 || fail "qemu-system-riscv64 not found"
QEMU_CMD=(qemu-system-riscv64 -machine virt -cpu rv64 -smp 1 -m 128M -nographic -monitor none -serial stdio -kernel "$ELF")
printf '[%s][ZIGN01D][INFO][QEMU][QEMUHV18] command:' "$(stamp)" | tee -a "$QEMU_LOG" "$SMOKE_LOG"; printf ' %q' "${QEMU_CMD[@]}" | tee -a "$QEMU_LOG" "$SMOKE_LOG"; printf '\n' | tee -a "$QEMU_LOG" "$SMOKE_LOG"
set +e
python3 - "$TRANSCRIPT" "${QEMU_CMD[@]}" <<'PYSMOKE'
import os,selectors,subprocess,sys,time
transcript=sys.argv[1]; cmd=sys.argv[2:]
commands=["hv handoff","hv handoff validate","hv handoff blockers","hv handoff prepare","hv handoff ranges","hv handoff summary","hv handoff validate","hv handoff overlap-test","hv handoff bounds-test","hv handoff missing-fdt-test","hv handoff missing-bootpkg-test","hv handoff reset","hv handoff","shutdown"]
proc=subprocess.Popen(cmd,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.STDOUT); os.set_blocking(proc.stdout.fileno(),False)
sel=selectors.DefaultSelector(); sel.register(proc.stdout,selectors.EVENT_READ); seen=bytearray(); ready=False; status=124; deadline=time.monotonic()+55
with open(transcript,'wb') as out:
    try:
        while time.monotonic()<deadline:
            if proc.poll() is not None: status=proc.returncode; break
            for key,_ in sel.select(timeout=0.05):
                chunk=key.fileobj.read()
                if chunk: out.write(chunk); out.flush(); seen.extend(chunk)
            if not ready and b'zign01d> ' in seen:
                ready=True
                for c in commands:
                    proc.stdin.write((c+'\n').encode()); proc.stdin.flush(); time.sleep(0.14)
            if ready and proc.poll() is not None: status=proc.returncode; break
    finally:
        if proc.poll() is None:
            proc.terminate()
            try: proc.wait(timeout=2)
            except subprocess.TimeoutExpired: proc.kill()
        while True:
            chunk=proc.stdout.read()
            if not chunk: break
            out.write(chunk)
if not ready and status==0: status=125
sys.exit(status)
PYSMOKE
QEMU_STATUS=$?; set -e
cat "$TRANSCRIPT" >> "$QEMU_LOG"; cp "$TRANSCRIPT" "$TRANSCRIPT_COPY"
[[ $QEMU_STATUS -eq 0 ]] || fail "qemu exited with status $QEMU_STATUS"; [[ -s "$TRANSCRIPT" ]] || fail "boot transcript missing or empty"
python3 - "$TRANSCRIPT" <<'PYCHECK' | tee -a "$SMOKE_LOG"
import re,sys
from pathlib import Path
text=Path(sys.argv[1]).read_text(errors='replace')
cmds=["hv handoff","hv handoff validate","hv handoff blockers","hv handoff prepare","hv handoff ranges","hv handoff summary","hv handoff validate","hv handoff overlap-test","hv handoff bounds-test","hv handoff missing-fdt-test","hv handoff missing-bootpkg-test","hv handoff reset","hv handoff"]
blocks=[]; cursor=0
for c in cmds:
    marker='zign01d> '+c; start=text.find(marker,cursor)
    if start<0: raise SystemExit(f'missing command echo: {c}')
    end=text.find('zign01d> ',start+len(marker)); blocks.append(text[start:] if end<0 else text[start:end]); cursor=len(text) if end<0 else end
def need(i,m):
    if m not in blocks[i]: raise SystemExit(f'missing in {cmds[i]}: {m}\n---block---\n{blocks[i]}')
    print(f'PASS {cmds[i]} contains {m}')
def num(i,key):
    m=re.search(re.escape(key)+r'(0x[0-9a-fA-F]+|[0-9]+)', blocks[i])
    if not m: raise SystemExit(f'missing numeric {key} in {cmds[i]}')
    return int(m.group(1),16) if m.group(1).startswith('0x') else int(m.group(1))
need(0,'hv: linux_handoff=empty'); need(0,'hv: handoff.ready=false'); need(0,'hv: handoff.blocker=guest_memory_missing'); need(0,'hv: handoff.blocker=binary_fdt_missing')
need(1,'hv: handoff.validate_result=rejected'); need(1,'hv: handoff.last_error=guest-memory-missing')
need(2,'hv: handoff.blocker_count='); need(2,'hv: handoff.blocker=boot_package_missing'); need(2,'hv: handoff.blocker=dtb_contract_missing')
need(3,'hv: handoff.prepare_result=ok'); need(3,'hv: linux_handoff=validated'); need(3,'hv: handoff.ready=true'); need(3,'hv: handoff.blocker=none')
need(3,'hv: handoff.bootargs=root=/dev/ram0 console=hvc0 earlycon'); need(3,'hv: handoff.fdt.header.magic=0xd00dfeed'); need(3,'hv: handoff.owner_vm_id='); need(3,'hv: handoff.owner_vcpu_id=')
for key in ['hv: handoff.kernel_load_gpa=','hv: handoff.kernel_entry_gpa=','hv: handoff.guest_pc=','hv: handoff.guest_sp=','hv: handoff.initrd.start=','hv: handoff.initrd.end=','hv: handoff.fdt.size=','hv: handoff.fdt.header.totalsize=','hv: handoff.fdt.checksum=']:
    assert num(3,key) >= 0
assert num(3,'hv: handoff.fdt.size=') == num(3,'hv: handoff.fdt.header.totalsize=') and num(3,'hv: handoff.fdt.size=') > 0
need(3,'hv: boot_package=implemented'); need(3,'hv: boot_package.state=ready'); need(3,'hv: boot_package.ready=true'); need(3,'hv: dtb_contract=implemented'); need(3,'hv: fdt_encoder=foundation-binary-buffer')
need(4,'hv: handoff.kernel_load_gpa='); need(4,'hv: handoff.initrd.end='); need(5,'hv: linux_handoff=validated')
need(6,'hv: handoff.validate_result=ok'); need(7,'hv: handoff.overlap_test=rejected'); need(7,'hv: handoff.last_error=range-overlap')
need(8,'hv: handoff.bounds_test=rejected'); need(8,'hv: handoff.last_error=initrd-bounds')
need(9,'hv: handoff.missing_fdt_test=rejected'); need(9,'hv: handoff.blocker=binary_fdt_missing')
need(10,'hv: handoff.missing_bootpkg_test=rejected'); need(10,'hv: handoff.blocker=boot_package_missing')
prep=num(3,'hv: handoff.prepare_count='); val=num(6,'hv: handoff.validate_count='); rej=num(10,'hv: handoff.reject_count=')
assert prep > 0 and val > 0 and rej > 0
print('PASS handoff counters changed through commands')
need(11,'hv: handoff.reset_result=ok'); need(11,'hv: linux_handoff=empty'); need(11,'hv: handoff.ready=false'); need(12,'hv: linux_handoff=empty')
for forbidden in ['linux_guest=supported','linux_guest=booted','linux_boot=ok','buildroot_boot=ok','ubuntu_boot=ok','guest_execution=supported','guest_entered=yes','first_guest_instruction=executed','second_stage_translation=ACTIVE','hgatp=written','hgatp_write=ok','hgatp=active','fdt_accepted_by_linux=yes','sbi_services=implemented']:
    if forbidden in text: raise SystemExit(f'forbidden marker found: {forbidden}')
for ok in ['linux_guest=not-supported-yet','guest_execution=not-supported-yet','second_stage_translation=MISSING','fdt_linux_acceptance=not-proven-yet','handoff_execution=not-attempted','guest_entered=no']:
    if ok not in text: raise SystemExit(f'missing non-claim: {ok}')
print('PASS HV18 Linux handoff behavior checks')
PYCHECK
log "HV18 Linux handoff smoke passed transcript=$TRANSCRIPT"; printf 'PASS HV18 Linux handoff smoke\n' | tee -a "$SMOKE_LOG"
