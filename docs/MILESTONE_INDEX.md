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

## HV0 Hypervisor Status Scaffold

- **Purpose:** Create the first honest visible boundary between the current kernel and the future hypervisor track.
- **Status:** IMPLEMENTED only for status reporting. Guest execution and Linux are MISSING.
- **Key commands added:** `hv`, `hv status`, plus flat alias `hv-status`.
- **Smoke test file:** `smoke/smoke-hv-status-v0.sh`.
- **Docs:** `docs/hypervisor/HYPERVISOR_BRANCH_CHARTER.md`, `docs/hypervisor/LINUX_GUEST_FAST_PATH.md`, `docs/hypervisor/HV_MILESTONE_LADDER.md`, `docs/hypervisor/RUST_ON_ZIGN01D_PLAN.md`, `docs/hypervisor/HV0_STATUS_AUDIT.md`.
- **Intentionally missing features:** Linux guest support, guest execution, guest memory, guest entry, guest trap return, second-stage translation, virtual timer, virtual console, SBI layer, and virtio for Linux.
- **Next dependency:** HV1: hypervisor capability detection and VM/vCPU data model design.

## HV1 Capability Detection

- **Purpose:** Add a safe hypervisor capability status surface that reports capability detection as implemented while keeping the current RISC-V H-extension status honest.
- **Status:** IMPLEMENTED for capability reporting only; current H-extension result is `unknown reason=no-safe-detection-yet`.
- **Key commands added:** `hv capability`, plus flat alias `hv-capability`.
- **Smoke test file:** `smoke/smoke-hv-capability-v0.sh`.
- **Docs:** `docs/hypervisor/HV1_CAPABILITY_DETECTION.md`, `docs/hypervisor/HV1_commands.md`.
- **Intentionally missing features:** H-extension presence proof, Linux guest support, guest execution, guest memory, guest entry, guest trap return, second-stage translation, virtual console, SBI layer, and virtio for Linux.
- **Next dependency:** HV2: real VM/vCPU data model objects and inspection, still with no guest execution or Linux support claim.

## HV2 VM/vCPU Data Model

- **Purpose:** Add real initialized VM and vCPU objects that are inspectable from the shell and proven by smoke tests.
- **Status:** IMPLEMENTED for VM/vCPU data-model objects only; guest execution and Linux remain not supported.
- **Key commands added:** `hv vm`, `hv vcpu`, `hv inspect`, `hv-objects`, plus flat aliases `hv-vm` and `hv-vcpu`.
- **Smoke test file:** `smoke/smoke-hv-vm-vcpu-v0.sh`.
- **Docs:** `docs/hypervisor/HV2_VM_VCPU_MODEL.md`.
- **Intentionally missing features:** guest memory object, guest execution, Linux guest support, H-extension presence proof, guest entry, guest trap return, second-stage translation, virtual console, SBI layer, and virtio for Linux.
- **Next dependency:** HV3: vCPU lifecycle state management.



## HV3 vCPU Lifecycle

- **Purpose:** Add real typed lifecycle state management for the boot vCPU after the HV2 VM/vCPU object model.
- **Status:** IMPLEMENTED only when `smoke/smoke-hv-vcpu-lifecycle-v0.sh` passes; this is lifecycle bookkeeping, not guest execution.
- **Key commands added:** `hv vcpu lifecycle`, `hv-vcpu-lifecycle`, `hv vcpu init`, `hv-vcpu-init`, `hv vcpu prepare`, `hv-vcpu-prepare`, `hv vcpu halt`, `hv-vcpu-halt`, `hv vcpu reset`, and `hv-vcpu-reset`.
- **Smoke test file:** `smoke/smoke-hv-vcpu-lifecycle-v0.sh`.
- **Transcript:** `smoke/transcripts/latest-hv-vcpu-lifecycle-v0.txt`.
- **Intentionally missing features:** guest memory object, guest execution, Linux guest support, H-extension presence proof, guest entry, guest trap return, second-stage translation, virtual console, SBI layer, and virtio for Linux.
- **Next dependency:** HV4 guest memory object.

## HV4 Guest Memory Object

