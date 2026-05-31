#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

run_step() {
  printf 'RUN %s\n' "$*"
  "$@"
}

run_step ./scripts/build.sh
run_step ./smoke/smoke-v0.sh
run_step ./smoke/smoke-v1.sh
run_step ./smoke/smoke-v2.sh
run_step ./smoke/smoke-v3.sh
run_step ./smoke/smoke-v4.sh
run_step ./smoke/smoke-comm-v0.sh

run_step ./smoke/smoke-zbus-v0.sh
run_step ./smoke/smoke-memory-v0.sh
run_step ./smoke/smoke-board-v0.sh
run_step ./smoke/smoke-virtio-discovery-v0.sh
run_step ./smoke/smoke-heap-v0.sh
run_step ./smoke/smoke-pmm-v0.sh
run_step ./smoke/smoke-tarfs-v0.sh
run_step ./smoke/smoke-ramfs-v0.sh

echo "PASS ZIGN01D full smoke ladder"
