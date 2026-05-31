#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT/logs/latest"
SMOKE_LOG="$LOG_DIR/smoke-pmm-v0.log"
QEMU_LOG="$LOG_DIR/qemu-pmm-v0.log"
BUILD_LOG="$LOG_DIR/build.log"
TRANSCRIPT="$ROOT/smoke/transcripts/latest-pmm-v0.txt"
TRANSCRIPT_COPY="$LOG_DIR/qemu-smoke-pmm-v0-transcript.txt"
ELF="$ROOT/zig-out/bin/zign01d-v0"

mkdir -p "$LOG_DIR" "$ROOT/smoke/transcripts"
: > "$SMOKE_LOG"
: > "$QEMU_LOG"
: > "$TRANSCRIPT"

stamp() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }
log() { printf '[%s][ZIGN01D][INFO][SMOKE][PMM001] %s\n' "$(stamp)" "$*" | tee -a "$SMOKE_LOG"; }
fail_note() {
    {
        echo "[ZIGN01D][ERROR][SMOKE][PMM099] PMM V0 smoke failure evidence:"
        echo "  build.log: $BUILD_LOG"
        echo "  qemu.log: $QEMU_LOG"
        echo "  smoke.log: $SMOKE_LOG"
        echo "  transcript: $TRANSCRIPT"
        echo "  likely cause: PMM markers/counters missing, invalid/double free accepted, exhaustion not rejected, or fake maturity claim present"
        echo "  inspect next: kernel/memory/pmm.zig kernel/memory/memory.zig kernel/console/shell.zig docs/PMM_V0.md"
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
printf '[%s][ZIGN01D][INFO][QEMU][PMM001] command:' "$(stamp)" | tee -a "$QEMU_LOG" "$SMOKE_LOG"
printf ' %q' "${QEMU_CMD[@]}" | tee -a "$QEMU_LOG" "$SMOKE_LOG"
printf '\n' | tee -a "$QEMU_LOG" "$SMOKE_LOG"

log "launching PMM V0 controlled qemu session and waiting for shell readiness"
set +e
python3 - "$TRANSCRIPT" "${QEMU_CMD[@]}" <<'PYSMOKE'
import os
import selectors
import subprocess
import sys
import time

transcript = sys.argv[1]
cmd = sys.argv[2:]
commands = [
    "help",
    "status",
    "memory",
    "memmap",
    "pmm",
    "pmm stats",
    "pmm alloc-test",
    "pmm free-test",
    "pmm invalid-free-test",
    "pmm double-free-test",
    "pmm exhaustion-test",
    "shutdown",
]
proc = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
os.set_blocking(proc.stdout.fileno(), False)
sel = selectors.DefaultSelector()
sel.register(proc.stdout, selectors.EVENT_READ)
seen = bytearray()
ready = False
status = 124
deadline = time.monotonic() + 30.0
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
    '[ZIGN01D][INFO][PMM][PMM000] physical page manager initialized; bitmap-v0 accounting active; kernel/unavailable pages reserved' \
    '[ZIGN01D][INFO][PMM][PMM001] managed_region_start=' \
    'commands:' \
    'pmm' \
    'pmm stats' \
    'pmm alloc-test' \
    'pmm free-test' \
    'pmm invalid-free-test' \
    'pmm double-free-test' \
    'pmm exhaustion-test' \
    'memory: pmm=implemented-v0' \
    'memmap: region=pmm-managed-ram' \
    'pmm_interface=present' \
    'pmm_kind=bitmap-v0' \
    'pmm_page_size=4096' \
    'pmm_managed_region_start=' \
    'pmm_managed_region_end=' \
    'pmm_total_pages=' \
    'pmm_free_pages=' \
    'pmm_used_pages=' \
    'pmm_reserved_pages=' \
    'pmm_alloc_count=' \
    'pmm_free_count=' \
    'pmm_invalid_free_count=' \
    'pmm_double_free_count=' \
    'pmm_exhaustion_count=' \
    'pmm_last_error=' \
    '[ZIGN01D][INFO][PMM][PMM010] allocation success page_addr=' \
    '[ZIGN01D][INFO][PMM][PMM011] free success page_addr=' \
    '[ZIGN01D][WARN][PMM][PMM012] invalid free rejected attempted_addr=' \
    '[ZIGN01D][WARN][PMM][PMM013] double free rejected attempted_addr=' \
    '[ZIGN01D][WARN][PMM][PMM014] exhaustion rejected reason=out-of-pages' \
    'virtual_memory=not-implemented' \
    'paging=not-implemented' \
    'userspace_memory=not-implemented' \
    'swap=not-implemented' \
    'numa=not-implemented' \
    'production_pmm=not-implemented' \
    'memory_hotplug=not-implemented' \
    'page_cache=not-implemented' \
    'pmm-alloc-test: begin' \
    'pmm_alloc_page_ok=yes' \
    'pmm_alloc_page_addr=' \
    'pmm_alloc_test=pass' \
    'pmm-free-test: begin' \
    'pmm_free_page_ok=yes' \
    'pmm_free_test=pass' \
    'pmm-invalid-free-test: begin' \
    'pmm_invalid_free_rejected=yes' \
    'pmm_last_error=invalid-free' \
    'pmm-invalid-free-test: result=pass' \
    'pmm-double-free-test: begin' \
    'pmm_double_free_rejected=yes' \
    'pmm_last_error=double-free' \
    'pmm-double-free-test: result=pass' \
    'pmm-exhaustion-test: begin' \
    'pmm_exhaustion_mode=bounded-test-pool' \
    'pmm_exhaustion_free_after_fill=0' \
    'pmm_exhaustion_rejected=yes' \
    'pmm_last_error=out-of-pages' \
    'pmm-exhaustion-test: result=pass'
do
    require "$marker"
done


log "validating PMM counter movement and rejection arithmetic"
set +e
python3 - "$TRANSCRIPT" <<'PYCHECK'
import re
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(errors="replace")

def section(name):
    start = text.find(f"{name}: begin")
    if start < 0:
        raise SystemExit(f"missing section {name}")
    nxt = text.find("zign01d> ", start + 1)
    return text[start:] if nxt < 0 else text[start:nxt]

def val(sec, key):
    m = re.search(rf"^{re.escape(key)}=(0x[0-9a-fA-F]+|[0-9]+|[A-Za-z0-9_-]+)", sec, re.M)
    if not m:
        raise SystemExit(f"missing {key}")
    raw = m.group(1)
    if raw.startswith("0x"):
        return int(raw, 16)
    if raw.isdigit():
        return int(raw)
    return raw

alloc = section("pmm-alloc-test")
free_before = val(alloc, "pmm_free_before")
used_before = val(alloc, "pmm_used_before")
alloc_count_before = val(alloc, "pmm_alloc_count_before")
addr = val(alloc, "pmm_alloc_page_addr")
free_after = val(alloc, "pmm_free_after_alloc")
used_after = val(alloc, "pmm_used_after_alloc")
alloc_count_after = val(alloc, "pmm_alloc_count_after")
if not (addr % 4096 == 0 and free_after == free_before - 1 and used_after == used_before + 1 and alloc_count_after == alloc_count_before + 1):
    raise SystemExit("alloc-test did not prove page/counter movement")

free = section("pmm-free-test")
free_before_alloc = val(free, "pmm_free_before_alloc")
free_before_free = val(free, "pmm_free_before_free")
used_before_free = val(free, "pmm_used_before_free")
free_count_before = val(free, "pmm_free_count_before")
free_after_free = val(free, "pmm_free_after_free")
used_after_free = val(free, "pmm_used_after_free")
free_count_after = val(free, "pmm_free_count_after")
if not (free_before_free == free_before_alloc - 1 and free_after_free == free_before_alloc and used_after_free == used_before_free - 1 and free_count_after == free_count_before + 1):
    raise SystemExit("free-test did not prove page/counter recovery")

invalid = section("pmm-invalid-free-test")
invalid_before = val(invalid, "pmm_invalid_free_count_before")
invalid_after = val(invalid, "pmm_invalid_free_count_after")
if not (invalid_after == invalid_before + 1 and val(invalid, "pmm_last_error") == "invalid-free"):
    raise SystemExit("invalid-free-test did not prove rejection counter/error")

double = section("pmm-double-free-test")
double_before = val(double, "pmm_double_free_count_before")
double_after = val(double, "pmm_double_free_count_after")
if not (double_after == double_before + 1 and val(double, "pmm_last_error") == "double-free"):
    raise SystemExit("double-free-test did not prove rejection counter/error")

exhaust = section("pmm-exhaustion-test")
start_free = val(exhaust, "pmm_exhaustion_start_free_pages")
global_free_before = val(exhaust, "pmm_exhaustion_global_free_pages_before")
allocated = val(exhaust, "pmm_exhaustion_allocated_pages")
after_fill = val(exhaust, "pmm_exhaustion_free_after_fill")
global_free_after = val(exhaust, "pmm_exhaustion_global_free_pages_after")
ex_before = val(exhaust, "pmm_exhaustion_count_before")
ex_after = val(exhaust, "pmm_exhaustion_count_after")
if not (allocated == start_free and after_fill == 0 and global_free_after == global_free_before and ex_after == ex_before + 1 and val(exhaust, "pmm_last_error") == "out-of-pages"):
    raise SystemExit("exhaustion-test did not prove bounded pool exhaustion without corrupting live counters")

print("PASS PMM V0 counter movement proof")
PYCHECK
CHECK_STATUS=$?
set -e
[[ $CHECK_STATUS -eq 0 ]] || fail "PMM counter movement validation failed"

for marker in \
    'virtual_memory=implemented' \
    'paging=implemented' \
    'userspace_memory=implemented' \
    'swap=implemented' \
    'numa=implemented' \
    'production_pmm=implemented' \
    'memory_hotplug=implemented' \
    'page_cache=implemented' \
    'invalid_free_accepted' \
    'double_free_accepted' \
    'exhaustion_accepted' \
    'fake_pmm_success' \
    'pmm_placeholder_only'
do
    reject "$marker"
done

log "smoke passed; transcript=$TRANSCRIPT"
echo "PASS ZIGN01D PMM V0 smoke"
