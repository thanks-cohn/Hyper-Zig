# ZIGN01D Hypervisor Master Plan

## 1. Executive summary

ZIGN01D is currently a Zig 0.14.x RISC-V teaching and research kernel. Its proven center of gravity is kernel bring-up, observable boot diagnostics, UART shell interaction, CSR visibility, board and memory reporting, heap and PMM V0 exercises, and transcript-backed smoke tests. It is not currently a guest-executing hypervisor.

`hypervisor-v0` is the intended branch-only hypervisor research track. It exists so ZIGN01D can move toward real hypervisor work without destabilizing `main`, without rewriting the teaching kernel out from under students, and without pretending that future capabilities already exist. The branch target is a serious RISC-V hypervisor research kernel written in original Zig 0.14.x code.

HV0 is status scaffold only. HV0 makes the boundary visible: it can print hypervisor research status and missing components, but it does not implement H-extension detection, VM objects, vCPU objects, guest memory ownership, guest entry, trap return, second-stage translation, virtual devices, Linux guest boot, a Linux shell, C compilation inside a guest, or Rust tooling inside a guest.

The long-term goal is to evolve this branch toward a real hypervisor in small, reviewable, proof-backed milestones. Each milestone must have source changes, documentation, command output, transcript markers, forbidden markers, and explicit exit criteria. The project must be honest about missing features at every step. A missing subsystem must be named as missing, not hidden behind aspirational wording.

Educationally, this branch can be used as a detailed laboratory for thinking deeply about a Zig RISC-V kernel and its path toward virtualization. Compared with the limited set of public Zig/RISC-V hypervisor options, especially Diosix as an important reference point, ZIGN01D should emphasize unusually explicit documentation of what works, why it works, what does not work yet, what proof was collected, and what claims are forbidden. The aim is not to copy Diosix; the aim is to provide a transparent, teachable, transcript-backed path from a small kernel toward hypervisor-grade architecture.

## 2. Toolchain law

- Zig 0.14.x is the only accepted language and toolchain target for this branch.
- Validation must use `./scripts/check-zig-version.sh` before build or smoke claims are accepted.
- Any future hypervisor code must compile under Zig 0.14.x.
- Do not introduce Zig 0.15.x, Zig 0.16.x, Zig 0.17.x, or later APIs, syntax, build-system assumptions, standard-library names, or language behavior.
- If validation cannot find an executable Zig 0.14.x compiler, validation is **BLOCKED**, not **PASS**.
- If a different Zig version is active, validation is **FAIL** unless the tool is replaced with Zig 0.14.x and the commands are rerun.
- A milestone cannot graduate on documentation alone; it must build and smoke under Zig 0.14.x.

Minimum validation sequence for every hypervisor milestone:

```sh
git branch --show-current
git status
./scripts/check-zig-version.sh
./scripts/build.sh
./smoke/<milestone-smoke-test>.sh
```

## 3. Current ZIGN01D baseline

### Present capabilities to preserve

The current repository baseline provides a small RISC-V kernel surface that the hypervisor branch must not regress:

- QEMU RISC-V `virt` machine boot path.
- UART serial console.
- Interactive shell command surface.
- CSR visibility through the existing `csr` command path.
- Board profile and board-device diagnostics.
- Heap V0 diagnostics and smoke tests.
- PMM V0 diagnostics and smoke tests.
- Existing smoke-test doctrine using QEMU transcripts and positive/negative markers.
- HV0 status command surface, if present, through `hv`, `hv status`, and `hv-status`.

### Current HV0 status markers

HV0 must print these markers exactly until a later milestone replaces a specific `MISSING` or `not-supported-yet` value with real proof:

```text
hv: branch=hypervisor-v0
hv: target=zig-0.14.x
hv: linux_guest=not-supported-yet
hv: rust_guest_toolchain=not-supported-yet
hv: guest_execution=not-supported-yet
hv: vm_object=MISSING
hv: vcpu_object=MISSING
hv: guest_memory=MISSING
hv: guest_entry=MISSING
hv: guest_trap_return=MISSING
hv: second_stage_translation=MISSING
hv: virtual_console=MISSING
hv: sbi_layer=MISSING
hv: virtio_for_linux=MISSING
```

