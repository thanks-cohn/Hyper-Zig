# Hyper-Zig commands

This file mirrors the project command index. The lowercase `commands.md` remains the short historical command index; the full command table lives in `docs/COMMAND_REFERENCE.md`.

## HV3 vCPU Lifecycle commands

HV3 adds real typed lifecycle state for the boot vCPU only. These commands mutate the in-kernel boot vCPU lifecycle counters and state machine. They do **not** imply guest memory, guest execution, Linux guest support, or RISC-V H-extension support.

### `hv vcpu lifecycle` / `hv-vcpu-lifecycle`
- **What it does:** prints the current boot vCPU lifecycle state, transition eligibility, reset generation, and lifecycle counters.
- **Example usage:** `hv vcpu lifecycle`
- **Expected output:**
  ```text
  hv: vcpu.lifecycle.state=created
  hv: vcpu.lifecycle.can_initialize=true
  hv: vcpu.lifecycle.can_prepare_runnable=false
  hv: vcpu.lifecycle.can_halt=false
  hv: vcpu.reset_generation=0
  hv: vcpu.stats.failed_transition_count=0
  hv: guest_execution=not-supported-yet
  hv: linux_guest=not-supported-yet
  ```
- **What it does not imply:** no guest memory object exists, no guest code runs, Linux guests are not supported, and H-extension presence is not proven.

### `hv vcpu init` / `hv-vcpu-init`
- **What it does:** attempts the lifecycle transition `created -> initialized` for the boot vCPU and increments `initialize_count` only when that transition succeeds.
- **Example usage:** `hv vcpu init`
- **Expected output:**
  ```text
  hv: vcpu.transition=initialize result=ok
  hv: vcpu.state=initialized
  hv: vcpu.hart_binding=boot-hart
  hv: vcpu.run_count=0
  hv: guest_execution=not-supported-yet
  hv: linux_guest=not-supported-yet
  ```
- **What it does not imply:** initialization is lifecycle bookkeeping only; it does not allocate guest memory or enter a guest.

### `hv vcpu prepare` / `hv-vcpu-prepare`
- **What it does:** attempts `initialized -> runnable` or `halted -> runnable` for the boot vCPU and increments `prepare_count` only on success.
- **Example usage:** `hv vcpu prepare`
- **Expected output:**
  ```text
  hv: vcpu.transition=prepare-runnable result=ok
  hv: vcpu.state=runnable
  hv: vcpu.run_count=0
  hv: guest_execution=not-supported-yet
  hv: linux_guest=not-supported-yet
  ```
- **What it does not imply:** runnable means ready in the lifecycle model only; it does not mean guest execution exists.

### `hv vcpu halt` / `hv-vcpu-halt`
- **What it does:** attempts `runnable -> halted` for the boot vCPU and increments `halt_count` only on success. If the vCPU is not runnable, the command returns `result=invalid-state` and increments `failed_transition_count`.
- **Example usage:** `hv vcpu halt`
- **Expected output:**
  ```text
  hv: vcpu.transition=halt result=ok
  hv: vcpu.state=halted
  hv: vcpu.run_count=0
  ```
  After a reset, halt is invalid:
  ```text
  hv: vcpu.transition=halt result=invalid-state
  hv: vcpu.state=created
  hv: vcpu.stats.failed_transition_count=1
  ```
- **What it does not imply:** halted is lifecycle state only; there is no guest trap-return or guest CPU execution.

### `hv vcpu reset` / `hv-vcpu-reset`
- **What it does:** returns the boot vCPU from any lifecycle state to `created`, increments `reset_generation`, and increments `reset_count`.
- **Example usage:** `hv vcpu reset`
- **Expected output:**
  ```text
  hv: vcpu.transition=reset result=ok
  hv: vcpu.state=created
  hv: vcpu.reset_generation=1
  hv: vcpu.run_count=0
  hv: guest_execution=not-supported-yet
  hv: linux_guest=not-supported-yet
  ```
- **What it does not imply:** reset does not enter a guest or execute code; HV4 guest memory is managed separately by `hv guest-memory reset`.

## HV4 Guest Memory Object commands

HV4 adds a real PMM-backed guest-memory ownership object for VM 0. The object tracks ownership metadata, allocation/free/reset counters, rejected bounds checks, double-free rejection, and oversized allocation rejection. HV4 does **not** execute guest code, install second-stage translation, load Linux, or claim RISC-V H-extension support.

### `hv guest-memory` / `hv guest memory` / `hv-guest-memory`
- **What it does:** prints the current guest-memory object state.
- **Expected markers:** `hv: guest_memory=implemented`, `hv: guest_memory.owner_vm_id=0`, `hv: guest_memory.state=not-configured|configured`, `hv: guest_memory.backing=pmm-bitmap-v0`, allocation/free/rejection counters, and non-claim markers for guest execution, Linux, guest entry, and second-stage translation.

### `hv guest-memory alloc`
- **What it does:** allocates the small bounded default guest-memory object for VM 0 from the PMM bitmap allocator.
- **Expected markers:** `hv: guest_memory.alloc_result=ok`, `hv: guest_memory.state=configured`, `hv: guest_memory.page_count=2`, and `hv: guest_memory.size_bytes=8192`.

### `hv guest-memory free`
- **What it does:** releases the configured guest-memory pages back to the PMM and clears the object to `not-configured`.
- **Expected markers:** `hv: guest_memory.free_result=ok` and `hv: guest_memory.state=not-configured`.

### `hv guest-memory reset`
- **What it does:** frees configured pages if needed, clears guest-memory metadata and counters, and increments `reset_count`.

### `hv guest-memory bounds-test`
- **What it does:** proves out-of-bounds metadata access is rejected without touching guest payload bytes or executing guest code.

### `hv guest-memory double-free-test`
- **What it does:** proves a second free is rejected and increments double-free/invalid-free accounting.

### `hv guest-memory overflow-test`
- **What it does:** proves an oversized guest-memory request is rejected and increments overflow rejection accounting.

## HV5 Guest Address Space commands

HV5 adds real guest-physical-address metadata and lookup behavior on top of HV4 guest memory. It does not execute a guest, load Linux, create second-stage page tables, or implement a guest entry path.

* `hv address-space` / `hv-address-space` prints the current address-space object state.
* `hv address-space create` configures HV4 guest memory if needed, then creates metadata for VM 0 where GPA `0x0` maps to the first configured guest page and GPA `0x1000` maps to the second configured guest page.
* `hv address-space lookup-zero` performs an aligned metadata lookup for GPA `0x0` and reports the first backing host physical page.
* `hv address-space lookup-page` performs an aligned metadata lookup for GPA `0x1000` and reports the second backing host physical page.
* `hv address-space bounds-test` proves an out-of-range GPA is rejected and increments rejection counters.
* `hv address-space alignment-test` proves a misaligned page lookup is rejected and increments alignment rejection counters.
* `hv address-space reset` clears address-space metadata only; it does not execute or unmap a guest.

Smoke proof: `smoke/smoke-hv-address-space-v0.sh` writes `smoke/transcripts/latest-hv-address-space-v0.txt` and verifies command-block state movement rather than grepping static claims.


## HV6 Guest Image Loader Commands

These commands are behavior commands, not static status claims. They load and verify the tiny `tiny-flat-v0` byte payload through HV4 guest memory and HV5 guest address-space metadata. They do not execute the guest, do not load Linux, do not implement guest entry, and do not implement second-stage translation.

- `hv guest-image` / `hv-image`: print the current `GuestImage` loader state, format, load base, entry point, byte counts, checksum, counters, and last error.
- `hv guest-image load-tiny`: configure default guest memory and address-space metadata if needed, then copy the static `tiny-flat-v0` payload bytes into GPA `0x0` and record entry point metadata at GPA `0x0`.
- `hv guest-image verify`: read the loaded bytes back through GPA lookup, compare them with the static payload, and prove the loaded byte count and checksum are stable.
- `hv guest-image bounds-test`: attempt a metadata-checked oversized load span and require rejection before any oversized image write.
- `hv guest-image reset`: clear guest-image loader metadata back to `not-loaded`.

Expected non-claims remain visible in command output: `hv: guest_execution=not-supported-yet`, `hv: linux_guest=not-supported-yet`, `hv: guest_entry=implemented`, and `hv: second_stage_translation=MISSING`.


## HV7 Guest Entry Preparation Commands

HV7 prepares guest-entry metadata only. It never executes a guest and never claims Linux support.

Commands:

- `hv guest-entry` / `hv-entry`: print the current guest-entry object, register-frame metadata, counters, and non-claims.
- `hv guest-entry prepare`: safely ensures HV4/HV5 metadata if needed, requires an already loaded HV6 guest image, derives `pc` from the image entry point, derives `sp` within guest memory, creates the register frame, and attaches it to VM 0 / vCPU 0.
- `hv guest-entry reset`: clears prepared metadata and returns to `not-prepared`.
- `hv guest-entry bounds-test`: proves invalid stack metadata is rejected.
- `hv guest-entry require-image-test`: proves preparation is rejected when no HV6 guest image is loaded.

