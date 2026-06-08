#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

failures=0

pass() {
  printf 'PASS %s\n' "$1"
}

fail() {
  printf 'FAIL %s\n' "$1"
  failures=$((failures + 1))
}

check_command() {
  local name="$1"
  if command -v "$name" >/dev/null 2>&1; then
    pass "$name exists"
  else
    fail "$name not found"
  fi
}

check_executable() {
  local path="$1"
  if [[ -x "$path" ]]; then
    pass "$path exists and is executable"
  else
    fail "$path missing or not executable"
  fi
}

check_file() {
  local path="$1"
  if [[ -f "$path" ]]; then
    pass "$path exists"
  else
    fail "$path missing"
  fi
}

check_command git
if ./scripts/check-zig-version.sh >/tmp/zign01d-zig-version-check.log 2>&1; then
  pass "Zig version is accepted for target 0.14.x"
else
  fail "$(cat /tmp/zign01d-zig-version-check.log)"
fi

check_command qemu-system-riscv64
check_file scripts/build.sh
check_file scripts/check-zig-version.sh
check_file smoke/smoke-v0.sh
check_file smoke/smoke-v1.sh
check_file smoke/smoke-v2.sh
check_file smoke/smoke-v3.sh
check_file smoke/smoke-v4.sh
check_file smoke/smoke-comm-v0.sh
check_file smoke/smoke-all.sh
check_file smoke/smoke-memory-v0.sh
check_file smoke/smoke-board-v0.sh
check_file smoke/smoke-virtio-discovery-v0.sh
check_file smoke/smoke-heap-v0.sh
check_file smoke/smoke-pmm-v0.sh

if [[ "$failures" -eq 0 ]]; then
  echo "PASS ZIGN01D doctor"
else
  echo "FAIL ZIGN01D doctor ($failures checks failed)"
  exit 1
fi
