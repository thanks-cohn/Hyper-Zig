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

if [[ -f ./smoke/smoke-zbus-v0.sh ]]; then
  run_step ./smoke/smoke-zbus-v0.sh
fi

echo "PASS ZIGN01D full smoke ladder"
