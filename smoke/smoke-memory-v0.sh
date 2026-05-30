#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT/logs/latest"
SMOKE_LOG="$LOG_DIR/smoke-memory-v0.log"
QEMU_LOG="$LOG_DIR/qemu-memory-v0.log"
BUILD_LOG="$LOG_DIR/build.log"
TRANSCRIPT="$ROOT/smoke/transcripts/latest-memory-v0.txt"
TRANSCRIPT_COPY="$LOG_DIR/qemu-smoke-memory-v0-transcript.txt"
ELF="$ROOT/zig-out/bin/zign01d-v0"

mkdir -p "$LOG_DIR" "$ROOT/smoke/transcripts"
: > "$SMOKE_LOG"
: > "$QEMU_LOG"
: > "$TRANSCRIPT"

stamp() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }
log() { printf '[%s][ZIGN01D][INFO][SMOKE][MEMORY001] %s\n' "$(stamp)" "$*" | tee -a "$SMOKE_LOG"; }
fail_note() {
    {
        echo "[ZIGN01D][ERROR][SMOKE][MEMORY099] MEMORY V0 smoke failure evidence:"
        echo "  build.log: $BUILD_LOG"
        echo "  qemu.log: $QEMU_LOG"
        echo "  smoke.log: $SMOKE_LOG"
        echo "  transcript: $TRANSCRIPT"
        echo "  likely cause: MEMORY000 marker/command/status missing or fake heap/paging claim present"
        echo "  inspect next: kernel/memory/memory.zig kernel/console/shell.zig docs/MEMORY_V0_AUDIT.md"
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
printf '[%s][ZIGN01D][INFO][QEMU][MEMORY001] command:' "$(stamp)" | tee -a "$QEMU_LOG" "$SMOKE_LOG"
printf ' %q' "${QEMU_CMD[@]}" | tee -a "$QEMU_LOG" "$SMOKE_LOG"
printf '\n' | tee -a "$QEMU_LOG" "$SMOKE_LOG"

log "launching MEMORY V0 controlled qemu session and waiting for shell readiness"
set +e
python3 - "$TRANSCRIPT" "${QEMU_CMD[@]}" <<'PYSMOKE'
import os
import selectors
import subprocess
import sys
import time

transcript = sys.argv[1]
cmd = sys.argv[2:]
commands = ["help", "status", "memory", "memmap", "kernel-bounds", "shutdown"]
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
    '[ZIGN01D][INFO][MEMORY][MEMORY000] memory map scaffold present; allocator not implemented' \
    'commands:' \
    'memory' \
    'memmap' \
    'kernel-bounds' \
    'memory_interface=present' \
    'memory_model=qemu-virt-fixed' \
    'ram_base=0x80000000' \
    'ram_size_mib=128' \
    'heap=not-implemented' \
    'allocator=not-implemented' \
    'paging=not-implemented' \
    'memory: interface=present' \
    'memory: model=qemu-virt-fixed' \
    'memory: ram_size_bytes=134217728' \
    'memory: ram_size_mib=128' \
    'memmap: region=ram' \
    'source=qemu-virt-assumption'
do
    require "$marker"
done

if grep -Fq 'kernel-bounds: start=0x' "$TRANSCRIPT" && grep -Fq 'kernel-bounds: end=0x' "$TRANSCRIPT" && grep -Fq 'kernel-bounds: size_bytes=' "$TRANSCRIPT"; then
    echo "PASS marker: kernel-bounds start/end/size_bytes" | tee -a "$SMOKE_LOG"
elif grep -Fq 'kernel-bounds: not-available' "$TRANSCRIPT" && grep -Fq 'kernel-bounds: reason=linker symbols not exposed' "$TRANSCRIPT"; then
    echo "PASS marker: kernel-bounds not-available with reason" | tee -a "$SMOKE_LOG"
else
    fail "missing kernel-bounds start/end/size_bytes or not-available reason"
fi

for marker in \
    'heap=implemented' \
    'allocator=implemented' \
    'paging=implemented' \
    'virtual_memory=implemented' \
    'userspace_memory=implemented' \
    'live_discovery=implemented' \
    'device_tree_parse=implemented'
do
    reject "$marker"
done

log "smoke passed; transcript=$TRANSCRIPT"
echo "PASS ZIGN01D MEMORY V0 smoke"
