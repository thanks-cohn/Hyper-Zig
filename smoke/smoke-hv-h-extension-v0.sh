#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT/logs/latest"; SMOKE_LOG="$LOG_DIR/smoke-hv-h-extension-v0.log"; QEMU_LOG="$LOG_DIR/qemu-hv-h-extension-v0.log"
TRANSCRIPT="$ROOT/smoke/transcripts/latest-hv-h-extension-v0.txt"; TRANSCRIPT_COPY="$LOG_DIR/qemu-smoke-hv-h-extension-v0-transcript.txt"; ELF="$ROOT/zig-out/bin/zign01d-v0"
mkdir -p "$LOG_DIR" "$ROOT/smoke/transcripts"; : > "$SMOKE_LOG"; : > "$QEMU_LOG"; : > "$TRANSCRIPT"
stamp(){ date -u '+%Y-%m-%dT%H:%M:%SZ'; }
log(){ printf '[%s][ZIGN01D][INFO][SMOKE][SMOKEHV24] %s\n' "$(stamp)" "$*" | tee -a "$SMOKE_LOG"; }
fail(){ printf 'FAIL %s\n' "$*" | tee -a "$SMOKE_LOG" >&2; printf 'inspect: %s %s %s\n' "$SMOKE_LOG" "$QEMU_LOG" "$TRANSCRIPT" | tee -a "$SMOKE_LOG" >&2; exit 1; }
log "checking Zig 0.14.x"; "$ROOT/scripts/check-zig-version.sh" >>"$SMOKE_LOG" 2>&1 || fail "Zig 0.14.x check failed"
log "running build"; "$ROOT/scripts/build.sh" >>"$SMOKE_LOG" 2>&1 || fail "build failed"
[[ -f "$ELF" ]] || fail "missing kernel ELF: $ELF"; command -v qemu-system-riscv64 >/dev/null 2>&1 || fail "qemu-system-riscv64 not found"
QEMU_CMD=(qemu-system-riscv64 -machine virt -cpu rv64 -smp 1 -m 128M -nographic -monitor none -serial stdio -kernel "$ELF")
printf '[%s][ZIGN01D][INFO][QEMU][QEMUHV24] command:' "$(stamp)" | tee -a "$QEMU_LOG" "$SMOKE_LOG"; printf ' %q' "${QEMU_CMD[@]}" | tee -a "$QEMU_LOG" "$SMOKE_LOG"; printf '\n' | tee -a "$QEMU_LOG" "$SMOKE_LOG"
set +e
python3 - "$TRANSCRIPT" "${QEMU_CMD[@]}" <<'PYSMOKE'
import os,selectors,subprocess,sys,time
transcript=sys.argv[1]; cmd=sys.argv[2:]
commands=["hv h-ext","hv h-ext validate","hv h-ext blockers","hv h-ext discover","hv h-ext safety","hv h-ext csr-table","hv h-ext validate","hv h-ext unsafe-probe-test","hv h-ext discover","hv h-ext fake-detected-test","hv h-ext reset","hv-hext","shutdown"]
proc=subprocess.Popen(cmd,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.STDOUT); os.set_blocking(proc.stdout.fileno(),False)
sel=selectors.DefaultSelector(); sel.register(proc.stdout,selectors.EVENT_READ); seen=bytearray(); ready=False; status=124; deadline=time.monotonic()+60
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
cmds=["hv h-ext","hv h-ext validate","hv h-ext blockers","hv h-ext discover","hv h-ext safety","hv h-ext csr-table","hv h-ext validate","hv h-ext unsafe-probe-test","hv h-ext discover","hv h-ext fake-detected-test","hv h-ext reset","hv-hext"]
blocks=[]; cursor=0
for c in cmds:
    marker='zign01d> '+c; start=text.find(marker,cursor)
    if start<0: raise SystemExit(f'missing command echo: {c}')
    end=text.find('zign01d> ',start+len(marker)); blocks.append(text[start:] if end<0 else text[start:end]); cursor=len(text) if end<0 else end
def need(i,m):
    if m not in blocks[i]: raise SystemExit(f'missing in {cmds[i]}: {m}\n---block---\n{blocks[i]}')
    print(f'PASS {cmds[i]} contains {m}')
