#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT/logs/latest"
SMOKE_LOG="$LOG_DIR/smoke-hv-guest-entry-v0.log"
QEMU_LOG="$LOG_DIR/qemu-hv-guest-entry-v0.log"
TRANSCRIPT="$ROOT/smoke/transcripts/latest-hv-guest-entry-v0.txt"
TRANSCRIPT_COPY="$LOG_DIR/qemu-smoke-hv-guest-entry-v0-transcript.txt"
ELF="$ROOT/zig-out/bin/zign01d-v0"

mkdir -p "$LOG_DIR" "$ROOT/smoke/transcripts"
: > "$SMOKE_LOG"
: > "$QEMU_LOG"
: > "$TRANSCRIPT"

stamp() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }
log() { printf '[%s][ZIGN01D][INFO][SMOKE][SMOKEHV7] %s\n' "$(stamp)" "$*" | tee -a "$SMOKE_LOG"; }
fail() {
    printf 'FAIL %s\n' "$*" | tee -a "$SMOKE_LOG" >&2
    printf 'inspect: %s %s %s\n' "$SMOKE_LOG" "$QEMU_LOG" "$TRANSCRIPT" | tee -a "$SMOKE_LOG" >&2
    exit 1
}
reject() {
    local marker="$1"
    if grep -Fqi "$marker" "$TRANSCRIPT"; then
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
    "hv guest-entry"
    "hv-entry"
    "hv guest-entry require-image-test"
    "hv guest-image load-tiny"
    "hv guest-entry prepare"
    "hv guest-entry"
    "hv vcpu"
    "hv guest-entry bounds-test"
    "hv guest-entry reset"
    "hv guest-entry"
    "hv status"
    "shutdown"
)

QEMU_CMD=(qemu-system-riscv64 -machine virt -cpu rv64 -smp 1 -m 128M -nographic -monitor none -serial stdio -kernel "$ELF")
printf '[%s][ZIGN01D][INFO][QEMU][QEMUHV7] command:' "$(stamp)" | tee -a "$QEMU_LOG" "$SMOKE_LOG"
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
    "hv guest-entry",
    "hv-entry",
    "hv guest-entry require-image-test",
    "hv guest-image load-tiny",
    "hv guest-entry prepare",
    "hv guest-entry",
    "hv vcpu",
    "hv guest-entry bounds-test",
    "hv guest-entry reset",
    "hv guest-entry",
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
deadline = time.monotonic() + 40.0

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
                    time.sleep(0.14)
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
    "hv guest-entry",
    "hv-entry",
    "hv guest-entry require-image-test",
    "hv guest-image load-tiny",
    "hv guest-entry prepare",
    "hv guest-entry",
    "hv vcpu",
    "hv guest-entry bounds-test",
    "hv guest-entry reset",
    "hv guest-entry",
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

def number(v):
    if v.startswith("0x"):
        return int(v, 16)
    return int(v, 10)

need(0, "hv guest-entry", "hv: guest_entry=implemented")
need(0, "hv guest-entry", "hv: guest_entry.state=not-prepared")
need(0, "hv guest-entry", "hv: guest_entry.prepare_count=0")
need(0, "hv guest-entry", "hv: guest_execution=not-supported-yet")
need(0, "hv guest-entry", "hv: linux_guest=not-supported-yet")
need(0, "hv guest-entry", "hv: second_stage_translation=MISSING")
need(0, "hv guest-entry", "hv: h_extension=unknown reason=no-safe-detection-yet")

need(1, "hv-entry", "hv: guest_entry=implemented")
need(1, "hv-entry", "hv: guest_entry.state=not-prepared")

need(2, "hv guest-entry require-image-test", "hv: guest_entry.require_image_test=rejected")
need(2, "hv guest-entry require-image-test", "hv: guest_entry.last_error=guest-image-not-loaded")
failed_after_require = number(value(2, "hv guest-entry require-image-test", "hv: guest_entry.failed_prepare_count="))
if failed_after_require < 1:
    raise SystemExit("require-image-test did not increment failed_prepare_count")
print("PASS require-image-test increments failed_prepare_count")

need(3, "hv guest-image load-tiny", "hv: guest_image.load_result=ok")
need(3, "hv guest-image load-tiny", "hv: guest_image.state=loaded")
need(3, "hv guest-image load-tiny", "hv: guest_image.entry_point=0x0")

need(4, "hv guest-entry prepare", "hv: guest_entry.prepare_result=ok")
need(4, "hv guest-entry prepare", "hv: guest_entry.state=prepared")
need(4, "hv guest-entry prepare", "hv: guest_entry.pc=0x0")
need(4, "hv guest-entry prepare", "hv: guest_entry.image_entry_point=0x0")
need(4, "hv guest-entry prepare", "hv: guest_entry.frame.valid=true")
need(4, "hv guest-entry prepare", "hv: guest_entry.frame.pc=0x0")
need(4, "hv guest-entry prepare", "hv: guest_entry.owner_vm_id=0")
need(4, "hv guest-entry prepare", "hv: guest_entry.owner_vcpu_id=0")

