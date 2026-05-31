# HEAP V0 Audit

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

## Commands added

- `heap`
- `heap stats`
- `heap alloc-test`
- `heap reset-test`
- `heap overflow-test`
- `heap-stats`
- `heap-alloc-test`
- `heap-reset-test`
- `heap-overflow-test`

## Smoke tests added

- `smoke/smoke-heap-v0.sh`

## Proof commands

```sh
./scripts/doctor.sh
./scripts/build.sh
./smoke/smoke-v0.sh
./smoke/smoke-v1.sh
./smoke/smoke-v2.sh
./smoke/smoke-v3.sh
./smoke/smoke-v4.sh
./smoke/smoke-comm-v0.sh
./smoke/smoke-zbus-v0.sh
./smoke/smoke-memory-v0.sh
./smoke/smoke-board-v0.sh
./smoke/smoke-virtio-discovery-v0.sh
./smoke/smoke-heap-v0.sh
./smoke/smoke-docs.sh
./smoke/smoke-all.sh
./smoke/smoke-stability.sh
```

## Exact capability proven

The smoke test boots the kernel, reaches the shell, confirms `HEAP000`, confirms heap commands are listed, confirms status/memory/memmap heap fields, allocates 64 bytes with 8-byte alignment, observes `heap_used_after_alloc=64`, resets heap used bytes to `0`, requests more bytes than the heap total, verifies overflow is rejected, and verifies used bytes remain `0` after failed overflow.

## Intentionally missing features

- Paging
- Virtual memory
- Userspace memory
- User-program `malloc`
- Filesystem
- Process isolation
- Individual block free
- Free lists
- General-purpose allocator maturity
- Thread safety
- SMP safety
- Production safety

## Fake-success risks and how smoke blocks them

- A static `heap=present` string is blocked because the smoke test runs shell allocator tests.
- A fake alloc test is blocked by checking `heap_used_before=0`, `heap_alloc_ok=yes`, `heap_used_after_alloc=64`, and `heap_alloc_count_after=1`.
- A fake reset test is blocked by checking `heap_reset=ok` and `heap_used_after_reset=0`.
- A fake overflow path is blocked by checking `heap_overflow_rejected=yes`, `heap_used_after_overflow=0`, and `heap_last_error=out-of-memory`.
- Fake maturity claims are blocked by rejecting production/general-purpose allocator, individual free, thread safety, userspace allocator, paging, virtual memory, and userspace memory claims.

## Next recommended milestone

PMM V0 should add physical page tracking over the known qemu-virt RAM range, visible page stats, reserved kernel region accounting, and smoke tests proving page accounting behavior.