### Current missing pieces

The following must remain explicitly missing until implemented and proven:

- H-extension detection.
- VM object.
- vCPU object.
- Guest memory object.
- Guest payload loader.
- Guest entry.
- Guest trap return.
- Second-stage translation.
- Virtual timer.
- Virtual console.
- SBI mediation.
- Linux image loading.
- Linux guest boot.
- Linux shell.
- C toolchain inside guest.
- Rust toolchain inside guest.

## 4. Diosix comparison

### Reference material inspected

This plan uses the local ZIGN01D documentation comparing ZIGN01D to Diosix and the public Diosix repository page at `https://github.com/diodesign/diosix` as reference material. The GitHub page describes Diosix as a type-1 bare-metal hypervisor written in Zig for 64-bit RISC-V systems, lists QEMU-based run instructions, and describes a Root VM flow. Some implementation details are visible from repository structure and existing local comparison notes; where a behavior is not directly proven from inspected material, this plan says so.

### What Diosix appears to provide

At a high level, Diosix appears to provide a serious RISC-V hypervisor direction with:

- A Zig and assembly RISC-V hypervisor codebase.
- Multiprocessor-oriented structure.
- A documented type-1 bare-metal hypervisor goal.
- A Root VM concept and build/run flow described by upstream documentation.
- Hypervisor-focused subsystems in areas such as boot, CPU state, traps, guest or virtual-core modeling, memory space management, SBI/interface handling, platform configuration, and tests, based on inspected local comparison material.

Do not treat this as a complete independent audit of Diosix. Exact runtime behavior, current guest matrix, and every supported device path are **unclear from inspected material** unless separately reproduced from Diosix itself.

### What ZIGN01D currently provides

ZIGN01D currently provides a Zig 0.14.x teaching/research kernel with QEMU boot, UART shell, CSR and board diagnostics, memory/heap/PMM proof surfaces, smoke tests, and an HV0 status scaffold. It provides a strong educational and proof-contract base, but not a real hypervisor yet.

### What ZIGN01D lacks

ZIGN01D lacks the minimum objects and execution machinery expected of a hypervisor: safe hypervisor capability detection, VM/vCPU objects, guest memory ownership, guest payload loading, guest entry, guest trap handling, second-stage translation, virtual timer/console paths, SBI mediation, Linux image and DTB loading, Linux boot proof, and guest toolchain proof.

### What ZIGN01D can learn from Diosix

ZIGN01D can learn the seriousness of direction: explicit guest abstractions, physical-core state, virtual-core state, memory-space ownership, trap routing, firmware/interface mediation, platform description, and repeatable build/run/test workflows. ZIGN01D should also learn that a hypervisor cannot be claimed through a shell banner; it needs real objects, real memory boundaries, real entry/trap behavior, and real transcripts.

### What ZIGN01D should intentionally do differently

ZIGN01D should remain Zig 0.14.x for this branch even if Diosix uses a newer Zig release. ZIGN01D should preserve its teaching-kernel style, small milestone ladder, smoke-test transcripts, forbidden-claim markers, and branch isolation from `main`. It should be more explicit than typical projects about what each milestone does **not** imply.

### Original implementation rule

Implementation must be original ZIGN01D Zig 0.14.x work. No Diosix code may be copied, translated, mechanically ported, or treated as a drop-in design. Diosix may inform high-level questions and seriousness of direction only.

## 5. Master milestone ladder

Every milestone from HV0 through HV13 must carry source proof, documentation proof, command output, a smoke transcript, required positive markers, required negative markers, and explicit non-claims. A milestone is not complete when code merely exists; it is complete only when the smoke test captures the expected transcript under Zig 0.14.x.

### HV0: Status scaffold only

