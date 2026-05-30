# BOARD V0 Spec

## What BOARD V0 is

BOARD V0 is a small board profile subsystem for ZIGN01D. It collects the current QEMU RISC-V `virt` machine assumptions into one visible source: `kernel/board/board.zig`.

The active profile is fixed:

- `board_name=qemu-virt`
- `board_arch=riscv64`
- `board_source=fixed-assumption`
- `board_detection=not-implemented`
- `device_tree_parse=not-implemented`

## What BOARD V0 is not

BOARD V0 is not a hardware abstraction layer, a device tree parser, a probing framework, a driver model, or a virtio implementation. It does not make ZIGN01D portable to real hardware.

## Why qemu-virt is fixed

The kernel already boots and smokes against `qemu-system-riscv64 -machine virt -m 128M`. BOARD V0 preserves that proven environment and names it explicitly rather than pretending the kernel can discover or adapt to other boards.

## What a board profile is

A board profile is a static set of addresses and facts that describe the machine the kernel assumes at boot. In BOARD V0, the profile is compile-time data and serial output only.

## Board assumptions

The profile records:

- RAM base: `0x80000000`
- RAM size bytes: `134217728`
- RAM size MiB: `128`
- UART0 base: `0x10000000`
- Virtio MMIO base: `0x10001000`
- Virtio MMIO stride: `0x1000`
- Virtio MMIO count: `8`
- PLIC base: `0x0c000000`
- CLINT base: `0x02000000`

## Memory, UART, MMIO, PLIC, and CLINT

- Memory uses the board profile RAM base and size for MEMORY V0 output.
- UART polling uses the board profile UART0 base as the fixed 16550-compatible serial MMIO address.
- MMIO reports the fixed QEMU virtio-mmio window as board-profile sourced, but live probing remains disabled.
- PLIC is present-assumed as a board fact, but no PLIC claim/complete driver is implemented.
- CLINT is present-assumed as a board fact, but no CLINT driver or timer interrupt path is implemented.

## Why no device tree parsing yet

Device tree parsing needs parser code, memory handling, validation rules, and careful failure behavior. BOARD V0 intentionally avoids that complexity so the fixed assumptions are teachable and smoke-testable first.

## Why no live detection yet

Live MMIO discovery can fault on absent addresses. ZIGN01D does not yet have a general recoverable fault path for arbitrary probing, so BOARD V0 reports `board_detection=not-implemented` and `live_probe=not-implemented`.

## Safety rules

- Do not claim real hardware support.
- Do not claim board detection is implemented.
- Do not claim device tree parsing is implemented.
- Do not claim virtio, PLIC, or CLINT drivers are implemented.
- Keep older MEMORY V0 compatibility strings such as `source=qemu-virt-assumption`.

## Command surface

- `board`
- `board profile`
- `board devices`
- `board-profile`
- `board-devices`

## Status fields

`status` includes:

```text
board_interface=present
board_name=qemu-virt
board_arch=riscv64
board_source=fixed-assumption
board_detection=not-implemented
device_tree_parse=not-implemented
```

## Limitations

BOARD V0 is a static visibility milestone. It does not allocate memory, parse firmware data, scan buses, bind drivers, negotiate virtio queues, enable interrupts, mount filesystems, or launch userspace.
