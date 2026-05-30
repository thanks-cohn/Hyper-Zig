# ZIGN01D VIRTIO DISCOVERY V0 Spec

## What VIRTIO DISCOVERY V0 is

VIRTIO DISCOVERY V0 is a small kernel capability that computes the expected virtio-mmio slot table for the QEMU RISC-V `virt` board profile already named by BOARD V0.

## Exact capability added

The kernel imports the BOARD V0 virtio-mmio constants and computes eight expected slots from:

```text
addr = virtio_mmio_base + index * virtio_mmio_stride
```

For BOARD V0 this means:

```text
base=0x10001000
stride=0x1000
count=8
```

The computed table is exposed through `virtio slots`, summarized through `virtio summary`, and identified through `virtio`, `status`, `board devices`, and `mmio`.

## What it is not

VIRTIO DISCOVERY V0 is not a virtio driver. It is not live device probing. It does not read MMIO magic registers. It does not negotiate features, set up queues, bind drivers, configure interrupts, or activate virtio-block or virtio-net.

## How the slot table is computed

The implementation keeps BOARD V0 as the source of truth. The discovery module uses the board constants for base, stride, and count, then computes each slot address using `base + index * stride`. The shell prints the computed slots, not a separately maintained shell-only table.

## Why the board profile is the source of truth

BOARD V0 defines ZIGN01D's current QEMU `virt` assumptions. VIRTIO DISCOVERY V0 is intentionally tied to that profile so memory, board, MMIO, and virtio-discovery output agree on one fixed machine model.

## Why live probing is not implemented yet

Safe live probing requires stronger trap recovery for absent or faulting MMIO regions. Without that recovery, broad or speculative MMIO reads can crash or wedge the kernel. VIRTIO DISCOVERY V0 therefore reports `live_probe=not-implemented` and does not read device registers.

## Why driver negotiation is not implemented yet

Virtio feature negotiation belongs after the kernel can safely identify a device, manage memory for descriptors, and enforce transport-state rules. This milestone only computes expected transport windows.

## Why queue setup is not implemented yet

Queue setup needs allocator support, descriptor memory ownership rules, device status transitions, and interrupt or polling policy. Those are future milestones.

## How this prepares for virtio-block later

A future virtio-block milestone can start from a known board-derived slot table instead of hard-coded ad hoc addresses. The table gives later smoke tests a stable way to verify which windows the kernel intends to inspect before adding safe magic reads and driver binding.

## Command surface

- `virtio` reports discovery interface, transport, board, source, base, stride, count, and missing driver/probe features.
- `virtio summary` reports the transport, slot count, computed source, live-probe boundary, and driver-binding boundary.
- `virtio slots` prints every computed slot address and marks each slot `expected-by-board-profile`.
- `virtio-summary` and `virtio-slots` are flat aliases.

## Status fields

`status` includes:

```text
virtio_discovery_interface=present
virtio_transport=mmio
virtio_board=qemu-virt
virtio_source=board-profile
virtio_slot_count=8
virtio_slot_stride=0x1000
virtio_base=0x10001000
virtio_live_probe=not-implemented
virtio_magic_read=not-implemented
virtio_driver_negotiation=not-implemented
virtio_queue_setup=not-implemented
virtio_interrupt_setup=not-implemented
```

## Limitations

- Only the current BOARD V0 QEMU `virt` profile is represented.
- The slot table is expected-by-profile, not detected-by-hardware.
- No live probe or magic read occurs.
- No driver or queue state exists.
- No interrupt setup exists.

## Safety rules

- Do not claim device presence from this table.
- Do not perform live MMIO reads until guarded load recovery exists.
- Do not add virtio-block or virtio-net claims without separate driver smoke proof.
- Keep not-implemented boundaries visible in shell output and smoke tests.
