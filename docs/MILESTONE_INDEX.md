# ZIGN01D Milestone Index

This index records the current milestone ladder and intentionally missing features. It does not claim production readiness or real hardware support.

## V0 bootable kernel

- **Purpose:** Prove the kernel boots on RISC-V under QEMU and reaches serial output/shell foundation.
- **Key commands added:** `mem`, `reboot`, `shutdown` and early shell basics where present.
- **Key boot markers:** Early ZIGN01D boot and shell markers checked by V0 smoke.
- **Smoke test file:** `smoke/smoke-v0.sh`.
- **Docs if present:** `docs/V0_PROOF.md`, `docs/v0-status.md`, `docs/boot-process.md`, `docs/smoke-test.md`.
- **Intentionally missing features:** filesystem, networking, modem, SMS, calls, GUI, userspace isolation, real hardware support.
- **Next dependency:** diagnostic commands and stable proof markers.

## V1 diagnostic foundation

- **Purpose:** Add a diagnostic shell foundation with status, version, build, breadcrumbs, logs, tasks, devices, syscalls, net and phone placeholder reporting.
- **Key commands added:** `help`, `status`, `version`, `build`, `breadcrumbs`, `logs`, `tasks`, `devices`, `syscalls`, `net`, `phone`, `ping`, `call`, `sms`.
- **Key boot markers:** Shell-ready and structured diagnostic markers.
- **Smoke test file:** `smoke/smoke-v1.sh`.
- **Docs if present:** `docs/V1_PLAN.md`, `docs/V1_FOUNDATION_AUDIT.md`, `docs/LOGGING_AND_BREADCRUMBS.md`.
- **Intentionally missing features:** real packet path, phone service, syscall boundary, persistent log buffer.
- **Next dependency:** architecture/machine boundary clarity.

## V2 machine boundary

- **Purpose:** Document and expose safe machine/CPU status while avoiding unsafe CSR claims.
- **Key commands added:** `machine`, `cpu`.
- **Key boot markers:** Machine boundary markers and status lines checked by smoke.
- **Smoke test file:** `smoke/smoke-v2.sh`.
- **Docs if present:** `docs/V2_PLAN.md`, `docs/V2_MACHINE_BOUNDARY_AUDIT.md`.
- **Intentionally missing features:** machine-mode CSR reads from supervisor mode, hardware feature discovery, board-generic boot.
- **Next dependency:** trap and panic boundary diagnostics.

## V3 timer and trap readiness

- **Purpose:** Add polling timer diagnostics and smoke-safe trap/panic reporting.
- **Key commands added:** `time`, `ticks`, `heartbeat`, `panic-test`, `trap-test`.
- **Key boot markers:** Timer stub, trap vector installed, V3 readiness shell banner.
- **Smoke test file:** `smoke/smoke-v3.sh`.
- **Docs if present:** `docs/V3_PLAN.md`, `docs/V3_TIMER_AND_TRAP_AUDIT.md`, `docs/TRAPS_AND_PANIC.md`.
- **Intentionally missing features:** timer interrupts, scheduler preemption, arbitrary trap recovery, live fault injection.
- **Next dependency:** guarded device/MMIO boundary.

## V4 guarded MMIO probe foundation

- **Purpose:** Add a guarded MMIO probe scaffold with a fixed QEMU virt allowlist and disabled live reads.
- **Key commands added:** `mmio`.
- **Key boot markers:** V4 guarded MMIO shell banner and device registry warnings.
- **Smoke test file:** `smoke/smoke-v4.sh`.
- **Docs if present:** `docs/V4_PLAN.md`, `docs/V4_GUARDED_MMIO_AUDIT.md`.
- **Intentionally missing features:** live absent-MMIO recovery, virtio negotiation, queue setup, interrupt setup, real block/network drivers.
- **Next dependency:** communication scaffold and/or safer host capability boundary.

## COMM V0 communication scaffold

