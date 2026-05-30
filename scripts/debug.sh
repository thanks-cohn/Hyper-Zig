#!/usr/bin/env sh
set -eu

KERNEL=${1:-zig-out/bin/zign01d-v0.elf}

exec qemu-system-riscv64 \
  -machine virt \
  -cpu rv64 \
  -smp 1 \
  -m 128M \
  -nographic \
  -S \
  -s \
  -kernel "$KERNEL"
