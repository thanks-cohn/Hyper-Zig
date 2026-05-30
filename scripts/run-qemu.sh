#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ELF="${1:-$ROOT/zig-out/bin/zign01d-v0}"
LOG_DIR="$ROOT/logs/latest"
LOG="$LOG_DIR/qemu.log"
mkdir -p "$LOG_DIR"
: > "$LOG"

stamp() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }
fail() { printf '[%s][ZIGN01D][ERROR][QEMU][QEMU999] %s\n' "$(stamp)" "$*" | tee -a "$LOG" >&2; exit 1; }

[[ -f "$ELF" ]] || fail "kernel ELF does not exist: $ELF"
command -v qemu-system-riscv64 >/dev/null 2>&1 || fail "qemu-system-riscv64 not found in PATH"

QEMU_CMD=(qemu-system-riscv64 -machine virt -cpu rv64 -smp 1 -m 128M -nographic -monitor none -serial stdio -kernel "$ELF")
printf '[%s][ZIGN01D][INFO][QEMU][QEMU001] command:' "$(stamp)" | tee -a "$LOG"
printf ' %q' "${QEMU_CMD[@]}" | tee -a "$LOG"
printf '\n' | tee -a "$LOG"

"${QEMU_CMD[@]}" 2>&1 | tee -a "$LOG"
