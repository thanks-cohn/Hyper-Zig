# ZIGN01D HEAP V0 User Guide

## What this milestone adds

HEAP V0 adds the first real kernel allocator organ to ZIGN01D: a fixed-size kernel heap, a deterministic bump-reset allocator, live heap statistics, shell commands, and a smoke proof that drives allocation, reset, and overflow rejection from the running kernel.

## The actual capability added

HEAP V0 adds a real kernel bump-reset allocator. The kernel can allocate from a fixed heap region, track heap stats, reset the heap, reject overflow, and expose deterministic allocator tests through the shell.

The heap is a static kernel region of `16384` bytes. Allocation bumps a used-byte cursor forward after validating size and power-of-two alignment. HEAP V0 intentionally supports reset of the whole heap, not individual free.

## What this milestone does not add

HEAP V0 does not add paging, virtual memory, userspace memory, user-program `malloc`, filesystem storage, process isolation, free lists, per-block free, thread safety, SMP safety, or a production general-purpose allocator.

## Build command

```sh
./scripts/build.sh
```

## Run command

```sh
qemu-system-riscv64 -machine virt -cpu rv64 -smp 1 -m 128M -nographic -monitor none -serial stdio -kernel zig-out/bin/zign01d-v0
```

## Shell commands added

- `heap`
- `heap stats`
- `heap alloc-test`
- `heap reset-test`
- `heap overflow-test`
- Flat aliases: `heap-stats`, `heap-alloc-test`, `heap-reset-test`, `heap-overflow-test`

## Command examples

```text
help
status
memory
memmap
heap
heap stats
heap alloc-test
heap reset-test
heap overflow-test
```

Example `heap` output includes:

```text
heap: interface=present
heap: kind=bump-reset
heap: total_bytes=16384
heap: used_bytes=0
heap: free_bytes=16384
heap: alloc_count=0
heap: reset_count=0
heap: overflow_count=0
heap: last_alloc_ok=no
heap: last_error=none
heap: free_individual_blocks=not-implemented
heap: thread_safe=not-implemented
heap: userspace_allocator=not-implemented
```

Example allocator proof output includes:

```text
heap-alloc-test: begin
heap_used_before=0
heap_alloc_size=64
heap_alloc_alignment=8
heap_alloc_ok=yes
heap_used_after_alloc=64
heap_alloc_count_after=1
heap_last_error=none
heap-alloc-test: result=pass
```

## Smoke test command

```sh
./smoke/smoke-heap-v0.sh
```

## Expected passing output

```text
PASS ZIGN01D HEAP V0 smoke
```

## Manual verification checklist

Confirm these strings in a boot transcript:

- `HEAP000`
- `heap_interface=present`
- `heap_kind=bump-reset`
- `heap_total_bytes=`
- `heap_used_before=0`
- `heap_alloc_size=64`
- `heap_alloc_ok=yes`
- `heap_used_after_alloc=64`
- `heap_reset=ok`
- `heap_used_after_reset=0`
- `heap_overflow_rejected=yes`
- `heap_last_error=out-of-memory`
- `free_individual_blocks=not-implemented`
- `userspace_allocator=not-implemented`
- `paging=not-implemented`

Also confirm the transcript does not claim production heap status, a general-purpose allocator, individual free, thread safety, userspace allocation, paging, virtual memory, or userspace memory.

## Files added

- `kernel/memory/heap.zig`
- `smoke/smoke-heap-v0.sh`
- `docs/MILESTONE_HEAP_V0_USER_GUIDE.md`
- `docs/HEAP_V0_SPEC.md`
- `docs/HEAP_V0_AUDIT.md`

## Files changed

- `kernel/memory/memory.zig`
- `kernel/console/shell.zig`
- `smoke/smoke-memory-v0.sh`
- `smoke/smoke-all.sh`
- `smoke/smoke-docs.sh`
- `scripts/doctor.sh`
- `docs/COMMAND_REFERENCE.md`
- `docs/MILESTONE_INDEX.md`
- `docs/README.md`
- `ROADMAP.md`
- `README.md`

## Next milestone

PMM V0 should add physical page tracking over the known qemu-virt RAM range, visible page stats, reserved kernel region accounting, and smoke tests proving page accounting behavior.
