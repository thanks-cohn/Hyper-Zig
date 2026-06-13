#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT/logs/latest"
SMOKE_LOG="$LOG_DIR/smoke-hv-stage2-activation-v0.log"
QEMU_LOG="$LOG_DIR/qemu-hv-stage2-activation-v0.log"
TRANSCRIPT="$ROOT/smoke/transcripts/latest-hv-stage2-activation-v0.txt"
TRANSCRIPT_COPY="$LOG_DIR/qemu-smoke-hv-stage2-activation-v0-transcript.txt"
ELF="$ROOT/zig-out/bin/zign01d-v0"

mkdir -p "$LOG_DIR" "$ROOT/smoke/transcripts"
: > "$SMOKE_LOG"
: > "$QEMU_LOG"
: > "$TRANSCRIPT"

stamp() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }
log() { printf '[%s][ZIGN01D][INFO][SMOKE][SMOKEHV13] %s\n' "$(stamp)" "$*" | tee -a "$SMOKE_LOG"; }
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

QEMU_CMD=(qemu-system-riscv64 -machine virt -cpu rv64 -smp 1 -m 128M -nographic -monitor none -serial stdio -kernel "$ELF")
printf '[%s][ZIGN01D][INFO][QEMU][QEMUHV13] command:' "$(stamp)" | tee -a "$QEMU_LOG" "$SMOKE_LOG"
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
    "hv stage2-activation",
    "hv guest-memory alloc",
    "hv address-space create",
    "hv second-stage configure",
    "hv stage2-table build",
    "hv stage2-table validate",
    "hv stage2-activation check",
    "hv stage2-activation plan",
    "hv stage2-activation validate",
    "hv stage2-activation hgatp-write-test",
    "hv stage2-activation require-table-test",
    "hv stage2-activation reset",
    "hv-stage2-activation",
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
deadline = time.monotonic() + 50.0

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
                    time.sleep(0.15)
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
    "hv stage2-activation",
    "hv guest-memory alloc",
    "hv address-space create",
    "hv second-stage configure",
    "hv stage2-table build",
    "hv stage2-table validate",
    "hv stage2-activation check",
    "hv stage2-activation plan",
    "hv stage2-activation validate",
    "hv stage2-activation hgatp-write-test",
    "hv stage2-activation require-table-test",
    "hv stage2-activation reset",
    "hv-stage2-activation",
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

def block(index, command):
    return blocks[(index, command)]

def require(haystack, marker, context):
    if marker not in haystack:
        raise SystemExit(f"missing marker in {context}: {marker}")
    print(f"PASS {context}: {marker}")

def require_re(pattern, haystack, context):
    m = re.search(pattern, haystack)
    if not m:
        raise SystemExit(f"missing pattern in {context}: {pattern}")
    print(f"PASS {context}: {pattern} -> {m.group(1) if m.groups() else m.group(0)}")
    return m

def value(marker, haystack, context):
    m = require_re(r"^" + re.escape(marker) + r"([^\r\n]+)", haystack, context)
    return m.group(1).strip()

initial = block(0, "hv stage2-activation")
require(initial, "hv: stage2_activation=implemented-guarded-readiness", "initial")
require(initial, "hv: stage2_activation.state=idle", "initial")
require(initial, "hv: stage2_activation.mode=guarded-readiness-only", "initial")
require(initial, "hv: stage2_activation.activation_allowed=false", "initial")
require(initial, "hv: stage2_activation.hgatp_write_allowed=false", "initial")
require(initial, "hv: stage2_activation.hgatp_written=false", "initial")
require(initial, "hv: stage2_activation.second_stage_enabled=false", "initial")

for index, command, marker in [
    (1, "hv guest-memory alloc", "hv: guest_memory.alloc_result=ok"),
    (2, "hv address-space create", "hv: address_space.create_result=ok"),
    (3, "hv second-stage configure", "hv: second_stage.configure_result=ok"),
    (4, "hv stage2-table build", "hv: stage2_table.build_result=ok"),
    (5, "hv stage2-table validate", "hv: stage2_table.validate_result=ok"),
]:
    require(block(index, command), marker, command)

stage2_validate = block(5, "hv stage2-table validate")
hv12_entry_count = value("hv: stage2_table.entry_count=", stage2_validate, "hv12 value flow")
hv12_page_size = value("hv: stage2_table.page_size=", stage2_validate, "hv12 value flow")
hv12_root = value("hv: stage2_table.root_host_address=", stage2_validate, "hv12 value flow")

check = block(6, "hv stage2-activation check")
require(check, "hv: stage2_activation.check_result=blocked", "check")
require(check, "hv: stage2_activation.table_validated=true", "check")
require(check, "hv: stage2_activation.blocker.h_extension_unknown=true", "check")
require(check, "hv: stage2_activation.blocker.hgatp_write_disabled=true", "check")
require(check, "hv: stage2_activation.blocker.guest_execution_disabled=true", "check")
require(check, "hv: stage2_activation.activation_allowed=false", "check")