Expected non-claims remain visible: `hv: guest_execution=not-supported-yet`, `hv: linux_guest=not-supported-yet`, `hv: second_stage_translation=MISSING`, and `hv: h_extension=unknown reason=no-safe-detection-yet`.

Smoke proof: `./smoke/smoke-hv-guest-entry-v0.sh` with transcript `smoke/transcripts/latest-hv-guest-entry-v0.txt`.

## HV8 Guest Trap / Exit Metadata Commands

HV8 adds a real guest-exit metadata object for VM 0 / vCPU 0. These commands classify simulated exits and copy the HV7 prepared PC/SP metadata into a `GuestExitFrame`. They do **not** execute guest code, do **not** jump to guest memory, do **not** increment `vcpu.run_count`, do **not** boot Linux, do **not** implement second-stage translation, and do **not** prove the RISC-V H-extension.

- `hv guest-exit`: prints the current `GuestExit` state, owner IDs, last kind/reason, last frame fields, counters, and explicit non-claims.
- `hv-exit`: flat alias for `hv guest-exit`.
- `hv guest-exit record-instruction`: records a simulated instruction-trap exit using the already prepared HV7 guest-entry frame PC/SP.
- `hv guest-exit record-memory-fault`: records a simulated memory-fault exit using the already prepared HV7 guest-entry frame PC/SP.
- `hv guest-exit record-timer`: records a simulated timer-interrupt exit using the already prepared HV7 guest-entry frame PC/SP.
- `hv guest-exit record-halt`: records a simulated explicit-halt exit using the already prepared HV7 guest-entry frame PC/SP.
- `hv guest-exit reset`: clears current last-exit state and frame back to `no-exit` while preserving historical record/failure counters and incrementing `reset_count`.
- `hv guest-exit require-entry-test`: resets guest-entry metadata and proves exit recording is rejected when no HV7 prepared frame exists.

Smoke proof: `./smoke/smoke-hv-guest-exit-v0.sh` writes `smoke/transcripts/latest-hv-guest-exit-v0.txt` and checks command blocks for state transitions, counter increments, frame PC/SP copying, `vcpu.run_count=0`, and continued non-support for guest execution, Linux guests, second-stage translation, and H-extension presence.

## HV9 Controlled Guest-Entry Attempt Commands

HV9 adds a real `GuestRunAttempt` safety-gate object for VM 0 / vCPU 0. It inspects the existing HV4 guest memory, HV5 address-space metadata, HV6 tiny image state, HV7 prepared entry frame, and HV8 exit model before any future guest entry is allowed. It deliberately refuses execution because second-stage translation is still missing, H-extension support is still unknown, and guest execution remains disabled.

Commands added:

- `hv guest-run`: prints the current run-attempt object state, prerequisite booleans, HV7/HV8-linked frame snapshot, counters, blocker list, and explicit non-claims. It does not check or execute by itself.
- `hv-run`: flat alias for `hv guest-run`.
- `hv guest-run check`: evaluates the real HV4/HV5/HV6/HV7/HV8 prerequisites, copies PC/SP/run-count metadata into the attempt frame, records deterministic blockers, and reports `blocked` rather than executing.
- `hv guest-run arm-no-execute`: arms metadata only when entry and exit metadata are ready, but still refuses execution because second-stage translation is missing, H-extension is unknown, and guest execution is disabled. It must not increment `vcpu.run_count` or mark a guest running.
- `hv guest-run reset`: clears the current attempt state back to `idle` and increments `reset_count` while preserving historical counters consistently.
- `hv guest-run require-entry-test`: resets HV7 entry metadata and proves the run attempt rejects when no prepared guest-entry frame exists.
- `hv guest-run require-exit-test`: resets HV8 exit metadata and proves no-execute arming rejects when no initialized exit model exists.

Smoke proof: `./smoke/smoke-hv-guest-run-attempt-v0.sh` writes `smoke/transcripts/latest-hv-guest-run-attempt-v0.txt` and verifies command blocks, prerequisite truth values, blocker fields, HV7 PC/SP copying, HV8 exit linkage, reset behavior, `vcpu.run_count=0`, and continued non-support for guest execution, Linux guests, second-stage translation, and H-extension presence.

HV9 does **not** enter guest code, does **not** jump to guest memory, does **not** use `sret`/`hret`/`mret` for guest execution, does **not** boot Linux, does **not** implement second-stage translation, and does **not** prove RISC-V H-extension support.

## HV10 Hardware-Gated Guest Execution Preparation Commands

HV10 adds a real `GuestExecutionGate` preparation object for VM 0 / vCPU 0. It collects the software execution path that future guest entry will need: VM/vCPU presence, HV4 guest memory, HV5 address-space metadata, HV6 tiny image state, HV7 entry frame, HV8 exit metadata, and HV9 no-execute run-attempt arming. It then applies the hardware gate and refuses execution because second-stage translation is missing, H-extension support is not proven, and guest instruction execution remains disabled.

Commands added:

- `hv exec` / `hv-exec` / `hv execution`: print the current execution-gate object, prerequisite booleans, execution-frame snapshot, blocker booleans, counters, and explicit non-claims.
- `hv exec-status` / `hv exec status`: alias for printing the current execution-gate status; increments the gate status counter.
- `hv exec-check` / `hv exec check`: evaluates all software prerequisites, records transition/rejection counters, captures PC/SP/guest-memory/image/exit metadata, and reports whether the request reached the hardware gate.
- `hv exec-arm` / `hv exec arm`: attempts to arm the hardware-gated execution preparation layer. With the current repository state it must produce `armed-blocked`, increment `hardware_block_count`, and report missing second-stage translation / unknown H-extension / disabled guest execution instead of entering a guest.
- `hv exec-blockers` / `hv exec blockers`: recomputes blockers and exposes the current execution-blocker list without claiming execution.
- `hv exec-reset` / `hv exec reset`: clears the gate state back to `cold` and increments `reset_count` while preserving historical accounting.
- `hv exec-require-prereq-test` / `hv exec require-prereq-test`: resets HV7 entry metadata and proves the execution gate rejects arming when a required software prerequisite is missing.

Smoke proof: `./smoke/smoke-hv-guest-execution-v0.sh` writes `smoke/transcripts/latest-hv-guest-execution-v0.txt` and verifies object mutations, state transitions, prerequisite truth values, execution-frame fields, hardware-gate blockers, counter increments, reset behavior, and continued non-support for guest instruction execution, Linux guests, second-stage translation, and H-extension presence.

HV10 does **not** enter guest code, does **not** jump to guest memory, does **not** increment `vcpu.run_count`, does **not** boot Linux, does **not** implement second-stage translation, and does **not** prove RISC-V H-extension support.

## HV11 Second-Stage Translation Metadata Commands

HV11 adds a real executing metadata subsystem in `kernel/hypervisor/second_stage.zig`. It derives a VM 0 second-stage mapping record from the already configured HV4 guest-memory object and HV5 guest address-space metadata. These commands **do not** activate hardware second-stage translation, **do not** write `hgatp`, **do not** prove the RISC-V H-extension, **do not** execute a guest, and **do not** support Linux guests.

New commands:

- `hv second-stage`: print the current second-stage metadata object, mapping fields, counters, and explicit non-claims. It reports metadata state only; it does not imply active translation.
- `hv-stage2`: flat alias for `hv second-stage`.
- `hv second-stage configure`: require configured HV4 guest memory and configured HV5 address-space metadata, then derive a metadata-only mapping with guest base, guest size, guest page count, host base, host size, page size, read/write permissions, execute=false, active=false, and validated metadata.
- `hv second-stage validate`: revalidate the current metadata mapping against the live guest-memory and address-space objects.
- `hv second-stage lookup-zero`: resolve GPA `0x0` through metadata to a host address inside configured guest memory.
- `hv second-stage lookup-page`: resolve GPA `0x1000` through metadata to the second guest page when the default two-page guest memory configuration exists.
- `hv second-stage bounds-test`: attempt an out-of-range GPA lookup and require an out-of-bounds rejection.
- `hv second-stage alignment-test`: validate intentionally unaligned mapping metadata and require a misalignment rejection.
- `hv second-stage execute-permission-test`: prove execute permission is not silently granted; HV11 mappings keep `flags_execute=false` and reject execute permission.
- `hv second-stage reset`: clear metadata back to inactive state while preserving reset statistics.

Smoke proof: `./smoke/smoke-hv-second-stage-v0.sh` writes `smoke/transcripts/latest-hv-second-stage-v0.txt` and checks command blocks for real state transitions, mapping values, lookup behavior, rejection behavior, reset behavior, and continued non-support for guest execution, Linux guests, H-extension presence, and active second-stage translation.

## HV12 software-only second-stage table commands

These commands exercise the HV12 software-owned second-stage page-table-like builder. They do **not** activate hardware second-stage translation, do **not** write `hgatp`, do **not** prove the RISC-V H extension, do **not** execute a guest, and do **not** imply Linux guest support.

