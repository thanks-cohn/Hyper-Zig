# ZIGN01D V4 Guarded MMIO Audit

## Audit result

V4 adds a guarded MMIO probe foundation but keeps live reads disabled. This is intentional. ZIGN01D does not yet prove that it can recover from an absent or faulting MMIO load and resume after the faulting instruction.

## Implemented boundary

The probe implementation is intentionally tiny:

- Probe policy: `fixed-qemu-virt-window`.
- Fixed addresses only:
  - `0x10001000`
  - `0x10002000`
  - `0x10003000`
  - `0x10004000`
- Probe result names:
  - `present`
  - `absent`
  - `unsafe`
  - `deferred`
  - `faulted`
  - `unknown`
- Expected virtio-mmio magic: `0x74726976` (`virt`).

Because live probing is disabled, fixed addresses report `deferred`, and non-allowlisted addresses report `unsafe` through the probe API. The disabled reason is: trap recovery is not strong enough for absent MMIO.

## What V4 proves

V4 proves:

- The fixed guarded MMIO probe path exists.
- QEMU virtio-mmio windows are enumerated without broad scanning.
- Device output can distinguish a deferred transport boundary from a missing driver.
- The shell can report MMIO probe status through `mmio`.
- Smoke coverage verifies the boundary and the explicit not-implemented driver pieces.

## What V4 does not prove

V4 does not prove:

- Virtio driver initialization.
- Queue setup.
- Feature negotiation.
- Interrupt handling.
- Block I/O.
- Network I/O.
- Filesystem support.
- Userspace support.

## Why broad scanning remains forbidden

Broad MMIO scanning is dangerous because reads can have effects or can fault on addresses where the kernel has no recovery path. A scan over arbitrary physical addresses could crash ZIGN01D or wedge QEMU before the shell can report a useful diagnostic. V4 therefore uses a fixed allowlist and does not walk MMIO ranges.

## Why virtio magic is not virtio support

The value `0x74726976` at a virtio-mmio base address identifies a virtio-mmio transport header. It does not negotiate features, select a queue, allocate descriptors, enable interrupts, or drive a device-specific protocol. Reporting magic as `present` in a future milestone must still say that driver negotiation and queue setup are not implemented.

## Honest device status

The V4 registry keeps the transport honest:

- `virtio-mmio-transport` is `deferred` while live probing is disabled.
- `virtio-mmio-net0` is `missing`.
- `virtio-mmio-blk0` is `missing`.

No network success, block success, filesystem mount, or userspace success is claimed.

## V5 next step

V5 should implement and test recoverable guarded MMIO fault handling. The acceptance bar should include a synthetic and live guarded-load proof that resumes safely after a load fault. Only after that proof should ZIGN01D enable fixed-window live magic reads by default.
