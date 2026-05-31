# HEAP V0 Spec

## What HEAP V0 is

HEAP V0 is the first real kernel heap capability in ZIGN01D. It is intentionally small, deterministic, and proof-oriented: a bump allocator over a fixed kernel-owned byte region with whole-heap reset.

## Exact capability it adds

HEAP V0 lets kernel code allocate bytes from a static heap region, track allocator statistics, reset the heap to empty, reject invalid or overflowing allocation requests, and expose allocator state through shell commands and status output.

## Fixed heap region

The heap source is `static-kernel-region`, implemented as a kernel static buffer. The HEAP V0 size is `16384` bytes. The `memmap` command reports this as `memmap: region=kernel-heap` and does not claim that the region was discovered from physical RAM firmware data.

## Allocator kind

The allocator kind is `bump-reset`. It maintains a single `used_bytes` cursor. Successful allocation advances the cursor. Reset returns the cursor to zero.

## Allocation behavior

`heap_alloc(size, alignment)` rejects `size == 0`, rejects invalid alignment, aligns the current bump address, checks that padding plus requested size fits in the fixed region, and returns failure without changing `used_bytes` when it does not fit.

A deterministic shell test allocates 64 bytes with 8-byte alignment after a reset and proves `heap_used_after_alloc=64`.

## Alignment behavior

HEAP V0 supports power-of-two alignment, including at least 8-byte alignment. Alignment `0` and non-power-of-two alignment are rejected with `heap_last_error=invalid-alignment`.

## Reset behavior

`heap_reset()` sets `heap_used_bytes` back to `0`, increments `heap_reset_count`, preserves the fixed total size, and leaves the allocator usable again. It is a whole-heap reset only.

## Overflow rejection behavior

If a requested allocation would exceed `heap_total_bytes`, allocation fails, `heap_overflow_count` increments, `heap_last_alloc_ok=no`, `heap_last_error=out-of-memory`, and `heap_used_bytes` remains unchanged.

## Stats fields

HEAP V0 exposes these stats:

- `heap_interface=present`
- `heap_kind=bump-reset`
- `heap_total_bytes=<number>`
- `heap_used_bytes=<number>`
- `heap_free_bytes=<number>`
- `heap_alloc_count=<number>`
- `heap_reset_count=<number>`
- `heap_overflow_count=<number>`
- `heap_last_alloc_size=<number>`
- `heap_last_alloc_ok=yes/no`
- `heap_last_error=none/out-of-memory/invalid-size/invalid-alignment`

## Command surface

Commands:

- `heap`
- `heap stats`
- `heap alloc-test`
- `heap reset-test`
- `heap overflow-test`

Flat aliases:

- `heap-stats`
- `heap-alloc-test`
- `heap-reset-test`
- `heap-overflow-test`

The test commands drive allocator state and verify their own conditions before printing `result=pass`.

## Status fields

`status` includes heap interface, kind, total, used, free, allocation count, reset count, overflow count, last allocation size, last allocation result, last error, `allocator=kernel-bump-reset-v0`, and the still-missing memory powers.

## Memory command integration

`memory` reports:

- `heap=implemented-v0`
- `allocator=kernel-bump-reset-v0`
- `heap_total_bytes=`
- `heap_used_bytes=`
- `heap_free_bytes=`
- `heap_reset_supported=yes`
- `heap_free_individual_blocks=not-implemented`
- `paging=not-implemented`

`memmap` reports the static heap region separately from the fixed QEMU RAM assumption.

## Limitations

HEAP V0 is not a general-purpose allocator. It has no individual free, no coalescing, no realloc, no per-allocation metadata, no thread-safety guarantee, no SMP-safety guarantee, no userspace allocator, no virtual memory, and no paging.

## Safety rules

HEAP V0 must not claim production maturity. Failed allocation must not advance `used_bytes`. Overflow must be visible in stats. Reset must restore `used_bytes` to zero. The smoke test must verify behavior through the shell rather than by static documentation strings.

## Why this comes before Lua/files/user programs

Lua interpreters, filesystems, user programs, and virtio queues need honest kernel allocation before they can be built responsibly. HEAP V0 establishes a constrained allocator proof before later milestones depend on memory allocation.