- **Goal:** Provide a branch-only hypervisor status surface that names missing pieces honestly. No guest execution.
- **Required Zig files likely touched:** `kernel/hypervisor/hv.zig`, `kernel/console/shell.zig`.
- **Required docs:** `docs/hypervisor/HYPERVISOR_BRANCH_CHARTER.md`, `docs/hypervisor/HV0_STATUS_AUDIT.md`, `docs/hypervisor/ZIGN01D_HYPERVISOR_MASTER_PLAN.md`, command/milestone index references if needed.
- **Required shell commands:** `git branch --show-current`, `git status`, `./scripts/check-zig-version.sh`, `./scripts/build.sh`, `./smoke/smoke-hv-status-v0.sh`.
- **Required smoke test file:** `smoke/smoke-hv-status-v0.sh`.
- **Required transcript markers:** `hv: branch=hypervisor-v0`, `hv: target=zig-0.14.x`, `hv: status=research-scaffold`, `hv: linux_guest=not-supported-yet`, `hv: rust_guest_toolchain=not-supported-yet`, `hv: guest_execution=not-supported-yet`, `hv: vm_object=MISSING`, `hv: vcpu_object=MISSING`, `hv: guest_memory=MISSING`, `hv: guest_entry=MISSING`, `hv: guest_trap_return=MISSING`, `hv: second_stage_translation=MISSING`, `hv: virtual_console=MISSING`, `hv: sbi_layer=MISSING`, `hv: virtio_for_linux=MISSING`.
- **Required negative markers / forbidden claims:** `linux_guest=supported`, `guest_execution=supported`, `vm_object=IMPLEMENTED`, `vcpu_object=IMPLEMENTED`, `booted linux`, `Linux guest booted`, `guest entered`, any panic text.
- **Exit criteria:** The smoke test builds first, boots QEMU, sends `hv status`, writes `smoke/transcripts/latest-hv-status-v0.txt`, proves all positive markers, rejects all forbidden markers, and prints final `PASS` only after all checks.
- **What it still does NOT imply:** No H-extension detection, VM, vCPU, guest memory, guest entry, guest trap return, Linux boot, Linux shell, C toolchain, or Rust toolchain.
- **Dependency for next milestone:** HV1 may begin only after HV0 output is stable and no baseline smoke tests are regressed.

### HV1: Hypervisor capability detection

- **Goal:** Safely report whether the RISC-V H-extension or another required hypervisor capability is present. No guest execution.
- **Required Zig files likely touched:** `kernel/hypervisor/hv.zig`, `kernel/hypervisor/capability.zig`, `kernel/arch/riscv64/csr.zig` or existing safe CSR helpers.
- **Required docs:** `docs/hypervisor/HV1_CAPABILITY_DETECTION.md`, `docs/hypervisor/HV1_commands.md`, update this master plan only if command names or marker contracts change.
- **Required shell commands:** `hv capability` and `hv-capability` for the capability surface, plus validation commands `git branch --show-current`, `git status`, `./scripts/check-zig-version.sh`, `./scripts/build.sh`, `./smoke/smoke-hv-capability-v0.sh`.
- **Required smoke test file:** `smoke/smoke-hv-capability-v0.sh`.
- **Required transcript markers:** `hv: capability_detection=implemented`, a source line such as `hv: capability_source=<safe-source>`, one of `hv: h_extension=present`, `hv: h_extension=absent`, or `hv: h_extension=unknown reason=<reason>`, and `hv: guest_execution=not-supported-yet`.
- **Required negative markers / forbidden claims:** `guest_execution=supported`, `guest entered`, `linux_guest=supported`, unsafe trap/panic output from probing privileged CSRs.
- **Exit criteria:** QEMU transcript proves capability reporting is safe and deterministic for the tested environment; unsupported capability remains a clean status value, not a crash.
- **What it still does NOT imply:** No VM object, no vCPU object, no guest memory, no entry path, and no Linux support.
- **Dependency for next milestone:** HV2 may use the capability result to gate object inspection, but must not infer execution support from detection alone.

### HV2: VM and vCPU data model

