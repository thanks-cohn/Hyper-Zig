#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT/logs/latest"
SMOKE_LOG="$LOG_DIR/smoke-hv-guest-execution-v0.log"
QEMU_LOG="$LOG_DIR/qemu-hv-guest-execution-v0.log"
TRANSCRIPT="$ROOT/smoke/transcripts/latest-hv-guest-execution-v0.txt"
TRANSCRIPT_COPY="$LOG_DIR/qemu-smoke-hv-guest-execution-v0-transcript.txt"
ELF="$ROOT/zig-out/bin/zign01d-v0"

mkdir -p "$LOG_DIR" "$ROOT/smoke/transcripts"
: > "$SMOKE_LOG"
: > "$QEMU_LOG"
: > "$TRANSCRIPT"

stamp() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }
log() { printf '[%s][ZIGN01D][INFO][SMOKE][SMOKEHV10] %s\n' "$(stamp)" "$*" | tee -a "$SMOKE_LOG"; }
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
    "hv exec"
    "hv exec-check"
    "hv guest-image load-tiny"
    "hv guest-entry prepare"
    "hv guest-exit record-instruction"
    "hv guest-run arm-no-execute"
    "hv exec-check"
    "hv exec-arm"
    "hv exec-blockers"
    "hv exec-require-prereq-test"
    "hv exec-reset"
    "hv exec-status"
    "hv status"
    "shutdown"
)

QEMU_CMD=(qemu-system-riscv64 -machine virt -cpu rv64 -smp 1 -m 128M -nographic -monitor none -serial stdio -kernel "$ELF")
printf '[%s][ZIGN01D][INFO][QEMU][QEMUHV10] command:' "$(stamp)" | tee -a "$QEMU_LOG" "$SMOKE_LOG"
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
    "hv exec",
    "hv exec-check",
    "hv guest-image load-tiny",
    "hv guest-entry prepare",
    "hv guest-exit record-instruction",
    "hv guest-run arm-no-execute",
    "hv exec-check",
    "hv exec-arm",
    "hv exec-blockers",
    "hv exec-require-prereq-test",
    "hv exec-reset",
    "hv exec-status",
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
    "hv exec",
    "hv exec-check",
    "hv guest-image load-tiny",
    "hv guest-entry prepare",
    "hv guest-exit record-instruction",
    "hv guest-run arm-no-execute",
    "hv exec-check",
    "hv exec-arm",
    "hv exec-blockers",
    "hv exec-require-prereq-test",
    "hv exec-reset",
    "hv exec-status",
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

def number(index, command, key):
    raw = value(index, command, key)
    if not re.fullmatch(r"[0-9]+", raw):
        raise SystemExit(f"non-numeric value after {command}: {key}{raw}")
    return int(raw)

need(0, "hv exec", "hv: guest_execution_gate=implemented")
need(0, "hv exec", "hv: guest_exec.state=cold")
need(0, "hv exec", "hv: guest_exec.prereq.guest_entry_prepared=false")
need(0, "hv exec", "hv: guest_exec.prereq.run_attempt_armed=false")
need(0, "hv exec", "hv: guest_exec.non_claim.guest_instruction_execution=false")

need(1, "hv exec-check", "hv: guest_exec.validate_result=rejected")
need(1, "hv exec-check", "hv: guest_exec.state=blocked")
initial_rejected = number(1, "hv exec-check", "hv: guest_exec.stats.rejected_count=")
if initial_rejected < 1:
    raise SystemExit("validate rejection counter did not increment")
print("PASS rejected_count incremented on missing prerequisites")

need(2, "hv guest-image load-tiny", "hv: guest_image.load_result=ok")
need(3, "hv guest-entry prepare", "hv: guest_entry.prepare_result=ok")
need(4, "hv guest-exit record-instruction", "hv: guest_exit.record_result=ok")
need(5, "hv guest-run arm-no-execute", "hv: guest_run.arm_result=armed-no-execute")

