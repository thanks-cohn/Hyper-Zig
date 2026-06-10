# Hypervisor Milestone Ladder

Every milestone keeps missing features honest. `not implemented yet` means the milestone must not claim guest execution or Linux support until its proof exists.

## HV0: Hypervisor Status Scaffold

- **Goal:** Add `hv status`/`hv` shell reporting and document the hypervisor research boundary.
- **Not implemented yet:** Linux guest, guest execution, VM, vCPU, guest memory, second-stage translation, virtual console, SBI layer, virtio for Linux.
- **Likely files:** `kernel/hypervisor/hv.zig`, `kernel/console/shell.zig`, `docs/hypervisor/*`, `smoke/smoke-hv-status-v0.sh`.
- **Proof command:** `./smoke/smoke-hv-status-v0.sh`.
- **Smoke test name:** `smoke-hv-status-v0`.
- **Acceptance markers:** `hv: status=research-scaffold`, `hv: linux_guest=not-supported-yet`, `hv: guest_execution=not-supported-yet`, `hv: vm_object=MISSING`, `hv: vcpu_object=MISSING`.

## HV1: Capability Detection and Data Model Design

- **Goal:** Safely report hypervisor capability and design VM/vCPU structs.
- **Not implemented yet:** Guest entry, Linux boot, virtual devices.
- **Likely files:** `kernel/hypervisor/hv.zig`, future capability/data-model docs.
- **Proof command:** `./smoke/smoke-hv-capability-v0.sh`.
- **Smoke test name:** `smoke-hv-capability-v0`.
- **Acceptance markers:** safe capability source, VM/vCPU model documented, no guest execution claim.

## HV2: VM/vCPU Structs

- **Goal:** Add concrete VM and vCPU data structures with initialization and inspection.
- **Not implemented yet:** Guest memory execution, second-stage translation, guest entry.
- **Likely files:** `kernel/hypervisor/vm.zig`, `kernel/hypervisor/vcpu.zig`, `kernel/hypervisor/hv.zig`.
- **Proof command:** `./smoke/smoke-hv-vm-vcpu-v0.sh`.
- **Smoke test name:** `smoke-hv-vm-vcpu-v0`.
- **Acceptance markers:** VM object present, vCPU object present, guest execution still not supported.

## HV3: vCPU Lifecycle

- **Goal:** Allocate and report guest memory ranges backed by real kernel memory ownership.
- **Not implemented yet:** Guest entry, second-stage translation, Linux loading.
- **Likely files:** `kernel/hypervisor/guest_memory.zig`, PMM integration points if required.
- **Proof command:** `./smoke/smoke-hv-guest-memory-v0.sh`.
- **Smoke test name:** `smoke-hv-guest-memory-v0`.
- **Acceptance markers:** guest memory allocated, bounds printed, overflow/rejection cases proven.

## HV4: Guest Memory Object

- **Goal:** Place a tiny test payload into guest memory without executing it.
- **Not implemented yet:** Guest entry, trap return, Linux Image loading.
- **Likely files:** `kernel/hypervisor/loader.zig`, `kernel/hypervisor/guest_memory.zig`.
- **Proof command:** `./smoke/smoke-hv-loader-v0.sh`.
- **Smoke test name:** `smoke-hv-loader-v0`.
- **Acceptance markers:** payload bytes loaded, entry address recorded, guest execution not attempted.

## HV5: Guest Entry Attempt

- **Goal:** Attempt a controlled non-Linux guest entry only when architecture support is proven.
- **Not implemented yet:** Linux boot, virtual console, SBI mediation.
- **Likely files:** `kernel/hypervisor/entry.zig`, architecture-specific trap/entry files as needed.
- **Proof command:** `./smoke/smoke-hv-entry-v0.sh`.
- **Smoke test name:** `smoke-hv-entry-v0`.
- **Acceptance markers:** guest entry attempted, result explicit, no Linux claim.

## HV6: Trap Return