- **Goal:** Introduce real VM and vCPU structs with initialized state and an inspection command. No guest memory execution.
- **Required Zig files likely touched:** `kernel/hypervisor/vm.zig`, `kernel/hypervisor/vcpu.zig`, `kernel/hypervisor/hv.zig`, `kernel/console/shell.zig`.
- **Required docs:** `docs/hypervisor/HV2_VM_VCPU_MODEL.md`.
- **Required shell commands:** `git branch --show-current`, `git status`, `./scripts/check-zig-version.sh`, `./scripts/build.sh`, `./smoke/smoke-hv-vm-vcpu-v0.sh`.
- **Required smoke test file:** `smoke/smoke-hv-vm-vcpu-v0.sh`.
- **Required transcript markers:** `hv: vm_object=IMPLEMENTED`, `hv: vcpu_object=IMPLEMENTED`, VM ID/state marker, vCPU ID/state marker, `hv: guest_memory=MISSING`, `hv: guest_execution=not-supported-yet`.
- **Required negative markers / forbidden claims:** `guest_memory=IMPLEMENTED`, `guest_execution=supported`, `guest entered`, `linux_guest=supported`, fake nonzero guest runtime counters.
- **Exit criteria:** The inspection command creates or reports initialized VM/vCPU state from real structs, with bounded IDs and deterministic default fields.
- **What it still does NOT imply:** No guest memory allocation, no payload loading, no entry, no trap return, no Linux.
- **Dependency for next milestone:** HV3 may attach owned guest-memory ranges to the real VM object.

### HV3: Guest memory object

- **Goal:** Allocate and account guest memory through real PMM-backed ownership. No guest entry.
- **Required Zig files likely touched:** `kernel/hypervisor/guest_memory.zig`, `kernel/hypervisor/vm.zig`, PMM integration files such as `kernel/memory/pmm.zig` if ownership hooks are required, `kernel/hypervisor/hv.zig`.
- **Required docs:** `docs/hypervisor/HV3_GUEST_MEMORY.md`.
- **Required shell commands:** `git branch --show-current`, `git status`, `./scripts/check-zig-version.sh`, `./scripts/build.sh`, `./smoke/smoke-hv-guest-memory-v0.sh`.
- **Required smoke test file:** `smoke/smoke-hv-guest-memory-v0.sh`.
- **Required transcript markers:** `hv: guest_memory=IMPLEMENTED`, guest-memory base, size, page count, owner VM ID, allocation success marker, accounting marker, `hv: guest_entry=MISSING`.
- **Required negative markers / forbidden claims:** `guest_entry=IMPLEMENTED`, `guest_execution=supported`, `linux_guest=supported`, out-of-bounds accepted markers, overlapping ownership accepted markers.
- **Exit criteria:** Transcript proves allocation, accounting, bounds rejection, and cleanup or stable ownership; PMM state remains consistent after the test.
- **What it still does NOT imply:** No payload loader, no guest execution, no second-stage translation, no Linux.
- **Dependency for next milestone:** HV4 may place bytes only into a proven guest-memory object.

### HV4: Guest payload loader

- **Goal:** Place a tiny non-Linux payload into guest memory and report its entry address. No execution.
- **Required Zig files likely touched:** `kernel/hypervisor/loader.zig`, `kernel/hypervisor/guest_memory.zig`, `kernel/hypervisor/vm.zig`, `kernel/hypervisor/hv.zig`.
- **Required docs:** `docs/hypervisor/HV4_TINY_PAYLOAD_LOADER.md`.
- **Required shell commands:** `git branch --show-current`, `git status`, `./scripts/check-zig-version.sh`, `./scripts/build.sh`, `./smoke/smoke-hv-loader-v0.sh`.
- **Required smoke test file:** `smoke/smoke-hv-loader-v0.sh`.
- **Required transcript markers:** `hv: guest_payload_loader=IMPLEMENTED`, payload name or ID, payload byte count, payload checksum, guest physical load address, guest entry address, `hv: guest_execution=not-supported-yet`.
- **Required negative markers / forbidden claims:** `guest entered`, `guest_execution=supported`, `linux_guest=supported`, `Linux Image loaded`, writes outside guest-memory bounds.
- **Exit criteria:** Smoke transcript proves a tiny payload is copied into owned guest memory, validated by length/checksum, and not executed.
- **What it still does NOT imply:** No guest entry, no guest trap return, no Linux loading, no Linux boot.
- **Dependency for next milestone:** HV5 may attempt entry only into a loaded non-Linux payload after HV1-HV4 are real.

### HV5: Controlled tiny guest entry attempt

