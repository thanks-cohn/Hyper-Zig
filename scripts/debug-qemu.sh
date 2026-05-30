#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ELF="${1:-$ROOT/zig-out/bin/zign01d-v0}"
[[ -f "$ELF" ]] || { echo "missing ELF: $ELF" >&2; exit 1; }
exec qemu-system-riscv64 -machine virt -cpu rv64 -smp 1 -m 128M -nographic -monitor none -serial stdio -S -s -kernel "$ELF"