- **Goal:** Handle a guest trap and return or stop with an explicit reason.
- **Not implemented yet:** Linux boot, virtual devices, SBI layer.
- **Likely files:** `kernel/hypervisor/trap.zig`, architecture trap integration.
- **Proof command:** `./smoke/smoke-hv-trap-return-v0.sh`.
- **Smoke test name:** `smoke-hv-trap-return-v0`.
- **Acceptance markers:** guest trap observed, cause printed, return path proven or not-supported reason printed.

## HV7: Virtual Console

- **Goal:** Provide a minimal guest-visible console path for tiny payload diagnostics.
- **Not implemented yet:** Linux console maturity, virtio console, Linux shell.
- **Likely files:** `kernel/hypervisor/console.zig`, shell/status integration.
- **Proof command:** `./smoke/smoke-hv-console-v0.sh`.
- **Smoke test name:** `smoke-hv-console-v0`.
- **Acceptance markers:** virtual console present for test payload, no Linux shell claim.

## HV8: SBI Mediation

- **Goal:** Mediate required SBI calls honestly for guest firmware expectations.
- **Not implemented yet:** Linux Image/DTB loading, Linux boot text.
- **Likely files:** `kernel/hypervisor/sbi.zig`, trap handling files.
- **Proof command:** `./smoke/smoke-hv-sbi-v0.sh`.
- **Smoke test name:** `smoke-hv-sbi-v0`.
- **Acceptance markers:** SBI call observed, handled/rejected reason printed, no fake firmware claim.

## HV9: Linux Image and DTB Loading

- **Goal:** Load a Linux `Image` and guest DTB into guest memory.
- **Not implemented yet:** Linux boot text, Linux shell, package/toolchain use.
- **Likely files:** `kernel/hypervisor/linux_loader.zig`, guest memory and loader files.
- **Proof command:** `./smoke/smoke-hv-linux-load-v0.sh`.
- **Smoke test name:** `smoke-hv-linux-load-v0`.
- **Acceptance markers:** Linux image loaded, DTB loaded, no boot claim unless entry proof exists.

## HV10: Early Linux Boot Text

- **Goal:** Capture earliest Linux boot text from a real guest attempt.
- **Not implemented yet:** Linux shell, C compilation, Rust toolchain.
- **Likely files:** virtual console, SBI, trap, loader files.
- **Proof command:** `./smoke/smoke-hv-linux-early-v0.sh`.
- **Smoke test name:** `smoke-hv-linux-early-v0`.
- **Acceptance markers:** real Linux early boot text captured, transcript path recorded.

## HV11: Linux Shell

- **Goal:** Reach an interactive Linux shell inside the guest.
- **Not implemented yet:** C/Rust compilation proof.
- **Likely files:** virtual devices, rootfs/loading docs and scripts.
- **Proof command:** `./smoke/smoke-hv-linux-shell-v0.sh`.
- **Smoke test name:** `smoke-hv-linux-shell-v0`.
- **Acceptance markers:** real shell prompt, command echo, uname or equivalent guest command output.

## HV12: Compile C Inside Linux Guest

- **Goal:** Compile and run a tiny C program inside the Linux guest.
- **Not implemented yet:** Rust toolchain proof.
- **Likely files:** guest rootfs/toolchain setup docs and smoke scripts.
- **Proof command:** `./smoke/smoke-hv-linux-c-v0.sh`.
- **Smoke test name:** `smoke-hv-linux-c-v0`.
- **Acceptance markers:** compiler version, compiled binary run, output captured from guest.

## HV13: Rust Toolchain Inside Linux Guest

- **Goal:** Install or expose Rust tooling inside the Linux guest and compile a tiny Rust program.
- **Not implemented yet:** Native Rust-on-ZIGN01D kernel/runtime support.
- **Likely files:** guest rootfs/toolchain docs and smoke scripts.
- **Proof command:** `./smoke/smoke-hv-linux-rust-v0.sh`.
- **Smoke test name:** `smoke-hv-linux-rust-v0`.
- **Acceptance markers:** rustc/cargo version, tiny Rust program compiled and run inside guest.
