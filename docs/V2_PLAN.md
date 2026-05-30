# ZIGN01D V2 Machine Boundary Plan

V2 keeps the V0 boot proof and V1 diagnostic shell intact while adding a first honest kernel-to-machine boundary. The output binary remains `zig-out/bin/zign01d-v0` so existing scripts and smoke tests continue to exercise the same boot path.

## Scope

V2 adds:

- A supervisor trap vector installation path at boot.
- A panic diagnostic boundary that reports subsystem, code, cause, stage, and inspect hints.
- Shell commands `machine`, `cpu`, and `panic-test`.
- Device boundary status classes: `active`, `detected`, `placeholder`, `missing`, and `unknown`.
- Smoke proof in `smoke/smoke-v2.sh` that verifies V0, V1, and V2 markers.

## What is real

- UART polling on QEMU `virt` 16550 MMIO at `0x10000000`.
- Kernel entry, BSS zeroing, and hart-id capture from the firmware handoff register.
- DRAM assumptions for QEMU `virt` as documented by the linker and PMM.
- `rdtime` polling for uptime and machine status.
- Supervisor `stvec` installation to a kernel trap vector.
- Panic diagnostics emitted to serial.

## What is placeholder or missing

- PLIC interrupt claim/complete is placeholder-only.
- Timer interrupts are not enabled; uptime is polling-only.
- Virtio MMIO probing is deferred until absent-MMIO traps can be recovered safely.
- Network, block, modem, cellular, audio, SMS, and userspace are missing or boundary placeholders.
- `panic-test` is smoke-safe: it emits the panic diagnostic report without halting QEMU. Real unhandled traps still halt through the panic path.

## Next inspection steps

1. Add a recoverable trap frame so device probing can safely read optional MMIO ranges.
2. Implement PLIC claim/complete and timer interrupt enablement.
3. Add a minimal virtio-mmio transport probe with trap-safe fault classification.
4. Add syscall/trap frame separation before claiming any userspace support.
