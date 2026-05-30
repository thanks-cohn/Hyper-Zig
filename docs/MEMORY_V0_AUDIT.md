# MEMORY V0 Audit

## Files added

- `kernel/memory/memory.zig`
- `smoke/smoke-memory-v0.sh`
- `docs/MILESTONE_MEMORY_V0_USER_GUIDE.md`
- `docs/MEMORY_V0_SPEC.md`
- `docs/MEMORY_V0_AUDIT.md`
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

## Commands added

- `memory`
- `memmap`
- `kernel-bounds`

## Smoke tests added

- `smoke/smoke-memory-v0.sh`

The full smoke ladder now runs the MEMORY V0 smoke after ZBUS V0 when the ZBUS smoke exists.

## Proof commands

Run these before accepting MEMORY V0:

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
./smoke/smoke-all.sh
./smoke/smoke-stability.sh
./smoke/smoke-docs.sh
```

## Intentionally missing features

- Heap allocation.
- Kernel allocator.
- Physical page allocation.
- Virtual memory.
- Paging.
- Userspace memory.
- Device-tree memory parsing.
- Runtime RAM discovery.

## Risk notes

- RAM base and size are fixed QEMU virt assumptions, not detected facts.
- Kernel bounds depend on linker symbols from `boot/linker.ld`.
- The status surface must keep `not-implemented` wording until real features exist.
- Smoke transcripts are generated under the existing transcript/log locations and should not be tracked.

## Next recommended milestone

**BOARD V0** should add a board profile command, a QEMU virt board profile, grouped memory/device assumptions, BOARD V0 docs, and `smoke/smoke-board-v0.sh`.
