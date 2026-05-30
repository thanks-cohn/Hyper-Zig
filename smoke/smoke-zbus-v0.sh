#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT/logs/latest"
SMOKE_LOG="$LOG_DIR/smoke-zbus-v0.log"
QEMU_LOG="$LOG_DIR/qemu-zbus-v0.log"
BUILD_LOG="$LOG_DIR/build.log"
TRANSCRIPT="$ROOT/smoke/transcripts/latest-zbus-v0.txt"
TRANSCRIPT_COPY="$LOG_DIR/qemu-smoke-zbus-v0-transcript.txt"
ELF="$ROOT/zig-out/bin/zign01d-v0"

mkdir -p "$LOG_DIR" "$ROOT/smoke/transcripts"
: > "$SMOKE_LOG"
: > "$QEMU_LOG"
: > "$TRANSCRIPT"

stamp() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }
log() { printf '[%s][ZIGN01D][INFO][SMOKE][ZBUS001] %s\n' "$(stamp)" "$*" | tee -a "$SMOKE_LOG"; }
fail_note() {
    {
        echo "[ZIGN01D][ERROR][SMOKE][ZBUS099] ZBUS V0 smoke failure evidence:"
        echo "  build.log: $BUILD_LOG"
        echo "  qemu.log: $QEMU_LOG"
        echo "  smoke.log: $SMOKE_LOG"
        echo "  transcript: $TRANSCRIPT"
        echo "  likely cause: ZBUS marker/command/status missing or fake capability success claimed"
        echo "  inspect next: kernel/comm/zbus.zig kernel/console/shell.zig docs/ZBUS_V0_AUDIT.md"
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
printf '[%s][ZIGN01D][INFO][QEMU][ZBUS001] command:' "$(stamp)" | tee -a "$QEMU_LOG" "$SMOKE_LOG"
printf ' %q' "${QEMU_CMD[@]}" | tee -a "$QEMU_LOG" "$SMOKE_LOG"
printf '\n' | tee -a "$QEMU_LOG" "$SMOKE_LOG"

log "launching ZBUS V0 controlled qemu session and waiting for shell readiness"
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
    "zbus",
    "zbus status",
    "zbus providers",
    "zbus ping",
    "comm",
    "net get http://example.com",
    "sms send +15551234567 hello",
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
    '[ZIGN01D][INFO][ZBUS][ZBUS000] host capability bus scaffold present; transport not connected' \
    'commands:' \
    'zbus' \
    'zbus status' \
    'zbus ping' \
    'zbus providers' \
    'zbus: interface=present' \
    'zbus: transport=none' \
    'zbus: connected=no' \
    'zbus: providers=none' \
    'zbus: net=not-implemented' \
    'zbus: sms=not-implemented' \
    'zbus: modem=not-implemented' \
    'zbus: files=not-implemented' \
    'zbus: time=not-implemented' \
    'zbus: ping=not-implemented' \
    'zbus: reason=no transport connected' \
    'zbus: safety=no host request sent' \
    'zbus_interface=present' \
    'zbus_transport=none' \
    'zbus_connected=no' \
    'zbus_providers=none' \
    'comm_bridge=zbus' \
    'net: provider=zbus' \
    'net: zbus=not-connected' \
    'net: safety=no network request sent' \
    'sms: provider=zbus' \
    'sms: zbus=not-connected' \
    'sms: safety=not-sent' \
    'modem: provider=zbus' \
    'modem: zbus=not-connected' \
    'modem: real_modem=not-attached'
do
    require "$marker"
done

reject_regex '(^|[^-])(internet|network|net)[[:space:]_-]*(works|working|success|succeeded|connected|online)' 'internet works'
reject_regex 'sms[[:space:]_-]*(was[[:space:]]*)?(sent|delivered|success|succeeded|received)' 'SMS sent or received'
reject_regex 'real_modem=(attached|present|connected)$|modem:[[:space:]]+(attached|present|connected)' 'real modem attached'
reject_regex 'call[[:space:]_-]*(works|working|connected|success|succeeded)' 'calls work'
reject_regex 'wifi[ -]?calling[[:space:]_-]*(works|working|enabled|success|succeeded)' 'Wi-Fi calling works'
reject_regex 'host[[:space:]_-]*bridge[[:space:]_-]*(connected|works|working|success|succeeded)' 'host bridge connected'
reject_regex 'providers[[:space:]_-]*(available|connected|enabled)' 'providers available'

log "smoke passed; transcript=$TRANSCRIPT"
echo "PASS ZIGN01D ZBUS V0 smoke"
