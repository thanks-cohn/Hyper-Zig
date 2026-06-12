#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT/logs/latest"
SMOKE_LOG="$LOG_DIR/smoke-hv-guest-run-attempt-v0.log"
QEMU_LOG="$LOG_DIR/qemu-hv-guest-run-attempt-v0.log"
TRANSCRIPT="$ROOT/smoke/transcripts/latest-hv-guest-run-attempt-v0.txt"
TRANSCRIPT_COPY="$LOG_DIR/qemu-smoke-hv-guest-run-attempt-v0-transcript.txt"
ELF="$ROOT/zig-out/bin/zign01d-v0"

mkdir -p "$LOG_DIR" "$ROOT/smoke/transcripts"
: > "$SMOKE_LOG"
: > "$QEMU_LOG"
: > "$TRANSCRIPT"

stamp() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }
log() { printf '[%s][ZIGN01D][INFO][SMOKE][SMOKEHV9] %s\n' "$(stamp)" "$*" | tee -a "$SMOKE_LOG"; }
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
    "hv guest-run"
    "hv-run"
    "hv guest-run require-entry-test"
    "hv guest-image load-tiny"
    "hv guest-entry prepare"
    "hv guest-run require-exit-test"
    "hv guest-exit record-instruction"
    "hv guest-run check"
    "hv vcpu"
    "hv guest-run arm-no-execute"
    "hv vcpu"
    "hv guest-run reset"
    "hv guest-run"
    "hv status"
    "shutdown"
)

QEMU_CMD=(qemu-system-riscv64 -machine virt -cpu rv64 -smp 1 -m 128M -nographic -monitor none -serial stdio -kernel "$ELF")
printf '[%s][ZIGN01D][INFO][QEMU][QEMUHV9] command:' "$(stamp)" | tee -a "$QEMU_LOG" "$SMOKE_LOG"
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
    "hv guest-run",
    "hv-run",
    "hv guest-run require-entry-test",
    "hv guest-image load-tiny",
    "hv guest-entry prepare",
    "hv guest-run require-exit-test",
    "hv guest-exit record-instruction",
    "hv guest-run check",
    "hv vcpu",
    "hv guest-run arm-no-execute",
    "hv vcpu",
    "hv guest-run reset",
    "hv guest-run",
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
    "hv guest-run",
    "hv-run",
    "hv guest-run require-entry-test",
    "hv guest-image load-tiny",
    "hv guest-entry prepare",
    "hv guest-run require-exit-test",
    "hv guest-exit record-instruction",
    "hv guest-run check",
    "hv vcpu",
    "hv guest-run arm-no-execute",
    "hv vcpu",
    "hv guest-run reset",
    "hv guest-run",
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
    return int(v, 16) if v.startswith("0x") else int(v, 10)

need(0, "hv guest-run", "hv: guest_run=implemented")
need(0, "hv guest-run", "hv: guest_run.owner_vm_id=0")
need(0, "hv guest-run", "hv: guest_run.owner_vcpu_id=0")
need(0, "hv guest-run", "hv: guest_run.state=idle")
need(0, "hv guest-run", "hv: guest_run.decision=not-checked")
need(0, "hv guest-run", "hv: guest_run.blocker=none")
need(0, "hv guest-run", "hv: guest_execution=not-supported-yet")
need(0, "hv guest-run", "hv: linux_guest=not-supported-yet")
need(0, "hv guest-run", "hv: second_stage_translation=MISSING")
need(0, "hv guest-run", "hv: h_extension=unknown reason=no-safe-detection-yet")

need(1, "hv-run", "hv: guest_run=implemented")
need(1, "hv-run", "hv: guest_run.state=idle")

need(2, "hv guest-run require-entry-test", "hv: guest_run.require_entry_test=rejected")
need(2, "hv guest-run require-entry-test", "hv: guest_run.decision=blocked-missing-entry")
need(2, "hv guest-run require-entry-test", "hv: guest_run.blocker=guest-entry-not-prepared")
failed_after_entry = number(value(2, "hv guest-run require-entry-test", "hv: guest_run.failed_check_count="))
if failed_after_entry < 1:
    raise SystemExit("require-entry-test did not increment failed_check_count")