- **Purpose:** Add communication status commands that make internet/SMS/modem/call absence explicit.
- **Key commands added:** `comm`, `bridge status`, `net status`, `net get`, `sms inbox`, `sms send`, `sms wait`, `modem status`.
- **Key boot markers:** `COMM000` communication scaffold marker.
- **Smoke test file:** `smoke/smoke-comm-v0.sh`.
- **Docs if present:** `docs/COMM_V0_PLAN.md`, `docs/COMM_V0_AUDIT.md`, `docs/COMM_BRIDGE_ROADMAP.md`.
- **Intentionally missing features:** host bridge transport, internet request path, SMS send/receive, attached modem, calls, Wi-Fi calling.
- **Next dependency:** host capability bus scaffold. Current repository also contains ZBUS scaffold files and smoke; see existing ZBUS docs where present.

## Recommended docs still useful for older milestones

- `docs/MILESTONE_V0_USER_GUIDE.md`: missing, recommended.
- `docs/MILESTONE_V1_USER_GUIDE.md`: missing, recommended.
- `docs/MILESTONE_V2_USER_GUIDE.md`: missing, recommended.
- `docs/MILESTONE_V3_USER_GUIDE.md`: missing, recommended.
- `docs/MILESTONE_V4_USER_GUIDE.md`: missing, recommended.
- `docs/MILESTONE_COMM_V0_USER_GUIDE.md`: missing, recommended.

## ZBUS V0 host capability bus scaffold

- **Purpose:** Make future host-provided capabilities visible while proving that no transport or providers are connected.
- **Key commands added:** `zbus`, `zbus status`, `zbus ping`, `zbus providers`.
- **Key boot marker:** `ZBUS000`.
- **Smoke test file:** `smoke/smoke-zbus-v0.sh`.
- **Docs if present:** `docs/MILESTONE_ZBUS_V0_USER_GUIDE.md`, `docs/ZBUS_V0_SPEC.md`, `docs/ZBUS_V0_AUDIT.md`, `docs/ZBUS_SECURITY_MODEL.md`.
- **Intentionally missing features:** host transport, real internet, real SMS, real modem, calls, Wi-Fi calling, file providers.
- **Next dependency:** memory visibility and board assumptions.

## MEMORY V0 memory visibility scaffold

- **Purpose:** Let learners ask where QEMU RAM starts, how large the fixed RAM assumption is, where the kernel image starts/ends, and which memory powers are not implemented.
- **Key commands added:** `memory`, `memmap`, `kernel-bounds`.
- **Key boot marker:** `MEMORY000`.
- **Smoke test file:** `smoke/smoke-memory-v0.sh`.
- **Docs:** `docs/MILESTONE_MEMORY_V0_USER_GUIDE.md`, `docs/MEMORY_V0_SPEC.md`, `docs/MEMORY_V0_AUDIT.md`.
- **Intentionally missing features:** heap allocation, allocator, paging, virtual memory, userspace memory, live RAM discovery, device-tree memory parsing.
- **Next dependency:** BOARD V0 now groups QEMU virt memory/device assumptions; VIRTIO DISCOVERY V0 should safely expose expected virtio-mmio slots next.

## BOARD V0

- **Purpose:** Collect the current QEMU RISC-V `virt` fixed assumptions into an explicit board profile layer before adding any discovery or drivers.
- **Commands:** `board`, `board profile`, `board devices`, plus flat aliases `board-profile` and `board-devices`.
- **Boot marker:** `[ZIGN01D][INFO][BOARD][BOARD000] board profile present; qemu-virt fixed assumptions active`.
- **Smoke test:** `smoke/smoke-board-v0.sh`.
- **Docs:** `docs/MILESTONE_BOARD_V0_USER_GUIDE.md`, `docs/BOARD_V0_SPEC.md`, `docs/BOARD_V0_AUDIT.md`.
- **Intentionally missing features:** real hardware support, device tree parsing, live board discovery, virtio drivers, PLIC driver, CLINT driver, heap allocation, paging, filesystem, userspace, real internet, real SMS, and real modem support.
- **Next dependency:** VIRTIO DISCOVERY V0 now computes the expected virtio-mmio slots from the BOARD V0 profile; HEAP V0 is the next dependency for later queue work.