- `hv stage2-table` / `hv-stage2-table` — prints the current software table state, entries, counters, and explicit non-claims.
- `hv stage2-table build` — requires HV11 second-stage metadata to be `metadata-ready`, derives one software entry per configured guest page, preserves read/write permissions, and forces execute permission off.
- `hv stage2-table validate` — validates the built software entries against the live HV11 metadata and guest-memory page list.
- `hv stage2-table walk-zero` — walks GPA `0x0` through the software table and reports the matching host page.
- `hv stage2-table walk-page` — walks GPA `0x1000` through the software table and reports the second host page.
- `hv stage2-table bounds-test` — attempts an out-of-range GPA walk and must report rejection.
- `hv stage2-table alignment-test` — attempts an unaligned GPA walk and must report rejection.
- `hv stage2-table execute-permission-test` — attempts an execute-qualified walk and must report rejection because HV12 entries are non-executable.
- `hv stage2-table reset` — clears all software entries and returns the table to `empty`.


## HV13 Guest Boot Package Contract commands

HV13 adds a real guest boot package object for VM 0. Readiness is computed from the object fields and active guest-memory limits. These commands do **not** boot Linux, execute guests, activate second-stage translation, write `hgatp`, or claim H-extension support.

- `hv bootpkg` / `hv-bootpkg` / `hv bootpkg status`: print boot package ownership, guest-memory bounds, kernel/initrd/DTB ranges, command line, readiness, blockers, counters, and non-claims.
- `hv bootpkg attach-kernel`: ensure the existing HV6 `tiny-flat-v0` image is loaded and attach its load GPA and byte range as kernel-like metadata.
- `hv bootpkg set-entry`: set and validate the kernel entry GPA using the HV6 tiny entry point.
- `hv bootpkg set-cmdline <text>`: store a command line in the fixed HV13 command-line buffer; rejects oversized lines.
- `hv bootpkg attach-initrd`: attach default initrd metadata at GPA `0x1000` with numeric bounds and overlap validation.
- `hv bootpkg attach-dtb`: attach default DTB metadata at GPA `0x1800` with numeric bounds and overlap validation.
- `hv bootpkg validate`: recompute readiness from kernel presence, entry GPA, guest-memory bounds, non-overlap of active ranges, and command-line validity.
- `hv bootpkg blockers`: print deterministic readiness blockers computed from the current object.
- `hv bootpkg overlap-test`: execute a real overlapping metadata attach and require rejection.
- `hv bootpkg bounds-test`: execute a real out-of-bounds metadata attach and require rejection.
- `hv bootpkg reset`: clear the package back to empty and not-ready.

HV13 smoke and validation entries:

- `./smoke/smoke-hv-boot-package-v0.sh`: behavior smoke proof with transcript `smoke/transcripts/latest-hv-boot-package-v0.txt`.
- `./scripts/validate-hyperzig.sh`: includes the HV13 smoke in the required validation ladder.
- `zig build validate-hyperzig`: runs the canonical validation script through the Zig build target.

## HV14 Guest DTB Contract Commands

HV14 adds a real structured guest DTB contract object derived from the HV13 boot package. These commands do not boot Linux, do not execute a guest, do not activate second-stage translation, and do not implement SBI.

- `hv dtb` / `hv-dtb` / `hv dtb status`: print DTB contract ownership, payload GPA/size, guest-memory bounds, bootargs, memory/cpu/chosen/initrd/console metadata, blockers, and non-claims.
- `hv dtb build`: require a ready HV13 boot package, copy HV13 bootargs, derive guest memory and initrd metadata, place the DTB payload metadata at a checked GPA, and reject kernel/initrd overlaps.
- `hv dtb validate`: recompute readiness from DTB fields and deterministic blockers.
- `hv dtb blockers`: print computed blockers.
- `hv dtb nodes`: print structured `/memory`, `/cpus/cpu@0`, `/chosen`, initrd, console, timer, and interrupt-controller metadata.
- `hv dtb bounds-test`: execute a numeric out-of-guest-memory DTB placement rejection.
- `hv dtb overlap-test`: execute a numeric kernel-overlap DTB placement rejection.
- `hv dtb reset`: clear the DTB contract back to empty/not-ready.

Smoke proof: `./smoke/smoke-hv-dtb-contract-v0.sh` writes `smoke/transcripts/latest-hv-dtb-contract-v0.txt` and is included in `./scripts/validate-hyperzig.sh` and `zig build validate-hyperzig`.

## HV15 SBI Foundation commands

HV15 adds a real SBI foundation object for VM 0 / vCPU 0. It records and validates SBI-shaped requests, tracks argument registers, return/error values, request counters, validation counters, rejection counters, and extension capability metadata. It does **not** implement SBI services, Linux guest support, guest execution, hgatp writes, or active second-stage translation.

- `hv sbi` / `hv-sbi` / `hv sbi status`: prints SBI foundation state and base/timer/legacy-console extension metadata.
- `hv sbi validate`: validates the currently recorded SBI request and rejects if no request has been recorded.
- `hv sbi reset`: clears recorded request state and counters while incrementing the SBI reset counter.
- `hv sbi blockers`: validates current state and prints the current validation blocker.
- `hv sbi base-test`: records and validates an SBI base-extension metadata request.
- `hv sbi timer-test`: records and validates an SBI timer-extension metadata request without implementing a timer service.
- `hv sbi console-test`: records and validates a legacy console-extension metadata request without implementing console service.

Smoke proof: `./smoke/smoke-hv-sbi-foundation-v0.sh` writes `smoke/transcripts/latest-hv-sbi-foundation-v0.txt` and checks state transitions, counters, validation success, reset behavior, and rejection behavior.


## HV16 Virtual Timer / SBI Timer Mediation Prerequisites commands

HV16 adds executable virtual timer metadata connected to the HV15 SBI foundation path. These commands do not inject timer interrupts, do not execute guests, do not boot Linux, do not activate second-stage translation, and do not implement full SBI services.

- `hv timer` / `hv-timer` / `hv timer status`: print virtual timer ownership, armed/pending state, compare value, counters, validation result, deterministic blockers, and non-claims.
- `hv timer arm`: arm the virtual timer with the default behavior-test compare value through the SBI timer path.
- `hv timer validate`: validate the current virtual timer object from live fields.
- `hv timer blockers`: report deterministic blockers computed from live object fields.
- `hv timer pending-test`: arm a timer and compute not-pending/pending results from numeric host tick and guest compare comparisons.
- `hv timer sbi-set-test`: record a valid SBI timer set request through the HV15 SBI foundation and arm the virtual timer.
- `hv timer invalid-test`: submit an invalid zero timer value through the HV15 path and prove rejection counters change.
- `hv timer reset`: clear the virtual timer back to empty, not armed, and not pending.
- `./smoke/smoke-hv-virtual-timer-v0.sh`: QEMU smoke proof for HV16 virtual timer behavior and non-claims.
- `./scripts/validate-hyperzig.sh`: includes the HV16 smoke in the required validation ladder.
- `zig build validate-hyperzig`: runs the canonical validator after building.

## HV17 Binary FDT / Device Tree Blob Encoder Foundation commands

HV17 adds an executable, byte-backed binary FDT encoder derived from the HV14 DTB contract. It writes an in-memory flattened-device-tree-shaped buffer, computes header offsets and sizes, interns property names into a string table, counts encoded nodes/properties, and exposes checksum proof. These commands do **not** boot Linux, do **not** execute guests, do **not** activate second-stage translation, do **not** write `hgatp`, and do **not** prove Linux accepts the FDT.

- `hv fdt` / `hv-fdt` / `hv fdt status`: print FDT encoder state, encoded length, header fields, counters, copied bootargs, node metadata, checksum, and non-claims.
- `hv fdt build`: require a ready HV14 DTB contract, encode the root, `/memory`, `/cpus`, `/cpus/cpu@0`, and `/chosen` nodes into the owned byte buffer, and reject missing prerequisites.
- `hv fdt validate`: validate header consistency, block boundaries, total size, and minimum encoded counters from the byte-backed object.
- `hv fdt header`: print FDT magic, total size, structure/string/reservation offsets, version fields, boot CPU ID, and block sizes.
- `hv fdt nodes`: print encoded root, memory, CPU, chosen, bootargs, and initrd metadata flags.
- `hv fdt strings`: print string-table size and property-name-table source.
- `hv fdt checksum`: print encoded byte length and byte-sum checksum proof.
- `hv fdt bounds-test`: execute a too-small-buffer rejection path.
- `hv fdt missing-contract-test`: reset HV14 and prove the FDT build rejects a missing DTB contract.
- `hv fdt reset`: clear the encoded buffer and return to empty/not-built state.

HV17 smoke and validation entries:

- `./smoke/smoke-hv-binary-fdt-v0.sh`: behavior smoke proof with transcript `smoke/transcripts/latest-hv-binary-fdt-v0.txt`.
- `./scripts/validate-hyperzig.sh`: includes the HV17 smoke in the required validation ladder.
- `zig build validate-hyperzig`: runs the canonical validation script through the Zig build target.

