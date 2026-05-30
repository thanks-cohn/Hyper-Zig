#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT/logs/latest"
SMOKE_LOG="$LOG_DIR/smoke-board-v0.log"
QEMU_LOG="$LOG_DIR/qemu-board-v0.log"
BUILD_LOG="$LOG_DIR/build.log"
TRANSCRIPT="$ROOT/smoke/transcripts/latest-board-v0.txt"
TRANSCRIPT_COPY="$LOG_DIR/qemu-smoke-board-v0-transcript.txt"
ELF="$ROOT/zig-out/bin/zign01d-v0"

mkdir -p "$LOG_DIR" "$ROOT/smoke/transcripts"
: > "$SMOKE_LOG"
: > "$QEMU_LOG"
: > "$TRANSCRIPT"

stamp() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }
log() { printf '[%s][ZIGN01D][INFO][SMOKE][BOARD001] %s\n' "$(stamp)" "$*" | tee -a "$SMOKE_LOG"; }
fail_note() {
    {
        echo "[ZIGN01D][ERROR][SMOKE][BOARD099] BOARD V0 smoke failure evidence:"
        echo "  build.log: $BUILD_LOG"
        echo "  qemu.log: $QEMU_LOG"
        echo "  smoke.log: $SMOKE_LOG"
        echo "  transcript: $TRANSCRIPT"
        echo "  likely cause: BOARD000 marker/commands/status missing or fake board discovery claim present"
        echo "  inspect next: kernel/board/board.zig kernel/console/shell.zig docs/BOARD_V0_AUDIT.md"
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
printf '[%s][ZIGN01D][INFO][QEMU][BOARD001] command:' "$(stamp)" | tee -a "$QEMU_LOG" "$SMOKE_LOG"
printf ' %q' "${QEMU_CMD[@]}" | tee -a "$QEMU_LOG" "$SMOKE_LOG"
printf '\n' | tee -a "$QEMU_LOG" "$SMOKE_LOG"

log "launching BOARD V0 controlled qemu session and waiting for shell readiness"
set +e
python3 - "$TRANSCRIPT" "${QEMU_CMD[@]}" <<'PYSMOKE'
import os
import selectors
import subprocess
import sys
import time

transcript = sys.argv[1]
cmd = sys.argv[2:]
commands = ["help", "status", "board", "board profile", "board devices", "memory", "memmap", "mmio", "shutdown"]
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
    '[ZIGN01D][INFO][BOARD][BOARD000] board profile present; qemu-virt fixed assumptions active' \
    'commands:' \
    'board' \
    'board profile' \
    'board devices' \
    'board_interface=present' \
    'board_name=qemu-virt' \
    'board_arch=riscv64' \
    'board_source=fixed-assumption' \
    'board_detection=not-implemented' \
    'device_tree_parse=not-implemented' \
    'board: name=qemu-virt' \
    'board: arch=riscv64' \
    'board: source=fixed-assumption' \
    'board-profile: ram_base=0x80000000' \
    'board-profile: ram_size_mib=128' \
    'board-profile: uart0_base=0x10000000' \
    'board-profile: virtio_mmio_base=0x10001000' \
    'board-profile: virtio_mmio_count=8' \
    'board-devices: uart0=present-assumed' \
    'board-devices: virtio_mmio=present-assumed' \
    'board-devices: live_probe=not-implemented' \
    'board-devices: driver_binding=not-implemented' \
    'memory: board=qemu-virt' \
    'memmap: source=board-profile' \
    'source=qemu-virt-assumption' \
    'mmio: board=qemu-virt source=board-profile'
do
    require "$marker"
done

for marker in \
    'board_detection=implemented' \
    'device_tree_parse=implemented' \
    'live_probe=implemented' \
    'real_hardware=implemented' \
    'virtio_driver=implemented' \
    'plic_driver=implemented' \
    'clint_driver=implemented'
do
    reject "$marker"
done

log "smoke passed; transcript=$TRANSCRIPT"
echo "PASS ZIGN01D BOARD V0 smoke"