- **Purpose:** Add real guest-memory ownership and inspection metadata for VM 0 without attempting guest execution.
- **Actual capability proven:** `GuestMemory` owns PMM pages while configured, tracks owner VM id, state, base, page count, byte size, allocation/free/reset/rejection counters, rejects out-of-bounds metadata checks, rejects double-free, and rejects oversized requests.
- **Backing:** `pmm-bitmap-v0`.
- **Key commands added:** `hv guest-memory`, `hv guest memory`, `hv-guest-memory`, `hv guest-memory alloc`, `hv guest-memory free`, `hv guest-memory reset`, `hv guest-memory bounds-test`, `hv guest-memory double-free-test`, `hv guest-memory overflow-test`.
- **Smoke test file:** `smoke/smoke-hv-guest-memory-v0.sh`.
- **Transcript:** `smoke/transcripts/latest-hv-guest-memory-v0.txt`.
- **Intentionally missing features:** guest execution, Linux guest support, H-extension presence proof, guest entry, guest trap return, second-stage translation, guest payload loading, virtual console, SBI layer, and virtio for Linux.
- **Next dependency:** HV5 guest address space metadata, still requiring separate smoke-proven loader and guest-entry milestones before any execution claim.

## HV5 Guest Address Space

- **Purpose:** Add real guest physical address metadata and lookup behavior backed by the HV4 PMM-owned guest pages.
- **Actual capability proven:** `GuestAddressSpace` tracks VM ownership, region count, page size, guest base, guest size, host base, translated page count, lookup counters, rejection counters, and last error. GPA `0x0` resolves to the first configured guest page; GPA `0x1000` resolves to the second configured guest page; out-of-range and misaligned page lookups are rejected.
- **Backing:** HV4 `pmm-bitmap-v0` guest memory pages; metadata-only translation.
- **Key commands added:** `hv address-space`, `hv-address-space`, `hv address-space create`, `hv address-space reset`, `hv address-space lookup-zero`, `hv address-space lookup-page`, `hv address-space bounds-test`, `hv address-space alignment-test`.
- **Smoke test file:** `smoke/smoke-hv-address-space-v0.sh`.
- **Transcript:** `smoke/transcripts/latest-hv-address-space-v0.txt`.
- **Intentionally missing features:** guest execution, Linux guest support, H-extension presence proof, guest entry, guest trap return, second-stage translation, guest payload loading, virtual console, SBI layer, and virtio for Linux.
- **Next dependency:** HV6 guest image loader research without claiming guest entry or Linux boot.

## HV6 Guest Image Loader

- **Purpose:** Load a tiny static flat guest payload into HV4 guest memory using HV5 guest physical address-space metadata, then verify it by reading the bytes back.
- **Actual capability proven:** `GuestImage` tracks owner VM id, state, `tiny-flat-v0` format, GPA load base, GPA entry point metadata, image size, loaded byte count, deterministic checksum, load/verify/failure/bounds counters, and last error. `hv guest-image load-tiny` writes real payload bytes to GPA `0x0`; `hv guest-image verify` reads them back and checks byte count and checksum; `hv guest-image bounds-test` rejects an oversized metadata-checked load span.
- **Key commands added:** `hv guest-image`, `hv-image`, `hv guest-image load-tiny`, `hv guest-image verify`, `hv guest-image reset`, `hv guest-image bounds-test`.
- **Smoke test file:** `smoke/smoke-hv-guest-image-v0.sh`.
- **Transcript:** `smoke/transcripts/latest-hv-guest-image-v0.txt`.
- **Intentionally missing features:** guest execution, Linux guest support, H-extension presence proof, guest entry, guest trap return, second-stage translation, ELF loading, Linux image loading, virtual console, SBI layer, and virtio for Linux.
- **Next dependency:** HV7 guest-entry preparation metadata, still without claiming guest execution, Linux boot, or second-stage translation until separately implemented and smoke-proven.


## HV7 Guest Entry Preparation