for marker in [
    "hv: guest_exec.validate_result=ok",
    "hv: guest_exec.state=validated",
    "hv: guest_exec.decision=blocked-by-hardware-gate",
    "hv: guest_exec.primary_blocker=second-stage-translation-missing",
    "hv: guest_exec.prereq.guest_memory_configured=true",
    "hv: guest_exec.prereq.address_space_configured=true",
    "hv: guest_exec.prereq.guest_image_loaded=true",
    "hv: guest_exec.prereq.guest_entry_prepared=true",
    "hv: guest_exec.prereq.guest_exit_model_ready=true",
    "hv: guest_exec.prereq.run_attempt_armed=true",
    "hv: guest_exec.prereq.second_stage_translation_present=false",
    "hv: guest_exec.prereq.h_extension_present=false",
    "hv: guest_exec.prereq.guest_execution_enabled=false",
    "hv: guest_exec.blocker.second_stage_translation_missing=true",
    "hv: guest_exec.blocker.h_extension_unknown=true",
    "hv: guest_exec.blocker.guest_execution_disabled=true",
]:
    need(6, "hv exec-check", marker)
score = number(6, "hv exec-check", "hv: guest_exec.stats.readiness_score=")
if score != 8:
    raise SystemExit(f"unexpected readiness score after prerequisites: {score}")
print("PASS readiness score proves eight prepared software prerequisites")

for key in [
    "hv: guest_exec.frame.pc=",
    "hv: guest_exec.frame.sp=",
    "hv: guest_exec.frame.guest_base=",
    "hv: guest_exec.frame.guest_size_bytes=",
    "hv: guest_exec.frame.translated_page_count=",
    "hv: guest_exec.frame.loaded_byte_count=",
    "hv: guest_exec.frame.exit_kind_tag=",
]:
    raw = value(6, "hv exec-check", key)
    if raw in {"0", "0x0"} and not key.endswith("pc="):
        raise SystemExit(f"execution frame field did not become populated: {key}{raw}")
print("PASS execution frame captured non-zero prepared state fields")

need(7, "hv exec-arm", "hv: guest_exec.arm_result=armed-blocked")
need(7, "hv exec-arm", "hv: guest_exec.state=armed-blocked")
need(7, "hv exec-arm", "hv: guest_exec.decision=armed-but-execution-blocked")
need(7, "hv exec-arm", "hv: guest_exec.stats.last_error=hardware-gate-blocked")
if number(7, "hv exec-arm", "hv: guest_exec.stats.hardware_block_count=") < 1:
    raise SystemExit("hardware block counter did not increment")
print("PASS hardware block counter incremented")

need(8, "hv exec-blockers", "hv: guest_exec.blockers_result=blocked")
if number(8, "hv exec-blockers", "hv: guest_exec.stats.blocker_count=") < 1:
    raise SystemExit("blocker command counter did not increment")
print("PASS blocker command counter incremented")

need(9, "hv exec-require-prereq-test", "hv: guest_exec.require_prereq_test_result=rejected")
need(9, "hv exec-require-prereq-test", "hv: guest_exec.primary_blocker=guest-entry-missing")
need(9, "hv exec-require-prereq-test", "hv: guest_exec.state=blocked")

need(10, "hv exec-reset", "hv: guest_exec.reset_result=ok")
need(10, "hv exec-reset", "hv: guest_exec.state=cold")
if number(10, "hv exec-reset", "hv: guest_exec.stats.reset_count=") < 1:
    raise SystemExit("reset counter did not increment")
print("PASS reset counter incremented")

need(11, "hv exec-status", "hv: guest_exec.stats.status_count=")
if number(11, "hv exec-status", "hv: guest_exec.stats.status_count=") < 1:
    raise SystemExit("status counter did not increment")
print("PASS status counter incremented")

need(12, "hv status", "hv: guest_execution_gate=implemented")
need(12, "hv status", "hv: next=HV10 hardware-gated guest execution research")
print("PASS HV10 guest execution preparation behavior validated")
PYCHECK

reject "guest entered"
reject "guest_instruction_execution=true"
reject "guest_execution=supported"
reject "linux_guest=supported"
reject "h_extension=present"
reject "second_stage_translation=implemented"
reject "Linux guest booted"

log "HV10 guest execution preparation smoke passed transcript=$TRANSCRIPT"
