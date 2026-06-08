#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT/logs/latest"
LOG="$LOG_DIR/build.log"
ELF="$ROOT/zig-out/bin/zign01d-v0"
ZIG_BIN="${ZIG:-}"
if [[ -z "$ZIG_BIN" ]]; then
  if command -v zig >/dev/null 2>&1; then
    ZIG_BIN="$(command -v zig)"
  elif [[ -x /opt/zig/zig ]]; then
    ZIG_BIN="/opt/zig/zig"
  else
    ZIG_BIN="zig"
  fi
fi
BUILD_CMD=("$ZIG_BIN" build)

mkdir -p "$LOG_DIR"
: > "$LOG"

stamp() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }
log() { printf '[%s][ZIGN01D][INFO][BUILD][BUILD001] %s\n' "$(stamp)" "$*" | tee -a "$LOG"; }
fail() { printf '[%s][ZIGN01D][ERROR][BUILD][BUILD999] %s\n' "$(stamp)" "$*" | tee -a "$LOG" >&2; exit 1; }

log "date=$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
if git -C "$ROOT" rev-parse --short HEAD >/dev/null 2>&1; then
  log "git_commit=$(git -C "$ROOT" rev-parse --short HEAD)"
else
  log "git_commit=unavailable"
fi
if [[ -x "$ZIG_BIN" ]] || command -v "$ZIG_BIN" >/dev/null 2>&1; then
  log "zig_path=$ZIG_BIN"
  if ! ZIG="$ZIG_BIN" "$ROOT/scripts/check-zig-version.sh" 2>&1 | tee -a "$LOG"; then
    fail "wrong Zig version; ZIGN01D targets Zig 0.14.x"
  fi
  log "zig_version=$($ZIG_BIN version)"
else
  fail "zig executable not found; tried PATH zig and /opt/zig/zig; ZIGN01D targets Zig 0.14.x"
fi
log "host_uname=$(uname -a)"
log "build_command=${BUILD_CMD[*]}"
log "output_kernel=$ELF"

cd "$ROOT"
log "starting zig build"
if ! "${BUILD_CMD[@]}" 2>&1 | tee -a "$LOG"; then
  fail "zig build failed"
fi

if [[ ! -f "$ELF" ]]; then
  fail "expected ELF missing: $ELF"
fi

SIZE=$(wc -c < "$ELF" | tr -d ' ')
log "final_elf_size_bytes=$SIZE"
log "build complete"