- **Purpose:** Prepare guest-entry metadata for a future guest entry attempt without executing the guest.
- **Actual capability proven:** `GuestEntry` tracks VM/vCPU ownership, state, PC from the HV6 loaded image entry point, SP derived within configured guest memory, stack bounds metadata, counters, last error, and a concrete `GuestRegisterFrame` attached to VM 0 / vCPU 0.
- **Key commands added:** `hv guest-entry`, `hv-entry`, `hv guest-entry prepare`, `hv guest-entry reset`, `hv guest-entry bounds-test`, `hv guest-entry require-image-test`.
- **Smoke test file:** `smoke/smoke-hv-guest-entry-v0.sh`.
- **Transcript:** `smoke/transcripts/latest-hv-guest-entry-v0.txt`.
- **Intentionally missing features:** guest execution, Linux guest support, H-extension presence proof, guest trap return, second-stage translation, Linux image loading, SBI mediation, virtual devices, and virtio for Linux.
- **Next dependency:** HV8 guest trap/exit metadata and classification, with no Linux support claim until separately implemented and smoke-proven.

## HV8 Guest Trap / Exit Metadata

- **Purpose:** Define and prove a real guest trap/exit metadata subsystem before any guest execution attempt.
- **Actual capability proven:** `GuestExit` tracks VM/vCPU ownership, no-exit vs recorded state, last exit kind/reason, last frame PC/SP/cause/trap-value/instruction-bits, record/reset/failure counters, kind-specific counters, and last error. Record commands require an HV7 prepared guest-entry frame and copy its PC/SP into the exit frame.
- **Key commands added:** `hv guest-exit`, `hv-exit`, `hv guest-exit record-instruction`, `hv guest-exit record-memory-fault`, `hv guest-exit record-timer`, `hv guest-exit record-halt`, `hv guest-exit reset`, `hv guest-exit require-entry-test`.
- **Smoke test file:** `smoke/smoke-hv-guest-exit-v0.sh`.
- **Transcript:** `smoke/transcripts/latest-hv-guest-exit-v0.txt`.
- **Intentionally missing features:** guest execution, Linux guest support, H-extension presence proof, second-stage translation, Linux image loading, SBI mediation, virtual devices, and virtio for Linux.
- **Next dependency:** HV9 controlled guest-entry attempt research, still without claiming Linux boot or second-stage translation until separately implemented and smoke-proven.

## HV9 Controlled Guest-Entry Attempt Research

- **Purpose:** Add the final no-execute safety gate before any later milestone may attempt guest execution.
- **Actual capability proven:** `GuestRunAttempt` tracks VM/vCPU ownership, idle/checked/blocked/armed-no-execute state, deterministic decisions, prerequisite booleans for HV4/HV5/HV6/HV7/HV8 readiness, explicit blockers for missing second-stage translation, unknown H-extension support, and disabled guest execution, a frame copied from HV7/HV8 metadata, run-count before/after snapshots, counters, and last error.
- **Key commands added:** `hv guest-run`, `hv-run`, `hv guest-run check`, `hv guest-run arm-no-execute`, `hv guest-run reset`, `hv guest-run require-entry-test`, `hv guest-run require-exit-test`.
- **Smoke test file:** `smoke/smoke-hv-guest-run-attempt-v0.sh`.
- **Transcript:** `smoke/transcripts/latest-hv-guest-run-attempt-v0.txt`.
- **Intentionally missing features:** guest execution, Linux guest support, H-extension presence proof, second-stage translation, Linux image loading, SBI mediation, virtual devices, and virtio for Linux.
- **Next dependency:** HV10 first hardware-gated guest execution research, still without claiming Linux boot until separately implemented and smoke-proven.

## HV10 Hardware-Gated Guest Execution Preparation

- **Purpose:** Create the first real guest execution preparation layer without executing guest instructions.
- **Actual capability proven:** `GuestExecutionGate` tracks VM/vCPU ownership, cold/collecting/validated/blocked/armed-blocked state, prerequisite booleans for HV4/HV5/HV6/HV7/HV8/HV9 readiness, an execution-frame snapshot containing PC/SP/guest-memory/image/exit metadata, hardware-gate blockers for missing second-stage translation, unproven H-extension support, and disabled guest execution, plus status/validate/arm/blocker/reset/rejection/hardware-block counters.
- **Key commands added:** `hv exec`, `hv-exec`, `hv execution`, `hv exec-status`, `hv exec check`, `hv exec-check`, `hv exec arm`, `hv exec-arm`, `hv exec blockers`, `hv exec-blockers`, `hv exec reset`, `hv exec-reset`, `hv exec require-prereq-test`, `hv exec-require-prereq-test`.
- **Smoke test file:** `smoke/smoke-hv-guest-execution-v0.sh`.
- **Transcript:** `smoke/transcripts/latest-hv-guest-execution-v0.txt`.
- **Intentionally missing features:** guest instruction execution, Linux guest support, H-extension presence proof, second-stage translation, Linux image loading, SBI mediation, virtual devices, guest trap return, and virtio for Linux.
- **Next dependency:** HV11 continued hardware-gated guest execution research, still without claiming Linux boot, guest instruction execution, second-stage translation, or H-extension support until separately implemented and smoke-proven.

