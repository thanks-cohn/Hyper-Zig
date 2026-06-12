#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT/logs/latest"
SMOKE_LOG="$LOG_DIR/smoke-hv-guest-memory-v0.log"
QEMU_LOG="$LOG_DIR/qemu-hv-guest-memory-v0.log"
TRANSCRIPT="$ROOT/smoke/transcripts/latest-hv-guest-memory-v0.txt"
TRANSCRIPT_COPY="$LOG_DIR/qemu-smoke-hv-guest-memory-v0-transcript.txt"
ELF="$ROOT/zig-out/bin/zign01d-v0"

mkdir -p "$LOG_DIR" "$ROOT/smoke/transcripts"
: > "$SMOKE_LOG"
: > "$QEMU_LOG"
: > "$TRANSCRIPT"

stamp() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }
log() { printf '[%s][ZIGN01D][INFO][SMOKE][SMOKEHV4] %s\n' "$(stamp)" "$*" | tee -a "$SMOKE_LOG"; }
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

log "checking Zig 0.14.x"
"$ROOT/scripts/check-zig-version.sh" >>"$SMOKE_LOG" 2>&1 || fail "Zig 0.14.x check failed"
log "running build"
"$ROOT/scripts/build.sh" >>"$SMOKE_LOG" 2>&1 || fail "build failed"
[[ -f "$ELF" ]] || fail "missing kernel ELF: $ELF"
command -v qemu-system-riscv64 >/dev/null 2>&1 || fail "qemu-system-riscv64 not found"

COMMANDS=(
    "hv guest-memory"
    "hv guest memory"
    "hv-guest-memory"
    "hv guest-memory alloc"
    "hv guest-memory"
    "hv vm"
    "hv guest-memory bounds-test"
    "hv guest-memory free"
    "hv guest-memory"
    "hv guest-memory double-free-test"
    "hv guest-memory overflow-test"
    "hv status"
    "shutdown"
)

QEMU_CMD=(qemu-system-riscv64 -machine virt -cpu rv64 -smp 1 -m 128M -nographic -monitor none -serial stdio -kernel "$ELF")
printf '[%s][ZIGN01D][INFO][QEMU][QEMUHV4] command:' "$(stamp)" | tee -a "$QEMU_LOG" "$SMOKE_LOG"
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
commands = [
    "hv guest-memory",
    "hv guest memory",
    "hv-guest-memory",
    "hv guest-memory alloc",
    "hv guest-memory",
    "hv vm",
    "hv guest-memory bounds-test",
    "hv guest-memory free",
    "hv guest-memory",
    "hv guest-memory double-free-test",
    "hv guest-memory overflow-test",
    "hv status",
    "shutdown",
]
proc = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
os.set_blocking(proc.stdout.fileno(), False)
selector = selectors.DefaultSelector()
selector.register(proc.stdout, selectors.EVENT_READ)
seen = bytearray()
ready = False
status = 124
deadline = time.monotonic() + 35.0

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
                for command in commands:
                    proc.stdin.write((command + "\n").encode())
                    proc.stdin.flush()
                    time.sleep(0.12)
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

python3 - "$TRANSCRIPT" <<'PYCHECK' | tee -a "$SMOKE_LOG"
import re
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(errors="replace")
commands = [
    "hv guest-memory",
    "hv guest memory",
    "hv-guest-memory",
    "hv guest-memory alloc",
    "hv guest-memory",
    "hv vm",
    "hv guest-memory bounds-test",
    "hv guest-memory free",
    "hv guest-memory",
    "hv guest-memory double-free-test",
    "hv guest-memory overflow-test",
    "hv status",
]
blocks = {}
seen_count = {}
for index, command in enumerate(commands):
    pattern = re.escape("zign01d> " + command) + r"\r?\n"
    matches = list(re.finditer(pattern, text))
    occurrence = seen_count.get(command, 0)
    seen_count[command] = occurrence + 1
    if len(matches) <= occurrence:
        raise SystemExit(f"missing command echo: {command}")
    start = matches[occurrence].end()
    next_prompt = text.find("zign01d> ", start)
    if next_prompt == -1:
        next_prompt = len(text)
    blocks[(index, command)] = text[start:next_prompt]

def need(index, command, marker):
    block = blocks[(index, command)]
    if marker not in block:
        raise SystemExit(f"missing marker after {command}: {marker}")
    print(f"PASS block marker after {command}: {marker}")

def value(index, command, key):
    block = blocks[(index, command)]
    m = re.search(re.escape(key) + r"([^\r\n]+)", block)
    if not m:
        raise SystemExit(f"missing value after {command}: {key}")
    return m.group(1).strip()

for idx, command in [(0, "hv guest-memory"), (1, "hv guest memory"), (2, "hv-guest-memory")]:
    need(idx, command, "hv: guest_memory=implemented")
    need(idx, command, "hv: guest_memory.state=not-configured")
    need(idx, command, "hv: guest_memory.owner_vm_id=0")
    need(idx, command, "hv: guest_memory.backing=pmm-bitmap-v0")