## HV18 Linux Handoff Package Validation Foundation commands

HV18 adds a stateful Linux-shaped handoff validation package. These commands assemble and validate metadata only; they do **not** boot Linux, execute a guest, write `hgatp`, activate second-stage translation, or prove Linux accepts the FDT.

- `hv handoff`, `hv-handoff`, `hv handoff status`: print current handoff state, ranges, counters, blockers, and non-claims.
- `hv handoff prepare`: execute the prerequisite ladder (guest memory/image, HV13 boot package, HV14 DTB contract, HV17 binary FDT, guest-entry metadata, SBI/timer metadata, software stage2 metadata) and assemble the handoff package.
- `hv handoff validate`: validate the current handoff package from actual subsystem state.
- `hv handoff blockers`: print computed readiness blockers.
- `hv handoff ranges`: print guest-memory, kernel, initrd, and FDT handoff ranges.
- `hv handoff summary`: print owner, ranges, FDT header summary, bootargs, guest PC/SP, counters, and readiness.
- `hv handoff overlap-test`: mutate handoff metadata through Zig logic and prove overlap rejection.
- `hv handoff bounds-test`: mutate handoff metadata through Zig logic and prove bounds rejection.
- `hv handoff missing-fdt-test`: reset the HV17 FDT object and prove missing-FDT rejection.
- `hv handoff missing-bootpkg-test`: reset the HV13 boot package and prove missing-boot-package rejection.
- `hv handoff reset`: clear the handoff object back to empty/not-ready state.

New script and validation entry:

- `./smoke/smoke-hv-linux-handoff-v0.sh`: behavior smoke for HV18.
- `./scripts/validate-hyperzig.sh`: now includes `smoke/smoke-hv-linux-handoff-v0.sh` in the required hypervisor ladder.
- `zig build validate-hyperzig`: runs the canonical validator including HV18.

## HV19 SBI Console Mediation Foundation commands

HV19 adds a real byte-backed SBI console mediation object connected to the HV15 SBI foundation. These commands model legacy SBI console metadata and buffering only. They do **not** boot Linux, execute guests, activate second-stage translation, claim full SBI services, implement DBCN, or prove `printk` works.

- `hv console` / `hv-console` / `hv console status`: print owner VM/vCPU IDs, mediation state, last SBI extension/function, last operation/character, counters, output buffer length/capacity/byte-sum, output bytes, deterministic no-input accounting, blockers, and non-claims.
- `hv console putchar-test`: record one legacy SBI console putchar request through the HV15 SBI path and append `A` to the byte-backed output buffer.
- `hv console putstring-test`: record multiple putchar operations through the same mediation object and preserve byte order in the output buffer.
- `hv console getchar-test`: record a legacy SBI console getchar request and return deterministic no-input/unavailable behavior.
- `hv console invalid-test`: reject unsupported legacy console function metadata and an invalid extension ID.
- `hv console overflow-test`: fill the real output buffer to capacity and reject the next putchar as overflow.
- `hv console validate`: validate the current console mediation request state and reject the empty/no-request state deterministically.
- `hv console blockers`: report deterministic blockers for the current mediation state.
- `hv console buffer`: inspect the current output buffer, length, capacity, and byte-sum computed from buffered bytes.
- `hv console reset`: clear buffered bytes and counters back to empty state while incrementing/reset-reporting reset generation honestly.

Validation additions:

- `./smoke/smoke-hv-sbi-console-v0.sh`: behavior smoke for HV19; writes `smoke/transcripts/latest-hv-sbi-console-v0.txt` from executed QEMU shell commands.
- `./scripts/validate-hyperzig.sh`: now includes the HV19 SBI console smoke in the required validation ladder.
- `zig build validate-hyperzig`: runs the canonical validation script, including HV19, through the build graph.


## HV20 SBI Dispatch Integration Foundation commands

HV20 adds a real dispatcher for modeled SBI request objects. The dispatcher routes supported metadata into the existing HV15 SBI foundation, HV16 virtual timer foundation, and HV19 SBI console mediation foundation. These commands do not imply Linux boot, guest execution, active second-stage translation, H-extension support, full SBI services, timer interrupt injection, or printk support.

### Shell commands

- `hv sbi-dispatch` / `hv-dispatch` / `hv sbi-dispatch status`: print dispatcher owner, state, last request/result metadata, argument registers, target counters, validation/rejection counters, reset count, blockers, and non-claims.
- `hv sbi-dispatch base-test`: route a modeled SBI base extension request into the HV15 SBI foundation and prove the HV15 request state/counters changed.
- `hv sbi-dispatch timer-test`: route a modeled SBI timer request into the HV16 virtual timer mediation layer and prove timer metadata/counters changed.
- `hv sbi-dispatch console-putchar-test`: route a modeled legacy console putchar request into HV19 console mediation and prove the output buffer changes.
- `hv sbi-dispatch console-getchar-test`: route a modeled legacy console getchar request into HV19 console mediation and prove deterministic no-input metadata.
- `hv sbi-dispatch unknown-test`: reject an unknown SBI extension ID and increment rejection/unknown counters through the dispatcher.
- `hv sbi-dispatch unsupported-function-test`: reject an unsupported function ID for a known extension and increment rejection counters.
- `hv sbi-dispatch validate`: dispatch the current request object or reject deterministically when no request is present.
- `hv sbi-dispatch blockers`: print deterministic blocker state derived from dispatcher metadata.
- `hv sbi-dispatch reset`: reset dispatcher state and counters back to an empty object while preserving reset accounting.

### Scripts and validation entries

- `./smoke/smoke-hv-sbi-dispatch-v0.sh`: behavior smoke for HV20; generates `smoke/transcripts/latest-hv-sbi-dispatch-v0.txt` from actual QEMU shell commands.
- `./scripts/validate-hyperzig.sh`: now includes HV20 as a required smoke milestone and reports its transcript path.
- `zig build validate-hyperzig`: continues to invoke the canonical validation script, now including HV20.


## HV21 Guest Context Switch Preparation Foundation commands

HV21 adds a real software guest context preparation object. It derives the future guest-entry register frame from existing guest-entry and Linux-shaped handoff metadata, checks stage2 metadata/table readiness and SBI dispatch readiness, and keeps all non-claims active. These commands do not boot Linux, execute a guest, enter guest mode, perform a trap return, activate second-stage translation, write `hgatp`, or prove printk.

- `hv context` / `hv-context` / `hv context status`: print context state, readiness, counters, deterministic blocker state, and non-claims.
- `hv context prepare`: build missing HV13-HV20 prerequisites through existing command paths where required, assemble the context frame, validate it, and print derived registers/ranges.
- `hv context validate`: validate the current context and reject deterministic missing or malformed state.
- `hv context blockers`: print blocker state derived from the current context and prerequisite subsystem state.
- `hv context registers`: print derived `pc`, `sp`, Linux-style `a0` boot hart ID, `a1` FDT GPA, reserved `a2`, status metadata, and privilege metadata.
- `hv context ranges`: print guest memory bounds, kernel entry GPA, FDT GPA, and initrd range recorded in the context.
- `hv context require-handoff-test`: reset the HV18 handoff package and prove context validation rejects when handoff metadata is missing.
- `hv context require-fdt-test`: reset the binary FDT and prove context validation rejects when FDT metadata is missing.
- `hv context bounds-test`: corrupt a prepared context stack pointer and prove range validation rejects the malformed context.
- `hv context reset`: clear context state to an empty object while preserving reset accounting.

Validation entries added by HV21:

- `./smoke/smoke-hv-guest-context-v0.sh`: behavior smoke for HV21; generates `smoke/transcripts/latest-hv-guest-context-v0.txt` from actual QEMU shell commands.
- `./scripts/validate-hyperzig.sh`: includes HV21 as a required smoke milestone and reports its transcript path.
- `zig build validate-hyperzig`: invokes the canonical validation script including HV21.

## HV23 Guest Entry Assembly Preparation commands

HV23 adds a software-only guest-entry assembly preparation object derived from the HV22 guarded trap-return plan. These commands build, validate, inspect, reject, attempt safely, and reset entry-stub preparation metadata only. They do not boot Linux, execute guests, enter guest mode, execute a trap return, write `hgatp`, activate second-stage translation, or claim H-extension support.

