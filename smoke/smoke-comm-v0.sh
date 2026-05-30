#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT/logs/latest"
SMOKE_LOG="$LOG_DIR/smoke-comm-v0.log"
QEMU_LOG="$LOG_DIR/qemu-comm-v0.log"
BUILD_LOG="$LOG_DIR/build.log"
TRANSCRIPT="$ROOT/smoke/transcripts/latest-comm-v0.txt"
TRANSCRIPT_COPY="$LOG_DIR/qemu-smoke-comm-v0-transcript.txt"
ELF="$ROOT/zig-out/bin/zign01d-v0"

mkdir -p "$LOG_DIR" "$ROOT/smoke/transcripts"
: > "$SMOKE_LOG"
: > "$QEMU_LOG"
: > "$TRANSCRIPT"

stamp() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }
log() { printf '[%s][ZIGN01D][INFO][SMOKE][COMM001] %s\n' "$(stamp)" "$*" | tee -a "$SMOKE_LOG"; }
fail_note() {
    {
        echo "[ZIGN01D][ERROR][SMOKE][COMM099] COMM V0 smoke failure evidence:"
        echo "  build.log: $BUILD_LOG"
        echo "  qemu.log: $QEMU_LOG"
        echo "  smoke.log: $SMOKE_LOG"
        echo "  transcript: $TRANSCRIPT"
        echo "  likely cause: communication scaffold marker/command missing or fake communication success claimed"
        echo "  inspect next: kernel/comm/ kernel/console/shell.zig docs/COMM_V0_AUDIT.md"
    } | tee -a "$SMOKE_LOG" >&2
}
fail() { echo "FAIL $*" | tee -a "$SMOKE_LOG"; fail_note; exit 1; }
require() {
    local marker="$1"
    if grep -Fq "$marker" "$TRANSCRIPT"; then
        echo "PASS marker: $marker" | tee -a "$SMOKE_LOG"
    else
        fail "missing marker: $marker"
    fi
}
reject_regex() {
    local pattern="$1"
    local label="$2"
    if grep -Eiq "$pattern" "$TRANSCRIPT"; then
        fail "forbidden fake success claim: $label"
    fi
    echo "PASS forbidden absent: $label" | tee -a "$SMOKE_LOG"
}

log "running build"
if ! "$ROOT/scripts/build.sh" >>"$SMOKE_LOG" 2>&1; then
    fail_note
    exit 1
fi

[[ -f "$ELF" ]] || fail "missing kernel ELF: $ELF"
command -v qemu-system-riscv64 >/dev/null 2>&1 || fail "qemu-system-riscv64 not found"

QEMU_CMD=(qemu-system-riscv64 -machine virt -cpu rv64 -smp 1 -m 128M -nographic -monitor none -serial stdio -kernel "$ELF")
printf '[%s][ZIGN01D][INFO][QEMU][COMM001] command:' "$(stamp)" | tee -a "$QEMU_LOG" "$SMOKE_LOG"
printf ' %q' "${QEMU_CMD[@]}" | tee -a "$QEMU_LOG" "$SMOKE_LOG"
printf '\n' | tee -a "$QEMU_LOG" "$SMOKE_LOG"

log "launching COMM V0 controlled qemu session and waiting for shell readiness"
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
    "help",
    "status",
    "comm",
    "bridge status",
    "net status",
    "net get http://example.com",
    "sms inbox",
    "sms send +15551234567 hello",
    "sms wait",
    "modem status",
    "shutdown",
]
proc = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
os.set_blocking(proc.stdout.fileno(), False)
sel = selectors.DefaultSelector()
sel.register(proc.stdout, selectors.EVENT_READ)
seen = bytearray()
ready = False
status = 124
deadline = time.monotonic() + 25.0
with open(transcript, "wb") as out:
    try:
        while time.monotonic() < deadline:
            if proc.poll() is not None:
                status = proc.returncode
                break
            for key, _ in sel.select(timeout=0.05):
                chunk = key.fileobj.read()
                if chunk:
                    out.write(chunk)
                    out.flush()
                    seen.extend(chunk)
            if not ready and b"zign01d> " in seen:
                ready = True
                for item in commands:
                    proc.stdin.write((item + "\n").encode())
                    proc.stdin.flush()
                    time.sleep(0.1)
            if ready and proc.poll() is not None:
                status = proc.returncode
                break
        else:
            status = 124
    finally:
        if proc.poll() is None:
            proc.terminate()
            try:
                proc.wait(timeout=2)
            except subprocess.TimeoutExpired:
                proc.kill()
        while True:
            try:
                chunk = proc.stdout.read()
            except Exception:
                chunk = b""
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

for marker in \
    'zign01d>' \
    '[ZIGN01D][INFO][COMM][COMM000] communication scaffold present; bridge not connected' \
    'commands:' \
    'comm' \
    'bridge status' \
    'net status' \
    'net get' \
    'sms inbox' \
    'sms send' \
    'modem status' \
    'comm_interface=present' \
    'comm_bridge=not-connected' \
    'real_internet=not-implemented' \
    'real_sms=not-implemented' \
    'comm: interface=present' \
    'bridge: connected=no' \
    'net: backend=none' \
    'net: get=not-implemented' \
    'net: safety=no network request sent' \
    'sms: inbox=unavailable' \
    'sms: send=not-implemented' \
    'sms: safety=not-sent' \
    'sms: wait=not-implemented' \
    'modem: real_modem=not-attached'
do
    require "$marker"
done

reject_regex '(^|[^-])(internet|network|net)[[:space:]_-]*(works|working|success|succeeded|connected|online)' 'internet works'
reject_regex 'sms[[:space:]_-]*(was[[:space:]]*)?(sent|delivered|success|succeeded|received)' 'SMS sent or received'
reject_regex 'real_modem=(attached|present|connected)$|modem:[[:space:]]+(attached|present|connected)' 'real modem attached'
reject_regex 'call[[:space:]_-]*(works|working|connected|success|succeeded)' 'calls work'
reject_regex 'wifi[ -]?calling[[:space:]_-]*(works|working|enabled|success|succeeded)' 'Wi-Fi calling works'
reject_regex 'cellular[[:space:]_-]*(works|working|connected|online|success|succeeded)' 'cellular works'

log "smoke passed; transcript=$TRANSCRIPT"
echo "PASS ZIGN01D COMM V0 smoke"
