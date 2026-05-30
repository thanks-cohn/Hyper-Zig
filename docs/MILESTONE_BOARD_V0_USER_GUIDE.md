# BOARD V0 User Guide

BOARD V0 adds an explicit board profile layer for the current QEMU RISC-V `virt` machine. It makes the fixed assumptions that were already used by memory, UART, MMIO, PLIC, and CLINT visible through a teachable command surface.

## What this milestone adds

- A BOARD V0 boot marker: `BOARD000`.
- A fixed board profile named `qemu-virt` for `riscv64`.
- Honest status fields for the board interface, source, detection, and device-tree parsing.
- Shell commands: `board`, `board profile`, and `board devices`.
- Flat aliases: `board-profile` and `board-devices`.
- Memory and MMIO output references to `source=board-profile` while keeping `source=qemu-virt-assumption` for MEMORY V0 compatibility.
- A dedicated smoke test: `smoke/smoke-board-v0.sh`.

## What this milestone does not add

- Real hardware support.
- Device tree parsing.
- Live board discovery.
- Live device probing.
- Virtio drivers.
- PLIC or CLINT drivers.
- Heap allocation, paging, filesystems, userspace, internet, SMS, or modem support.

## Build command

```sh
./scripts/build.sh
```

## Run command

```sh
./scripts/run-qemu.sh
```

## Shell commands added

- `board`
- `board profile`
- `board devices`
- `board-profile`
- `board-devices`

## Command examples

```text
zign01d> help
zign01d> status
zign01d> board
zign01d> board profile
zign01d> board devices
zign01d> memory
zign01d> memmap
zign01d> mmio
```

Expected `board` facts include:

```text
board: name=qemu-virt
board: arch=riscv64
board: source=fixed-assumption
board: detection=not-implemented
board: device_tree_parse=not-implemented
```

Expected `board profile` facts include:

```text
board-profile: name=qemu-virt
board-profile: ram_base=0x80000000
board-profile: ram_size_mib=128
board-profile: uart0_base=0x10000000
board-profile: virtio_mmio_base=0x10001000
board-profile: virtio_mmio_count=8
board-profile: plic_base=0x0c000000
board-profile: clint_base=0x02000000
```

Expected `board devices` facts include:

```text
board-devices: uart0=present-assumed
board-devices: virtio_mmio=present-assumed
board-devices: plic=present-assumed
board-devices: clint=present-assumed
board-devices: live_probe=not-implemented
board-devices: driver_binding=not-implemented
```

## Smoke test command

```sh
./smoke/smoke-board-v0.sh
```

## Expected passing output

```text
PASS ZIGN01D BOARD V0 smoke
```

## Manual verification checklist

Look for these strings in the serial transcript or smoke output:

- `BOARD000`
- `board_interface=present`
- `board_name=qemu-virt`
- `board_arch=riscv64`
- `board_source=fixed-assumption`
- `board_detection=not-implemented`
- `device_tree_parse=not-implemented`
- `ram_base=0x80000000`
- `ram_size_mib=128`
- `uart0_base=0x10000000`
- `virtio_mmio_base=0x10001000`

## Files added

- `kernel/board/board.zig`
- `docs/MILESTONE_BOARD_V0_USER_GUIDE.md`
- `docs/BOARD_V0_SPEC.md`
- `docs/BOARD_V0_AUDIT.md`
- `smoke/smoke-board-v0.sh`

## Files changed

- `kernel/main.zig`
- `kernel/console/shell.zig`
- `kernel/memory/memory.zig`
- `kernel/device/mmio_probe.zig`
- `smoke/smoke-all.sh`
- `smoke/smoke-docs.sh`
- `scripts/doctor.sh`
- `docs/COMMAND_REFERENCE.md`
- `docs/MILESTONE_INDEX.md`
- `docs/README.md`
- `ROADMAP.md`
- `README.md`

## Next milestone

The next recommended milestone is **VIRTIO DISCOVERY V0**, which should add safe, non-destructive visibility into expected virtio-mmio slots without claiming driver negotiation.
