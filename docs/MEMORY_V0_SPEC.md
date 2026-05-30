# MEMORY V0 Specification

## What MEMORY V0 is

MEMORY V0 is a visibility milestone. It names the current memory interface, exposes fixed QEMU `virt` RAM assumptions, reports linker-symbol kernel image bounds, and states clearly that allocation, paging, and userspace memory are not implemented.

## What MEMORY V0 is not

MEMORY V0 is not a heap, allocator, physical page manager, virtual memory manager, userspace isolation layer, device-tree parser, or live RAM discovery feature.

## QEMU virt memory assumptions

The smoke ladder runs QEMU with `-machine virt` and `-m 128M`. MEMORY V0 therefore reports an honest fixed model:

- `memory_model=qemu-virt-fixed`
- RAM base: `0x80000000`
- RAM size: `134217728` bytes
- RAM size: `128` MiB
- Source: `qemu-virt-assumption`

These values are assumptions from the controlled smoke target, not dynamically discovered facts.

## RAM base

The reported RAM base is `0x80000000`. This is the QEMU virt DRAM base used by the teaching target.

## RAM size

The reported RAM size is `128MiB`, or `134217728` bytes. The smoke tests launch QEMU with `-m 128M` so this is a controlled test assumption.

## Kernel bounds

`kernel-bounds` reports `__kernel_start` and `__kernel_end` from `boot/linker.ld`. The current linker script already defines those symbols around the kernel image and stack region. MEMORY V0 subtracts start from end to report `kernel_size_bytes`.

## Status fields

`status` includes:

- `memory_interface=present`
- `memory_model=qemu-virt-fixed`
- `ram_base=0x80000000`
- `ram_size_mib=128`
- `heap=not-implemented`
- `allocator=not-implemented`
- `paging=not-implemented`

## Command surface

MEMORY V0 adds:

- `memory` — summary of fixed model and unimplemented memory powers.
- `memmap` — fixed RAM region plus explicit absence of live discovery and device-tree parsing.
- `kernel-bounds` — linker-symbol image start, end, and size.

The existing `mem` command remains as a legacy physical-memory report.

## Limitations

- No runtime probing validates the 128MiB assumption.
- No device tree is parsed.
- No free-list, bitmap, or page allocator is created.
- No `sbrk`, `malloc`, or Zig allocator is exposed.
- No page tables are installed by this milestone.
- No userspace address spaces exist.

## Safety rules

- Do not claim dynamic RAM discovery until it is implemented and smoke-proven.
- Do not claim heap, allocator, paging, virtual memory, or userspace memory support.
- Preserve all existing shell commands and smoke tests.
- Keep MEMORY V0 output inspectable and deterministic.

## Why no heap yet

A heap needs allocation policy, ownership rules, failure behavior, and tests. Adding it before board assumptions are grouped would hide important teaching boundaries. MEMORY V0 intentionally stops at facts and absence markers.

## Why no paging yet

Paging requires page-table construction, address-space policy, trap behavior, and careful safety proof. MEMORY V0 does not turn on or modify paging because the milestone is about visibility, not power.

## Why honest fixed assumptions are acceptable now

The project is a proof-driven teaching kernel with a controlled QEMU target. Fixed assumptions are acceptable when they are labeled as assumptions, tested under the matching QEMU command, and not described as live discovery. BOARD V0 should later group these assumptions under a named board profile.
