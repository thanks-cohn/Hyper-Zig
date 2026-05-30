# BOARD V0 Audit

## Files added

- `kernel/board/board.zig`
- `docs/MILESTONE_BOARD_V0_USER_GUIDE.md`
- `docs/BOARD_V0_SPEC.md`
- `docs/BOARD_V0_AUDIT.md`
- `smoke/smoke-board-v0.sh`

## Files changed

- `kernel/main.zig`
- `kernel/console/shell.zig`
- `kernel/memory/memory.zig`
- `kernel/device/mmio_probe.zig`
- `smoke/smoke-all.sh`
- `smoke/smoke-docs.sh`
- `scripts/doctor.sh`
- `docs/COMMAND_REFERENCE.md`
- `docs/MILESTONE_INDEX.md`
- `docs/README.md`
- `ROADMAP.md`
- `README.md`

## Commands added

- `board`
- `board profile`
- `board devices`
- `board-profile`
- `board-devices`

## Smoke tests added

- `smoke/smoke-board-v0.sh`

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
./smoke/smoke-docs.sh
./smoke/smoke-all.sh
./smoke/smoke-stability.sh
```

## Intentionally missing features

- Real hardware support.
- Device tree parsing.
- Live board discovery.
- Live MMIO probing.
- Virtio drivers.
- PLIC driver.
- CLINT driver.
- Heap allocation, paging, filesystems, userspace, internet, SMS, and modem support.

## Risk notes

- BOARD V0 centralizes constants but remains fixed to QEMU `virt`; using a different machine can break assumptions.
- `present-assumed` means the board profile expects a device location; it is not runtime proof.
- MMIO live probing remains disabled because broad probing is unsafe without stronger trap recovery.

## Next recommended milestone

**VIRTIO DISCOVERY V0** should add safe, non-destructive visibility into expected virtio-mmio slots without claiming driver negotiation.
