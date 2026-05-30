#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT/logs/latest"
SMOKE_LOG="$LOG_DIR/smoke-v3.log"
QEMU_LOG="$LOG_DIR/qemu-v3.log"
BUILD_LOG="$LOG_DIR/build.log"
TRANSCRIPT="$ROOT/smoke/transcripts/latest-v3.txt"
TRANSCRIPT_COPY="$LOG_DIR/qemu-smoke-v3-transcript.txt"
ELF="$ROOT/zig-out/bin/zign01d-v0"

mkdir -p "$LOG_DIR" "$ROOT/smoke/transcripts"
: > "$SMOKE_LOG"
: > "$QEMU_LOG"
: > "$TRANSCRIPT"

stamp() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }
log() { printf '[%s][ZIGN01D][INFO][SMOKE][SMOKE301] %s\n' "$(stamp)" "$*" | tee -a "$SMOKE_LOG"; }
fail_note() {
    {
        echo "[ZIGN01D][ERROR][SMOKE][SMOKE399] V3 smoke failure evidence:"
        echo "  build.log: $BUILD_LOG"
        echo "  qemu.log: $QEMU_LOG"
        echo "  smoke.log: $SMOKE_LOG"
        echo "  transcript: $TRANSCRIPT"
        echo "  likely cause: V3 timer/trap readiness marker missing or unsafe feature claimed"
        echo "  inspect next: kernel/interrupt/timer.zig kernel/arch/riscv64/trap.zig kernel/device/device.zig kernel/console/shell.zig docs/V3_TIMER_AND_TRAP_AUDIT.md"
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
printf '[%s][ZIGN01D][INFO][QEMU][QEMU301] command:' "$(stamp)" | tee -a "$QEMU_LOG" "$SMOKE_LOG"
printf ' %q' "${QEMU_CMD[@]}" | tee -a "$QEMU_LOG" "$SMOKE_LOG"
printf '\n' | tee -a "$QEMU_LOG" "$SMOKE_LOG"

log "launching V3 controlled qemu session and waiting for shell readiness"
set +e
python3 - "$TRANSCRIPT" "${QEMU_CMD[@]}" <<'PYSMOKE'
import os
import selectors
import subprocess
import sys
import time

transcript = sys.argv[1]
cmd = sys.argv[2:]
commands = ["help", "status", "time", "ticks", "heartbeat", "machine", "devices", "trap-test", "uptime", "shutdown"]
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
    '[ZIGN01D][INFO][BOOT][BOOT004]' \
    'ZIGN01D V3 timer and trap recovery readiness' \
    '[ZIGN01D][INFO][SHELL][SHELL001]' \
    'commands:' \
    'time' \
    'ticks' \
    'heartbeat' \
    'trap-test' \
    'timer: source=rdtime-polling value=' \
    'ticks: source=rdtime-polling value=' \
    'heartbeat: source=rdtime-polling value=' \
    'monotonic=yes' \
    'timer: interrupts=not-enabled' \
    'timer: scheduler_preemption=not-implemented' \
    'heartbeat: scheduler_preemption=not-implemented' \
    'trap: installed=yes' \
    'last_cause_name=none' \
    'cause_names=available' \
    'trap-test: mode=synthetic' \
    'trap-test: illegal-instruction name=illegal instruction' \
    'trap-test: load-access-fault name=load access fault' \
    'trap-test: store-access-fault name=store access fault' \
    'trap-test: ecall-u-mode name=ecall from U-mode' \
    'trap-test: ecall-s-mode name=ecall from S-mode' \
    'trap-test: instruction-page-fault name=instruction page fault' \
    'trap-test: load-page-fault name=load page fault' \
    'trap-test: store-page-fault name=store page fault' \
    'trap-test: unknown-cause name=unknown cause' \
    'trap-test: recovery=not-implemented' \
    'trap-test: live fault injection deferred until safe recovery exists' \
    'virtio-mmio: probing deferred until fault recovery is proven' \
    'virtio-mmio-transport' \
    'probing deferred until guarded load/store fault recovery is proven'
do
    require "$marker"
done

if grep -Eiq '(timer interrupts enabled|preemptive scheduling active|trap recovery implemented|live fault injection succeeded|ping success|call connected|sms sent|virtio.*boundary_status=detected|driver success|userspace active|filesystem mounted)' "$TRANSCRIPT"; then
    fail "unsafe or missing feature pretended to succeed"
fi

TIMER_VALUES=$(sed -n 's/.*timer: source=rdtime-polling value=\([0-9][0-9]*\).*/\1/p' "$TRANSCRIPT")
[[ -n "$TIMER_VALUES" ]] || fail "no timer rdtime value found"
while read -r value; do
    [[ -n "$value" ]] || continue
    [[ "$value" != "0" ]] || fail "timer reported canned zero"
done <<< "$TIMER_VALUES"

TICK_VALUES=$(sed -n 's/.*ticks: source=rdtime-polling value=\([0-9][0-9]*\).*/\1/p' "$TRANSCRIPT")
[[ -n "$TICK_VALUES" ]] || fail "no ticks rdtime value found"
while read -r value; do
    [[ -n "$value" ]] || continue
    [[ "$value" != "0" ]] || fail "ticks reported canned zero"
done <<< "$TICK_VALUES"

log "smoke passed; transcript=$TRANSCRIPT"
echo "PASS ZIGN01D V3 smoke"
