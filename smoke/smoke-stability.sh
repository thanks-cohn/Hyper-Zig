#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

printf 'RUN ./scripts/doctor.sh\n'
./scripts/doctor.sh

printf 'RUN ./smoke/smoke-all.sh\n'
./smoke/smoke-all.sh

echo "PASS ZIGN01D stability smoke"