## HV11 — Second-stage translation metadata research

Status: implemented only when `./smoke/smoke-hv-second-stage-v0.sh` passes.

Evidence:

- Implementation: `kernel/hypervisor/second_stage.zig`
- Integration: `kernel/hypervisor/hv.zig`, `kernel/console/shell.zig`, `scripts/validate-hyperzig.sh`
- Smoke: `smoke/smoke-hv-second-stage-v0.sh`
- Transcript: `smoke/transcripts/latest-hv-second-stage-v0.txt`

Scope: metadata and validation only. HV11 does not activate second-stage translation, does not write `hgatp`, does not prove H-extension support, does not execute a guest, and does not support Linux guests.

Next milestone after HV11: HV12 real second-stage page-table activation research.

## HV12 — Second-stage software table builder

HV12 is the software-only page-table construction layer after HV11 metadata. It adds `kernel/hypervisor/stage2_table.zig`, derives one entry per HV11 metadata page, maps the current two-page guest region as GPA `0x0` and `0x1000`, preserves read/write permissions, denies execute permission, supports software walks and validation, and exposes rejection tests for bounds, alignment, and execute access.

HV12 does not activate second-stage translation, does not write `hgatp`, does not claim H-extension support, does not execute a guest, and does not support Linux guests. Evidence is `smoke/smoke-hv-stage2-table-v0.sh` with transcript `smoke/transcripts/latest-hv-stage2-table-v0.txt`.

Next milestone after HV12: HV13 Guest Boot Package Contract, still without Linux or guest-execution claims until proven.


## HV13 Guest Boot Package Contract

- **Purpose:** Add executable boot-contract infrastructure for future tiny Linux guest boot work without claiming Linux support.
- **Actual capability proven:** A `Guest Boot Package` object tracks VM ownership, guest-memory bounds, kernel-like HV6 tiny image range and load GPA, entry GPA, optional initrd range, optional DTB range, command line buffer, readiness state, deterministic blockers, numeric overlap checks, numeric bounds checks, reset behavior, and inspection/reporting.
- **Key commands added:** `hv bootpkg`, `hv-bootpkg`, `hv bootpkg status`, `hv bootpkg attach-kernel`, `hv bootpkg set-entry`, `hv bootpkg set-cmdline <text>`, `hv bootpkg attach-initrd`, `hv bootpkg attach-dtb`, `hv bootpkg validate`, `hv bootpkg blockers`, `hv bootpkg overlap-test`, `hv bootpkg bounds-test`, `hv bootpkg reset`.
- **Smoke test file:** `smoke/smoke-hv-boot-package-v0.sh`.
- **Transcript:** `smoke/transcripts/latest-hv-boot-package-v0.txt`.
- **Intentionally missing features:** Linux boot, Buildroot boot, Ubuntu boot, guest execution, active second-stage translation, `hgatp` writes, H-extension support claims, SBI mediation, and virtio for Linux.
- **Next dependency:** DTB/SBI/active guest-entry prerequisites for later Linux work, still without claiming Linux boot until separately implemented and smoke-proven.

## HV14 Guest DTB Contract / Device Tree Payload Foundation