plan = block(7, "hv stage2-activation plan")
require(plan, "hv: stage2_activation.plan_result=blocked", "plan")
require(plan, "hv: stage2_activation.activation_allowed=false", "plan")
require(plan, "hv: stage2_activation.hgatp_write_allowed=false", "plan")
require(plan, "hv: stage2_activation.hgatp_written=false", "plan")
require(plan, "hv: stage2_activation.second_stage_enabled=false", "plan")
require(plan, "hv: stage2_activation.h_extension_known=false", "plan")
require(plan, "hv: guest_execution=not-supported-yet", "plan")
require(plan, "hv: linux_guest=not-supported-yet", "plan")
require(plan, "hv: h_extension=unknown reason=no-safe-detection-yet", "plan")
hv13_entry_count = value("hv: stage2_activation.entry_count=", plan, "hv13 value flow")
hv13_page_size = value("hv: stage2_activation.page_size=", plan, "hv13 value flow")
hv13_ppn = value("hv: stage2_activation.expected_hgatp_ppn=", plan, "hv13 value flow")
if hv12_entry_count != hv13_entry_count:
    raise SystemExit(f"HV12/HV13 entry_count mismatch: {hv12_entry_count} != {hv13_entry_count}")
print(f"PASS value flow: HV12 entry_count {hv12_entry_count} == HV13 entry_count {hv13_entry_count}")
if hv12_page_size != hv13_page_size:
    raise SystemExit(f"HV12/HV13 page_size mismatch: {hv12_page_size} != {hv13_page_size}")
print(f"PASS value flow: HV12 page_size {hv12_page_size} == HV13 page_size {hv13_page_size}")
if hv12_root.lower() in ("0x0", "0"):
    if hv13_ppn.lower() not in ("0x0", "0"):
        raise SystemExit(f"HV12 root is {hv12_root} but HV13 expected_hgatp_ppn is {hv13_ppn}")
    require(plan, "hv: stage2_activation.activation_allowed=false", "root unavailable block")
    require(plan, "hv: stage2_activation.blocker.table_root_unavailable=true", "root unavailable block")
    print("PASS value flow: zero HV12 root produced zero HV13 HGATP PPN and remained blocked")

validate = block(8, "hv stage2-activation validate")
require(validate, "hv: stage2_activation.validate_result=ok", "validate")
require(validate, "hv: stage2_activation.validate.safe_non_activating=true", "validate")
require(validate, "hv: stage2_activation.validate.activation_still_blocked=true", "validate")
require(validate, "hv: stage2_activation.activation_allowed=false", "validate")
require(validate, "hv: stage2_activation.would_write_hgatp=false", "validate")
require(validate, "hv: stage2_activation.would_enable_second_stage=false", "validate")

hgatp = block(9, "hv stage2-activation hgatp-write-test")
require(hgatp, "hv: stage2_activation.hgatp_write_test=rejected", "hgatp-write-test")
require(hgatp, "hv: stage2_activation.hgatp_written=false", "hgatp-write-test")
require(hgatp, "hv: stage2_activation.hgatp_write_allowed=false", "hgatp-write-test")
require(hgatp, "hv: stage2_activation.activation_allowed=false", "hgatp-write-test")

table_test = block(10, "hv stage2-activation require-table-test")
require(table_test, "hv: stage2_activation.require_table_test=rejected", "require-table-test")
require(table_test, "hv: stage2_activation.table_validated=false", "require-table-test")
require(table_test, "hv: stage2_activation.blocker.missing_stage2_table=true", "require-table-test")

reset = block(11, "hv stage2-activation reset")
require(reset, "hv: stage2_activation.reset_result=ok", "reset")
require(reset, "hv: stage2_activation.state=idle", "reset")

alias = block(12, "hv-stage2-activation")
require(alias, "hv: stage2_activation=implemented-guarded-readiness", "alias")
require(alias, "hv: stage2_activation.state=idle", "alias")

status = block(13, "hv status")
require(status, "hv: stage2_activation=implemented-guarded-readiness", "status")
require(status, "hv: second_stage_translation=MISSING", "status")
require(status, "hv: guest_execution=not-supported-yet", "status")
require(status, "hv: linux_guest=not-supported-yet", "status")

for marker in ("[ZIGN01D][PANIC]", "kernel panic", "panic:", "PANIC:"):
    if marker in text:
        raise SystemExit(f"true panic marker found: {marker}")
print("PASS true panic markers absent")
PYCHECK
PYCHECK_STATUS=${PIPESTATUS[0]}
[[ $PYCHECK_STATUS -eq 0 ]] || fail "transcript semantic checks failed"

reject "stage2_activation.activation_allowed=true"
reject "stage2_activation.hgatp_write_allowed=true"
reject "stage2_activation.hgatp_written=true"
reject "stage2_activation.second_stage_enabled=true"
reject "second_stage_translation=implemented"
reject "second_stage_translation=supported"
reject "hgatp written"
reject "hgatp=enabled"
reject "hgatp_write=ok"
reject "h_extension=present"
reject "guest_execution=supported"
reject "linux_guest=supported"
reject "guest entered"
reject "guest running"
reject "Linux guest booted"
reject "booted linux"
reject "stage2_activation fake"
reject "stage2_activation=fake"
reject "stage2_activation placeholder"
reject "stage2_activation=placeholder"
reject "hv: stage2_activation=fake"
reject "hv: stage2_activation=placeholder"

log "PASS HV13 guarded stage2 activation readiness smoke"
