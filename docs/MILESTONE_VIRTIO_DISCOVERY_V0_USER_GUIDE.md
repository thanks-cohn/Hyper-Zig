# ZIGN01D VIRTIO DISCOVERY V0 User Guide

## What this milestone adds

VIRTIO DISCOVERY V0 adds a kernel virtio discovery module that computes the expected QEMU `virt` virtio-mmio slot table from BOARD V0 constants and exposes it through the shell, status output, board-device output, and MMIO output.

## The actual capability added

VIRTIO DISCOVERY V0 computes the expected qemu-virt virtio-mmio slot table from the BOARD V0 profile and exposes it through kernel shell commands.

The board profile supplies:

- `virtio_mmio_base=0x10001000`
- `virtio_mmio_stride=0x1000`
- `virtio_mmio_count=8`

The kernel computes each slot as `base + index * stride`, so slot 0 is `0x10001000` and slot 7 is `0x10008000`.

## What this milestone does not add

This milestone does not add live MMIO probing, virtio magic-value reads, driver negotiation, queue setup, interrupt setup, virtio-block, virtio-net, heap allocation, paging, filesystems, userspace, real hardware detection, or device tree parsing.

## Build command

```sh
./scripts/build.sh
```

## Run command

```sh
qemu-system-riscv64 -machine virt -cpu rv64 -smp 1 -m 128M -nographic -monitor none -serial stdio -kernel zig-out/bin/zign01d-v0
```

## Shell commands added

- `virtio`
- `virtio summary`
- `virtio slots`
- Flat aliases: `virtio-summary`, `virtio-slots`

## Command examples

```text
help
status
board devices
mmio
virtio
virtio summary
virtio slots
```

Example `virtio` output includes:

```text
virtio: interface=present
virtio: transport=mmio
virtio: board=qemu-virt
virtio: source=board-profile
virtio: base=0x10001000
virtio: stride=0x1000
virtio: slot_count=8
virtio: live_probe=not-implemented
virtio: magic_read=not-implemented
virtio: driver_negotiation=not-implemented
virtio: queue_setup=not-implemented
virtio: interrupt_setup=not-implemented
```

Example `virtio slots` output includes:

```text
virtio-slot: index=0 addr=0x10001000 status=expected-by-board-profile
virtio-slot: index=1 addr=0x10002000 status=expected-by-board-profile
virtio-slot: index=2 addr=0x10003000 status=expected-by-board-profile
virtio-slot: index=3 addr=0x10004000 status=expected-by-board-profile
virtio-slot: index=4 addr=0x10005000 status=expected-by-board-profile
virtio-slot: index=5 addr=0x10006000 status=expected-by-board-profile
virtio-slot: index=6 addr=0x10007000 status=expected-by-board-profile
virtio-slot: index=7 addr=0x10008000 status=expected-by-board-profile
```

## Smoke test command

```sh
./smoke/smoke-virtio-discovery-v0.sh
```

## Expected passing output

```text
PASS ZIGN01D VIRTIO DISCOVERY V0 smoke
```

## Manual verification checklist

Confirm these strings in a boot transcript:

- `VIRTIO000`
- `virtio_discovery_interface=present`
- `virtio_transport=mmio`
- `virtio_board=qemu-virt`
- `virtio_source=board-profile`
- `virtio_slot_count=8`
- `virtio: base=0x10001000`
- `virtio: stride=0x1000`
- `virtio-slot: index=0 addr=0x10001000`
- `virtio-slot: index=7 addr=0x10008000`
- `live_probe=not-implemented`
- `driver_negotiation=not-implemented`
- `queue_setup=not-implemented`

Also confirm the transcript does not claim implemented live probing, magic reads, driver negotiation, queue setup, interrupt setup, virtio-block, or virtio-net.

## Files added

- `kernel/virtio/discovery.zig`
- `smoke/smoke-virtio-discovery-v0.sh`
- `docs/MILESTONE_VIRTIO_DISCOVERY_V0_USER_GUIDE.md`
- `docs/VIRTIO_DISCOVERY_V0_SPEC.md`
- `docs/VIRTIO_DISCOVERY_V0_AUDIT.md`

## Files changed

- `kernel/main.zig`
- `kernel/console/shell.zig`
- `kernel/board/board.zig`
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

HEAP V0 should add a constrained kernel allocator with deterministic shell-testable allocation statistics and smoke proof. Do not treat VIRTIO DISCOVERY V0 as a driver milestone.
