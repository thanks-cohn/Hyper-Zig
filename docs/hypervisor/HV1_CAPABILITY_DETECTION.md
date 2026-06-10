# HV1 Capability Detection

## Goal

HV1 adds an honest hypervisor capability status surface for the branch-only ZIGN01D hypervisor research track. The command reports whether capability detection itself is implemented and whether the RISC-V H-extension is known to be present, absent, or unknown.

HV1 does **not** execute a guest, create a VM object, create a vCPU object, allocate guest memory, enter guest mode, boot Linux, or claim Linux support.

## Exact command

Run either command from the ZIGN01D shell:

```text
hv capability
hv-capability
```

The existing HV0 status commands remain separate:

```text
hv
hv status
hv-status
```

## Current detection result

The current supervisor-mode kernel does not have a proven safe H-extension probe. HV1 therefore reports the capability surface as implemented while leaving the H-extension result unknown:

```text
hv: branch=hypervisor-v0
hv: target=zig-0.14.x
hv: capability_detection=implemented
hv: capability_source=supervisor-mode-safe-static-policy
hv: h_extension=unknown reason=no-safe-detection-yet
hv: guest_execution=not-supported-yet
hv: linux_guest=not-supported-yet
hv: vm_object=MISSING
hv: vcpu_object=MISSING
```

`supervisor-mode-safe-static-policy` means the command intentionally avoids unsafe privileged CSR probing from the current S-mode code path. Until ZIGN01D has a trap-safe or firmware-backed way to classify H-extension availability, `unknown reason=no-safe-detection-yet` is the honest result.

## Exact smoke test

```sh
./smoke/smoke-hv-capability-v0.sh
```

The smoke test must first validate Zig 0.14.x, then build, boot QEMU, send `hv capability`, capture a transcript, require positive HV1 markers, reject forbidden guest/Linux/VM/vCPU claim markers, and fail on panic or QEMU crash output.

## Exact transcript path

```text
smoke/transcripts/latest-hv-capability-v0.txt
```

A copy is also written under `logs/latest/` for quick inspection by the smoke harness.

## Why no guest execution is implied

Capability detection only describes the reporting surface and the known/unknown H-extension status. It does not build a guest address space, does not allocate or own guest pages, does not create VM or vCPU state, does not configure second-stage translation, and does not transfer control to guest code.

The command must continue to print:

```text
hv: guest_execution=not-supported-yet
hv: linux_guest=not-supported-yet
hv: vm_object=MISSING
hv: vcpu_object=MISSING
```

## What HV1 still does not implement

HV1 still does not implement:

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
- Virtio support for Linux guests.
- Linux image loading.
- Linux boot.
- Linux shell.
- C or Rust toolchains inside a guest.

## What unlocks HV2

HV2 may begin only after HV1 command output is stable and transcript-backed under Zig 0.14.x. HV2 should introduce real VM and vCPU data-model objects with inspection output, while still making no guest-memory, guest-entry, guest-execution, or Linux-support claim.

## Zig 0.14.x validation requirement

HV1 validation is blocked unless the repository can run an executable Zig 0.14.x compiler. The required validation sequence is:

```sh
git branch --show-current
git status
./scripts/check-zig-version.sh
./scripts/build.sh
./smoke/smoke-hv-status-v0.sh
./smoke/smoke-hv-capability-v0.sh
```

If `./scripts/check-zig-version.sh` cannot find Zig 0.14.x, report **BLOCKED** rather than claiming that HV1 passed.