def num(i,key):
    m=re.search(re.escape(key)+r'([0-9]+)', blocks[i])
    if not m: raise SystemExit(f'missing numeric {key} in {cmds[i]}')
    return int(m.group(1))
need(0,'hv: h_extension_discovery.state=empty'); need(0,'hv: h_extension_discovery.ready=false'); need(0,'hv: h_extension.blocker=discovery-empty')
need(1,'hv: h_extension.validate_result=rejected'); need(1,'hv: h_extension.last_error=discovery-empty'); assert num(1,'hv: h_extension.reject_count=') >= 1
need(2,'hv: h_extension.blockers=deterministic-from-h-extension-state')
need(3,'hv: h_extension.discover_result=ok'); need(3,'hv: h_extension.safe_detection_attempted=true'); need(3,'hv: unsafe_csr_read_forbidden=true')
if 'hv: h_extension_status=unknown' in blocks[3]: need(3,'hv: h_extension.reason=no-safe-h-csr-probe')
elif 'hv: h_extension_status=detected' in blocks[3] or 'hv: h_extension_status=not_detected' in blocks[3]: pass
else: raise SystemExit('missing acceptable h_extension_status')
need(3,'hv: h_extension_claim=not-claimed'); need(3,'hv: hgatp_write=not-attempted'); need(3,'hv: active_stage2=false'); need(3,'hv: guest_entered=no'); need(3,'hv: first_guest_instruction=not-executed')
need(4,'hv: hypervisor_csr_probe=safety-blocked'); need(4,'hv: unsafe_direct_h_csr_reads=forbidden')
for csr in ['hgatp','hstatus','hedeleg','hideleg','hvip','hie','htval','htinst','vscause','vstval','vsstatus','vstvec','vsepc']:
    m=re.search(r'hv: csr\.'+csr+r'\.read=(allowed|blocked-by-safety-policy|unsupported|unknown)', blocks[5])
    if not m: raise SystemExit(f'missing csr status for {csr}')
need(6,'hv: h_extension.validate_result=ok')
before=num(6,'hv: h_extension.reject_count=')
need(7,'hv: h_extension.unsafe_probe_test=rejected'); need(7,'hv: h_extension.last_error=unsafe-probe-forbidden')
need(9,'hv: h_extension.fake_detected_test=rejected'); need(9,'hv: h_extension.last_error=fake-detected-rejected')
after=num(9,'hv: h_extension.reject_count='); assert after > before
need(10,'hv: h_extension.reset_result=ok'); need(10,'hv: h_extension_discovery.state=empty'); need(10,'hv: h_extension_discovery.ready=false')
for forbidden in ['linux_guest=supported','linux_guest=booted','linux_boot=ok','buildroot_boot=ok','busybox_boot=ok','alpine_boot=ok','ubuntu_boot=ok','guest_execution=supported','guest_entered=yes','first_guest_instruction=executed','context_switch=executed','entry_stub=executed','trap_return=executed','trap_return=ok','sret=executed','hret=executed','mret=executed','second_stage_translation=ACTIVE','hgatp=written','hgatp_write=ok','hgatp=active','h_extension=supported','h_extension=implemented','h_extension_claim=supported','printk=works','early_printk=works','linux_console=working']:
    if forbidden in text: raise SystemExit(f'forbidden marker found: {forbidden}')
for ok in ['h_extension_discovery=implemented','h_extension_claim=not-claimed','hgatp_write=not-attempted','active_stage2=false','guest_entered=no','first_guest_instruction=not-executed','trap_return=not-executed','linux_guest=not-supported-yet','guest_execution=not-supported-yet','second_stage_translation=MISSING','printk=not-proven-yet']:
    if ok not in text: raise SystemExit(f'missing non-claim: {ok}')
print('PASS HV24 h-extension discovery and CSR safety behavior checks')
PYCHECK
log "HV24 H-extension discovery smoke passed transcript=$TRANSCRIPT"; printf 'PASS HV24 H-extension discovery and CSR safety smoke\n' | tee -a "$SMOKE_LOG"
