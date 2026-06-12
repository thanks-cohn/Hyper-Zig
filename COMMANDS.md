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
