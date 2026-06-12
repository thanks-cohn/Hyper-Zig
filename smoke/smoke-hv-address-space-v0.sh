#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT/logs/latest"
SMOKE_LOG="$LOG_DIR/smoke-hv-address-space-v0.log"
QEMU_LOG="$LOG_DIR/qemu-hv-address-space-v0.log"
TRANSCRIPT="$ROOT/smoke/transcripts/latest-hv-address-space-v0.txt"
TRANSCRIPT_COPY="$LOG_DIR/qemu-smoke-hv-address-space-v0-transcript.txt"
ELF="$ROOT/zig-out/bin/zign01d-v0"

mkdir -p "$LOG_DIR" "$ROOT/smoke/transcripts"
: > "$SMOKE_LOG"
: > "$QEMU_LOG"
: > "$TRANSCRIPT"

stamp() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }
log() { printf '[%s][ZIGN01D][INFO][SMOKE][SMOKEHV5] %s\n' "$(stamp)" "$*" | tee -a "$SMOKE_LOG"; }
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
    "hv address-space"
    "hv-address-space"
    "hv address-space create"
    "hv address-space"
    "hv address-space lookup-zero"
    "hv address-space lookup-page"
    "hv address-space bounds-test"
    "hv address-space alignment-test"
    "hv address-space reset"
    "hv address-space"
    "hv status"
    "shutdown"
)

QEMU_CMD=(qemu-system-riscv64 -machine virt -cpu rv64 -smp 1 -m 128M -nographic -monitor none -serial stdio -kernel "$ELF")
printf '[%s][ZIGN01D][INFO][QEMU][QEMUHV5] command:' "$(stamp)" | tee -a "$QEMU_LOG" "$SMOKE_LOG"
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
    "hv address-space",
    "hv-address-space",
    "hv address-space create",
    "hv address-space",
    "hv address-space lookup-zero",
    "hv address-space lookup-page",
    "hv address-space bounds-test",
    "hv address-space alignment-test",
    "hv address-space reset",
    "hv address-space",
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
    "hv address-space",
    "hv-address-space",
    "hv address-space create",
    "hv address-space",
    "hv address-space lookup-zero",
    "hv address-space lookup-page",
    "hv address-space bounds-test",
    "hv address-space alignment-test",
    "hv address-space reset",
    "hv address-space",
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

for idx, command in [(0, "hv address-space"), (1, "hv-address-space")]:
    need(idx, command, "hv: address_space=implemented")
    need(idx, command, "hv: address_space.owner_vm_id=0")
    need(idx, command, "hv: address_space.state=not-configured")
    need(idx, command, "hv: address_space.page_size=4096")
    need(idx, command, "hv: address_space.guest_base=0x0")

need(2, "hv address-space create", "hv: address_space.create_result=ok")
need(2, "hv address-space create", "hv: address_space.state=configured")
need(2, "hv address-space create", "hv: address_space.region_count=1")
need(2, "hv address-space create", "hv: address_space.guest_size_bytes=8192")
need(2, "hv address-space create", "hv: address_space.translated_page_count=2")
need(3, "hv address-space", "hv: address_space.state=configured")
need(4, "hv address-space lookup-zero", "hv: address_space.lookup_result=ok")
need(4, "hv address-space lookup-zero", "hv: address_space.lookup_zero.gpa=0x0")
need(4, "hv address-space lookup-zero", "hv: address_space.lookup_zero.page_index=0")
need(5, "hv address-space lookup-page", "hv: address_space.lookup_result=ok")
need(5, "hv address-space lookup-page", "hv: address_space.lookup_page.gpa=0x1000")
need(5, "hv address-space lookup-page", "hv: address_space.lookup_page.page_index=1")
need(6, "hv address-space bounds-test", "hv: address_space.bounds_test=rejected")
need(6, "hv address-space bounds-test", "hv: address_space.lookup_result=rejected")
need(6, "hv address-space bounds-test", "hv: address_space.last_error=out-of-bounds")
need(7, "hv address-space alignment-test", "hv: address_space.alignment_test=rejected")
need(7, "hv address-space alignment-test", "hv: address_space.lookup_result=rejected")
need(7, "hv address-space alignment-test", "hv: address_space.last_error=misaligned")
need(8, "hv address-space reset", "hv: address_space.reset_result=ok")
need(8, "hv address-space reset", "hv: address_space.state=not-configured")
need(9, "hv address-space", "hv: address_space.state=not-configured")
need(10, "hv status", "hv: guest_execution=not-supported-yet")
need(10, "hv status", "hv: linux_guest=not-supported-yet")
need(10, "hv status", "hv: second_stage_translation=MISSING")
need(10, "hv status", "hv: guest_entry=implemented")

