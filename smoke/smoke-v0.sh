#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT/logs/latest"
SMOKE_LOG="$LOG_DIR/smoke.log"
QEMU_LOG="$LOG_DIR/qemu.log"
BUILD_LOG="$LOG_DIR/build.log"
TRANSCRIPT="$ROOT/smoke/transcripts/latest.txt"
TRANSCRIPT_COPY="$LOG_DIR/qemu-smoke-transcript.txt"
MARKERS="$ROOT/smoke/expected-markers.txt"
ELF="$ROOT/zig-out/bin/zign01d-v0.elf"
mkdir -p "$LOG_DIR" "$ROOT/smoke/transcripts"
: > "$SMOKE_LOG"
: > "$QEMU_LOG"
: > "$TRANSCRIPT"

stamp() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }
log() { printf '[%s][ZIGN01D][INFO][SMOKE][SMOKE001] %s\n' "$(stamp)" "$*" | tee -a "$SMOKE_LOG"; }
fail_note() {
  {
    echo "[ZIGN01D][ERROR][SMOKE][SMOKE999] smoke failure evidence:"
    echo "  build.log: $BUILD_LOG"
    echo "  qemu.log: $QEMU_LOG"
    echo "  smoke.log: $SMOKE_LOG"
    echo "  transcript: $TRANSCRIPT"
  } | tee -a "$SMOKE_LOG" >&2
}

log "running build"
if ! "$ROOT/scripts/build.sh" >>"$SMOKE_LOG" 2>&1; then
  fail_note
  exit 1
fi
[[ -f "$ELF" ]] || { echo "FAIL missing ELF: $ELF" | tee -a "$SMOKE_LOG"; fail_note; exit 1; }
command -v qemu-system-riscv64 >/dev/null 2>&1 || { echo "FAIL qemu-system-riscv64 not found" | tee -a "$SMOKE_LOG"; fail_note; exit 1; }

QEMU_CMD=(qemu-system-riscv64 -machine virt -cpu rv64 -smp 1 -m 128M -nographic -monitor none -serial stdio -kernel "$ELF")
printf '[%s][ZIGN01D][INFO][QEMU][QEMU001] command:' "$(stamp)" | tee -a "$QEMU_LOG" "$SMOKE_LOG"
printf ' %q' "${QEMU_CMD[@]}" | tee -a "$QEMU_LOG" "$SMOKE_LOG"
printf '\n' | tee -a "$QEMU_LOG" "$SMOKE_LOG"

log "launching controlled qemu session"
set +e
{
  printf 'status\n'
  printf 'mem\n'
  printf 'uptime\n'
  printf 'log\n'
  printf 'help\n'
  printf 'shutdown\n'
} | timeout 15s "${QEMU_CMD[@]}" >"$TRANSCRIPT" 2>&1
QEMU_STATUS=$?
set -e
cat "$TRANSCRIPT" >> "$QEMU_LOG"
cp "$TRANSCRIPT" "$TRANSCRIPT_COPY"

if [[ $QEMU_STATUS -ne 0 ]]; then
  echo "FAIL qemu exited with status $QEMU_STATUS" | tee -a "$SMOKE_LOG"
  fail_note
  exit 1
fi
if [[ ! -s "$TRANSCRIPT" ]]; then
  echo "FAIL boot transcript missing or empty" | tee -a "$SMOKE_LOG"
  fail_note
  exit 1
fi

missing=0
while IFS= read -r marker || [[ -n "$marker" ]]; do
  [[ -z "$marker" ]] && continue
  if grep -Fq "$marker" "$TRANSCRIPT"; then
    echo "PASS marker: $marker" | tee -a "$SMOKE_LOG"
  else
    echo "FAIL marker: $marker" | tee -a "$SMOKE_LOG"
    missing=1
  fi
done < "$MARKERS"

if [[ $missing -ne 0 ]]; then
  fail_note
  exit 1
fi

log "smoke passed; transcript=$TRANSCRIPT"
echo "PASS ZIGN01D V0 smoke"
