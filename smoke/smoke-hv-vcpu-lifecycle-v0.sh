#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT/logs/latest"
SMOKE_LOG="$LOG_DIR/smoke-hv-vcpu-lifecycle-v0.log"
QEMU_LOG="$LOG_DIR/qemu-hv-vcpu-lifecycle-v0.log"
TRANSCRIPT="$ROOT/smoke/transcripts/latest-hv-vcpu-lifecycle-v0.txt"
TRANSCRIPT_COPY="$LOG_DIR/qemu-smoke-hv-vcpu-lifecycle-v0-transcript.txt"
ELF="$ROOT/zig-out/bin/zign01d-v0"

mkdir -p "$LOG_DIR" "$ROOT/smoke/transcripts"
: > "$SMOKE_LOG"
: > "$QEMU_LOG"
: > "$TRANSCRIPT"

stamp() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }
log() { printf '[%s][ZIGN01D][INFO][SMOKE][SMOKEHV3] %s\n' "$(stamp)" "$*" | tee -a "$SMOKE_LOG"; }
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
"$ROOT/scripts/check-zig-version.sh" >>"$SMOKE_LOG" 2>&1 || fail "Zig 0.14.x validation failed or is blocked"

log "running build"
"$ROOT/scripts/build.sh" >>"$SMOKE_LOG" 2>&1 || fail "build failed"
[[ -f "$ELF" ]] || fail "missing kernel ELF: $ELF"
command -v qemu-system-riscv64 >/dev/null 2>&1 || fail "qemu-system-riscv64 not found"

QEMU_CMD=(qemu-system-riscv64 -machine virt -cpu rv64 -smp 1 -m 128M -nographic -monitor none -serial stdio -kernel "$ELF")
printf '[%s][ZIGN01D][INFO][QEMU][QEMUHV3] command:' "$(stamp)" | tee -a "$QEMU_LOG" "$SMOKE_LOG"
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
commands = (
    "hv vcpu lifecycle",
    "hv vcpu init",
    "hv vcpu prepare",
    "hv vcpu halt",
    "hv vcpu prepare",
    "hv vcpu reset",
    "hv vcpu halt",
    "shutdown",
)
proc = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
os.set_blocking(proc.stdout.fileno(), False)
selector = selectors.DefaultSelector()
selector.register(proc.stdout, selectors.EVENT_READ)
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

path = Path(sys.argv[1])
text = path.read_text(errors="replace")
commands = [
    "hv vcpu lifecycle",
    "hv vcpu init",
    "hv vcpu prepare",
    "hv vcpu halt",
    "hv vcpu prepare",
    "hv vcpu reset",
    "hv vcpu halt",
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
    match = matches[occurrence]
    start = match.end()
    next_prompt = text.find("zign01d> ", start)
    if next_prompt == -1:
        next_prompt = len(text)
    blocks[(index, command)] = text[start:next_prompt]

def need(index, command, marker):
    block = blocks[(index, command)]
    if marker not in block:
        raise SystemExit(f"missing marker after {command}: {marker}")
    print(f"PASS block marker after {command}: {marker}")

need(0, "hv vcpu lifecycle", "hv: vcpu.lifecycle.state=created")
need(0, "hv vcpu lifecycle", "hv: vcpu.lifecycle.can_initialize=true")
need(0, "hv vcpu lifecycle", "hv: vcpu.lifecycle.can_prepare_runnable=false")
need(0, "hv vcpu lifecycle", "hv: vcpu.lifecycle.can_halt=false")
need(1, "hv vcpu init", "hv: vcpu.transition=initialize result=ok")
need(1, "hv vcpu init", "hv: vcpu.state=initialized")
need(1, "hv vcpu init", "hv: vcpu.hart_binding=boot-hart")
need(2, "hv vcpu prepare", "hv: vcpu.transition=prepare-runnable result=ok")
need(2, "hv vcpu prepare", "hv: vcpu.state=runnable")
need(3, "hv vcpu halt", "hv: vcpu.transition=halt result=ok")
need(3, "hv vcpu halt", "hv: vcpu.state=halted")
need(4, "hv vcpu prepare", "hv: vcpu.transition=prepare-runnable result=ok")
need(4, "hv vcpu prepare", "hv: vcpu.state=runnable")
need(5, "hv vcpu reset", "hv: vcpu.transition=reset result=ok")
need(5, "hv vcpu reset", "hv: vcpu.state=created")
need(5, "hv vcpu reset", "hv: vcpu.reset_generation=1")
need(6, "hv vcpu halt", "hv: vcpu.transition=halt result=invalid-state")
need(6, "hv vcpu halt", "hv: vcpu.state=created")
need(6, "hv vcpu halt", "hv: vcpu.stats.failed_transition_count=1")
need(6, "hv vcpu halt", "hv: vcpu.run_count=0")

state_sequence = [
    (0, "hv vcpu lifecycle", "created"),
    (1, "hv vcpu init", "initialized"),
    (2, "hv vcpu prepare", "runnable"),
    (3, "hv vcpu halt", "halted"),
    (4, "hv vcpu prepare", "runnable"),
    (5, "hv vcpu reset", "created"),
    (6, "hv vcpu halt", "created"),
]
previous = None
for index, command, expected in state_sequence:
    block = blocks[(index, command)]
    marker = f"state={expected}"
    if marker not in block:
        raise SystemExit(f"state proof missing after {command}: {marker}")
    if previous is not None and index <= 5 and previous == expected:
        raise SystemExit(f"state did not change across lifecycle command {command}")
    previous = expected
print("PASS state transitions changed across commands through reset")
print("PASS invalid halt after reset preserved created state and incremented failed_transition_count")
PYCHECK

for marker in \
    'hv: guest_execution=not-supported-yet' \
    'hv: linux_guest=not-supported-yet' \
    'hv: vcpu.run_count=0'
do
    require "$marker"
done

for forbidden in \
    'guest_execution=supported' \
    'linux_guest=supported' \
    'h_extension=present' \
    'guest entered' \
    'guest running' \
    'booted linux' \
    'Linux guest booted'
do
    reject "$forbidden"
done

if grep -Fq '[ZIGN01D][PANIC]' "$TRANSCRIPT" \
    || grep -Fq 'panic:' "$TRANSCRIPT" \
    || grep -Fq 'PANIC' "$TRANSCRIPT" \
    || grep -Fq 'kernel panic' "$TRANSCRIPT" \
    || grep -Fq 'panicked at' "$TRANSCRIPT"; then
    fail "true panic marker found in HV3 vCPU lifecycle transcript"
fi
if grep -Fq 'QEMU: Terminated' "$TRANSCRIPT" || grep -Fq 'qemu-system-riscv64: terminating' "$TRANSCRIPT"; then
    fail "qemu crash/termination output found in HV3 transcript"
fi

log "HV3 vCPU lifecycle smoke passed; transcript=$TRANSCRIPT"
echo "PASS ZIGN01D HV3 vCPU lifecycle smoke"
