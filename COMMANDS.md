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
