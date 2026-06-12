#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT/logs/latest"
SMOKE_LOG="$LOG_DIR/smoke-hv-stage2-table-v0.log"
QEMU_LOG="$LOG_DIR/qemu-hv-stage2-table-v0.log"
TRANSCRIPT="$ROOT/smoke/transcripts/latest-hv-stage2-table-v0.txt"
TRANSCRIPT_COPY="$LOG_DIR/qemu-smoke-hv-stage2-table-v0-transcript.txt"
ELF="$ROOT/zig-out/bin/zign01d-v0"

mkdir -p "$LOG_DIR" "$ROOT/smoke/transcripts"
: > "$SMOKE_LOG"
: > "$QEMU_LOG"
: > "$TRANSCRIPT"

stamp() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }
log() { printf '[%s][ZIGN01D][INFO][SMOKE][SMOKEHV12] %s\n' "$(stamp)" "$*" | tee -a "$SMOKE_LOG"; }
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
    "hv stage2-table"
    "hv guest-memory alloc"
    "hv address-space create"
    "hv second-stage configure"
    "hv stage2-table build"
    "hv stage2-table walk-zero"
    "hv stage2-table walk-page"
    "hv stage2-table bounds-test"
    "hv stage2-table alignment-test"
    "hv stage2-table execute-permission-test"
    "hv stage2-table validate"
    "hv-stage2-table"
    "hv exec"
    "hv stage2-table reset"
    "hv stage2-table"
    "hv status"
    "shutdown"
)

QEMU_CMD=(qemu-system-riscv64 -machine virt -cpu rv64 -smp 1 -m 128M -nographic -monitor none -serial stdio -kernel "$ELF")
printf '[%s][ZIGN01D][INFO][QEMU][QEMUHV12] command:' "$(stamp)" | tee -a "$QEMU_LOG" "$SMOKE_LOG"
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
    "hv stage2-table",
    "hv guest-memory alloc",
    "hv address-space create",
    "hv second-stage configure",
    "hv stage2-table build",
    "hv stage2-table walk-zero",
    "hv stage2-table walk-page",
    "hv stage2-table bounds-test",
    "hv stage2-table alignment-test",
    "hv stage2-table execute-permission-test",
    "hv stage2-table validate",
    "hv-stage2-table",
    "hv exec",
    "hv stage2-table reset",
    "hv stage2-table",
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
    "hv stage2-table",
    "hv guest-memory alloc",
    "hv address-space create",
    "hv second-stage configure",
    "hv stage2-table build",
    "hv stage2-table validate",
    "hv stage2-table walk-zero",
    "hv stage2-table walk-page",
    "hv stage2-table bounds-test",
    "hv stage2-table alignment-test",
    "hv stage2-table execute-permission-test",
    "hv-stage2-table",
    "hv exec",
    "hv stage2-table reset",
    "hv stage2-table",
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

def block_for(index, command):
    if (index, command) in blocks:
        return blocks[(index, command)]
    matches = [block for (i, c), block in blocks.items() if c == command]
    if matches:
        return matches[0]
    raise SystemExit(f"missing command block: {command}")

def need(index, command, marker):
    block = block_for(index, command)
    if marker not in block:
        raise SystemExit(f"missing marker after {command}: {marker}")
    print(f"PASS block marker after {command}: {marker}")

def value(index, command, key):
    block = block_for(index, command)
    m = re.search(re.escape(key) + r"([^\r\n]+)", block)
    if not m:
        raise SystemExit(f"missing value after {command}: {key}")
    return m.group(1).strip()

# Initial state proves the stage2 software table object starts empty, not prebuilt by status text.
need(0, "hv stage2-table", "hv: stage2_table=implemented-software-only")
need(0, "hv stage2-table", "hv: stage2_table.state=empty")
need(0, "hv stage2-table", "hv: stage2_table.mode=software-table-only")
need(0, "hv stage2-table", "hv: stage2_table.active=false")
need(0, "hv stage2-table", "hv: stage2_table.entry_count=0")
need(0, "hv stage2-table", "hv: second_stage_translation=MISSING")

# HV4/HV5/HV11 preparation is executed before HV12 build.
need(1, "hv guest-memory alloc", "hv: guest_memory.alloc_result=ok")
need(1, "hv guest-memory alloc", "hv: guest_memory.state=configured")
need(2, "hv address-space create", "hv: address_space.create_result=ok")
need(2, "hv address-space create", "hv: address_space.state=configured")
need(3, "hv second-stage configure", "hv: second_stage.configure_result=ok")
need(3, "hv second-stage configure", "hv: second_stage.state=metadata-ready")
need(3, "hv second-stage configure", "hv: second_stage.mapping.active=false")