- **Goal:** Attempt guest entry only when HV1-HV4 are real. No Linux.
- **Required Zig files likely touched:** `kernel/hypervisor/entry.zig`, `kernel/hypervisor/vcpu.zig`, `kernel/hypervisor/vm.zig`, `kernel/hypervisor/guest_memory.zig`, architecture trap/CSR helpers as needed.
- **Required docs:** `docs/hypervisor/HV5_GUEST_ENTRY_ATTEMPT.md`.
- **Required shell commands:** `git branch --show-current`, `git status`, `./scripts/check-zig-version.sh`, `./scripts/build.sh`, `./smoke/smoke-hv-entry-v0.sh`.
- **Required smoke test file:** `smoke/smoke-hv-entry-v0.sh`.
- **Required transcript markers:** gate checks for HV1-HV4, `hv: guest_entry=ATTEMPTED`, entry address, vCPU state before entry, explicit result such as `blocked_no_h_extension`, `entered_and_trapped`, or `entry_rejected=<reason>`.
- **Required negative markers / forbidden claims:** `linux_guest=supported`, `Linux guest booted`, `Linux shell`, `guest_execution=fully-supported`, silent reset, unclassified panic.
- **Exit criteria:** The attempt is gated, bounded, observable, and produces a controlled result. If hardware support is absent, the test passes only by proving clean rejection.
- **What it still does NOT imply:** No Linux support, no general guest execution support, no virtual devices, no shell inside a guest.
- **Dependency for next milestone:** HV6 needs a controlled entry or controlled rejection path plus trap-frame work sufficient to classify guest exits.

### HV6: Guest trap capture

- **Goal:** Capture guest trap cause and stop or return explicitly. No Linux.
- **Required Zig files likely touched:** `kernel/hypervisor/trap.zig`, `kernel/hypervisor/entry.zig`, `kernel/hypervisor/vcpu.zig`, architecture trap assembly/Zig files as needed.
- **Required docs:** `docs/hypervisor/HV6_GUEST_TRAP_CAPTURE.md`.
- **Required shell commands:** `git branch --show-current`, `git status`, `./scripts/check-zig-version.sh`, `./scripts/build.sh`, `./smoke/smoke-hv-trap-capture-v0.sh`.
- **Required smoke test file:** `smoke/smoke-hv-trap-capture-v0.sh`.
- **Required transcript markers:** `hv: guest_trap_capture=IMPLEMENTED`, trap cause, trap PC, trap value when available, vCPU stopped/returned state, `hv: linux_guest=not-supported-yet`.
- **Required negative markers / forbidden claims:** unclassified `panic`, `Linux boot`, `guest trap ignored`, `guest_execution=fully-supported`.
- **Exit criteria:** A tiny payload causes a known trap or exit; the hypervisor records it, reports it, and returns to the host shell or stops cleanly.
- **What it still does NOT imply:** No Linux boot, no virtual console, no SBI mediation, no reliable guest OS support.
- **Dependency for next milestone:** HV7 may build a diagnostic output path using controlled traps or explicit hypercalls.

### HV7: Virtual console path

- **Goal:** Provide a tiny guest diagnostic output path. No Linux shell claim.
- **Required Zig files likely touched:** `kernel/hypervisor/console.zig`, `kernel/hypervisor/trap.zig`, `kernel/hypervisor/vcpu.zig`, `kernel/console/uart.zig` integration if required.
- **Required docs:** `docs/hypervisor/HV7_VIRTUAL_CONSOLE.md`.
- **Required shell commands:** `git branch --show-current`, `git status`, `./scripts/check-zig-version.sh`, `./scripts/build.sh`, `./smoke/smoke-hv-console-v0.sh`.
- **Required smoke test file:** `smoke/smoke-hv-console-v0.sh`.
- **Required transcript markers:** `hv: virtual_console=IMPLEMENTED`, tiny guest diagnostic text marker, byte count, channel name, `hv: linux_shell=not-supported-yet`.
- **Required negative markers / forbidden claims:** `Linux shell`, `login:`, `uname`, `linux_guest=supported`, guest output not attributable to a controlled tiny payload.
- **Exit criteria:** A non-Linux tiny payload emits diagnostic bytes through an explicit virtual console path and the host transcript attributes them correctly.
- **What it still does NOT imply:** No Linux console, no shell, no virtio console, no general device model.
- **Dependency for next milestone:** HV8 may use the trap/console path to report mediated or rejected SBI calls.

