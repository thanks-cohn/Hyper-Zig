# Hyper-Zig project-unique commands

This file is the short index of commands unique to Hyper-Zig's kernel and validation workflow. The full command table lives in `docs/COMMAND_REFERENCE.md`.

## Host validation commands

### `./scripts/validate-hyperzig.sh`
Runs the canonical Hyper-Zig validation ladder and writes the Minimus-Log summary under `logs/latest/`.

### `zig build validate-hyperzig`
Runs the same canonical validator through the Zig build graph.

### `zig build hyperzig-status`
Prints the current Hyper-Zig milestone status and non-claims.

## Hypervisor shell commands

### `hv`
Prints the hypervisor status surface, including implemented HV2 VM/vCPU object markers and unsupported guest/Linux markers.

### `hv status` / `hv-status`
Aliases for `hv`.

### `hv capability` / `hv-capability`
Prints the safe HV1 capability surface without claiming H-extension support.

### `hv vm` / `hv-vm`
Prints the HV2 VM object: `vm.id=0`, `vm.state=defined`, and `vm.guest_memory=not-configured`.

### `hv vcpu` / `hv-vcpu`
Prints the HV2 vCPU object: `vcpu.id=0`, `vcpu.vm_id=0`, `vcpu.state=defined`, `vcpu.hart_binding=unbound`, and `vcpu.run_count=0`.

### `hv inspect` / `hv-inspect`
Prints the VM and vCPU objects together.

### `hv-objects`
Flat alias for `hv inspect`, useful for smoke tests and transcript scans.

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

## HV22 Guarded Trap-Return Preparation commands

HV22 adds a software-only guarded trap-return plan object derived from the HV21 guest context. These commands do not enter guest mode, execute guest code, write `hgatp`, activate second-stage translation, or execute `sret`/`hret`/`mret`.

- `hv trap-plan` / `hv-trap-plan` / `hv trap-plan status`: print the trap-plan state, counters, blockers, gates, and non-claims.
- `hv trap-plan prepare`: prepare HV21 guest context if needed, derive the plan registers and gates, and validate the plan.
- `hv trap-plan validate`: validate the current plan and mutate validation/rejection counters.
- `hv trap-plan blockers`: print deterministic blockers from current trap-plan state.
- `hv trap-plan registers`: print planned `pc`, `sp`, `a0`, `a1`, `a2`, status, privilege, trap-return kind, and entry-mode metadata.
- `hv trap-plan gates`: print stage2, hgatp, H-extension, execution-gate, run-attempt-gate, and SBI dispatch readiness metadata.
- `hv trap-plan attempt`: model a guarded entry attempt and safely deny it without executing a trap return or guest instruction.
- `hv trap-plan require-context-test`: prove rejection when the HV21 context is missing.
- `hv trap-plan pc-bounds-test`: prove rejection when planned PC is outside guest memory.
- `hv trap-plan sp-bounds-test`: prove rejection when planned SP is outside guest memory.
- `hv trap-plan fdt-bounds-test`: prove rejection when planned FDT register `a1` is outside guest memory.
- `hv trap-plan active-stage2-test`: prove rejection when active-stage2 metadata is falsely marked active.
- `hv trap-plan reset`: clear the plan to empty while incrementing the reset counter.

## HV22 validation entries

- `./smoke/smoke-hv-trap-plan-v0.sh`: behavior-based HV22 smoke proof with generated transcript at `smoke/transcripts/latest-hv-trap-plan-v0.txt`.
- `./scripts/validate-hyperzig.sh`: now includes `smoke/smoke-hv-trap-plan-v0.sh` in the required hypervisor validation ladder.
- `zig build validate-hyperzig`: runs the same validation ladder through `build.zig`.

## HV23 Guest Entry Assembly Preparation commands

- `hv entry-stub` / `hv-entry-stub` / `hv entry-stub status`
- `hv entry-stub prepare`
- `hv entry-stub validate`
- `hv entry-stub blockers`
- `hv entry-stub registers`
- `hv entry-stub gates`
- `hv entry-stub descriptor`
- `hv entry-stub checksum`
- `hv entry-stub attempt`
- `hv entry-stub require-plan-test`
- `hv entry-stub pc-bounds-test`
- `hv entry-stub sp-bounds-test`
- `hv entry-stub fdt-bounds-test`
- `hv entry-stub active-stage2-test`
- `hv entry-stub reset`

Smoke proof: `./smoke/smoke-hv-entry-stub-v0.sh`. Canonical validation: `./scripts/validate-hyperzig.sh` and `zig build validate-hyperzig`.


## HV24 H-Extension Discovery and Hypervisor CSR Safety commands

- `hv h-ext` / `hv-hext` / `hv h-ext status`: print H-extension discovery state, safety policy, counters, blockers, and non-claims.
- `hv h-ext discover`: run the safe discovery path and block unsafe H-CSR reads when no safe probe exists.
- `hv h-ext validate`: validate discovered state and reject empty or inconsistent state.
- `hv h-ext blockers`: print deterministic blocker state.
- `hv h-ext csr-table`: print tracked hypervisor CSR read statuses.
- `hv h-ext safety`: print CSR safety policy.
- `hv h-ext fake-detected-test`: prove fake detection is rejected.
- `hv h-ext unsafe-probe-test`: prove unsafe forced probing is rejected.
- `hv h-ext reset`: reset discovery state to empty.

HV24 validation entries:

- `./smoke/smoke-hv-h-extension-v0.sh`: behavior smoke for HV24; generates `smoke/transcripts/latest-hv-h-extension-v0.txt`.
- `./scripts/validate-hyperzig.sh`: includes HV24 as a required smoke milestone.
- `zig build validate-hyperzig`: invokes canonical validation including HV24.
