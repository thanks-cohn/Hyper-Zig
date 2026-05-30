#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT/logs/latest"
SMOKE_LOG="$LOG_DIR/smoke-virtio-discovery-v0.log"
QEMU_LOG="$LOG_DIR/qemu-virtio-discovery-v0.log"
BUILD_LOG="$LOG_DIR/build.log"
TRANSCRIPT="$ROOT/smoke/transcripts/latest-virtio-discovery-v0.txt"
TRANSCRIPT_COPY="$LOG_DIR/qemu-smoke-virtio-discovery-v0-transcript.txt"
ELF="$ROOT/zig-out/bin/zign01d-v0"

mkdir -p "$LOG_DIR" "$ROOT/smoke/transcripts"
: > "$SMOKE_LOG"
: > "$QEMU_LOG"
: > "$TRANSCRIPT"

stamp() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }
log() { printf '[%s][ZIGN01D][INFO][SMOKE][VIRTIO001] %s\n' "$(stamp)" "$*" | tee -a "$SMOKE_LOG"; }
fail_note() {
    {
        echo "[ZIGN01D][ERROR][SMOKE][VIRTIO099] VIRTIO DISCOVERY V0 smoke failure evidence:"
        echo "  build.log: $BUILD_LOG"
        echo "  qemu.log: $QEMU_LOG"
        echo "  smoke.log: $SMOKE_LOG"
        echo "  transcript: $TRANSCRIPT"
        echo "  likely cause: VIRTIO000 marker/commands/status/slot table missing or fake driver/probe success claimed"
        echo "  inspect next: kernel/virtio/discovery.zig kernel/console/shell.zig kernel/board/board.zig kernel/device/mmio_probe.zig docs/VIRTIO_DISCOVERY_V0_AUDIT.md"
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
reject() {
    local marker="$1"
    if grep -Fq "$marker" "$TRANSCRIPT"; then
        fail "forbidden fake success claim: $marker"
    fi
    echo "PASS forbidden absent: $marker" | tee -a "$SMOKE_LOG"
}

log "running build"
if ! "$ROOT/scripts/build.sh" >>"$SMOKE_LOG" 2>&1; then
    fail_note
    exit 1
fi

[[ -f "$ELF" ]] || fail "missing kernel ELF: $ELF"
command -v qemu-system-riscv64 >/dev/null 2>&1 || fail "qemu-system-riscv64 not found"

QEMU_CMD=(qemu-system-riscv64 -machine virt -cpu rv64 -smp 1 -m 128M -nographic -monitor none -serial stdio -kernel "$ELF")
printf '[%s][ZIGN01D][INFO][QEMU][VIRTIO001] command:' "$(stamp)" | tee -a "$QEMU_LOG" "$SMOKE_LOG"
printf ' %q' "${QEMU_CMD[@]}" | tee -a "$QEMU_LOG" "$SMOKE_LOG"
printf '\n' | tee -a "$QEMU_LOG" "$SMOKE_LOG"

log "launching VIRTIO DISCOVERY V0 controlled qemu session and waiting for shell readiness"
set +e
python3 - "$TRANSCRIPT" "${QEMU_CMD[@]}" <<'PYSMOKE'
import os
import selectors
import subprocess
import sys
import time

transcript = sys.argv[1]
cmd = sys.argv[2:]
commands = ["help", "status", "board devices", "mmio", "virtio", "virtio summary", "virtio slots", "shutdown"]
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
    'zign01d>' \
    '[ZIGN01D][INFO][VIRTIO][VIRTIO000] virtio-mmio discovery table present; live probing not implemented' \
    'commands:' \
    'virtio' \
    'virtio slots' \
    'virtio summary' \
    'virtio_discovery_interface=present' \
    'virtio_transport=mmio' \
    'virtio_board=qemu-virt' \
    'virtio_source=board-profile' \
    'virtio_slot_count=8' \
    'virtio_live_probe=not-implemented' \
    'virtio_driver_negotiation=not-implemented' \
    'virtio_queue_setup=not-implemented' \
    'virtio: interface=present' \
    'virtio: transport=mmio' \
    'virtio: board=qemu-virt' \
    'virtio: source=board-profile' \
    'virtio: base=0x10001000' \
    'virtio: stride=0x1000' \
    'virtio: slot_count=8' \
    'virtio: live_probe=not-implemented' \
    'virtio: magic_read=not-implemented' \
    'virtio: driver_negotiation=not-implemented' \
    'virtio: queue_setup=not-implemented' \
    'virtio: interrupt_setup=not-implemented' \
    'virtio-summary: slots=8' \
    'virtio-summary: computed_from=board-profile' \
    'virtio-slot: index=0 addr=0x10001000 status=expected-by-board-profile' \
    'virtio-slot: index=1 addr=0x10002000 status=expected-by-board-profile' \
    'virtio-slot: index=2 addr=0x10003000 status=expected-by-board-profile' \
    'virtio-slot: index=3 addr=0x10004000 status=expected-by-board-profile' \
    'virtio-slot: index=4 addr=0x10005000 status=expected-by-board-profile' \
    'virtio-slot: index=5 addr=0x10006000 status=expected-by-board-profile' \
    'virtio-slot: index=6 addr=0x10007000 status=expected-by-board-profile' \
    'virtio-slot: index=7 addr=0x10008000 status=expected-by-board-profile' \
    'status=expected-by-board-profile' \
    'board-devices: virtio_discovery=present' \
    'board-devices: virtio_slots=8' \
    'board-devices: virtio_source=board-profile' \
    'mmio: virtio_discovery=present' \
    'mmio: virtio_slots=8' \
    'mmio: virtio_slot_table=computed'
do
    require "$marker"
done

for marker in \
    'virtio_live_probe=implemented' \
    'live_probe=implemented' \
    'virtio_magic_read=implemented' \
    'magic_read=implemented' \
    'virtio_driver_negotiation=implemented' \
    'driver_negotiation=implemented' \
    'virtio_queue_setup=implemented' \
    'queue_setup=implemented' \
    'virtio_interrupt_setup=implemented' \
    'interrupt_setup=implemented' \
    'virtio-block=implemented' \
    'virtio-net=implemented' \
    'driver_bound=yes' \
    'device_active=yes' \
    'negotiated=yes' \
    'real_hardware=implemented'
do
    reject "$marker"
done

log "smoke passed; transcript=$TRANSCRIPT"
echo "PASS ZIGN01D VIRTIO DISCOVERY V0 smoke"