- `hv entry-stub` / `hv-entry-stub` / `hv entry-stub status`: print entry-stub state, counters, blockers, gates, and non-claims.
- `hv entry-stub prepare`: prepare HV22 trap-plan prerequisites if needed, derive planned PC/SP/a0/a1/a2 and gate metadata, compute the software-only entry-stub descriptor checksum, and validate the object.
- `hv entry-stub validate`: validate the current entry-stub plan and mutate validation/rejection counters.
- `hv entry-stub blockers`: print deterministic blockers from current entry-stub state.
- `hv entry-stub registers`: print derived planned registers and status/privilege/trap-return/entry-mode metadata.
- `hv entry-stub gates`: print stage2 readiness, active-stage2 forbidden, hgatp forbidden, H-extension unknown, execution-gate, run-attempt-gate, and SBI dispatch metadata.
- `hv entry-stub descriptor`: print software-only entry-stub address, size, kind, and checksum metadata.
- `hv entry-stub checksum`: recompute and print the deterministic entry-stub checksum from derived fields.
- `hv entry-stub attempt`: model a guarded entry-stub attempt and safely deny it without executing a stub, trap return, or guest instruction.
- `hv entry-stub require-plan-test`: prove rejection when the HV22 trap plan is missing.
- `hv entry-stub pc-bounds-test`: prove rejection when planned PC is outside guest memory.
- `hv entry-stub sp-bounds-test`: prove rejection when planned SP is outside guest memory.
- `hv entry-stub fdt-bounds-test`: prove rejection when planned FDT register `a1` is outside guest memory.
- `hv entry-stub active-stage2-test`: prove rejection when active-stage2 metadata is falsely marked active.
- `hv entry-stub reset`: clear the entry-stub object to empty while incrementing the reset counter.

## HV23 validation entries

- `./smoke/smoke-hv-entry-stub-v0.sh`: behavior-based HV23 smoke proof with generated transcript at `smoke/transcripts/latest-hv-entry-stub-v0.txt`.
- `./scripts/validate-hyperzig.sh`: includes `smoke/smoke-hv-entry-stub-v0.sh` in the required hypervisor validation ladder.
- `zig build validate-hyperzig`: runs the same validation ladder through `build.zig`.


## HV24 H-Extension Discovery and Hypervisor CSR Safety commands

- `hv h-ext` / `hv-hext` / `hv h-ext status`: print the current H-extension discovery object state, owner IDs, safety policy, counters, blockers, and non-claims.
- `hv h-ext discover`: execute the safe discovery path. When no proven safe H-CSR probe exists, it blocks unsafe reads, records `h_extension_status=unknown`, marks H-CSRs as `blocked-by-safety-policy`, and exposes `no-safe-h-csr-probe`.
- `hv h-ext validate`: validate the discovery object and reject empty or inconsistent state.
- `hv h-ext blockers`: print deterministic blocker state.
- `hv h-ext csr-table`: print tracked CSR read statuses for hgatp, hstatus, hedeleg, hideleg, hvip, hie, htval, htinst, vscause, vstval, vsstatus, vstvec, and vsepc.
- `hv h-ext safety`: print the CSR safety policy and active-stage2 non-claim.
- `hv h-ext fake-detected-test`: prove unsupported fake detection is rejected.
- `hv h-ext unsafe-probe-test`: prove unsafe forced probing is rejected.
- `hv h-ext reset`: reset discovery state to empty.

HV24 validation entries:

- `./smoke/smoke-hv-h-extension-v0.sh`: behavior-based HV24 smoke proof with generated transcript at `smoke/transcripts/latest-hv-h-extension-v0.txt`.
- `./scripts/validate-hyperzig.sh`: includes `smoke/smoke-hv-h-extension-v0.sh` in the required hypervisor validation ladder.
- `zig build validate-hyperzig`: runs the same validation ladder through `build.zig`.

## HV25 Software HGATP Candidate Commands

HV25 adds a software-only HGATP candidate object. These commands build, validate, inspect, reset, and corrupt that candidate through real subsystem logic. They do not write `hgatp`, do not activate stage-2 translation, do not enter a guest, and do not execute guest instructions.

- `hv hgatp` / `hv-hgatp` / `hv hgatp status`: print current software-only HGATP candidate state, counters, blocker, and safety policy.
- `hv hgatp build`: derive VMID, root PPN, mode, sources, candidate value, and checksum from existing VM, vCPU, guest address-space, HV11 second-stage metadata, HV12 software table, and HV24 H-extension safety state.
- `hv hgatp validate`: validate the current candidate without writing any CSR.
- `hv hgatp blockers`: validate and print the actual blocker from candidate state.
- `hv hgatp fields`: print mode, VMID, root table GPA, root PPN, candidate value, and checksum.
- `hv hgatp checksum`: print the deterministic checksum.
- `hv hgatp reset`: clear the candidate back to empty state.
- `hv hgatp invariant-lifecycle-test`: run lifecycle invariants directly against the subsystem.
- `hv hgatp invariant-derivation-test`: run VMID and root-PPN mutation invariants directly against the subsystem.
- `hv hgatp invariant-corruption-test`: run corruption rejection invariants directly against the subsystem.
- `hv hgatp mode-test`: corrupt mode and print the blocker recorded by validation.
- `hv hgatp ppn-alignment-test`: corrupt root PPN alignment and print the blocker recorded by validation.
- `hv hgatp vmid-bounds-test`: corrupt VMID bounds and print the blocker recorded by validation.
- `hv hgatp require-hext-test`: remove H-extension discovery source and print the blocker recorded by validation.
- `hv hgatp write-attempt-test`: mark a software write-attempt flag and print the blocker recorded by validation.
- `hv hgatp active-stage2-test`: mark a software active-stage2 flag and print the blocker recorded by validation.

Smoke proof: `./smoke/smoke-hv25-hgatp-candidate-v0.sh` and `./smoke/smoke-hv25-hgatp-negative-v0.sh`.


## HV26 External-State HGATP Activation Readiness Observer Commands

HV26 adds a software-only readiness observer in `kernel/hypervisor/hgatp_activation_readiness.zig`. It consumes existing VM, vCPU, HV25 HGATP candidate, second-stage metadata, software stage2 table, and HV24 H-extension/CSR-safety state. It computes source presence, source validity, source fingerprints, blockers, next action, checksum, readiness state, and non-claim policy fields without building, validating, resetting, repairing, or mutating prerequisite subsystems. These commands do not boot Linux, boot BusyBox, boot Alpine, execute guest instructions, enter guest mode, execute a trap return, write `hgatp`, activate second-stage translation, or prove active virtualization.

- `hv hgatp-readiness` / `hv-hgatp-readiness` / `hv hgatp-readiness status`: print the current readiness observer state, counters, blocker, source summary, source fingerprint checksums, and non-claim policy.
- `hv hgatp-readiness build`: observe existing prerequisite state, capture source fingerprints before and after observation, compute readiness and next action, and reject if the observed source fingerprint changes.
- `hv hgatp-readiness validate`: validate only the readiness object; it does not validate prerequisite subsystems.
- `hv hgatp-readiness blockers`: print the current readiness blocker and blocker count.
- `hv hgatp-readiness next`: print the computed next action.
- `hv hgatp-readiness checksum`: print the deterministic readiness checksum.
- `hv hgatp-readiness reset`: reset only the readiness observer object.
- `hv hgatp-readiness invariant-lifecycle-test`: run readiness object lifecycle invariants.
- `hv hgatp-readiness invariant-consumption-test`: prove readiness observes the current HV25 candidate checksum rather than inventing one.
- `hv hgatp-readiness invariant-corruption-test`: run readiness-local corruption rejection invariants.
- `hv hgatp-readiness require-candidate-test`: corrupt only the readiness-local candidate-present observation and print the resulting blocker.
- `hv hgatp-readiness invalid-candidate-test`: corrupt only the readiness-local candidate-valid observation and print the resulting blocker.
- `hv hgatp-readiness require-stage2-test`: corrupt only the readiness-local second-stage metadata observation and print the resulting blocker.
- `hv hgatp-readiness require-table-test`: corrupt only the readiness-local software stage2 table observation and print the resulting blocker.
- `hv hgatp-readiness require-hext-test`: corrupt only the readiness-local H-extension discovery observation and print the resulting blocker.
- `hv hgatp-readiness require-csr-safety-test`: corrupt only the readiness-local CSR-safety observation and print the resulting blocker.
- `hv hgatp-readiness write-attempt-test`: corrupt only the readiness-local HGATP-write-attempt observation and print the resulting blocker.
- `hv hgatp-readiness active-stage2-test`: corrupt only the readiness-local active-stage2 observation and print the resulting blocker.
- `hv hgatp-readiness source-integrity-test`: corrupt only the readiness-local source-fingerprint-unchanged observation and print the resulting blocker.

Smoke proof: `./smoke/smoke-hv26-hgatp-readiness-v0.sh` and `./smoke/smoke-hv26-hgatp-readiness-negative-v0.sh`.

## HV27 Guarded HGATP Write Plan Commands

HV27 adds a software-only guarded HGATP write-plan object. It consumes externally produced HV25 HGATP candidate state and HV26 readiness state, computes planned HGATP metadata, blockers, next action, checksum, and source-integrity fingerprints. It does not write `hgatp`, activate second-stage translation, enter a guest, execute guest instructions, or execute trap return.