print("PASS require-entry-test increments failed_check_count")

need(3, "hv guest-image load-tiny", "hv: guest_image.load_result=ok")
need(3, "hv guest-image load-tiny", "hv: guest_image.entry_point=0x0")
need(4, "hv guest-entry prepare", "hv: guest_entry.prepare_result=ok")
need(4, "hv guest-entry prepare", "hv: guest_entry.state=prepared")
entry_pc = number(value(4, "hv guest-entry prepare", "hv: guest_entry.frame.pc="))
entry_sp = number(value(4, "hv guest-entry prepare", "hv: guest_entry.frame.sp="))
if entry_pc != 0 or entry_sp == 0:
    raise SystemExit(f"bad HV7 frame pc={entry_pc:#x} sp={entry_sp:#x}")
print(f"PASS captured HV7 frame pc={entry_pc:#x} sp={entry_sp:#x}")

need(5, "hv guest-run require-exit-test", "hv: guest_run.require_exit_test=rejected")
need(5, "hv guest-run require-exit-test", "hv: guest_run.decision=blocked-missing-exit-model")
need(5, "hv guest-run require-exit-test", "hv: guest_run.blocker=guest-exit-model-missing")

need(6, "hv guest-exit record-instruction", "hv: guest_exit.record_result=ok")
need(6, "hv guest-exit record-instruction", "hv: guest_exit.state=recorded")
need(6, "hv guest-exit record-instruction", "hv: guest_exit.last_kind=instruction-trap")
exit_pc = number(value(6, "hv guest-exit record-instruction", "hv: guest_exit.frame.pc="))
exit_sp = number(value(6, "hv guest-exit record-instruction", "hv: guest_exit.frame.sp="))
if exit_pc != entry_pc or exit_sp != entry_sp:
    raise SystemExit("HV8 exit frame did not copy HV7 PC/SP")
print("PASS recorded HV8 exit model event copies HV7 frame")

need(7, "hv guest-run check", "hv: guest_run.check_result=blocked")
need(7, "hv guest-run check", "hv: guest_run.state=blocked")
need(7, "hv guest-run check", "hv: guest_run.decision=blocked-missing-second-stage-translation")
need(7, "hv guest-run check", "hv: guest_run.blocker=second-stage-translation-missing")
for marker in [
    "hv: guest_run.prereq.vm_present=true",
    "hv: guest_run.prereq.vcpu_present=true",
    "hv: guest_run.prereq.guest_memory_configured=true",
    "hv: guest_run.prereq.address_space_configured=true",
    "hv: guest_run.prereq.guest_image_loaded=true",
    "hv: guest_run.prereq.guest_entry_prepared=true",
    "hv: guest_run.prereq.guest_exit_model_ready=true",
    "hv: guest_run.prereq.second_stage_translation_present=false",
    "hv: guest_run.prereq.h_extension_present=false",
    "hv: guest_run.prereq.guest_execution_enabled=false",
    "hv: guest_run.blocker.second_stage_translation_missing=true",
    "hv: guest_run.blocker.h_extension_unknown=true",
    "hv: guest_run.blocker.guest_execution_disabled=true",
    "hv: guest_execution=not-supported-yet",
    "hv: linux_guest=not-supported-yet",
    "hv: second_stage_translation=MISSING",
    "hv: h_extension=unknown reason=no-safe-detection-yet",
]:
    need(7, "hv guest-run check", marker)
run_pc = number(value(7, "hv guest-run check", "hv: guest_run.frame.pc="))
run_sp = number(value(7, "hv guest-run check", "hv: guest_run.frame.sp="))
run_before = number(value(7, "hv guest-run check", "hv: guest_run.frame.vcpu_run_count_before="))
run_after = number(value(7, "hv guest-run check", "hv: guest_run.frame.vcpu_run_count_after="))
if run_pc != entry_pc or run_sp != entry_sp:
    raise SystemExit("guest-run frame did not copy HV7 PC/SP")
