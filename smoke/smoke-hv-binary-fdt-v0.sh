#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT/logs/latest"; SMOKE_LOG="$LOG_DIR/smoke-hv-binary-fdt-v0.log"; QEMU_LOG="$LOG_DIR/qemu-hv-binary-fdt-v0.log"
TRANSCRIPT="$ROOT/smoke/transcripts/latest-hv-binary-fdt-v0.txt"; TRANSCRIPT_COPY="$LOG_DIR/qemu-smoke-hv-binary-fdt-v0-transcript.txt"; ELF="$ROOT/zig-out/bin/zign01d-v0"
mkdir -p "$LOG_DIR" "$ROOT/smoke/transcripts"; : > "$SMOKE_LOG"; : > "$QEMU_LOG"; : > "$TRANSCRIPT"
stamp(){ date -u '+%Y-%m-%dT%H:%M:%SZ'; }
log(){ printf '[%s][ZIGN01D][INFO][SMOKE][SMOKEHV17] %s\n' "$(stamp)" "$*" | tee -a "$SMOKE_LOG"; }
fail(){ printf 'FAIL %s\n' "$*" | tee -a "$SMOKE_LOG" >&2; printf 'inspect: %s %s %s\n' "$SMOKE_LOG" "$QEMU_LOG" "$TRANSCRIPT" | tee -a "$SMOKE_LOG" >&2; exit 1; }
log "checking Zig 0.14.x"; "$ROOT/scripts/check-zig-version.sh" >>"$SMOKE_LOG" 2>&1 || fail "Zig 0.14.x check failed"
log "running build"; "$ROOT/scripts/build.sh" >>"$SMOKE_LOG" 2>&1 || fail "build failed"
[[ -f "$ELF" ]] || fail "missing kernel ELF: $ELF"; command -v qemu-system-riscv64 >/dev/null 2>&1 || fail "qemu-system-riscv64 not found"
QEMU_CMD=(qemu-system-riscv64 -machine virt -cpu rv64 -smp 1 -m 128M -nographic -monitor none -serial stdio -kernel "$ELF")
printf '[%s][ZIGN01D][INFO][QEMU][QEMUHV17] command:' "$(stamp)" | tee -a "$QEMU_LOG" "$SMOKE_LOG"; printf ' %q' "${QEMU_CMD[@]}" | tee -a "$QEMU_LOG" "$SMOKE_LOG"; printf '\n' | tee -a "$QEMU_LOG" "$SMOKE_LOG"
set +e
python3 - "$TRANSCRIPT" "${QEMU_CMD[@]}" <<'PYSMOKE'
import os,selectors,subprocess,sys,time
transcript=sys.argv[1]; cmd=sys.argv[2:]
commands=["hv fdt","hv fdt build","hv bootpkg reset","hv bootpkg attach-kernel","hv bootpkg set-cmdline root=/dev/ram0 console=hvc0 earlycon","hv bootpkg set-entry","hv bootpkg attach-initrd","hv bootpkg validate","hv dtb build","hv fdt build","hv fdt header","hv fdt nodes","hv fdt strings","hv fdt checksum","hv fdt validate","hv-fdt","hv fdt bounds-test","hv fdt missing-contract-test","hv fdt reset","hv fdt","shutdown"]
proc=subprocess.Popen(cmd,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.STDOUT); os.set_blocking(proc.stdout.fileno(),False)
sel=selectors.DefaultSelector(); sel.register(proc.stdout,selectors.EVENT_READ); seen=bytearray(); ready=False; status=124; deadline=time.monotonic()+45
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
                    proc.stdin.write((c+'\n').encode()); proc.stdin.flush(); time.sleep(0.12)
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
cmds=["hv fdt","hv fdt build","hv bootpkg reset","hv bootpkg attach-kernel","hv bootpkg set-cmdline root=/dev/ram0 console=hvc0 earlycon","hv bootpkg set-entry","hv bootpkg attach-initrd","hv bootpkg validate","hv dtb build","hv fdt build","hv fdt header","hv fdt nodes","hv fdt strings","hv fdt checksum","hv fdt validate","hv-fdt","hv fdt bounds-test","hv fdt missing-contract-test","hv fdt reset","hv fdt"]
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
need(0,'hv: fdt_encoder=foundation-binary-buffer'); need(0,'hv: fdt.state=empty'); need(0,'hv: fdt.built=false'); need(0,'hv: fdt.encoded_len=0')
need(1,'hv: fdt.build_result=rejected'); need(1,'hv: fdt.last_error=dtb-contract-not-ready')
need(7,'hv: boot_package.validate_result=ok'); need(8,'hv: dtb.build_result=ok'); need(8,'hv: dtb.state=built')
need(9,'hv: fdt.build_result=ok'); need(9,'hv: fdt.state=built'); need(9,'hv: binary_fdt=encoded-minimal')
encoded=num(9,'hv: fdt.encoded_len='); total=num(9,'hv: fdt.header.totalsize='); struct_off=num(9,'hv: fdt.header.off_dt_struct='); strings_off=num(9,'hv: fdt.header.off_dt_strings='); struct_size=num(9,'hv: fdt.header.size_dt_struct='); strings_size=num(9,'hv: fdt.header.size_dt_strings='); nodes=num(9,'hv: fdt.node_count='); props=num(9,'hv: fdt.property_count='); checksum=num(9,'hv: fdt.checksum=')
assert encoded > 0 and total == encoded and struct_off > 0 and strings_off > struct_off and struct_size > 0 and strings_size > 0 and nodes >= 5 and props >= 10 and checksum > 0
print('PASS numeric FDT buffer/header/counter/checksum invariants')
need(9,'hv: fdt.header.magic=0xd00dfeed'); need(9,'hv: fdt.bootargs=root=/dev/ram0 console=hvc0 earlycon')
need(10,'hv: fdt.header.magic=0xd00dfeed'); need(11,'hv: fdt.node=/memory encoded=true'); need(11,'hv: fdt.node=/cpus/cpu@0 encoded=true'); need(11,'hv: fdt.node=/chosen encoded=true'); need(11,'hv: fdt.initrd_metadata_encoded=true')
need(12,'hv: fdt.strings.source=property-name-table'); need(14,'hv: fdt.validate_result=ok'); need(15,'hv: fdt.state=built')
need(16,'hv: fdt.bounds_test=rejected'); need(16,'hv: fdt.last_error=buffer-too-small')
need(17,'hv: fdt.missing_contract_test=rejected'); need(17,'hv: fdt.last_error=dtb-contract-not-ready')
need(18,'hv: fdt.reset_result=ok'); need(18,'hv: fdt.state=empty'); need(18,'hv: fdt.encoded_len=0')
need(19,'hv: fdt.state=empty'); need(19,'hv: fdt.built=false')
for forbidden in ['linux_guest=supported','guest_execution=supported','second_stage_translation=ACTIVE','hgatp=written','hgatp_write=ok','hgatp=active','linux_boot=ok','buildroot_boot=ok','ubuntu_boot=ok','fdt_accepted_by_linux=yes','guest_entered=yes']:
    if forbidden in text: raise SystemExit(f'forbidden marker found: {forbidden}')
print('PASS HV17 binary FDT behavior checks')
PYCHECK
log "HV17 binary FDT smoke passed transcript=$TRANSCRIPT"; printf 'PASS HV17 binary FDT smoke\n' | tee -a "$SMOKE_LOG"
