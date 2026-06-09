# Hypervisor Branch Charter

`hypervisor-v0` is a research branch for making the future hypervisor track visible without pretending that a hypervisor exists today. The branch adds a small status surface and documentation so readers can see the boundary between the current ZIGN01D kernel and later guest-execution work.

`main` remains the real kernel track. Existing kernel boot, shell, CSR, memory, board, heap, PMM, filesystem, and communication scaffolds should continue to build and smoke-test normally. Hypervisor research must not rewrite unrelated subsystems or change the Zig build target.

## HV0 truth line

HV0 does not boot Linux. HV0 does not execute guests. HV0 does not provide VM objects, vCPU objects, guest memory management, second-stage translation, virtual console, SBI emulation, or virtio support for Linux. Missing features must be printed as `MISSING` or `not-supported-yet`.

HV0 establishes an honest reporting interface through the shell command `hv status` and the alias `hv`. That interface exists only to report readiness and missing pieces.

## Toolchain rule

All hypervisor-branch work remains Zig 0.14.x work. Zig 0.15 and Zig 0.16 are not project targets for this branch. Validation must use `./scripts/check-zig-version.sh`, `./scripts/build.sh`, and smoke tests under a Zig 0.14.x executable.

## Source rule

No Diosix code may be copied, ported, or translated into ZIGN01D. Documentation may mention architecture direction at a high level, but implementation must be original ZIGN01D work.

## Stop point

HV0 stops after status reporting, documentation, and smoke proof. The next exact milestone is HV1: hypervisor capability detection and VM/vCPU data model design.
