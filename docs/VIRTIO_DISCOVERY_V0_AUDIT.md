# ZIGN01D VIRTIO DISCOVERY V0 Audit

## Files added

- `kernel/virtio/discovery.zig`
- `smoke/smoke-virtio-discovery-v0.sh`
- `docs/MILESTONE_VIRTIO_DISCOVERY_V0_USER_GUIDE.md`
- `docs/VIRTIO_DISCOVERY_V0_SPEC.md`
- `docs/VIRTIO_DISCOVERY_V0_AUDIT.md`

## Files changed

- `kernel/main.zig`
- `kernel/console/shell.zig`
- `kernel/board/board.zig`
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

- `virtio`
- `virtio summary`
- `virtio slots`
- `virtio-summary`
- `virtio-slots`

## Smoke tests added

- `smoke/smoke-virtio-discovery-v0.sh`

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
./smoke/smoke-docs.sh
./smoke/smoke-all.sh
./smoke/smoke-stability.sh
```

## Exact capability proven

The new smoke test proves the kernel boots, reaches the shell, emits `VIRTIO000`, lists the virtio commands, exposes virtio status fields, reports board-device and MMIO relationships, and prints all eight computed slot addresses from the BOARD V0 base, stride, and count.

## Intentionally missing features

- Live MMIO probing
- Virtio magic reads
- Driver negotiation
- Queue setup
- Interrupt setup
- Virtio-block
- Virtio-net
- Heap allocation
- Paging
- Filesystem
- Userspace

## Fake-success risks and how the smoke test blocks them

The smoke test fails when the slot table is absent, when any of the eight expected addresses is missing, when the count is wrong, or when output claims implemented live probing, magic reads, driver negotiation, queue setup, interrupt setup, virtio-block, virtio-net, bound drivers, active devices, negotiation, or real hardware support.

## Next recommended milestone

HEAP V0: add a simple kernel allocator with visible allocation stats and deterministic shell-testable allocation commands.
