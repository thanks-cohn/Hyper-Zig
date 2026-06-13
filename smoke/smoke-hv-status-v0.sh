#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT/logs/latest"
SMOKE_LOG="$LOG_DIR/smoke-hv-status-v0.log"
QEMU_LOG="$LOG_DIR/qemu-hv-status-v0.log"
TRANSCRIPT="$ROOT/smoke/transcripts/latest-hv-status-v0.txt"
TRANSCRIPT_COPY="$LOG_DIR/qemu-smoke-hv-status-v0-transcript.txt"
ELF="$ROOT/zig-out/bin/zign01d-v0"

mkdir -p "$LOG_DIR" "$ROOT/smoke/transcripts"
: > "$SMOKE_LOG"
: > "$QEMU_LOG"
: > "$TRANSCRIPT"

stamp() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }
log() { printf '[%s][ZIGN01D][INFO][SMOKE][SMOKEHV0] %s\n' "$(stamp)" "$*" | tee -a "$SMOKE_LOG"; }
fail() {
    printf 'FAIL %s\n' "$*" | tee -a "$SMOKE_LOG" >&2
    printf 'inspect: %s %s %s\n' "$SMOKE_LOG" "$QEMU_LOG" "$TRANSCRIPT" | tee -a "$SMOKE_LOG" >&2
    exit 1
}
require() {
    local marker="$1"
    grep -Fq "$marker" "$TRANSCRIPT" || fail "missing marker: $marker"
    printf 'PASS marker: %s\n' "$marker" | tee -a "$SMOKE_LOG"
}
reject() {
    local marker="$1"
    if grep -Fq "$marker" "$TRANSCRIPT"; then
        fail "forbidden marker found: $marker"
    fi
    printf 'PASS forbidden absent: %s\n' "$marker" | tee -a "$SMOKE_LOG"
}

log "running build"
"$ROOT/scripts/build.sh" >>"$SMOKE_LOG" 2>&1 || fail "build failed"
[[ -f "$ELF" ]] || fail "missing kernel ELF: $ELF"
command -v qemu-system-riscv64 >/dev/null 2>&1 || fail "qemu-system-riscv64 not found"

QEMU_CMD=(qemu-system-riscv64 -machine virt -cpu rv64 -smp 1 -m 128M -nographic -monitor none -serial stdio -kernel "$ELF")
printf '[%s][ZIGN01D][INFO][QEMU][QEMUHV0] command:' "$(stamp)" | tee -a "$QEMU_LOG" "$SMOKE_LOG"
printf ' %q' "${QEMU_CMD[@]}" | tee -a "$QEMU_LOG" "$SMOKE_LOG"
printf '\n' | tee -a "$QEMU_LOG" "$SMOKE_LOG"

set +e
python3 - "$TRANSCRIPT" "${QEMU_CMD[@]}" <<'PYSMOKE'
import os
import selectors
import subprocess
import sys
import time

transcript = sys.argv[1]
cmd = sys.argv[2:]
proc = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
os.set_blocking(proc.stdout.fileno(), False)
selector = selectors.DefaultSelector()
selector.register(proc.stdout, selectors.EVENT_READ)
seen = bytearray()
ready = False
status = 124
deadline = time.monotonic() + 25.0

with open(transcript, "wb") as out:
    try:
        while time.monotonic() < deadline:
            if proc.poll() is not None:
                status = proc.returncode
                break
            for key, _ in selector.select(timeout=0.05):
                chunk = key.fileobj.read()
                if chunk:
                    out.write(chunk)
                    out.flush()
                    seen.extend(chunk)
            if not ready and b"zign01d> " in seen:
                ready = True
                for command in ("hv status", "shutdown"):
                    proc.stdin.write((command + "\n").encode())
                    proc.stdin.flush()
                    time.sleep(0.1)
            if ready and proc.poll() is not None:
                status = proc.returncode
                break
    finally:
        if proc.poll() is None:
            proc.terminate()
            try:
                proc.wait(timeout=2)
            except subprocess.TimeoutExpired:
                proc.kill()
        while True:
            chunk = proc.stdout.read()
            if not chunk:
                break
            out.write(chunk)

if not ready and status == 0:
    status = 125
sys.exit(status)
PYSMOKE
QEMU_STATUS=$?
set -e

cat "$TRANSCRIPT" >> "$QEMU_LOG"
cp "$TRANSCRIPT" "$TRANSCRIPT_COPY"

[[ $QEMU_STATUS -eq 0 ]] || fail "qemu exited with status $QEMU_STATUS"
[[ -s "$TRANSCRIPT" ]] || fail "boot transcript missing or empty"

for marker in \
    '[ZIGN01D][INFO][SHELL][SHELL001]' \
    'zign01d>' \
    'hv: branch=hypervisor-v0' \
    'hv: target=zig-0.14.x' \
    'hv: status=experimental-hypervisor-candidate' \
    'hv: linux_guest=not-supported-yet' \
    'hv: rust_guest_toolchain=not-supported-yet' \
    'hv: guest_execution=not-supported-yet' \
    'hv: vm_object=implemented' \
    'hv: vcpu_object=implemented' \
    'hv: guest_memory=implemented' \
    'hv: guest_entry=implemented' \
    'hv: guest_trap_return=MISSING' \
    'hv: second_stage_translation=MISSING' \
    'hv: virtual_timer=MISSING' \
    'hv: virtual_console=MISSING' \
    'hv: sbi_layer=foundation-metadata-only' \
    'hv: virtio_for_linux=MISSING'
do
    require "$marker"
done

for forbidden in \
    'linux_guest=supported' \
    'guest_execution=supported' \
    'vm_object=IMPLEMENTED' \
    'vcpu_object=IMPLEMENTED' \
    'booted linux' \
    'Linux guest booted' \
    'guest entered'
do
    reject "$forbidden"
done

if grep -Fq '[ZIGN01D][PANIC]' "$TRANSCRIPT" \
    || grep -Fq 'panic:' "$TRANSCRIPT" \
    || grep -Fq 'PANIC' "$TRANSCRIPT" \
    || grep -Fq 'kernel panic' "$TRANSCRIPT" \
    || grep -Fq 'panicked at' "$TRANSCRIPT"; then
    fail "true panic marker found in HV0 transcript"
fi

log "HV0 status smoke passed; transcript=$TRANSCRIPT"
echo "PASS ZIGN01D HV0 status smoke"