- `hv hgatp-write-plan` / `hv-hgatp-write-plan` / `hv hgatp-write-plan status`: print plan status, blockers, source observations, and policy fields.
- `hv hgatp-write-plan build`: observe current prerequisite state and build a side-effect-free software-only write plan.
- `hv hgatp-write-plan validate`: validate only the existing write-plan object.
- `hv hgatp-write-plan blockers`: print the current deterministic blocker.
- `hv hgatp-write-plan next`: print the next action implied by the blocker.
- `hv hgatp-write-plan checksum`: print the plan checksum.
- `hv hgatp-write-plan reset`: reset only the write-plan object.
- `hv hgatp-write-plan fields`: print observed sources and planned HGATP fields.
- `hv hgatp-write-plan invariant-lifecycle-test`: exercise reset/build/validate lifecycle behavior.
- `hv hgatp-write-plan invariant-consumption-test`: prove the plan consumes the current candidate checksum.
- `hv hgatp-write-plan invariant-corruption-test`: prove local corruption changes validation blockers.
- `hv hgatp-write-plan require-candidate-test`: corrupt the local candidate-present observation.
- `hv hgatp-write-plan invalid-candidate-test`: corrupt the local candidate-valid observation.
- `hv hgatp-write-plan require-readiness-test`: corrupt the local readiness-present observation.
- `hv hgatp-write-plan invalid-readiness-test`: corrupt the local readiness-valid observation.
- `hv hgatp-write-plan require-hext-test`: corrupt the local H-extension discovery observation.
- `hv hgatp-write-plan require-csr-safety-test`: corrupt the local CSR-safety observation.
- `hv hgatp-write-plan source-integrity-test`: corrupt the local source-fingerprint comparison.
- `hv hgatp-write-plan write-allowed-test`: corrupt the local write-allowed policy field.
- `hv hgatp-write-plan write-attempt-test`: corrupt the local write-attempt observation.
- `hv hgatp-write-plan active-stage2-test`: corrupt the local active-stage2 observation.
- `hv hgatp-write-plan require-stage2-metadata-test`: corrupt the local second-stage metadata observation.
- `hv hgatp-write-plan require-stage2-table-test`: corrupt the local stage2 table observation.
- `hv hgatp-write-plan readiness-not-ready-test`: corrupt the local future-guarded-write readiness observation.

## HV28 Guarded HGATP Write Gate commands

HV28 adds a software-only guarded HGATP write gate. The gate consumes externally produced HV27 write-plan state and H-extension/CSR-safety state, fingerprints prerequisite sources before and after observation, computes blockers, computes a next action and checksum, and always blocks current write requests before the hardware boundary. It does not write `hgatp`, reach the hardware write boundary, activate second-stage translation, enter a guest, execute guest instructions, execute trap return, or boot any guest OS.

- `hv hgatp-write-gate` / `hv-hgatp-write-gate` / `hv hgatp-write-gate status`: print gate status, source observations, policy fields, and blocker.
- `hv hgatp-write-gate build`: observe current prerequisite state and build only the write-gate object.
- `hv hgatp-write-gate validate`: validate only the existing write-gate object.
- `hv hgatp-write-gate blockers`: print the current deterministic blocker.
- `hv hgatp-write-gate next`: print the next action implied by the blocker.
- `hv hgatp-write-gate checksum`: print the gate checksum.
- `hv hgatp-write-gate reset`: reset only the write-gate object.
- `hv hgatp-write-gate fields`: print observed write-plan fields, source fingerprints, and gate policy fields.
- `hv hgatp-write-gate decision`: print the software-only gate decision.
- `hv hgatp-write-gate invariant-lifecycle-test`: exercise reset/build/validate lifecycle behavior.
- `hv hgatp-write-gate invariant-consumption-test`: prove the gate consumes the current HV27 write-plan checksum.
- `hv hgatp-write-gate invariant-corruption-test`: prove local corruption changes validation blockers.
- `hv hgatp-write-gate require-plan-test`: corrupt the local write-plan-present observation.
- `hv hgatp-write-gate invalid-plan-test`: corrupt the local write-plan-valid observation.
- `hv hgatp-write-gate require-hext-test`: corrupt the local H-extension discovery observation.
- `hv hgatp-write-gate require-csr-safety-test`: corrupt the local CSR-safety observation.
- `hv hgatp-write-gate source-integrity-test`: corrupt the local source-fingerprint comparison.
- `hv hgatp-write-gate boundary-attempt-test`: corrupt the local hardware-boundary observation.
- `hv hgatp-write-gate write-attempt-test`: corrupt the local write-attempt observation.
- `hv hgatp-write-gate write-performed-test`: corrupt the local write-performed observation.
- `hv hgatp-write-gate active-stage2-test`: corrupt the local active-stage2 observation.

## HV29 HGATP Hardware Boundary Preparation commands

HV29 adds a software-only HGATP hardware-facing write-boundary object. The boundary consumes externally produced HV28 write-gate state, captures prerequisite fingerprints before and after observation, constructs a boundary request from the observed planned HGATP value, denies that request before hardware, computes blockers, computes next action, and computes a checksum. It does not write `hgatp`, reach the hardware write boundary, activate second-stage translation, enter a guest, execute guest instructions, execute trap return, or boot any guest OS.

- `hv hgatp-write-boundary` / `hv-hgatp-write-boundary` / `hv hgatp-write-boundary status`: print boundary status, source observations, request policy, and blocker.
- `hv hgatp-write-boundary build`: observe current HV28 write-gate state and build only the boundary object.
- `hv hgatp-write-boundary validate`: validate only the existing boundary object.
- `hv hgatp-write-boundary blockers`: print the current deterministic blocker.
- `hv hgatp-write-boundary next`: print the next action implied by the blocker.
- `hv hgatp-write-boundary checksum`: print the boundary checksum.
- `hv hgatp-write-boundary reset`: reset only the boundary object.
- `hv hgatp-write-boundary fields`: print observed write-gate fields, source fingerprints, and request policy fields.
- `hv hgatp-write-boundary request`: print the constructed request value, request checksum, deny/allow counters, and non-activation policy fields.
- `hv hgatp-write-boundary decision`: print the software-only boundary decision.
- `hv hgatp-write-boundary invariant-lifecycle-test`: exercise reset/build/validate lifecycle behavior.
- `hv hgatp-write-boundary invariant-consumption-test`: prove the boundary consumes the current HV28 write-gate checksum and planned HGATP value.
- `hv hgatp-write-boundary invariant-corruption-test`: prove boundary-local corruption changes validation blockers.
- `hv hgatp-write-boundary require-gate-test`: corrupt the local write-gate-present observation.
- `hv hgatp-write-boundary invalid-gate-test`: corrupt the local write-gate-valid observation.
- `hv hgatp-write-boundary gate-allows-boundary-test`: corrupt the local gate-allows-hardware-boundary observation.
- `hv hgatp-write-boundary source-integrity-test`: corrupt the local source-fingerprint comparison.
- `hv hgatp-write-boundary request-value-test`: corrupt the local request value observation.
- `hv hgatp-write-boundary boundary-allowed-test`: corrupt the local boundary-request-allowed policy field.
- `hv hgatp-write-boundary boundary-reached-test`: corrupt the local hardware-boundary-reached policy field.
- `hv hgatp-write-boundary write-attempt-test`: corrupt the local write-attempt observation.
- `hv hgatp-write-boundary write-performed-test`: corrupt the local write-performed observation.
- `hv hgatp-write-boundary active-stage2-test`: corrupt the local active-stage2 observation.

Smoke proof: `./smoke/smoke-hv29-hgatp-write-boundary-v0.sh` and `./smoke/smoke-hv29-hgatp-write-boundary-negative-v0.sh`.

## HV30 Guarded HGATP Write Attempt commands

HV30 adds a software-only guarded HGATP write-attempt object. The attempt consumes externally produced HV29 write-boundary state, fingerprints the HV29 checksum, HV29 request checksum, HV29 request value, HV29 ready flag, HV29 boundary state, VM ID, and vCPU ID before and after observation, constructs a denied attempt request, and stops before any CSR write function can be called. It does not write `hgatp`, activate second-stage translation, enter a guest, execute guest instructions, execute trap return, or boot any guest OS.

- `hv hgatp-write-attempt` / `hv-hgatp-write-attempt` / `hv hgatp-write-attempt status`: print attempt status, HV29 source observations, request policy fields, and blocker.
- `hv hgatp-write-attempt build`: observe current HV29 write-boundary state and build only the HV30 write-attempt object.
- `hv hgatp-write-attempt validate`: validate only the existing write-attempt object.
- `hv hgatp-write-attempt blockers`: print the current deterministic blocker.
- `hv hgatp-write-attempt next`: print the next action implied by the blocker.
- `hv hgatp-write-attempt checksum`: print the attempt checksum.
- `hv hgatp-write-attempt reset`: reset only the attempt object.
- `hv hgatp-write-attempt fields`: print observed HV29 boundary fields and source fingerprints.
- `hv hgatp-write-attempt request`: print attempt request checksum and no-CSR/no-write/no-activation policy fields.
- `hv hgatp-write-attempt decision`: print the software-only denial decision.
- `hv hgatp-write-attempt require-boundary-test`: corrupt the local boundary-present observation.
- `hv hgatp-write-attempt source-integrity-test`: corrupt the local source-fingerprint comparison.
- `hv hgatp-write-attempt request-value-test`: corrupt the local request value observation.
- `hv hgatp-write-attempt invariant-consumption-test`: prove the attempt consumes the current HV29 boundary checksum, request value, and ready state.
- `hv hgatp-write-attempt invariant-corruption-test`: prove attempt-local corruption changes validation blockers.