## VIRTIO DISCOVERY V0

- **Purpose:** compute and expose the QEMU `virt` virtio-mmio slot table from the BOARD V0 profile without claiming live probing or drivers.
- **Actual capability proven:** the kernel computes exactly eight slot addresses from `virtio_mmio_base=0x10001000`, `virtio_mmio_stride=0x1000`, and `virtio_mmio_count=8`, then exposes them through shell output.
- **Commands:** `virtio`, `virtio summary`, `virtio slots`, plus flat aliases `virtio-summary` and `virtio-slots`.
- **Boot marker:** `[ZIGN01D][INFO][VIRTIO][VIRTIO000] virtio-mmio discovery table present; live probing not implemented`.
- **Smoke test:** `smoke/smoke-virtio-discovery-v0.sh`.
- **Docs:** `docs/MILESTONE_VIRTIO_DISCOVERY_V0_USER_GUIDE.md`, `docs/VIRTIO_DISCOVERY_V0_SPEC.md`, `docs/VIRTIO_DISCOVERY_V0_AUDIT.md`.
- **Intentionally missing features:** live MMIO probing, magic reads, driver negotiation, queue setup, interrupt setup, virtio-block, virtio-net, heap allocation, paging, filesystem, and userspace.
- **Next dependency:** HEAP V0 should provide constrained allocator support before later virtio queue work.


## HEAP V0

- **Purpose:** add a real but constrained kernel heap allocator before later driver, file, runtime, or userspace work depends on allocation.
- **Actual capability proven:** the kernel allocates 64 bytes from a fixed static heap region, tracks used/free/count stats, resets used bytes to zero, rejects overflow, preserves used bytes on failed overflow, and exposes these facts through shell-driven tests.
- **Commands:** `heap`, `heap stats`, `heap alloc-test`, `heap reset-test`, `heap overflow-test`, plus flat aliases `heap-stats`, `heap-alloc-test`, `heap-reset-test`, and `heap-overflow-test`.
- **Boot marker:** `[ZIGN01D][INFO][HEAP][HEAP000] kernel heap initialized; bump-reset allocator active`.
- **Smoke test:** `smoke/smoke-heap-v0.sh`.
- **Docs:** `docs/MILESTONE_HEAP_V0_USER_GUIDE.md`, `docs/HEAP_V0_SPEC.md`, `docs/HEAP_V0_AUDIT.md`.
- **Intentionally missing features:** paging, virtual memory, userspace memory, user-program malloc, filesystem, process isolation, individual block free, free lists, general-purpose allocator maturity, thread safety, SMP safety, and production safety.
- **Next dependency:** PMM V0 now adds physical page tracking over the known qemu-virt RAM range before larger memory consumers are introduced.

## PMM V0

- **Purpose:** Track physical page ownership over the known QEMU virt RAM range, reserve kernel-owned/unavailable pages honestly, and prove allocation/free/rejection behavior through shell commands.
- **Key commands added:** `pmm`, `pmm stats`, `pmm alloc-test`, `pmm free-test`, `pmm invalid-free-test`, `pmm double-free-test`, `pmm exhaustion-test`.
- **Key boot marker:** `PMM000`.
- **Smoke test file:** `smoke/smoke-pmm-v0.sh`.
- **Docs:** `docs/PMM_V0.md`.
- **Intentionally missing features:** virtual memory, paging, userspace memory, swap, NUMA, production PMM policy, DMA zones, SMP safety.
- **Next dependency:** Later paging, userspace, filesystems, fork, and program loading should build on PMM page ownership proof rather than hidden assumptions.
