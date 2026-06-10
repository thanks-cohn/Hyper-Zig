#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT/logs/latest"
SMOKE_LOG="$LOG_DIR/smoke-hv-guest-image-v0.log"
QEMU_LOG="$LOG_DIR/qemu-hv-guest-image-v0.log"
TRANSCRIPT="$ROOT/smoke/transcripts/latest-hv-guest-image-v0.txt"
TRANSCRIPT_COPY="$LOG_DIR/qemu-smoke-hv-guest-image-v0-transcript.txt"
ELF="$ROOT/zig-out/bin/zign01d-v0"

mkdir -p "$LOG_DIR" "$ROOT/smoke/transcripts"
: > "$SMOKE_LOG"
: > "$QEMU_LOG"
: > "$TRANSCRIPT"

stamp() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }
log() { printf '[%s][ZIGN01D][INFO][SMOKE][SMOKEHV6] %s\n' "$(stamp)" "$*" | tee -a "$SMOKE_LOG"; }
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
    "hv guest-image"
    "hv-image"
    "hv guest-image load-tiny"
    "hv guest-image"
    "hv guest-image verify"
    "hv guest-image bounds-test"
    "hv guest-image reset"
    "hv guest-image"
    "hv status"
    "shutdown"
)

QEMU_CMD=(qemu-system-riscv64 -machine virt -cpu rv64 -smp 1 -m 128M -nographic -monitor none -serial stdio -kernel "$ELF")
printf '[%s][ZIGN01D][INFO][QEMU][QEMUHV6] command:' "$(stamp)" | tee -a "$QEMU_LOG" "$SMOKE_LOG"
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
    "hv guest-image",
    "hv-image",
    "hv guest-image load-tiny",
    "hv guest-image",
    "hv guest-image verify",
    "hv guest-image bounds-test",
    "hv guest-image reset",
    "hv guest-image",
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
    "hv guest-image",
    "hv-image",
    "hv guest-image load-tiny",
    "hv guest-image",
    "hv guest-image verify",
    "hv guest-image bounds-test",
    "hv guest-image reset",
    "hv guest-image",
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

need(0, "hv guest-image", "hv: guest_image=implemented")
need(0, "hv guest-image", "hv: guest_image.state=not-loaded")
need(0, "hv guest-image", "hv: guest_image.format=tiny-flat-v0")
need(0, "hv guest-image", "hv: guest_execution=not-supported-yet")
need(0, "hv guest-image", "hv: linux_guest=not-supported-yet")
need(0, "hv guest-image", "hv: guest_entry=MISSING")
need(0, "hv guest-image", "hv: second_stage_translation=MISSING")
need(1, "hv-image", "hv: guest_image=implemented")

need(2, "hv guest-image load-tiny", "hv: guest_image.load_result=ok")
need(2, "hv guest-image load-tiny", "hv: guest_image.state=loaded")
need(2, "hv guest-image load-tiny", "hv: guest_image.owner_vm_id=0")
need(2, "hv guest-image load-tiny", "hv: guest_image.guest_load_base=0x0")
need(2, "hv guest-image load-tiny", "hv: guest_image.entry_point=0x0")
load_count = int(value(2, "hv guest-image load-tiny", "hv: guest_image.load_count="))
if load_count != 1:
    raise SystemExit(f"load_count did not increment to 1: {load_count}")
image_size = int(value(2, "hv guest-image load-tiny", "hv: guest_image.image_size_bytes="))
loaded = int(value(2, "hv guest-image load-tiny", "hv: guest_image.loaded_byte_count="))
if image_size < 16 or image_size > 64:
    raise SystemExit(f"unexpected tiny image size: {image_size}")
if loaded != image_size:
    raise SystemExit(f"loaded_byte_count mismatch: loaded={loaded} image_size={image_size}")
load_checksum = value(2, "hv guest-image load-tiny", "hv: guest_image.checksum=")
if load_checksum in ("0x0", "0"):
    raise SystemExit("checksum was zero after load")
print(f"PASS load state/count/bytes/checksum: load_count={load_count} bytes={loaded} checksum={load_checksum}")

