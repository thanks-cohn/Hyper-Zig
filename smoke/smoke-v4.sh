#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT/logs/latest"
SMOKE_LOG="$LOG_DIR/smoke-v4.log"
QEMU_LOG="$LOG_DIR/qemu-v4.log"
BUILD_LOG="$LOG_DIR/build.log"
TRANSCRIPT="$ROOT/smoke/transcripts/latest-v4.txt"
TRANSCRIPT_COPY="$LOG_DIR/qemu-smoke-v4-transcript.txt"
ELF="$ROOT/zig-out/bin/zign01d-v0"

mkdir -p "$LOG_DIR" "$ROOT/smoke/transcripts"
: > "$SMOKE_LOG"
: > "$QEMU_LOG"
: > "$TRANSCRIPT"

stamp() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }
log() { printf '[%s][ZIGN01D][INFO][SMOKE][SMOKE401] %s\n' "$(stamp)" "$*" | tee -a "$SMOKE_LOG"; }
fail_note() {
    {
        echo "[ZIGN01D][ERROR][SMOKE][SMOKE499] V4 smoke failure evidence:"
        echo "  build.log: $BUILD_LOG"
        echo "  qemu.log: $QEMU_LOG"
        echo "  smoke.log: $SMOKE_LOG"
        echo "  transcript: $TRANSCRIPT"
        echo "  likely cause: V4 guarded MMIO marker missing, mmio command missing, or fake virtio driver success claimed"
        echo "  inspect next: kernel/device/mmio_probe.zig kernel/device/device.zig kernel/console/shell.zig docs/V4_GUARDED_MMIO_AUDIT.md"
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
printf '[%s][ZIGN01D][INFO][QEMU][QEMU401] command:' "$(stamp)" | tee -a "$QEMU_LOG" "$SMOKE_LOG"
printf ' %q' "${QEMU_CMD[@]}" | tee -a "$QEMU_LOG" "$SMOKE_LOG"
printf '\n' | tee -a "$QEMU_LOG" "$SMOKE_LOG"

log "launching V4 controlled qemu session and waiting for shell readiness"
set +e
python3 - "$TRANSCRIPT" "${QEMU_CMD[@]}" <<'PYSMOKE'
import os
import selectors
import subprocess
import sys
import time

transcript = sys.argv[1]
cmd = sys.argv[2:]
commands = ["help", "status", "devices", "mmio", "shutdown"]
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
    '[ZIGN01D][INFO][BOOT][BOOT005] ZIGN01D V4 guarded MMIO probe foundation' \
    '[ZIGN01D][INFO][SHELL][SHELL001]' \
    'commands:' \
    'mmio' \
    'guarded-mmio: V4 fixed QEMU virt window scaffold' \
    'name=virtio-mmio-transport' \
    'boundary_status=deferred' \
    'live probing disabled' \
    'mmio: policy=fixed-qemu-virt-window' \
    'mmio: live_probe=' \
    'mmio: addr=0x10001000' \
    'mmio: driver_negotiation=not-implemented' \
    'mmio: queue_setup=not-implemented' \
    'mmio: interrupt_setup=not-implemented'
do
    require "$marker"
done

if ! grep -Eq 'mmio: addr=0x10001000 result=present magic=0x74726976 device=virtio-mmio|mmio: reason=trap recovery not strong enough for absent MMIO|mmio: live_probe=disabled' "$TRANSCRIPT"; then
    fail "mmio output lacks detected virtio magic or honest deferred/disabled reason"
fi

# Reject only affirmative fake-success claims. Honest negative-state output such as
# not-implemented, missing, deferred, no fake userspace, or no userspace
# boundary must not fail this smoke test. Keep this list intentionally
# concrete so V4 proves the scaffold without pretending virtio/userspace works.
for forbidden_success in \
    'virtio-net[[:space:]_-]+works' \
    'virtio-net[^[:alnum:]_=-]+working' \
    'virtio-net[^[:alnum:]_=-]+active' \
    'virtio-net[^[:alnum:]_=-]+success' \
    'virtio-blk[[:space:]_-]+works' \
    'virtio-blk[^[:alnum:]_=-]+working' \
    'virtio-blk[^[:alnum:]_=-]+active' \
    'virtio-blk[^[:alnum:]_=-]+success' \
    'network[[:space:]_-]+works' \
    'block[[:space:]_-]+works' \
    'userspace[[:space:]_-]+works' \
    'driver_negotiation=implemented' \
    'queue_setup=implemented' \
    'interrupt_setup=implemented' \
    'driver[[:space:]_-]+negotiation[[:space:]_-]+implemented' \
    'queue[[:space:]_-]+setup[[:space:]_-]+implemented' \
    'interrupt[[:space:]_-]+setup[[:space:]_-]+implemented' \
    'real[[:space:]_-]+packets[[:space:]_-]+sent' \
    'block[[:space:]_-]+read[[:space:]_-]+success' \
    'filesystem[[:space:]_-]+mounted' \
    'userspace[[:space:]_-]+launched'
do
    if grep -Eiq "$forbidden_success" "$TRANSCRIPT"; then
        fail "forbidden fake-success claim matched: $forbidden_success"
    fi
done

log "smoke passed; transcript=$TRANSCRIPT"
echo "PASS ZIGN01D V4 smoke"