### HV8: Minimal SBI mediation

- **Goal:** Observe and handle or reject basic SBI calls honestly. No firmware pretending.
- **Required Zig files likely touched:** `kernel/hypervisor/sbi.zig`, `kernel/hypervisor/trap.zig`, `kernel/hypervisor/vcpu.zig`, `kernel/hypervisor/console.zig`.
- **Required docs:** `docs/hypervisor/HV8_SBI_MEDIATION.md`.
- **Required shell commands:** `git branch --show-current`, `git status`, `./scripts/check-zig-version.sh`, `./scripts/build.sh`, `./smoke/smoke-hv-sbi-v0.sh`.
- **Required smoke test file:** `smoke/smoke-hv-sbi-v0.sh`.
- **Required transcript markers:** `hv: sbi_layer=IMPLEMENTED`, SBI extension/function ID, result code, handled/rejected decision, guest PC advance policy.
- **Required negative markers / forbidden claims:** `firmware complete`, `all SBI supported`, `linux_guest=supported`, unhandled SBI accepted as success.
- **Exit criteria:** The tiny guest can issue known SBI-like calls; the host reports which calls were handled and which were rejected with explicit error status.
- **What it still does NOT imply:** No Linux boot, no full SBI implementation, no device virtualization completeness.
- **Dependency for next milestone:** HV9 may load Linux assets only after guest memory, entry/trap capture, console, and minimal SBI policy are visible.

### HV9: Linux Image and DTB loading

- **Goal:** Load a Linux `Image` and DTB into guest memory. No boot claim.
- **Required Zig files likely touched:** `kernel/hypervisor/linux_loader.zig`, `kernel/hypervisor/guest_memory.zig`, `kernel/hypervisor/loader.zig`, DTB helper files if introduced.
- **Required docs:** `docs/hypervisor/HV9_LINUX_IMAGE_DTB_LOADING.md`.
- **Required shell commands:** `git branch --show-current`, `git status`, `./scripts/check-zig-version.sh`, `./scripts/build.sh`, `./smoke/smoke-hv-linux-load-v0.sh`.
- **Required smoke test file:** `smoke/smoke-hv-linux-load-v0.sh`.
- **Required transcript markers:** `hv: linux_image_loader=IMPLEMENTED`, Linux image byte count/checksum, DTB byte count/checksum, guest load addresses, entry address, `hv: linux_guest=not-booted-yet`.
- **Required negative markers / forbidden claims:** `Linux booted`, `Freeing unused kernel memory`, `login:`, `shell`, `linux_guest=supported`.
- **Exit criteria:** Transcript proves bytes were loaded and accounted in guest memory without claiming execution or boot.
- **What it still does NOT imply:** No Linux boot, no early boot text, no shell, no guest toolchain.
- **Dependency for next milestone:** HV10 may attempt Linux entry and early text capture only after HV9 loading proof exists.

### HV10: Early Linux boot text

- **Goal:** Capture real early Linux boot text. No shell claim.
- **Required Zig files likely touched:** `kernel/hypervisor/linux_entry.zig`, `kernel/hypervisor/console.zig`, `kernel/hypervisor/sbi.zig`, `kernel/hypervisor/trap.zig`, virtual timer files if needed.
- **Required docs:** `docs/hypervisor/HV10_EARLY_LINUX_BOOT_TEXT.md`.
- **Required shell commands:** `git branch --show-current`, `git status`, `./scripts/check-zig-version.sh`, `./scripts/build.sh`, `./smoke/smoke-hv-linux-early-v0.sh`.
- **Required smoke test file:** `smoke/smoke-hv-linux-early-v0.sh`.
- **Required transcript markers:** `hv: linux_early_text=CAPTURED`, at least one real early Linux boot line from the guest transcript, guest console source marker, stop reason or timeout reason.
- **Required negative markers / forbidden claims:** `Linux shell`, `login:`, `uname -a`, `C compiler works`, `Rust works`, synthetic Linux-looking text generated by the host.
- **Exit criteria:** Transcript captures authentic early Linux output from the guest path and still rejects shell/toolchain claims.
- **What it still does NOT imply:** No interactive shell, no userspace proof, no C or Rust toolchain.
- **Dependency for next milestone:** HV11 may pursue userspace shell proof after early boot text and required device/timer/SBI issues are solved.