need(4, "hv stage2-table build", "hv: stage2_table.build_result=ok")
need(4, "hv stage2-table build", "hv: stage2_table.state=built")
need(4, "hv stage2-table build", "hv: stage2_table.mode=software-table-only")
need(4, "hv stage2-table build", "hv: stage2_table.owner_vm_id=0")
need(4, "hv stage2-table build", "hv: stage2_table.active=false")
need(4, "hv stage2-table build", "hv: stage2_table.entry_count=2")
need(4, "hv stage2-table build", "hv: stage2_table.page_size=4096")
need(4, "hv stage2-table build", "hv: stage2_table.root_host_address=0x0")
need(4, "hv stage2-table build", "hv: stage2_table.entry0.guest_page_base=0x0")
need(4, "hv stage2-table build", "hv: stage2_table.entry1.guest_page_base=0x1000")
for idx in (0, 1):
    need(4, "hv stage2-table build", f"hv: stage2_table.entry{idx}.flags_read=true")
    need(4, "hv stage2-table build", f"hv: stage2_table.entry{idx}.flags_write=true")
    need(4, "hv stage2-table build", f"hv: stage2_table.entry{idx}.flags_execute=false")
    need(4, "hv stage2-table build", f"hv: stage2_table.entry{idx}.flags_valid=true")
    hpa = value(4, "hv stage2-table build", f"hv: stage2_table.entry{idx}.host_page_base=")
    if not hpa.startswith("0x") or hpa == "0x0":
        raise SystemExit(f"entry{idx} invalid host base {hpa}")
print("PASS build produced two software entries with nonzero host pages")

need(5, "hv stage2-table walk-zero", "hv: stage2_table.walk_zero_result=ok")
need(5, "hv stage2-table walk-zero", "hv: stage2_table.walk_zero.gpa=0x0")
need(5, "hv stage2-table walk-zero", "hv: stage2_table.walk_zero.page_index=0")
need(5, "hv stage2-table walk-zero", "hv: stage2_table.walk_zero.flags_execute=false")
need(6, "hv stage2-table walk-page", "hv: stage2_table.walk_page_result=ok")
need(6, "hv stage2-table walk-page", "hv: stage2_table.walk_page.gpa=0x1000")
need(6, "hv stage2-table walk-page", "hv: stage2_table.walk_page.page_index=1")
need(7, "hv stage2-table bounds-test", "hv: stage2_table.bounds_test=rejected")
need(7, "hv stage2-table bounds-test", "hv: stage2_table.bounds_test.table_error=out-of-bounds")
need(8, "hv stage2-table alignment-test", "hv: stage2_table.alignment_test=rejected")
need(8, "hv stage2-table alignment-test", "hv: stage2_table.alignment_test.table_error=misaligned")
need(9, "hv stage2-table execute-permission-test", "hv: stage2_table.execute_permission_test=rejected")
need(9, "hv stage2-table execute-permission-test", "hv: stage2_table.execute_permission_test.table_error=execute-not-permitted")
need(9, "hv stage2-table execute-permission-test", "hv: stage2_table.entry0.flags_execute=false")
need(10, "hv stage2-table validate", "hv: stage2_table.validate_result=ok")
need(10, "hv stage2-table validate", "hv: stage2_table.validate.checked_entry_count=2")
need(10, "hv stage2-table validate", "hv: stage2_table.state=validated")
need(11, "hv-stage2-table", "hv: stage2_table.state=validated")
need(11, "hv-stage2-table", "hv: stage2_table.active=false")
need(11, "hv-stage2-table", "hv: second_stage_translation=MISSING")
need(12, "hv exec", "hv: guest_exec.non_claim.guest_instruction_execution=false")
need(12, "hv exec", "hv: guest_exec.prereq.second_stage_translation_present=false")
need(12, "hv exec", "hv: guest_exec.non_claim.second_stage_translation=false")
need(13, "hv stage2-table reset", "hv: stage2_table.reset_result=ok")
need(13, "hv stage2-table reset", "hv: stage2_table.state=empty")
need(13, "hv stage2-table reset", "hv: stage2_table.entry_count=0")
need(14, "hv stage2-table", "hv: stage2_table.state=empty")
need(14, "hv stage2-table", "hv: stage2_table.active=false")
need(15, "hv status", "hv: guest_execution=not-supported-yet")
need(15, "hv status", "hv: linux_guest=not-supported-yet")
need(15, "hv status", "hv: h_extension=unknown reason=no-safe-detection-yet")
need(15, "hv status", "hv: second_stage_translation=MISSING")

for panic_marker in ("[ZIGN01D][PANIC]", "kernel panic", "panic:", "PANIC:"):
    if panic_marker.lower() in text.lower():
        raise SystemExit(f"true panic marker found: {panic_marker}")
print("PASS no true panic markers")
PYCHECK

reject "second_stage_translation=implemented"
reject "second_stage_translation=supported"
reject "stage2_table.active=true"
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

reject "hgatp_root=0x"
reject "stage2_table fake"
reject "stage2_table=fake"
reject "stage2_table placeholder"
reject "stage2_table=placeholder"

log "HV12 stage2 software table smoke passed transcript=$TRANSCRIPT"
printf 'PASS HV12 stage2 software table smoke\n' | tee -a "$SMOKE_LOG"
