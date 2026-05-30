# ZIGN01D V4 Plan: Guarded MMIO Probe Foundation

## Purpose

V4 prepares ZIGN01D to inspect QEMU `virt` MMIO device regions without pretending that full virtio drivers exist. The milestone adds a small, auditable probe module and a shell-visible report for a fixed set of QEMU virtio-mmio transport windows.

## What V4 proves

V4 proves only the following boundaries:

- A fixed guarded MMIO probe path exists in `kernel/device/mmio_probe.zig`.
- The only considered virtio-mmio windows are the known QEMU `virt` addresses:
  - `0x10001000`
  - `0x10002000`
  - `0x10003000`
  - `0x10004000`
- The probe API can distinguish `present`, `absent`, `unsafe`, `deferred`, `faulted`, and `unknown` outcomes.
- The device registry can report a virtio-mmio transport as a boundary status instead of treating it as a working driver.
- The `mmio` shell command reports probe policy, live-probe state, considered addresses, and missing driver work.
- `smoke-v4.sh` verifies the guarded MMIO boundary and rejects fake virtio-net, virtio-blk, filesystem, and userspace success claims.

## What V4 does not prove

V4 does not prove:

- Virtio driver initialization.
- Virtio feature negotiation.
- Virtio queue setup.
- Virtio interrupt setup.
- Block reads.
- Network packets.
- Filesystem support.
- Userspace support.

## Live probing policy

Live probing is disabled in V4 because trap recovery is not yet strong enough to guarantee safe recovery from absent or faulting MMIO reads. The scaffold is intentionally present, but it does not perform broad reads across the physical address space.

If live reads are enabled in a future milestone, they must remain restricted to the fixed QEMU `virt` allowlist until trap recovery has been audited. The expected virtio-mmio magic value is `0x74726976`, the ASCII bytes for `virt`.

## Why broad MMIO scanning is dangerous

MMIO reads are not normal RAM reads. Accessing an unmapped, reserved, write-sensitive, or device-specific region can trap, hang the machine, trigger device side effects, or leave the kernel unable to continue. Without proven trap recovery, a broad scanner would turn device discovery into a crash path.

V4 therefore rejects open-ended scanning and exposes only a fixed allowlist for known QEMU `virt` transport windows.

## Why virtio magic detection is not a driver

Finding the virtio-mmio magic value would prove only that a virtio-mmio transport appears present at that address. It would not prove that ZIGN01D can negotiate features, allocate queues, publish descriptors, handle interrupts, or exchange packets/blocks. Magic detection is transport identification, not device operation.

## Why virtio-net and virtio-blk remain missing

`virtio-mmio-net0` and `virtio-mmio-blk0` remain missing because no virtio device-specific driver has been implemented. V4 deliberately does not add fake packet paths, fake block reads, fake filesystems, or fake userspace.

## V5 recommendation

V5 should prove recoverable guarded MMIO fault handling before enabling live probing by default. A good next milestone is:

1. Add a minimal trap recovery frame for intentionally guarded loads.
2. Prove that a faulting guarded load resumes at the next instruction.
3. Keep the fixed QEMU `virt` allowlist.
4. Only then allow the `mmio` command to perform live reads and classify fixed windows as `present`, `absent`, or `faulted`.
5. Continue to defer virtio feature negotiation and queue setup until a later virtio transport milestone.