- **Purpose:** Add executable structured DTB handoff contract machinery derived from the HV13 guest boot package, without attempting Linux boot or guest execution.
- **Actual capability proven:** `GuestDtbContract` tracks VM ownership, payload GPA/size, guest memory bounds, bootargs copied from HV13 command line metadata, memory node metadata, CPU node metadata, chosen node metadata, optional initrd start/end metadata, console path metadata, explicit missing/non-claim timer and interrupt-controller metadata, readiness, deterministic blockers, validation, bounds rejection, overlap rejection, and reset behavior.
- **Key commands added:** `hv dtb`, `hv-dtb`, `hv dtb status`, `hv dtb build`, `hv dtb validate`, `hv dtb blockers`, `hv dtb nodes`, `hv dtb bounds-test`, `hv dtb overlap-test`, `hv dtb reset`.
- **Smoke test file:** `smoke/smoke-hv-dtb-contract-v0.sh`.
- **Transcript:** `smoke/transcripts/latest-hv-dtb-contract-v0.txt`.
- **Intentionally missing features:** Linux guest support, Buildroot/Ubuntu boot, guest execution, active second-stage translation, `hgatp` writes, H-extension support claims, SBI, binary FDT encoding, virtual timer, virtual interrupt controller, and virtio for Linux.
- **Next dependency:** SBI foundation or controlled active guest-entry prerequisites, still without Linux support claims until separately implemented and smoke-proven.


## HV15 SBI Foundation

- **Purpose:** Add a real metadata-only SBI foundation for future guest/hypervisor request mediation.
- **Actual capability proven:** `SbiFoundation` tracks VM/vCPU ownership, the last SBI extension/function, six argument registers, return value, error code, request counters, validation counters, reset counters, rejection counters, and base/timer/legacy-console capability metadata.
- **Key commands added:** `hv sbi`, `hv-sbi`, `hv sbi status`, `hv sbi validate`, `hv sbi reset`, `hv sbi blockers`, `hv sbi base-test`, `hv sbi timer-test`, `hv sbi console-test`.
- **Smoke test file:** `smoke/smoke-hv-sbi-foundation-v0.sh`.
- **Transcript:** `smoke/transcripts/latest-hv-sbi-foundation-v0.txt`.
- **Intentionally missing features:** Linux guest support, guest execution, H-extension proof, hgatp writes, active second-stage translation, and actual SBI base/timer/console service implementation.
- **Next dependency:** later virtual timer/SBI mediation prerequisites before Linux guest boot can be attempted honestly.


## HV16 Virtual Timer / SBI Timer Mediation Prerequisites

- **Purpose:** Add executable virtual timer metadata connected to the HV15 SBI foundation so future SBI timer calls can be mediated honestly.
- **Actual capability proven:** The virtual timer tracks owner VM/vCPU, empty/armed/expired state, host tick snapshot, guest compare value, pending interrupt metadata, valid/rejected/query/expiration counters, last SBI timer request metadata, validation result, deterministic blockers, and reset behavior. Pending state is computed from numeric tick/compare logic.
- **Key commands added:** `hv timer`, `hv-timer`, `hv timer status`, `hv timer arm`, `hv timer validate`, `hv timer blockers`, `hv timer pending-test`, `hv timer sbi-set-test`, `hv timer invalid-test`, `hv timer reset`.
- **Smoke test file:** `smoke/smoke-hv-virtual-timer-v0.sh`.
- **Transcript:** `smoke/transcripts/latest-hv-virtual-timer-v0.txt`.
- **Intentionally missing features:** Linux guest support, guest execution, active second-stage translation, `hgatp` writes, real timer interrupt injection, H-extension support claims, and full SBI service implementation.
- **Next dependency:** SBI console mediation, binary FDT, or controlled active guest-entry prerequisites.

## HV17 Binary FDT / Device Tree Blob Encoder Foundation

