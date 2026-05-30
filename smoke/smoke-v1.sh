#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT/logs/latest"
SMOKE_LOG="$LOG_DIR/smoke-v1.log"
QEMU_LOG="$LOG_DIR/qemu-v1.log"
BUILD_LOG="$LOG_DIR/build.log"
TRANSCRIPT="$ROOT/smoke/transcripts/latest-v1.txt"
TRANSCRIPT_COPY="$LOG_DIR/qemu-smoke-v1-transcript.txt"
ELF="$ROOT/zig-out/bin/zign01d-v0"

mkdir -p "$LOG_DIR" "$ROOT/smoke/transcripts"
: > "$SMOKE_LOG"
: > "$QEMU_LOG"
: > "$TRANSCRIPT"

stamp() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }

log() {
    printf '[%s][ZIGN01D][INFO][SMOKE][SMOKE101] %s\n' "$(stamp)" "$*" | tee -a "$SMOKE_LOG"
}

fail_note() {
    {
        echo "[ZIGN01D][ERROR][SMOKE][SMOKE199] V1 smoke failure evidence:"
        echo "  build.log: $BUILD_LOG"
        echo "  qemu.log: $QEMU_LOG"
        echo "  smoke.log: $SMOKE_LOG"
        echo "  transcript: $TRANSCRIPT"
        echo "  likely cause: boot, shell command dispatch, command timing, or honest placeholder marker missing"
        echo "  inspect next: kernel/main.zig kernel/console/shell.zig smoke/smoke-v1.sh"
    } | tee -a "$SMOKE_LOG" >&2
}

fail() {
    echo "FAIL $*" | tee -a "$SMOKE_LOG"
    fail_note
    exit 1
}

require() {
    local marker="$1"
    if grep -Fq "$marker" "$TRANSCRIPT"; then
        echo "PASS marker: $marker" | tee -a "$SMOKE_LOG"
    else
        fail "missing marker: $marker"
    fi
}

log "running build"
if ! "$ROOT/scripts/build.sh" >>"$SMOKE_LOG" 2>&1; then
    fail_note
    exit 1
fi

[[ -f "$ELF" ]] || fail "missing kernel ELF: $ELF"
command -v qemu-system-riscv64 >/dev/null 2>&1 || fail "qemu-system-riscv64 not found"

QEMU_CMD=(
    qemu-system-riscv64
    -machine virt
    -cpu rv64
    -smp 1
    -m 128M
    -nographic
    -monitor none
    -serial stdio
    -kernel "$ELF"
)

printf '[%s][ZIGN01D][INFO][QEMU][QEMU101] command:' "$(stamp)" | tee -a "$QEMU_LOG" "$SMOKE_LOG"
printf ' %q' "${QEMU_CMD[@]}" | tee -a "$QEMU_LOG" "$SMOKE_LOG"
printf '\n' | tee -a "$QEMU_LOG" "$SMOKE_LOG"

log "launching V1 controlled qemu session"

set +e
{
    # Let OpenSBI and the kernel reach the shell prompt before feeding commands.
    sleep 2

    printf 'help\n'
    sleep 0.1
    printf 'status\n'
    sleep 0.1
    printf 'version\n'
    sleep 0.1
    printf 'build\n'
    sleep 0.1
    printf 'breadcrumbs\n'
    sleep 0.1
    printf 'logs\n'
    sleep 0.1
    printf 'devices\n'
    sleep 0.1
    printf 'tasks\n'
    sleep 0.1
    printf 'syscalls\n'
    sleep 0.1
    printf 'net\n'
    sleep 0.1
    printf 'ping 1.1.1.1\n'
    sleep 0.1
    printf 'phone\n'
    sleep 0.1
    printf 'call 5551234\n'
    sleep 0.1
    printf 'sms 5551234 hello\n'
    sleep 0.1
    printf 'uptime\n'
    sleep 0.1
    printf 'shutdown\n'
} | timeout 25s "${QEMU_CMD[@]}" >"$TRANSCRIPT" 2>&1
QEMU_STATUS=$?
set -e

cat "$TRANSCRIPT" >> "$QEMU_LOG"
cp "$TRANSCRIPT" "$TRANSCRIPT_COPY"

[[ $QEMU_STATUS -eq 0 ]] || fail "qemu exited with status $QEMU_STATUS"
[[ -s "$TRANSCRIPT" ]] || fail "boot transcript missing or empty"

for marker in \
    '[ZIGN01D][INFO][BOOT][BOOT001]' \
    '[ZIGN01D][INFO][BOOT][BOOT002]' \
    '[ZIGN01D][INFO][UART][UART001]' \
    '[ZIGN01D][INFO][MEM][MEM001]' \
    '[ZIGN01D][INFO][TASK][TASK001]' \
    '[ZIGN01D][INFO][DEV][DEV001]' \
    '[ZIGN01D][INFO][SYSCALL][SYS001]' \
    '[ZIGN01D][WARN][NET][NET001]' \
    '[ZIGN01D][WARN][PHONE][PHONE001]' \
    '[ZIGN01D][INFO][SHELL][SHELL001]' \
    'zign01d>' \
    'commands:' \
    'status:' \
    'version:' \
    'build:' \
    'breadcrumbs:' \
    'logs:' \
    'devices:' \
    'tasks:' \
    'syscalls:' \
    'net:' \
    'network driver not implemented' \
    'phone:' \
    'modem driver missing' \
    'cellular stack missing' \
    'audio path missing' \
    'sms stack missing'
do
    require "$marker"
done

if grep -Fq 'ping success' "$TRANSCRIPT" || grep -Fq 'call connected' "$TRANSCRIPT" || grep -Fq 'sms sent' "$TRANSCRIPT"; then
    fail "placeholder command pretended to succeed"
fi

UPTIME_VALUES=$(sed -n 's/.*uptime ticks=\([0-9][0-9]*\).*/\1/p' "$TRANSCRIPT")
[[ -n "$UPTIME_VALUES" ]] || fail "no uptime value found"

while read -r value; do
    [[ -n "$value" ]] || continue
    [[ "$value" != "0" ]] || fail "uptime reported canned zero"
done <<< "$UPTIME_VALUES"

log "smoke passed; transcript=$TRANSCRIPT"
echo "PASS ZIGN01D V1 smoke"