create_lookup_count = int(value(2, "hv address-space create", "hv: address_space.lookup_count="))
after_zero_lookup_count = int(value(4, "hv address-space lookup-zero", "hv: address_space.lookup_count="))
after_page_lookup_count = int(value(5, "hv address-space lookup-page", "hv: address_space.lookup_count="))
after_bounds_lookup_count = int(value(6, "hv address-space bounds-test", "hv: address_space.lookup_count="))
after_alignment_lookup_count = int(value(7, "hv address-space alignment-test", "hv: address_space.lookup_count="))
if after_zero_lookup_count != create_lookup_count + 1:
    raise SystemExit("lookup-zero did not increment lookup_count")
if after_page_lookup_count != after_zero_lookup_count + 1:
    raise SystemExit("lookup-page did not increment lookup_count")
if after_bounds_lookup_count != after_page_lookup_count + 1:
    raise SystemExit("bounds-test did not increment lookup_count")
if after_alignment_lookup_count != after_bounds_lookup_count + 1:
    raise SystemExit("alignment-test did not increment lookup_count")
if int(value(5, "hv address-space lookup-page", "hv: address_space.successful_lookup_count=")) < 2:
    raise SystemExit("successful_lookup_count did not reflect two successful lookups")
if int(value(7, "hv address-space alignment-test", "hv: address_space.failed_lookup_count=")) < 2:
    raise SystemExit("failed_lookup_count did not reflect rejection tests")
if int(value(6, "hv address-space bounds-test", "hv: address_space.bounds_reject_count=")) < 1:
    raise SystemExit("bounds_reject_count did not increment")
if int(value(7, "hv address-space alignment-test", "hv: address_space.alignment_reject_count=")) < 1:
    raise SystemExit("alignment_reject_count did not increment")
first_host = value(4, "hv address-space lookup-zero", "hv: address_space.lookup_zero.hpa=")
second_host = value(5, "hv address-space lookup-page", "hv: address_space.lookup_page.hpa=")
if first_host in ("0x0", "0") or second_host in ("0x0", "0") or first_host == second_host:
    raise SystemExit("host page metadata did not distinguish first and second guest pages")
print("PASS address-space state moved not-configured -> configured -> not-configured")
print("PASS address lookups and rejection counters changed through command behavior")
PYCHECK

for marker in \
    'hv: address_space=implemented' \
    'hv: address_space.owner_vm_id=0' \
    'hv: address_space.state=configured' \
    'hv: address_space.page_size=4096' \
    'hv: address_space.guest_base=0x0' \
    'hv: address_space.lookup_result=ok' \
    'hv: address_space.lookup_result=rejected' \
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
    'address_space placeholder' \
    'address_space=placeholder' \
    'address_space=fake' \
    'hv: address_space=fake' \
    'hv: address_space=placeholder' \
    'fake address space' \
    'placeholder address space'
do
    reject "$forbidden"
done

if grep -Fq '[ZIGN01D][PANIC]' "$TRANSCRIPT" \
    || grep -Fq 'panic:' "$TRANSCRIPT" \
    || grep -Fq 'PANIC' "$TRANSCRIPT" \
    || grep -Fq 'kernel panic' "$TRANSCRIPT" \
    || grep -Fq 'panicked at' "$TRANSCRIPT"; then
    fail "true panic marker found in HV5 address-space transcript"
fi
if grep -Fq 'QEMU: Terminated' "$TRANSCRIPT" || grep -Fq 'qemu-system-riscv64: terminating' "$TRANSCRIPT"; then
    fail "qemu crash/termination output found in HV5 transcript"
fi

log "HV5 address space smoke passed; transcript=$TRANSCRIPT"
echo "PASS ZIGN01D HV5 guest address space smoke"
