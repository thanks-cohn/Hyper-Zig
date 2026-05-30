# ZIGN01D V1 Plan

ZIGN01D V1 is a diagnostic kernel foundation. It adds small, real, inspectable state models for tasks, devices, syscalls, networking, and phone services while preserving the V0 boot path.

V1 is not real phone hardware support and not a general-purpose OS. Placeholder services must identify themselves as placeholders and point to the next file or subsystem to inspect.

## V1 foundation goals

- Keep the RISC-V QEMU boot path reproducible.
- Keep the output binary at `zig-out/bin/zign01d-v0` for continuity with V0 scripts.
- Expose kernel state through shell commands that read actual static module state.
- Fail honestly for unimplemented network, call, and SMS paths.
- Prove shell command processing and live timer behavior through smoke tests.

## What real calls and SMS require

Real phone functionality requires, at minimum:

- modem driver
- AT/QMI/MBIM or equivalent modem control
- SIM handling
- APN handling
- cellular stack integration
- audio path
- permissions/security model
- power management

Until those exist, `call` and `sms` must remain honest diagnostics, not pretend successes.

## Likely V2

- `virtio-net` or hosted network bridge, proving a real packet path instead of fake ping output.
- `virtio-blk` or initramfs/ramdisk, giving persistent or packaged input to the kernel.
- Cleaner syscall/trap boundary, turning the V1 syscall table into a real userspace interface.

## Likely V3

- Real board bring-up beyond QEMU `virt`.
- Real driver strategy and ownership model.
- Hardware abstraction that keeps board-specific details out of generic subsystems.
