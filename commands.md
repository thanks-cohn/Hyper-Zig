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
