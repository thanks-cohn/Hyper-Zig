#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT/logs/latest"
SMOKE_LOG="$LOG_DIR/smoke-hv-second-stage-v0.log"
QEMU_LOG="$LOG_DIR/qemu-hv-second-stage-v0.log"
TRANSCRIPT="$ROOT/smoke/transcripts/latest-hv-second-stage-v0.txt"
TRANSCRIPT_COPY="$LOG_DIR/qemu-smoke-hv-second-stage-v0-transcript.txt"
ELF="$ROOT/zig-out/bin/zign01d-v0"

mkdir -p "$LOG_DIR" "$ROOT/smoke/transcripts"
: > "$SMOKE_LOG"
: > "$QEMU_LOG"
: > "$TRANSCRIPT"

stamp() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }
log() { printf '[%s][ZIGN01D][INFO][SMOKE][SMOKEHV11] %s\n' "$(stamp)" "$*" | tee -a "$SMOKE_LOG"; }
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
    "hv second-stage"
    "hv guest-memory alloc"
    "hv address-space create"
    "hv second-stage configure"
    "hv second-stage validate"
    "hv second-stage lookup-zero"
    "hv second-stage lookup-page"
    "hv second-stage bounds-test"
    "hv second-stage alignment-test"
    "hv second-stage execute-permission-test"
    "hv-stage2"
    "hv exec"
    "hv second-stage reset"
    "hv second-stage"
    "hv status"
    "shutdown"
)

QEMU_CMD=(qemu-system-riscv64 -machine virt -cpu rv64 -smp 1 -m 128M -nographic -monitor none -serial stdio -kernel "$ELF")
printf '[%s][ZIGN01D][INFO][QEMU][QEMUHV11] command:' "$(stamp)" | tee -a "$QEMU_LOG" "$SMOKE_LOG"
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
    "hv second-stage",
    "hv guest-memory alloc",
    "hv address-space create",
    "hv second-stage configure",
    "hv second-stage validate",
    "hv second-stage lookup-zero",
    "hv second-stage lookup-page",
    "hv second-stage bounds-test",
    "hv second-stage alignment-test",
    "hv second-stage execute-permission-test",
    "hv-stage2",
    "hv exec",
    "hv second-stage reset",
    "hv second-stage",
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
deadline = time.monotonic() + 45.0

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
    "hv second-stage",
    "hv guest-memory alloc",
    "hv address-space create",
    "hv second-stage configure",
    "hv second-stage validate",
    "hv second-stage lookup-zero",
    "hv second-stage lookup-page",
    "hv second-stage bounds-test",
    "hv second-stage alignment-test",
    "hv second-stage execute-permission-test",
    "hv-stage2",
    "hv exec",
    "hv second-stage reset",
    "hv second-stage",
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

# Initial state proves the object starts inactive, not preconfigured by static status text.
need(0, "hv second-stage", "hv: second_stage=implemented-metadata")
need(0, "hv second-stage", "hv: second_stage.state=inactive")
need(0, "hv second-stage", "hv: second_stage.mapping.active=false")
need(0, "hv second-stage", "hv: second_stage_translation=MISSING")

# HV4/HV5 preparation is executed before HV11 configure.
need(1, "hv guest-memory alloc", "hv: guest_memory.alloc_result=ok")
need(1, "hv guest-memory alloc", "hv: guest_memory.state=configured")
need(2, "hv address-space create", "hv: address_space.create_result=ok")
need(2, "hv address-space create", "hv: address_space.state=configured")

# Configure derives metadata from the live HV4/HV5 objects and keeps hardware inactive.
need(3, "hv second-stage configure", "hv: second_stage.configure_result=ok")
need(3, "hv second-stage configure", "hv: second_stage.state=metadata-ready")
need(3, "hv second-stage configure", "hv: second_stage.mode=metadata-only")
need(3, "hv second-stage configure", "hv: second_stage.owner_vm_id=0")
need(3, "hv second-stage configure", "hv: second_stage.mapping.active=false")
need(3, "hv second-stage configure", "hv: second_stage.mapping.validated=true")
need(3, "hv second-stage configure", "hv: second_stage.mapping.guest_base=0x0")
need(3, "hv second-stage configure", "hv: second_stage.mapping.page_size=4096")
need(3, "hv second-stage configure", "hv: second_stage.mapping.flags_read=true")
need(3, "hv second-stage configure", "hv: second_stage.mapping.flags_write=true")
need(3, "hv second-stage configure", "hv: second_stage.mapping.flags_execute=false")
pages = int(value(3, "hv second-stage configure", "hv: second_stage.mapping.guest_page_count="))
size = int(value(3, "hv second-stage configure", "hv: second_stage.mapping.guest_size_bytes="))
host_size = int(value(3, "hv second-stage configure", "hv: second_stage.mapping.host_size_bytes="))
host_base = value(3, "hv second-stage configure", "hv: second_stage.mapping.host_base=")
if pages < 2:
    raise SystemExit(f"expected at least two guest pages for lookup-page, got {pages}")