### HV11: Linux shell proof

- **Goal:** Reach a Linux shell and prove command echo, `uname`, or an equivalent unambiguous shell command.
- **Required Zig files likely touched:** Hypervisor Linux/SBI/console/timer/device files as required by the real blockers identified in HV10.
- **Required docs:** `docs/hypervisor/HV11_LINUX_SHELL_PROOF.md`.
- **Required shell commands:** `git branch --show-current`, `git status`, `./scripts/check-zig-version.sh`, `./scripts/build.sh`, `./smoke/smoke-hv-linux-shell-v0.sh`.
- **Required smoke test file:** `smoke/smoke-hv-linux-shell-v0.sh`.
- **Required transcript markers:** `hv: linux_shell=PROVEN`, shell prompt or login completion marker, command sent marker, command output marker such as `uname` output or deterministic echo output.
- **Required negative markers / forbidden claims:** fabricated shell transcript, host-side `uname` mistaken for guest `uname`, `C compiler works`, `Rust works`.
- **Exit criteria:** Smoke test boots the guest to a shell, sends a command through the guest console path, captures guest output, and distinguishes guest output from host output.
- **What it still does NOT imply:** No C compiler proof, no Rust toolchain proof, no broad Linux distribution support.
- **Dependency for next milestone:** HV12 may install or use an available guest C compiler only after shell I/O is proven.

### HV12: Compile C inside Linux guest

- **Goal:** Compile and run a tiny C program inside the Linux guest.
- **Required Zig files likely touched:** Usually none in the hypervisor core unless HV11 revealed missing I/O/storage/process blockers; guest asset/build scripts may be touched if the repo owns them.
- **Required docs:** `docs/hypervisor/HV12_GUEST_C_TOOLCHAIN.md`.
- **Required shell commands:** `git branch --show-current`, `git status`, `./scripts/check-zig-version.sh`, `./scripts/build.sh`, `./smoke/smoke-hv-linux-c-v0.sh`.
- **Required smoke test file:** `smoke/smoke-hv-linux-c-v0.sh`.
- **Required transcript markers:** `hv: linux_c_toolchain=PROVEN`, C source creation marker, compiler invocation marker, program run marker, expected program output marker.
- **Required negative markers / forbidden claims:** host compiler output mistaken for guest output, prebuilt binary substituted for compilation, `Rust works`.
- **Exit criteria:** Transcript proves a C source file is created or present inside the guest, compiled inside the guest, executed inside the guest, and produces expected output.
- **What it still does NOT imply:** No Rust toolchain proof, no package-manager support claim, no performance claim.
- **Dependency for next milestone:** HV13 may add Rust only after guest shell and C compile/run proof are stable.

### HV13: Rust toolchain inside Linux guest

- **Goal:** Compile and run a tiny Rust program inside the Linux guest.
- **Required Zig files likely touched:** Usually none in the hypervisor core unless toolchain workload exposes missing virtualization support; guest asset/build scripts may be touched if owned by this repo.
- **Required docs:** `docs/hypervisor/HV13_GUEST_RUST_TOOLCHAIN.md`.
- **Required shell commands:** `git branch --show-current`, `git status`, `./scripts/check-zig-version.sh`, `./scripts/build.sh`, `./smoke/smoke-hv-linux-rust-v0.sh`.
- **Required smoke test file:** `smoke/smoke-hv-linux-rust-v0.sh`.
- **Required transcript markers:** `hv: linux_rust_toolchain=PROVEN`, Rust source creation marker, `rustc` or documented Rust build command marker, program run marker, expected program output marker.
- **Required negative markers / forbidden claims:** host Rust output mistaken for guest output, prebuilt binary substituted for compilation, broad Rust ecosystem support claim without proof.
- **Exit criteria:** Transcript proves Rust source is compiled and run inside the guest with deterministic output.
- **What it still does NOT imply:** No claim that every Rust crate works, no performance or production-readiness claim, no support claim beyond the tested toolchain path.
- **Dependency for next milestone:** Post-HV13 work may focus on hardening, scheduling, device models, isolation audits, and broader guest matrices, each with its own proof ladder.

