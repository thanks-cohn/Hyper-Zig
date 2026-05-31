#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT/logs/latest"
SMOKE_LOG="$LOG_DIR/smoke-heap-v0.log"
QEMU_LOG="$LOG_DIR/qemu-heap-v0.log"
BUILD_LOG="$LOG_DIR/build.log"
TRANSCRIPT="$ROOT/smoke/transcripts/latest-heap-v0.txt"
TRANSCRIPT_COPY="$LOG_DIR/qemu-smoke-heap-v0-transcript.txt"
ELF="$ROOT/zig-out/bin/zign01d-v0"

mkdir -p "$LOG_DIR" "$ROOT/smoke/transcripts"
: > "$SMOKE_LOG"
: > "$QEMU_LOG"
: > "$TRANSCRIPT"

stamp() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }
log() { printf '[%s][ZIGN01D][INFO][SMOKE][HEAP001] %s\n' "$(stamp)" "$*" | tee -a "$SMOKE_LOG"; }
fail_note() {
    {
        echo "[ZIGN01D][ERROR][SMOKE][HEAP099] HEAP V0 smoke failure evidence:"
        echo "  build.log: $BUILD_LOG"
        echo "  qemu.log: $QEMU_LOG"
        echo "  smoke.log: $SMOKE_LOG"
        echo "  transcript: $TRANSCRIPT"
        echo "  likely cause: HEAP000 marker/heap command/status missing or fake maturity claim present"
        echo "  inspect next: kernel/memory/heap.zig kernel/memory/memory.zig kernel/console/shell.zig docs/HEAP_V0_AUDIT.md"
    } | tee -a "$SMOKE_LOG" >&2
}
fail() { echo "FAIL $*" | tee -a "$SMOKE_LOG"; fail_note; exit 1; }
require() {
    local marker="$1"
    if LC_ALL=C grep -aFq "$marker" "$TRANSCRIPT"; then
        echo "PASS marker: $marker" | tee -a "$SMOKE_LOG"
    else
        fail "missing marker: $marker"
    fi
}
reject() {
    local marker="$1"
    if LC_ALL=C grep -aFq "$marker" "$TRANSCRIPT"; then
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
printf '[%s][ZIGN01D][INFO][QEMU][HEAP001] command:' "$(stamp)" | tee -a "$QEMU_LOG" "$SMOKE_LOG"
printf ' %q' "${QEMU_CMD[@]}" | tee -a "$QEMU_LOG" "$SMOKE_LOG"
printf '\n' | tee -a "$QEMU_LOG" "$SMOKE_LOG"

log "launching HEAP V0 controlled qemu session and waiting for shell readiness"
set +e
python3 - "$TRANSCRIPT" "${QEMU_CMD[@]}" <<'PYSMOKE'
import os
import selectors
import subprocess
import sys
import time

transcript = sys.argv[1]
cmd = sys.argv[2:]
commands = ["help", "status", "memory", "memmap", "heap", "heap stats", "heap alloc-test", "heap reset-test", "heap overflow-test", "shutdown"]
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
    '[ZIGN01D][INFO][HEAP][HEAP000] kernel heap initialized; bump-reset allocator active' \
    'commands:' \
    'heap' \
    'heap stats' \
    'heap alloc-test' \
    'heap reset-test' \
    'heap overflow-test' \
    'heap_interface=present' \
    'heap_kind=bump-reset' \
    'heap_total_bytes=' \
    'heap_used_bytes=' \
    'heap_free_bytes=' \
    'heap_alloc_count=' \
    'heap_reset_count=' \
    'heap_overflow_count=' \
    'allocator=kernel-bump-reset-v0' \
    'paging=not-implemented' \
    'virtual_memory=not-implemented' \
    'userspace_memory=not-implemented' \
    'memory: heap=implemented-v0' \
    'memory: allocator=kernel-bump-reset-v0' \
    'memory: heap_total_bytes=' \
    'memory: heap_used_bytes=' \
    'memory: heap_free_bytes=' \
    'memory: heap_reset_supported=yes' \
    'memory: heap_free_individual_blocks=not-implemented' \
    'memory: paging=not-implemented' \
    'memmap: region=kernel-heap' \
    'memmap: heap_source=static-kernel-region' \
    'memmap: heap_total_bytes=' \
    'heap: interface=present' \
    'heap: kind=bump-reset' \
    'heap: total_bytes=' \
    'heap: used_bytes=' \
    'heap: free_bytes=' \
    'heap: alloc_count=' \
    'heap: reset_count=' \
    'heap: overflow_count=' \
    'heap: free_individual_blocks=not-implemented' \
    'heap: thread_safe=not-implemented' \
    'heap: userspace_allocator=not-implemented' \
    'heap-alloc-test: begin' \
    'heap_used_before=0' \
    'heap_alloc_size=64' \
    'heap_alloc_alignment=8' \
    'heap_alloc_ok=yes' \
    'heap_used_after_alloc=64' \
    'heap_alloc_count_after=1' \
    'heap_last_error=none' \
    'heap-alloc-test: result=pass' \
    'heap-reset-test: begin' \
    'heap_reset=ok' \
    'heap_used_after_reset=0' \
    'heap-reset-test: result=pass' \
    'heap-overflow-test: begin' \
    'heap_used_before_overflow=0' \
    'heap_overflow_rejected=yes' \
    'heap_used_after_overflow=0' \
    'heap_last_error=out-of-memory' \
    'heap-overflow-test: result=pass'
do
    require "$marker"
done

for marker in \
    'heap=production' \
    'heap=general-purpose' \
    'allocator=production' \
    'allocator=general-purpose' \
    'free_individual_blocks=implemented' \
    'thread_safe=implemented' \
    'userspace_allocator=implemented' \
    'paging=implemented' \
    'virtual_memory=implemented' \
    'userspace_memory=implemented' \
    'out-of-memory ignored' \
    'overflow accepted'
do
    reject "$marker"
done

log "smoke passed; transcript=$TRANSCRIPT"
echo "PASS ZIGN01D HEAP V0 smoke"
