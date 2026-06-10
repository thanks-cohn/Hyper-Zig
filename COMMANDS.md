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
- **What it does not imply:** reset does not reset or create guest memory because guest memory is still missing.
