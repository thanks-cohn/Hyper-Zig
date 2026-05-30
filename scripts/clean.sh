#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
rm -rf "$ROOT/zig-out" "$ROOT/.zig-cache" "$ROOT/zig-cache"
rm -f "$ROOT/logs/latest"/*.log "$ROOT/logs/latest"/*.txt "$ROOT/smoke/transcripts/latest.txt"
echo "[ZIGN01D][INFO][BUILD][BUILD002] clean complete"