## 6. Smoke-test doctrine

Every hypervisor smoke test must:

1. Run `./scripts/check-zig-version.sh` directly or through a documented validation sequence before accepting results.
2. Build first with `./scripts/build.sh`.
3. Boot QEMU from the built kernel artifact.
4. Send exactly documented shell or guest-console commands.
5. Capture a transcript under `smoke/transcripts/` and, when useful, copy it under `logs/latest/`.
6. Require all positive markers for that milestone.
7. Reject all forbidden markers for that milestone.
8. Fail if `[ZIGN01D][PANIC]`, lowercase `panic`, unclassified trap output, or a QEMU crash appears unless the milestone explicitly proves a controlled trap and names it.
9. Print the transcript path before or with final success.
10. Print final `PASS` only after build, boot, command send, positive-marker checks, negative-marker checks, panic rejection, and transcript persistence all succeed.

A smoke test that cannot find Zig 0.14.x must report **BLOCKED** or fail before making any milestone capability claim. It must never turn a missing compiler into a hypervisor pass.

## 7. Branch isolation rules

- `hypervisor-v0` evolves independently as the hypervisor research branch.
- `main` remains the stable kernel track.
- No unstable hypervisor claims are allowed in `main` unless they are explicitly merged later with proof.
- The hypervisor branch must not break existing kernel smoke tests.
- Each milestone should be mergeable and revertible as its own proof step.
- Each milestone should keep its source changes bounded to the smallest necessary files.
- Documentation may describe future work, but command output must only claim features that exist.
- Branch documentation must remain clear when the current checked-out local branch name differs from the intended `hypervisor-v0` track; validation must report the actual `git branch --show-current` output.

## 8. Adoption-quality goals

For ZIGN01D to be “on par with the Diosix direction,” it does not need to be copied from Diosix and should not be identical to Diosix. It should reach comparable seriousness through its own design and proof discipline:

- Original Zig 0.14.x implementation.
- Real VM model.
- Real vCPU model.
- Real guest memory ownership and accounting.
- Real guest payload loading.
- Real guest entry and trap handling.
- Real second-stage translation or explicitly documented architecture-specific isolation mechanism.
- Real SBI mediation policy.
- Real virtual console path.
- Real Linux Image/DTB loading proof before any boot claim.
- Real early Linux text before any shell claim.
- Real Linux shell proof before any guest toolchain claim.
- Real C compile/run proof before any Rust claim.
- Real Rust compile/run proof before any Rust guest-toolchain support claim.
- Transcript-backed milestones.
- Reproducibility under Zig 0.14.x.
- Clear statements of what is still missing after every milestone.

## 9. Proof records required per milestone

Each milestone PR or change record must include:

- Current branch output from `git branch --show-current`.
- Clean or explained `git status`.
- Zig version validation output from `./scripts/check-zig-version.sh`.
- Build output summary from `./scripts/build.sh`.
- Smoke-test output summary.
- Transcript path.
- Positive markers observed.
- Forbidden markers rejected.
- Panic/crash rejection result.
- Explicit non-claims.
- Any environment limitation marked **BLOCKED**, not **PASS**.

## 10. Final checklist

- [ ] Zig 0.14.x enforced.
- [ ] No Linux claim before HV9-HV11 proof, as applicable.
- [ ] No guest execution claim before real HV5/HV6 proof.
- [ ] Every milestone has smoke proof requirements.
- [ ] Every milestone has command-output requirements.
- [ ] Every milestone has required transcript markers.
- [ ] Every milestone has forbidden markers.
- [ ] Every missing feature is named.
- [ ] `main` unaffected.
- [ ] Branch-only hypervisor track preserved.
- [ ] Implementation remains original ZIGN01D Zig 0.14.x work.