pc = number(value(4, "hv guest-entry prepare", "hv: guest_entry.pc="))
sp = number(value(4, "hv guest-entry prepare", "hv: guest_entry.sp="))
base = number(value(4, "hv guest-entry prepare", "hv: guest_entry.guest_memory_base="))
size = number(value(4, "hv guest-entry prepare", "hv: guest_entry.guest_memory_size_bytes="))
stack_top = number(value(4, "hv guest-entry prepare", "hv: guest_entry.stack_top="))
stack_size = number(value(4, "hv guest-entry prepare", "hv: guest_entry.stack_size_bytes="))
prepare_count = number(value(4, "hv guest-entry prepare", "hv: guest_entry.prepare_count="))
if pc != 0:
    raise SystemExit(f"prepared pc is not HV6 entry point 0x0: {pc:#x}")
if not (base <= sp < base + size):
    raise SystemExit(f"prepared sp outside guest memory: sp={sp:#x} base={base:#x} size={size}")
if not (base < stack_top <= base + size):
    raise SystemExit("stack_top outside configured guest memory")
if not (0 < stack_size <= size):
    raise SystemExit("invalid prepared stack_size_bytes")
if prepare_count < 1:
    raise SystemExit("prepare_count did not increment")
print(f"PASS prepared pc={pc:#x} sp={sp:#x} within [{base:#x}, {base + size:#x})")
print("PASS prepare_count increments on success")

need(5, "hv guest-entry", "hv: guest_entry.state=prepared")
need(5, "hv guest-entry", "hv: guest_entry.pc=0x0")

need(6, "hv vcpu", "hv: vcpu.state=created")
need(6, "hv vcpu", "hv: vcpu.run_count=0")
need(6, "hv vcpu", "hv: vcpu.guest_entry.prepared=true")
need(6, "hv vcpu", "hv: vcpu.guest_entry.pc=0x0")
need(6, "hv vcpu", f"hv: vcpu.guest_entry.sp={sp:#x}")

need(7, "hv guest-entry bounds-test", "hv: guest_entry.bounds_test=rejected")
need(7, "hv guest-entry bounds-test", "hv: guest_entry.last_error=stack-out-of-bounds")
bounds_reject_count = number(value(7, "hv guest-entry bounds-test", "hv: guest_entry.bounds_reject_count="))
if bounds_reject_count < 1:
    raise SystemExit("bounds-test did not increment bounds_reject_count")
print("PASS bounds-test increments bounds_reject_count")

need(8, "hv guest-entry reset", "hv: guest_entry.reset_result=ok")
need(8, "hv guest-entry reset", "hv: guest_entry.state=not-prepared")
reset_count = number(value(8, "hv guest-entry reset", "hv: guest_entry.reset_count="))
if reset_count < 1:
    raise SystemExit("reset_count did not increment")
print("PASS reset_count increments")

need(9, "hv guest-entry", "hv: guest_entry.state=not-prepared")
need(9, "hv guest-entry", "hv: guest_entry.frame.valid=false")

need(10, "hv status", "hv: guest_entry=implemented")
need(10, "hv status", "hv: guest_execution=not-supported-yet")
need(10, "hv status", "hv: linux_guest=not-supported-yet")
need(10, "hv status", "hv: second_stage_translation=MISSING")
need(10, "hv status", "hv: h_extension=unknown reason=no-safe-detection-yet")

for forbidden in [
    "guest_execution=supported",
    "linux_guest=supported",
    "guest entered",
    "guest running",
    "Linux guest booted",
    "booted linux",
    "h_extension=present",
    "second_stage_translation=implemented",
    "guest_entry fake",
    "guest_entry=fake",
    "guest_entry placeholder",
    "guest_entry=placeholder",
    "hv: guest_entry=fake",
    "hv: guest_entry=placeholder",
    "PANIC",
    "panic:",
]:
    if forbidden.lower() in text.lower():
        raise SystemExit(f"forbidden marker found: {forbidden}")
    print(f"PASS forbidden absent in transcript: {forbidden}")

print("PASS hv guest entry smoke behavior checks")
PYCHECK

for forbidden in \
    'guest_execution=supported' \
    'linux_guest=supported' \
    'h_extension=present' \
    'second_stage_translation=implemented' \
    'guest entered' \
    'guest running' \
    'booted linux' \
    'Linux guest booted' \
    'guest_entry fake' \
    'guest_entry=fake' \
    'guest_entry placeholder' \
    'guest_entry=placeholder' \
    'hv: guest_entry=fake' \
    'hv: guest_entry=placeholder'
do
    reject "$forbidden"
done

if grep -Fq '[ZIGN01D][PANIC]' "$TRANSCRIPT" \
    || grep -Fq 'panic:' "$TRANSCRIPT" \
    || grep -Fq 'PANIC' "$TRANSCRIPT"; then
    fail "panic marker found"
fi

log "PASS hv guest entry smoke; transcript=$TRANSCRIPT"