- **Purpose:** turn the HV14 DTB contract into an executable binary Flattened Device Tree encoder foundation for future Linux handoff work.
- **Actual capability proven:** the kernel builds a byte-backed FDT-shaped buffer with header, reservation block, structure block, strings block, BEGIN_NODE/PROP/END_NODE/END tokens, copied bootargs, guest-memory metadata, CPU metadata, chosen-node metadata, initrd metadata when present, computed offsets/sizes, counters, validation blockers, reset behavior, and checksum proof.
- **Commands:** `hv fdt`, `hv-fdt`, `hv fdt status`, `hv fdt build`, `hv fdt validate`, `hv fdt header`, `hv fdt nodes`, `hv fdt strings`, `hv fdt checksum`, `hv fdt bounds-test`, `hv fdt missing-contract-test`, `hv fdt reset`.
- **Smoke test:** `smoke/smoke-hv-binary-fdt-v0.sh`.
- **Intentionally missing features:** Linux guest support, guest execution, active hardware second-stage translation, `hgatp` writes, H-extension support claim, full SBI services, timer interrupt injection, Buildroot boot, Ubuntu boot, and proof that Linux accepts the FDT.
- **Next dependency:** SBI console mediation, controlled active guest-entry prerequisites, or Linux image handoff validation without claiming Linux support.

## HV18 Linux Handoff Package Validation Foundation

- **Purpose:** Assemble a Linux-shaped software handoff package from smoke-proven guest-image, boot-package, DTB contract, binary FDT, initrd, bootargs, VM/vCPU ownership, guest-entry, SBI/timer, software stage2 metadata, and guest-memory bounds.
- **Commands:** `hv handoff`, `hv-handoff`, `hv handoff status`, `hv handoff prepare`, `hv handoff validate`, `hv handoff blockers`, `hv handoff ranges`, `hv handoff summary`, `hv handoff overlap-test`, `hv handoff bounds-test`, `hv handoff missing-fdt-test`, `hv handoff missing-bootpkg-test`, `hv handoff reset`.
- **Smoke test:** `smoke/smoke-hv-linux-handoff-v0.sh`.
- **Intentionally missing features:** Linux guest support, Linux boot, guest execution, active hardware second-stage translation, `hgatp` writes, H-extension support claim, full SBI services, timer interrupt injection, Buildroot boot, Ubuntu boot, and proof that Linux accepts the FDT.
- **Next dependency:** SBI console mediation, controlled active guest-entry prerequisites, or first guest-instruction infrastructure.


## HV19 SBI Console Mediation Foundation

- **Purpose:** Add a real, byte-backed SBI console mediation subsystem connected to the HV15 SBI foundation, so future guest console SBI calls can be modeled, validated, buffered, inspected, rejected, and reset without claiming guest execution.
- **Commands:** `hv console`, `hv-console`, `hv console status`, `hv console putchar-test`, `hv console putstring-test`, `hv console getchar-test`, `hv console invalid-test`, `hv console overflow-test`, `hv console validate`, `hv console blockers`, `hv console buffer`, `hv console reset`.
- **Smoke test:** `smoke/smoke-hv-sbi-console-v0.sh`.
- **Transcript:** `smoke/transcripts/latest-hv-sbi-console-v0.txt`, generated by the smoke test from executed QEMU shell commands.
- **Intentionally missing features:** Linux guest support, Linux boot, guest execution, active hardware second-stage translation, `hgatp` writes, H-extension support claim, full SBI services, timer interrupt injection, Buildroot boot, Ubuntu boot, proof that Linux accepts the FDT, and proof that `printk` works.
- **Next dependency:** controlled active guest-entry prerequisites, SBI dispatch integration, or first guest-instruction infrastructure.


## HV20 SBI Dispatch Integration Foundation

- **Purpose:** Route structured modeled SBI request metadata into existing HV15 SBI, HV16 virtual timer, and HV19 SBI console mediation foundations without claiming Linux support or guest execution.
- **Actual capability proven:** the dispatcher records owner VM/vCPU IDs, argument registers, extension/function IDs, dispatch target, result, SBI return/error fields, validation/rejection counters, per-target counters, reset count, and deterministic blocker state. Base requests mutate HV15 SBI state, timer requests mutate HV16 timer state/counters, console putchar/getchar requests mutate HV19 console mediation state, and unknown/unsupported requests are rejected.
- **Commands:** `hv sbi-dispatch`, `hv-dispatch`, `hv sbi-dispatch status`, `hv sbi-dispatch base-test`, `hv sbi-dispatch timer-test`, `hv sbi-dispatch console-putchar-test`, `hv sbi-dispatch console-getchar-test`, `hv sbi-dispatch unknown-test`, `hv sbi-dispatch unsupported-function-test`, `hv sbi-dispatch validate`, `hv sbi-dispatch blockers`, and `hv sbi-dispatch reset`.
- **Smoke test:** `smoke/smoke-hv-sbi-dispatch-v0.sh`.
- **Transcript:** `smoke/transcripts/latest-hv-sbi-dispatch-v0.txt` generated by the smoke test.
- **Intentionally missing features:** Linux guest support, Linux boot, guest execution, active second-stage translation, `hgatp` writes, H-extension support claim, full SBI services, real timer interrupt injection, Buildroot/Ubuntu/Alpine boot, proof that Linux accepts the FDT, and printk support.
- **Next dependency:** controlled guest-entry preconditions, trap-return preparation, or first guest instruction infrastructure.