need(3, "hv guest-image", "hv: guest_image.state=loaded")
need(4, "hv guest-image verify", "hv: guest_image.verify_result=ok")
verify_count = int(value(4, "hv guest-image verify", "hv: guest_image.verify_count="))
if verify_count != 1:
    raise SystemExit(f"verify_count did not increment to 1: {verify_count}")
verified = int(value(4, "hv guest-image verify", "hv: guest_image.verify_result.verified_byte_count="))
if verified != loaded:
    raise SystemExit(f"verified byte count mismatch: verified={verified} loaded={loaded}")
verify_checksum = value(4, "hv guest-image verify", "hv: guest_image.checksum=")
actual_checksum = value(4, "hv guest-image verify", "hv: guest_image.verify_result.actual_checksum=")
if verify_checksum != load_checksum or actual_checksum != load_checksum:
    raise SystemExit(f"checksum changed: load={load_checksum} field={verify_checksum} actual={actual_checksum}")
print(f"PASS verify count and stable checksum: verify_count={verify_count} checksum={actual_checksum}")

need(5, "hv guest-image bounds-test", "hv: guest_image.bounds_test=rejected")
bounds_rejects = int(value(5, "hv guest-image bounds-test", "hv: guest_image.bounds_reject_count="))
if bounds_rejects < 1:
    raise SystemExit(f"bounds reject count did not increment: {bounds_rejects}")
print(f"PASS bounds-test rejected oversized load: bounds_reject_count={bounds_rejects}")

need(6, "hv guest-image reset", "hv: guest_image.reset_result=ok")
need(6, "hv guest-image reset", "hv: guest_image.state=not-loaded")
reset_loaded = int(value(6, "hv guest-image reset", "hv: guest_image.loaded_byte_count="))
if reset_loaded != 0:
    raise SystemExit(f"reset did not clear loaded bytes: {reset_loaded}")
need(7, "hv guest-image", "hv: guest_image.state=not-loaded")
need(8, "hv status", "hv: guest_image=implemented")
need(8, "hv status", "hv: guest_execution=not-supported-yet")
need(8, "hv status", "hv: linux_guest=not-supported-yet")
need(8, "hv status", "hv: guest_entry=MISSING")
need(8, "hv status", "hv: second_stage_translation=MISSING")

for forbidden in [
    "guest_execution=supported",
    "linux_guest=supported",
    "guest entered",
    "guest running",
    "Linux guest booted",
    "booted linux",
    "h_extension=present",
    "second_stage_translation=implemented",
    "guest_entry=implemented",
    "guest_image placeholder",
    "guest_image=placeholder",
    "guest_image fake",
    "hv: guest_image=fake",
    "hv: guest_image=placeholder",
    "elf=implemented",
    "linux_image=implemented",
]:
    if forbidden.lower() in text.lower():
        raise SystemExit(f"forbidden marker found: {forbidden}")
    print(f"PASS forbidden absent in transcript: {forbidden}")

runtime_blocks = "\n".join(blocks.values())
for forbidden in [
    "[ZIGN01D][PANIC]",
    "kernel panic",
    "unhandled trap",
    "unhandled panic",
    "panic:",
]:
    if forbidden.lower() in runtime_blocks.lower():
        raise SystemExit(f"runtime panic marker found in HV6 command blocks: {forbidden}")
    print(f"PASS runtime panic absent in HV6 command blocks: {forbidden}")

print("PASS hv guest image smoke behavior checks")
PYCHECK

reject "guest_execution=supported"
reject "linux_guest=supported"
reject "guest entered"
reject "guest running"
reject "Linux guest booted"
reject "booted linux"
reject "h_extension=present"
reject "second_stage_translation=implemented"
reject "guest_entry=implemented"
reject "guest_image placeholder"
reject "guest_image=placeholder"
reject "guest_image fake"
reject "hv: guest_image=fake"
reject "hv: guest_image=placeholder"
reject "elf=implemented"
reject "linux_image=implemented"

log "PASS hv guest image smoke; transcript=$TRANSCRIPT"
