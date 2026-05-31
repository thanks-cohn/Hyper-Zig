# MEMORY V0 User Guide

MEMORY V0 makes ZIGN01D's fixed QEMU memory assumptions visible to a learner. The milestone adds a memory command surface and smoke proof, but it deliberately does not add allocation power.

## What this milestone adds

- A MEMORY V0 boot marker: `MEMORY000`.
- Fixed QEMU `virt` RAM facts: `ram_base=0x80000000`, `ram_size_bytes=134217728`, and `ram_size_mib=128`.
- Linker-symbol kernel bounds through `kernel-bounds`.
- Shell commands: `memory`, `memmap`, and `kernel-bounds`.
- Status fields that make heap, allocator, paging, and userspace memory absence explicit.
- A dedicated smoke test: `smoke/smoke-memory-v0.sh`.

## What this milestone does not add

- Heap allocation.
- A kernel allocator API.
- Physical page allocation.
- Virtual memory.
- Paging.
- Userspace memory or process isolation.
- Device-tree memory discovery.
- Runtime RAM probing.

## Build command

```sh
./scripts/build.sh
```

## Run command

```sh
./scripts/run-qemu.sh
```

## Shell commands added

- `memory`
- `memmap`
- `kernel-bounds`

Existing commands, including `help`, `status`, and `mem`, remain available.

## Command examples

```text
zign01d> help
zign01d> status
zign01d> memory
zign01d> memmap
zign01d> kernel-bounds
```

Expected `memory` facts include:

```text
memory: interface=present
memory: model=qemu-virt-fixed
memory: ram_base=0x80000000
memory: ram_size_bytes=134217728
memory: ram_size_mib=128
memory: heap=implemented-v0
memory: allocator=kernel-bump-reset-v0
memory: paging=not-implemented
memory: virtual_memory=not-implemented
memory: userspace_memory=not-implemented
```

Expected `memmap` facts include:

```text
memmap: region=ram base=0x80000000 size_bytes=134217728 size_mib=128 source=qemu-virt-assumption
memmap: live_discovery=not-implemented
memmap: device_tree_parse=not-implemented
```

Expected `kernel-bounds` facts include linker-symbol-derived addresses:

```text
kernel-bounds: start=0x...
kernel-bounds: end=0x...
kernel-bounds: size_bytes=...
```

## Smoke test command

```sh
./smoke/smoke-memory-v0.sh
```

## Expected passing output

```text
PASS ZIGN01D MEMORY V0 smoke
```

## Manual verification checklist

Look for these strings in the serial transcript or smoke output:

- `MEMORY000`
- `memory_interface=present`
- `memory_model=qemu-virt-fixed`
- `ram_base=0x80000000`
- `ram_size_mib=128`
- `heap=implemented-v0`
- `allocator=kernel-bump-reset-v0`
- `paging=not-implemented`
- `memmap: region=ram`
- `source=qemu-virt-assumption`

## Files added

- `kernel/memory/memory.zig`
- `docs/MILESTONE_MEMORY_V0_USER_GUIDE.md`
- `docs/MEMORY_V0_SPEC.md`
- `docs/MEMORY_V0_AUDIT.md`
- `smoke/smoke-memory-v0.sh`
- `ROADMAP.md`

## Files changed

- `kernel/memory/pmm.zig`
- `kernel/console/shell.zig`
- `smoke/smoke-all.sh`
- `smoke/smoke-docs.sh`
- `scripts/doctor.sh`
- `docs/COMMAND_REFERENCE.md`
- `docs/MILESTONE_INDEX.md`
- `docs/README.md`
- `README.md`

## Next milestone

HEAP V0 now adds constrained allocation power after BOARD V0 and VIRTIO DISCOVERY V0. The next recommended milestone is **PMM V0** for physical page tracking.
