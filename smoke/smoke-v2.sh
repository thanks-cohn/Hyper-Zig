#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT/logs/latest"
SMOKE_LOG="$LOG_DIR/smoke-v2.log"
QEMU_LOG="$LOG_DIR/qemu-v2.log"
BUILD_LOG="$LOG_DIR/build.log"
TRANSCRIPT="$ROOT/smoke/transcripts/latest-v2.txt"
TRANSCRIPT_COPY="$LOG_DIR/qemu-smoke-v2-transcript.txt"
ELF="$ROOT/zig-out/bin/zign01d-v0"

mkdir -p "$LOG_DIR" "$ROOT/smoke/transcripts"
: > "$SMOKE_LOG"
: > "$QEMU_LOG"
: > "$TRANSCRIPT"

stamp() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }
log() { printf '[%s][ZIGN01D][INFO][SMOKE][SMOKE201] %s\n' "$(stamp)" "$*" | tee -a "$SMOKE_LOG"; }
fail_note() {
    {
        echo "[ZIGN01D][ERROR][SMOKE][SMOKE299] V2 smoke failure evidence:"
        echo "  build.log: $BUILD_LOG"
        echo "  qemu.log: $QEMU_LOG"
        echo "  smoke.log: $SMOKE_LOG"
        echo "  transcript: $TRANSCRIPT"
        echo "  likely cause: V2 trap/machine/device boundary marker missing or placeholder claimed success"
        echo "  inspect next: kernel/arch/riscv64/trap.zig kernel/arch/riscv64/cpu.zig kernel/device/device.zig kernel/console/shell.zig"
    } | tee -a "$SMOKE_LOG" >&2
}
fail() { echo "FAIL $*" | tee -a "$SMOKE_LOG"; fail_note; exit 1; }
require() {
    local marker="$1"
    if grep -Fq "$marker" "$TRANSCRIPT"; then
        echo "PASS marker: $marker" | tee -a "$SMOKE_LOG"
    else
        fail "missing marker: $marker"
    fi
}

log "running build"
if ! "$ROOT/scripts/build.sh" >>"$SMOKE_LOG" 2>&1; then
    fail_note
    exit 1
fi

[[ -f "$ELF" ]] || fail "missing kernel ELF: $ELF"
command -v qemu-system-riscv64 >/dev/null 2>&1 || fail "qemu-system-riscv64 not found"

QEMU_CMD=(qemu-system-riscv64 -machine virt -cpu rv64 -smp 1 -m 128M -nographic -monitor none -serial stdio -kernel "$ELF")
printf '[%s][ZIGN01D][INFO][QEMU][QEMU201] command:' "$(stamp)" | tee -a "$QEMU_LOG" "$SMOKE_LOG"
printf ' %q' "${QEMU_CMD[@]}" | tee -a "$QEMU_LOG" "$SMOKE_LOG"
printf '\n' | tee -a "$QEMU_LOG" "$SMOKE_LOG"

log "launching V2 controlled qemu session and waiting for shell readiness"
set +e
python3 - "$TRANSCRIPT" "${QEMU_CMD[@]}" <<'PYSMOKE'
import os
import selectors
import subprocess
import sys
import time

transcript = sys.argv[1]
cmd = sys.argv[2:]
commands = ["help", "status", "machine", "cpu", "devices", "syscalls", "panic-test", "uptime", "shutdown"]
proc = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
os.set_blocking(proc.stdout.fileno(), False)
sel = selectors.DefaultSelector()
sel.register(proc.stdout, selectors.EVENT_READ)
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
            for key, _ in sel.select(timeout=0.05):
                chunk = key.fileobj.read()
                if chunk:
                    out.write(chunk)
                    out.flush()
                    seen.extend(chunk)
            if not ready and b"zign01d> " in seen:
                ready = True
                for item in commands:
                    proc.stdin.write((item + "\n").encode())
                    proc.stdin.flush()
                    time.sleep(0.1)
            if ready and proc.poll() is not None:
                status = proc.returncode
                break
        else:
            status = 124
    finally:
        if proc.poll() is None:
            proc.terminate()
            try:
                proc.wait(timeout=2)
            except subprocess.TimeoutExpired:
                proc.kill()
        while True:
            try:
                chunk = proc.stdout.read()
            except Exception:
                chunk = b""
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
    '[ZIGN01D][INFO][BOOT][BOOT001]' \
    '[ZIGN01D][INFO][BOOT][BOOT002]' \
    '[ZIGN01D][INFO][BOOT][BOOT003]' \
    '[ZIGN01D][INFO][TRAP][TRAP001]' \
    '[ZIGN01D][INFO][DEV][DEV001]' \
    '[ZIGN01D][WARN][DEV][DEV002]' \
    '[ZIGN01D][INFO][SHELL][SHELL001]' \
    'ZIGN01D V1 interactive diagnostic shell' \
    'ZIGN01D V2 machine boundary' \
    'commands:' \
    'panic-test' \
    'status:' \
    'machine: hart_id=' \
    'machine: qemu_virt_assumptions=' \
    'timer_source=rdtime-polling' \
    'interrupt_controller=placeholder' \
    'trap: installed=yes' \
    'devices:' \
    'boundary_status=active' \
    'boundary_status=placeholder' \
    'boundary_status=missing' \
    'boundary_status=unknown' \
    'virtio-mmio probing deferred' \
    'syscalls:' \
    '[ZIGN01D][PANIC][PANIC][PANIC900]' \
    '[ZIGN01D][PANIC][SHELL][PANIC901]' \
    'missing stack unwinder and trap frame dump' \
    '[ZIGN01D][INFO][TIMER][TIMER002] uptime ticks='
do
    require "$marker"
done

if grep -Eiq '(ping success|call connected|sms sent|virtio.*boundary_status=detected|driver success|userspace active)' "$TRANSCRIPT"; then
    fail "placeholder or missing feature pretended to succeed"
fi

if ! grep -Fq 'inspect=' "$TRANSCRIPT"; then
    fail "missing inspect hints in V2 transcript"
fi

UPTIME_VALUES=$(sed -n 's/.*uptime ticks=\([0-9][0-9]*\).*/\1/p' "$TRANSCRIPT")
[[ -n "$UPTIME_VALUES" ]] || fail "no uptime value found"
while read -r value; do
    [[ -n "$value" ]] || continue
    [[ "$value" != "0" ]] || fail "uptime reported canned zero"
done <<< "$UPTIME_VALUES"

log "smoke passed; transcript=$TRANSCRIPT"
echo "PASS ZIGN01D V2 smoke"