if run_before != 0 or run_after != 0:
    raise SystemExit("guest-run check changed vCPU run_count")
print("PASS guest-run check copies HV7/HV8 metadata and leaves run_count at 0")

need(8, "hv vcpu", "hv: vcpu.run_count=0")
need(9, "hv guest-run arm-no-execute", "hv: guest_run.arm_result=armed-no-execute")
need(9, "hv guest-run arm-no-execute", "hv: guest_run.state=armed-no-execute")
need(9, "hv guest-run arm-no-execute", "hv: guest_run.decision=armed-no-execute")
need(9, "hv guest-run arm-no-execute", "hv: guest_run.blocker.second_stage_translation_missing=true")
need(9, "hv guest-run arm-no-execute", "hv: guest_run.blocker.h_extension_unknown=true")
need(9, "hv guest-run arm-no-execute", "hv: guest_run.blocker.guest_execution_disabled=true")
arm_before = number(value(9, "hv guest-run arm-no-execute", "hv: guest_run.frame.vcpu_run_count_before="))
arm_after = number(value(9, "hv guest-run arm-no-execute", "hv: guest_run.frame.vcpu_run_count_after="))
if arm_before != 0 or arm_after != 0:
    raise SystemExit("arm-no-execute changed vCPU run_count")
print("PASS arm-no-execute arms metadata without running guest")
need(10, "hv vcpu", "hv: vcpu.run_count=0")

need(11, "hv guest-run reset", "hv: guest_run.reset_result=ok")
need(11, "hv guest-run reset", "hv: guest_run.state=idle")
reset_count = number(value(11, "hv guest-run reset", "hv: guest_run.reset_count="))
if reset_count < 1:
    raise SystemExit("reset_count did not increment")
print("PASS reset returns state to idle and increments reset_count")
need(12, "hv guest-run", "hv: guest_run.state=idle")
need(13, "hv status", "hv: guest_run=implemented")
need(13, "hv status", "hv: guest_execution=not-supported-yet")
need(13, "hv status", "hv: linux_guest=not-supported-yet")
need(13, "hv status", "hv: second_stage_translation=MISSING")
need(13, "hv status", "hv: h_extension=unknown reason=no-safe-detection-yet")

if re.search(r"(?<!true-)panic", text, flags=re.IGNORECASE):
    raise SystemExit("panic marker appeared in transcript")
for forbidden in [
    "guest_execution=supported",
    "linux_guest=supported",
    "guest entered",
    "guest running",
    "guest_run executed",
    "vcpu.run_count=1",
    "Linux guest booted",
    "booted linux",
    "h_extension=present",
    "second_stage_translation=implemented",
    "guest_run fake",
    "guest_run=fake",
    "guest_run placeholder",
    "guest_run=placeholder",
    "hv: guest_run=fake",
    "hv: guest_run=placeholder",
]:
    if forbidden.lower() in text.lower():
        raise SystemExit(f"forbidden marker found: {forbidden}")
print("PASS forbidden claims absent")
print("PASS HV9 guest run-attempt smoke behavior checks complete")
PYCHECK

reject "guest_execution=supported"
reject "linux_guest=supported"
reject "guest entered"
reject "guest running"
reject "guest_run executed"
reject "vcpu.run_count=1"
reject "Linux guest booted"
reject "booted linux"
reject "h_extension=present"
reject "second_stage_translation=implemented"
reject "guest_run fake"
reject "guest_run=fake"
reject "guest_run placeholder"
reject "guest_run=placeholder"
reject "hv: guest_run=fake"
reject "hv: guest_run=placeholder"

log "HV9 controlled guest-entry run-attempt smoke passed"
printf 'PASS smoke-hv-guest-run-attempt-v0 transcript=%s\n' "$TRANSCRIPT" | tee -a "$SMOKE_LOG"