Smoke proof: `./smoke/smoke-hv30-hgatp-write-attempt-v0.sh` and `./smoke/smoke-hv30-hgatp-write-attempt-negative-v0.sh`.

## HV31 Guarded HGATP CSR Interface commands

HV31 adds a guarded HGATP CSR interface object that consumes the existing HV30 write-attempt state and preserves the no-write policy. It exposes the CSR boundary and an isolated dangerous raw-write function in code, but the default command path denies before CSR assembly and reports that the CSR function and raw assembly path were not called.

* `hv hgatp-csr-interface` / `hv-hgatp-csr-interface` / `hv hgatp-csr-interface status` prints HV31 state, source fingerprints, request/result fields, and no-write policy fields.
* `hv hgatp-csr-interface build` observes HV30 state, builds an HV31 request from the HV30 attempted HGATP value/checksums, denies before CSR assembly, and computes result/checksum state.
* `hv hgatp-csr-interface validate` revalidates the current HV31 object.
* `hv hgatp-csr-interface blockers` prints blocker count and blocker name.
* `hv hgatp-csr-interface next` prints the next action.
* `hv hgatp-csr-interface checksum` prints the HV31 checksum.
* `hv hgatp-csr-interface reset` resets only the HV31 object.
* `hv hgatp-csr-interface fields` prints owner, HV30-consumption, CSR-call, raw-assembly, no-write, no-activation, no-guest-entry, and source-fingerprint fields.
* `hv hgatp-csr-interface request` prints the HV31 request value and checksum derived from HV30.
* `hv hgatp-csr-interface result` prints the HV31 result code and result checksum.
* `hv hgatp-csr-interface decision` prints the current decision.
* `hv hgatp-csr-interface require-attempt-test` proves missing HV30 state blocks HV31.
* `hv hgatp-csr-interface source-integrity-test` proves source fingerprint mutation is rejected.
* `hv hgatp-csr-interface request-value-test` proves request-value mismatch is rejected.
* `hv hgatp-csr-interface csr-called-test` proves any observed CSR function call is rejected.
* `hv hgatp-csr-interface raw-asm-called-test` proves any observed raw assembly call is rejected.
* `hv hgatp-csr-interface write-attempted-test` proves any observed HGATP write attempt is rejected.
* `hv hgatp-csr-interface write-performed-test` proves any observed HGATP write completion is rejected.
* `hv hgatp-csr-interface active-stage2-test` proves active second-stage state is rejected.
* `hv hgatp-csr-interface invariant-consumption-test` proves HV31 consumes HV30 value, checksum, request checksum, and readiness state.
* `hv hgatp-csr-interface invariant-corruption-test` proves HV31-local corruption paths reject as expected.

HV31 does not boot Linux, boot BusyBox, boot Alpine, enter guest mode, execute guest instructions, execute trap return, write HGATP, or activate second-stage translation.

## HV32 Guarded HGATP CSR Result/Fault Accounting

New HV32 shell commands:

- `hv hgatp-csr-result`
- `hv-hgatp-csr-result`
- `hv hgatp-csr-result status`
- `hv hgatp-csr-result build`
- `hv hgatp-csr-result validate`
- `hv hgatp-csr-result blockers`
- `hv hgatp-csr-result next`
- `hv hgatp-csr-result checksum`
- `hv hgatp-csr-result reset`
- `hv hgatp-csr-result fields`
- `hv hgatp-csr-result observation`
- `hv hgatp-csr-result trap-slot`
- `hv hgatp-csr-result readback`
- `hv hgatp-csr-result decision`
- `hv hgatp-csr-result require-interface-test`
- `hv hgatp-csr-result invalid-interface-test`
- `hv hgatp-csr-result source-integrity-test`
- `hv hgatp-csr-result request-value-test`
- `hv hgatp-csr-result csr-called-test`
- `hv hgatp-csr-result raw-asm-called-test`
- `hv hgatp-csr-result write-attempted-test`
- `hv hgatp-csr-result write-performed-test`
- `hv hgatp-csr-result fake-fault-test`
- `hv hgatp-csr-result fake-readback-test`
- `hv hgatp-csr-result active-stage2-test`
- `hv hgatp-csr-result guest-entered-test`
- `hv hgatp-csr-result first-instruction-test`
- `hv hgatp-csr-result invariant-consumption-test`
- `hv hgatp-csr-result invariant-corruption-test`

HV32 consumes the already-built HV31 CSR interface and records denied/not-called result accounting, empty trap slots, and readback-not-attempted slots. It does not perform an HGATP write or readback.


## HV33 Guarded HGATP Hardware Write Preparation Foundation

New HV33 shell commands:

- `hv hgatp-hardware-write-prep`
- `hv-hgatp-hardware-write-prep`
- `hv hgatp-hardware-write-prep status`
- `hv hgatp-hardware-write-prep build`
- `hv hgatp-hardware-write-prep validate`
- `hv hgatp-hardware-write-prep blockers`
- `hv hgatp-hardware-write-prep next`
- `hv hgatp-hardware-write-prep checksum`
- `hv hgatp-hardware-write-prep reset`
- `hv hgatp-hardware-write-prep fields`
- `hv hgatp-hardware-write-prep envelope`
- `hv hgatp-hardware-write-prep trap-envelope`
- `hv hgatp-hardware-write-prep readback-envelope`
- `hv hgatp-hardware-write-prep decision`
- `hv hgatp-hardware-write-prep require-result-test`
- `hv hgatp-hardware-write-prep invalid-result-test`
- `hv hgatp-hardware-write-prep source-integrity-test`
- `hv hgatp-hardware-write-prep request-value-test`
- `hv hgatp-hardware-write-prep policy-allows-test`
- `hv hgatp-hardware-write-prep call-reachable-test`
- `hv hgatp-hardware-write-prep call-called-test`
- `hv hgatp-hardware-write-prep raw-write-called-test`
- `hv hgatp-hardware-write-prep fake-trap-test`
- `hv hgatp-hardware-write-prep fake-readback-test`
- `hv hgatp-hardware-write-prep write-attempted-test`
- `hv hgatp-hardware-write-prep write-performed-test`
- `hv hgatp-hardware-write-prep active-stage2-test`
- `hv hgatp-hardware-write-prep guest-entered-test`
- `hv hgatp-hardware-write-prep first-instruction-test`
- `hv hgatp-hardware-write-prep invariant-consumption-test`
- `hv hgatp-hardware-write-prep invariant-corruption-test`

HV33 consumes the existing HV32 CSR result/fault accounting state, builds a guarded hardware-write envelope, and preserves the current no-write policy: hardware calls are blocked before call, raw write is not called, trap/readback envelopes remain empty, and no guest execution or active stage-2 state is claimed.

## HV34 HGATP Hardware Write Operation Framework

New shell commands:

- `hv hgatp-hardware-write-operation`
- `hv-hgatp-hardware-write-operation`
- `hv hgatp-hardware-write-operation status`
- `hv hgatp-hardware-write-operation build`
- `hv hgatp-hardware-write-operation validate`
- `hv hgatp-hardware-write-operation blockers`
- `hv hgatp-hardware-write-operation next`
- `hv hgatp-hardware-write-operation checksum`
- `hv hgatp-hardware-write-operation reset`
- `hv hgatp-hardware-write-operation fields`
- `hv hgatp-hardware-write-operation request`
- `hv hgatp-hardware-write-operation preflight`
- `hv hgatp-hardware-write-operation result`
- `hv hgatp-hardware-write-operation trap-slot`
- `hv hgatp-hardware-write-operation readback`
- `hv hgatp-hardware-write-operation decision`
- `hv hgatp-hardware-write-operation require-prep-test`
- `hv hgatp-hardware-write-operation invalid-prep-test`
- `hv hgatp-hardware-write-operation source-integrity-test`
- `hv hgatp-hardware-write-operation request-value-test`
- `hv hgatp-hardware-write-operation opt-in-test`
- `hv hgatp-hardware-write-operation policy-allows-test`
- `hv hgatp-hardware-write-operation call-reachable-test`
- `hv hgatp-hardware-write-operation call-called-test`
- `hv hgatp-hardware-write-operation raw-write-called-test`
- `hv hgatp-hardware-write-operation fake-trap-test`
- `hv hgatp-hardware-write-operation fake-readback-test`
- `hv hgatp-hardware-write-operation write-attempted-test`
- `hv hgatp-hardware-write-operation write-performed-test`
- `hv hgatp-hardware-write-operation active-stage2-test`
- `hv hgatp-hardware-write-operation guest-entered-test`
- `hv hgatp-hardware-write-operation first-instruction-test`
- `hv hgatp-hardware-write-operation invariant-consumption-test`
- `hv hgatp-hardware-write-operation invariant-corruption-test`