need(3, "hv guest-memory alloc", "hv: guest_memory.alloc_result=ok")
need(3, "hv guest-memory alloc", "hv: guest_memory.state=configured")
need(3, "hv guest-memory alloc", "hv: guest_memory.page_count=2")
need(3, "hv guest-memory alloc", "hv: guest_memory.size_bytes=8192")
need(4, "hv guest-memory", "hv: guest_memory.state=configured")
need(5, "hv vm", "hv: vm.guest_memory=configured")
need(6, "hv guest-memory bounds-test", "hv: guest_memory.bounds_test=rejected")
need(6, "hv guest-memory bounds-test", "hv: guest_memory.last_error=out-of-bounds")
need(7, "hv guest-memory free", "hv: guest_memory.free_result=ok")
need(7, "hv guest-memory free", "hv: guest_memory.state=not-configured")
need(8, "hv guest-memory", "hv: guest_memory.state=not-configured")
need(9, "hv guest-memory double-free-test", "hv: guest_memory.double_free_test=rejected")
need(9, "hv guest-memory double-free-test", "hv: guest_memory.double_free_second=rejected")
need(10, "hv guest-memory overflow-test", "hv: guest_memory.overflow_test=rejected")
need(10, "hv guest-memory overflow-test", "hv: guest_memory.last_error=invalid-page-count")
need(11, "hv status", "hv: guest_execution=not-supported-yet")
need(11, "hv status", "hv: linux_guest=not-supported-yet")
need(11, "hv status", "hv: guest_entry=implemented")
need(11, "hv status", "hv: second_stage_translation=MISSING")

initial_allocs = int(value(0, "hv guest-memory", "hv: guest_memory.alloc_count="))
after_allocs = int(value(3, "hv guest-memory alloc", "hv: guest_memory.alloc_count="))
if after_allocs != initial_allocs + 1:
    raise SystemExit("alloc_count did not increment across alloc command")
base = value(3, "hv guest-memory alloc", "hv: guest_memory.base=")
if base in ("0x0", "0"):
    raise SystemExit("configured guest memory did not report a nonzero PMM base")
free_count = int(value(7, "hv guest-memory free", "hv: guest_memory.free_count="))
if free_count < 1:
    raise SystemExit("free_count did not increment across free command")
double_free_count = int(value(9, "hv guest-memory double-free-test", "hv: guest_memory.double_free_count="))
invalid_free_count = int(value(9, "hv guest-memory double-free-test", "hv: guest_memory.invalid_free_count="))
if double_free_count < 1 and invalid_free_count < 1:
    raise SystemExit("double-free test did not increment rejection counters")
overflow_reject_count = int(value(10, "hv guest-memory overflow-test", "hv: guest_memory.overflow_reject_count="))
if overflow_reject_count < 1:
    raise SystemExit("overflow test did not increment overflow_reject_count")
bounds_reject_count = int(value(6, "hv guest-memory bounds-test", "hv: guest_memory.bounds_reject_count="))
if bounds_reject_count < 1:
    raise SystemExit("bounds test did not increment bounds_reject_count")
print("PASS guest-memory state moved not-configured -> configured -> not-configured")
print("PASS allocation/free/double-free/overflow/bounds counters changed through command behavior")
PYCHECK

for marker in \
    'hv: guest_memory=implemented' \
    'hv: guest_memory.owner_vm_id=0' \
    'hv: guest_memory.backing=pmm-bitmap-v0' \
    'hv: guest_execution=not-supported-yet' \
    'hv: linux_guest=not-supported-yet' \
    'hv: second_stage_translation=MISSING' \
    'hv: guest_entry=implemented'
do
    require "$marker"
done

for forbidden in \
    'guest_execution=supported' \
    'linux_guest=supported' \
    'h_extension=present' \
    'second_stage_translation=implemented' \
    'guest entered' \
    'guest running' \
    'booted linux' \
    'Linux guest booted' \
    'guest_memory placeholder' \
    'guest_memory=placeholder' \
    'guest_memory=fake' \
    'hv: guest_memory=fake' \
    'hv: guest_memory=placeholder' \
    'fake guest memory' \
    'placeholder guest memory'
do
    reject "$forbidden"
done

if grep -Fq '[ZIGN01D][PANIC]' "$TRANSCRIPT" \
    || grep -Fq 'panic:' "$TRANSCRIPT" \
    || grep -Fq 'PANIC' "$TRANSCRIPT" \
    || grep -Fq 'kernel panic' "$TRANSCRIPT" \
    || grep -Fq 'panicked at' "$TRANSCRIPT"; then
    fail "true panic marker found in HV4 guest memory transcript"
fi
if grep -Fq 'QEMU: Terminated' "$TRANSCRIPT" || grep -Fq 'qemu-system-riscv64: terminating' "$TRANSCRIPT"; then
    fail "qemu crash/termination output found in HV4 transcript"
fi

log "HV4 guest memory smoke passed; transcript=$TRANSCRIPT"
echo "PASS ZIGN01D HV4 guest memory smoke"