## HV21 Guest Context Switch Preparation Foundation

- **Capability:** Constructs, validates, inspects, rejects, and resets a software guest context frame derived from HV7 guest-entry metadata, HV18 Linux-shaped handoff metadata, HV11/HV12 stage2 metadata/table readiness, and HV20 SBI dispatch readiness.
- **Non-claims:** No Linux guest support, no Linux boot, no guest execution, no guest mode entry, no trap return, no active second-stage translation, no `hgatp` write, and no printk proof.
- **Commands:** `hv context`, `hv-context`, `hv context status`, `hv context prepare`, `hv context validate`, `hv context blockers`, `hv context registers`, `hv context ranges`, `hv context require-handoff-test`, `hv context require-fdt-test`, `hv context bounds-test`, and `hv context reset`.
- **Smoke test:** `smoke/smoke-hv-guest-context-v0.sh`.
- **Transcript:** `smoke/transcripts/latest-hv-guest-context-v0.txt` generated by the smoke test from executed QEMU shell commands.

## HV22 Guarded Trap-Return Preparation Foundation

- **Purpose:** Build and validate a software-only guarded trap-return plan from the HV21 guest context, execution-preparation gates, run-attempt gate, stage2 metadata/table readiness, and SBI dispatch readiness.
- **Commands:** `hv trap-plan`, `hv-trap-plan`, `hv trap-plan status`, `hv trap-plan prepare`, `hv trap-plan validate`, `hv trap-plan blockers`, `hv trap-plan registers`, `hv trap-plan gates`, `hv trap-plan attempt`, `hv trap-plan require-context-test`, `hv trap-plan pc-bounds-test`, `hv trap-plan sp-bounds-test`, `hv trap-plan fdt-bounds-test`, `hv trap-plan active-stage2-test`, and `hv trap-plan reset`.
- **Smoke test:** `smoke/smoke-hv-trap-plan-v0.sh`.
- **Transcript:** `smoke/transcripts/latest-hv-trap-plan-v0.txt`, generated by the smoke test.
- **Intentionally missing features:** Linux guest support, Linux boot, guest execution, guest mode entry, first guest instruction execution, real trap return, active second-stage translation, `hgatp` writes, H-extension support claim, full SBI services, timer interrupt injection, distro boot, and printk proof.
- **Next dependency:** active stage2 activation prerequisites, guarded first-instruction infrastructure, or real trap-entry/trap-return assembly preparation while preserving the non-claims.


## HV23 Guest Entry Assembly Preparation Foundation

- **Purpose:** Build a validated software-only entry-stub preparation object from the HV22 guarded trap-return plan before any future real guest-entry assembly path.
- **Key commands added:** `hv entry-stub`, `hv-entry-stub`, `hv entry-stub status`, `prepare`, `validate`, `blockers`, `registers`, `gates`, `descriptor`, `checksum`, `attempt`, `require-plan-test`, `pc-bounds-test`, `sp-bounds-test`, `fdt-bounds-test`, `active-stage2-test`, and `reset`.
- **Smoke test file:** `smoke/smoke-hv-entry-stub-v0.sh`.
- **Intentionally missing features:** Linux boot, Linux guest support, guest execution, guest mode entry, first guest instruction execution, trap return execution, active hardware second-stage translation, `hgatp` writes, H-extension support claim, full SBI services, real timer interrupt injection, distro boot, and printk proof.
- **Next dependency:** active stage2 activation prerequisites, guarded first-instruction infrastructure, or real trap-entry/trap-return assembly preparation with all non-claims intact.