HV34 builds an opt-in guarded HGATP hardware-write operation object from the existing HV33 preparation envelope. The default operation is denied before CSR access and blocked before the raw write path.

## HV35 Guarded HGATP Execution Path Dry-Run Foundation

New shell commands:

- `hv hgatp-execution-dry-run`
- `hv-hgatp-execution-dry-run`
- `hv hgatp-execution-dry-run status`
- `hv hgatp-execution-dry-run build`
- `hv hgatp-execution-dry-run validate`
- `hv hgatp-execution-dry-run execute`
- `hv hgatp-execution-dry-run blockers`
- `hv hgatp-execution-dry-run next`
- `hv hgatp-execution-dry-run checksum`
- `hv hgatp-execution-dry-run reset`
- `hv hgatp-execution-dry-run fields`
- `hv hgatp-execution-dry-run request`
- `hv hgatp-execution-dry-run steps`
- `hv hgatp-execution-dry-run result`
- `hv hgatp-execution-dry-run trap-slot`
- `hv hgatp-execution-dry-run readback`
- `hv hgatp-execution-dry-run decision`
- `hv hgatp-execution-dry-run require-operation-test`
- `hv hgatp-execution-dry-run invalid-operation-test`
- `hv hgatp-execution-dry-run source-integrity-test`
- `hv hgatp-execution-dry-run request-value-test`
- `hv hgatp-execution-dry-run opt-in-test`
- `hv hgatp-execution-dry-run policy-allows-test`
- `hv hgatp-execution-dry-run operation-call-reachable-test`
- `hv hgatp-execution-dry-run operation-call-called-test`
- `hv hgatp-execution-dry-run raw-write-called-test`
- `hv hgatp-execution-dry-run execution-reached-raw-write-test`
- `hv hgatp-execution-dry-run execution-called-raw-write-test`
- `hv hgatp-execution-dry-run fake-trap-test`
- `hv hgatp-execution-dry-run fake-readback-test`
- `hv hgatp-execution-dry-run write-attempted-test`
- `hv hgatp-execution-dry-run write-performed-test`
- `hv hgatp-execution-dry-run active-stage2-test`
- `hv hgatp-execution-dry-run guest-entered-test`
- `hv hgatp-execution-dry-run first-instruction-test`
- `hv hgatp-execution-dry-run invariant-consumption-test`
- `hv hgatp-execution-dry-run invariant-corruption-test`

HV35 builds and executes a guarded HGATP execution dry-run object from the existing HV34 hardware-write operation state. The executor records real dry-run control-flow accounting while preserving denial before CSR access, blocking before the raw write path, empty trap/readback slots, and all no-write/no-activation/no-guest-entry invariants.

## HV36 Guarded HGATP Hardware Executor Skeleton commands

HV36 adds a guarded HGATP hardware executor skeleton that consumes the existing HV35 execution dry-run state and executes no-write executor control flow. It denies before CSR access, skips CSR/raw writes, exposes empty trap/readback slots, and preserves no guest entry or second-stage activation.

- `hv hgatp-hardware-executor`
- `hv-hgatp-hardware-executor`
- `hv hgatp-hardware-executor status`
- `hv hgatp-hardware-executor build`
- `hv hgatp-hardware-executor validate`
- `hv hgatp-hardware-executor execute`
- `hv hgatp-hardware-executor blockers`
- `hv hgatp-hardware-executor next`
- `hv hgatp-hardware-executor checksum`
- `hv hgatp-hardware-executor reset`
- `hv hgatp-hardware-executor fields`
- `hv hgatp-hardware-executor request`
- `hv hgatp-hardware-executor steps`
- `hv hgatp-hardware-executor result`
- `hv hgatp-hardware-executor trap-slot`
- `hv hgatp-hardware-executor readback`
- `hv hgatp-hardware-executor decision`
- `hv hgatp-hardware-executor require-dry-run-test`
- `hv hgatp-hardware-executor invalid-dry-run-test`
- `hv hgatp-hardware-executor source-integrity-test`
- `hv hgatp-hardware-executor request-value-test`
- `hv hgatp-hardware-executor policy-allows-test`
- `hv hgatp-hardware-executor boundary-bypass-test`
- `hv hgatp-hardware-executor csr-reached-test`
- `hv hgatp-hardware-executor csr-called-test`
- `hv hgatp-hardware-executor raw-reached-test`
- `hv hgatp-hardware-executor raw-called-test`
- `hv hgatp-hardware-executor fake-trap-test`
- `hv hgatp-hardware-executor fake-readback-test`
- `hv hgatp-hardware-executor write-attempted-test`
- `hv hgatp-hardware-executor write-performed-test`
- `hv hgatp-hardware-executor active-stage2-test`
- `hv hgatp-hardware-executor guest-entered-test`
- `hv hgatp-hardware-executor first-instruction-test`
- `hv hgatp-hardware-executor invariant-consumption-test`
- `hv hgatp-hardware-executor invariant-corruption-test`

Smoke proof: `./smoke/smoke-hv36-hgatp-hardware-executor-v0.sh` and `./smoke/smoke-hv36-hgatp-hardware-executor-negative-v0.sh` are included in `./scripts/validate-hyperzig.sh` and `zig build validate-hyperzig`.


## HV37 guarded HGATP trap/fault capture preparation

* `hv hgatp-trap-capture-prep` / `hv-hgatp-trap-capture-prep` / `hv hgatp-trap-capture-prep status`
* `hv hgatp-trap-capture-prep build`
* `hv hgatp-trap-capture-prep validate`
* `hv hgatp-trap-capture-prep prepare`
* `hv hgatp-trap-capture-prep blockers`
* `hv hgatp-trap-capture-prep next`
* `hv hgatp-trap-capture-prep checksum`
* `hv hgatp-trap-capture-prep reset`
* `hv hgatp-trap-capture-prep fields`
* `hv hgatp-trap-capture-prep trap-slot`
* `hv hgatp-trap-capture-prep fault-slot`
* `hv hgatp-trap-capture-prep result`
* `hv hgatp-trap-capture-prep decision`
* `hv hgatp-trap-capture-prep require-executor-test`
* `hv hgatp-trap-capture-prep invalid-executor-test`
* `hv hgatp-trap-capture-prep source-integrity-test`
* `hv hgatp-trap-capture-prep fake-trap-test`
* `hv hgatp-trap-capture-prep fake-fault-test`
* `hv hgatp-trap-capture-prep csr-called-test`
* `hv hgatp-trap-capture-prep raw-called-test`
* `hv hgatp-trap-capture-prep readback-test`
* `hv hgatp-trap-capture-prep write-attempted-test`
* `hv hgatp-trap-capture-prep write-performed-test`
* `hv hgatp-trap-capture-prep active-stage2-test`
* `hv hgatp-trap-capture-prep guest-entered-test`
* `hv hgatp-trap-capture-prep first-instruction-test`
* `hv hgatp-trap-capture-prep invariant-consumption-test`
* `hv hgatp-trap-capture-prep invariant-corruption-test`

## HV38 Guarded HGATP CSR Write Boundary Foundation commands

HV38 adds a real software-controlled CSR write boundary immediately before any future `hgatp` CSR write. These commands construct, validate, inspect, execute as a no-write readiness path, account for denials, and reset the boundary. They do **not** write `hgatp`, execute raw CSR writes, read back `hgatp`, activate second-stage translation, enter guest mode, or execute guest instructions.

### `hv csr-boundary` / `hv-csr-boundary` / `hv csr-boundary status`
- **What it does:** prints the current CSR boundary lifecycle, source fingerprint, authorization, accounting, execution record, and no-write invariant fields.

### `hv csr-boundary create`
- **What it does:** consumes the HV37 trap-capture preparation object, builds a CSR boundary request, records source fingerprints, assigns a replay nonce, and evaluates whether the software boundary is constructible.

### `hv csr-boundary inspect`
- **What it does:** inspects the current boundary object and execution record without mutating the write path.

### `hv csr-boundary validate`
- **What it does:** validates source stability, replay protection, denial policy, accounting, and required invariants while keeping `authorized_to_write=false`.

### `hv csr-boundary execute`
- **What it does:** records execution readiness and an execution record for the boundary while deliberately denying the hardware write path before CSR access.

### `hv csr-boundary reset`
- **What it does:** resets the CSR boundary lifecycle, request metadata, accounting, and execution record.

### HV38 behavior tests
- `hv csr-boundary denial-test` proves a CSR-call observation is rejected.
- `hv csr-boundary replay-test` proves replayed boundary nonces are rejected.
- `hv csr-boundary no-write-invariant-test` proves `hgatp_write_attempted=false`, `hgatp_write_performed=false`, `active_stage2=false`, `guest_entered=false`, and `first_guest_instruction_executed=false` across the execute-readiness path.

Smoke proof: `smoke/smoke-hv38-csr-boundary-v0.sh` writes `smoke/transcripts/latest-hv38-csr-boundary-v0.txt` and verifies creation, validation, denial, accounting, lifecycle reset, replay protection, and no-write invariants from command behavior.
