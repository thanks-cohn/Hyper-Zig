#!/usr/bin/env bash
set -euo pipefail

ZIG_BIN="${ZIG:-}"
if [[ -z "$ZIG_BIN" ]]; then
  if command -v zig >/dev/null 2>&1; then
    ZIG_BIN="$(command -v zig)"
  elif [[ -x /opt/zig/zig ]]; then
    ZIG_BIN="/opt/zig/zig"
  else
    echo "ERROR: zig executable not found; ZIGN01D targets Zig 0.14.x." >&2
    echo "Set ZIG=/path/to/zig-0.14.x or install Zig 0.14.x on PATH." >&2
    exit 1
  fi
fi

if [[ ! -x "$ZIG_BIN" ]] && ! command -v "$ZIG_BIN" >/dev/null 2>&1; then
  echo "ERROR: zig executable not found or not executable: $ZIG_BIN" >&2
  echo "ZIGN01D targets Zig 0.14.x." >&2
  exit 1
fi

ZIG_VERSION="$($ZIG_BIN version)"
case "$ZIG_VERSION" in
  0.14.*)
    echo "PASS Zig version $ZIG_VERSION accepted for ZIGN01D target 0.14.x"
    ;;
  *)
    echo "ERROR: Zig version $ZIG_VERSION is active, but ZIGN01D targets Zig 0.14.x." >&2
    echo "Zig 0.16 is not the project target; 0.16-only code must be labeled and backported." >&2
    exit 1
    ;;
esac
