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
- **Next dependency:** BOARD V0 should group QEMU virt memory/device assumptions before VIRTIO DISCOVERY V0 and HEAP V0.