if size != pages * 4096 or host_size != size:
    raise SystemExit(f"mapping size/page mismatch pages={pages} size={size} host_size={host_size}")
if not host_base.startswith("0x") or host_base == "0x0":
    raise SystemExit(f"invalid host_base: {host_base}")
print(f"PASS configured mapping pages={pages} size={size} host_base={host_base}")

need(4, "hv second-stage validate", "hv: second_stage.validate_result=ok")
need(4, "hv second-stage validate", f"hv: second_stage.validate.checked_page_count={pages}")
need(5, "hv second-stage lookup-zero", "hv: second_stage.lookup_zero_result=ok")
need(5, "hv second-stage lookup-zero", "hv: second_stage.lookup_zero.gpa=0x0")
need(5, "hv second-stage lookup-zero", "hv: second_stage.lookup_zero.page_index=0")
need(6, "hv second-stage lookup-page", "hv: second_stage.lookup_page_result=ok")
need(6, "hv second-stage lookup-page", "hv: second_stage.lookup_page.gpa=0x1000")
need(6, "hv second-stage lookup-page", "hv: second_stage.lookup_page.page_index=1")
need(7, "hv second-stage bounds-test", "hv: second_stage.bounds_test=rejected")
need(7, "hv second-stage bounds-test", "hv: second_stage.bounds_test.error=out-of-bounds")
need(8, "hv second-stage alignment-test", "hv: second_stage.alignment_test=rejected")
need(8, "hv second-stage alignment-test", "hv: second_stage.alignment_test.error=misaligned")
need(9, "hv second-stage execute-permission-test", "hv: second_stage.execute_permission_test=rejected")
need(9, "hv second-stage execute-permission-test", "hv: second_stage.mapping.flags_execute=false")
need(10, "hv-stage2", "hv: second_stage.state=metadata-ready")
need(10, "hv-stage2", "hv: second_stage.mapping.active=false")
need(10, "hv-stage2", "hv: second_stage_translation=MISSING")
need(11, "hv exec", "hv: guest_execution=not-supported-yet")
need(11, "hv exec", "hv: guest_exec.prereq.second_stage_translation_present=false")
need(11, "hv exec", "hv: guest_exec.non_claim.second_stage_translation=false")
need(12, "hv second-stage reset", "hv: second_stage.reset_result=ok")
need(12, "hv second-stage reset", "hv: second_stage.state=inactive")
need(13, "hv second-stage", "hv: second_stage.state=inactive")
need(13, "hv second-stage", "hv: second_stage.mapping.active=false")
need(14, "hv status", "hv: guest_execution=not-supported-yet")
need(14, "hv status", "hv: linux_guest=not-supported-yet")
need(14, "hv status", "hv: h_extension=unknown reason=no-safe-detection-yet")
need(14, "hv status", "hv: second_stage_translation=MISSING")

for panic_marker in ("[ZIGN01D][PANIC]", "kernel panic", "panic:", "PANIC:"):
    if panic_marker.lower() in text.lower():
        raise SystemExit(f"true panic marker found: {panic_marker}")
print("PASS no true panic markers")
PYCHECK

reject "second_stage_translation=implemented"
reject "second_stage_translation=supported"
reject "second_stage.active=true"
reject "hgatp written"
reject "hgatp=enabled"
reject "guest_execution=supported"
reject "linux_guest=supported"
reject "guest entered"
reject "guest running"
reject "Linux guest booted"
reject "booted linux"
reject "h_extension=present"
reject "second_stage fake"
reject "second_stage=fake"
reject "second_stage placeholder"
reject "second_stage=placeholder"
reject "hv: second_stage=fake"
reject "hv: second_stage=placeholder"

log "HV11 second-stage metadata smoke passed transcript=$TRANSCRIPT"
printf 'PASS HV11 second-stage metadata smoke\n' | tee -a "$SMOKE_LOG"
