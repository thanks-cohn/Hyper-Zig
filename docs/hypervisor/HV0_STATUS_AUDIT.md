# HV0 Status Audit

## What was implemented

- Added `kernel/hypervisor/hv.zig` with one public status printer.
- Added shell commands `hv status`, `hv`, and `hv-status` that print the same HV0 status.
- Added a smoke test for the HV0 status command.
- Added hypervisor branch documentation and command/milestone references.

## What is deliberately missing

- Linux guest support is `not-supported-yet`.
- Rust guest toolchain support is `not-supported-yet`.
- Guest execution is `not-supported-yet`.
- VM object, vCPU object, guest memory, guest entry, guest trap return, second-stage translation, virtual timer, virtual console, SBI layer, and virtio for Linux are `MISSING`.
- H-extension detection is `unknown` because there is no safe detection path yet from the current supervisor-mode shell.

## Why fake Linux claims are forbidden

A fake Linux claim would hide the exact work that must be built: capability detection, VM/vCPU state, guest memory, guest entry, trap return, virtual console, SBI mediation, image/DTB loading, and device support. HV0 exists to keep that boundary visible.

## Exact smoke markers

- `hv: branch=hypervisor-v0`
- `hv: target=zig-0.14.x`
- `hv: status=research-scaffold`
- `hv: linux_guest=not-supported-yet`
- `hv: rust_guest_toolchain=not-supported-yet`
- `hv: guest_execution=not-supported-yet`
- `hv: vm_object=MISSING`
- `hv: vcpu_object=MISSING`
- `hv: guest_memory=MISSING`
- `hv: guest_entry=MISSING`
- `hv: guest_trap_return=MISSING`
- `hv: second_stage_translation=MISSING`
- `hv: virtual_console=MISSING`
- `hv: sbi_layer=MISSING`
- `hv: virtio_for_linux=MISSING`

## Zig 0.14.x validation requirement

Validation must use Zig 0.14.x through existing scripts:

```sh
export ZIG=/home/big-bro/dev/zig-zag/.tools/zig-x86_64-linux-0.14.1/zig
./scripts/check-zig-version.sh
./scripts/build.sh
./smoke/smoke-csr-v0.sh
./smoke/smoke-hv-status-v0.sh
```

## Commands run

```sh
export ZIG=/home/big-bro/dev/zig-zag/.tools/zig-x86_64-linux-0.14.1/zig
./scripts/check-zig-version.sh
./scripts/build.sh
./smoke/smoke-csr-v0.sh
./smoke/smoke-hv-status-v0.sh
```

## Pass/fail status

- `./scripts/check-zig-version.sh`: failed in the local environment because the requested Zig executable was not present or executable.
- `./scripts/build.sh`: failed in the local environment because no Zig executable was available at the requested path, on `PATH`, or at `/opt/zig/zig`.
- `./smoke/smoke-csr-v0.sh`: failed before QEMU boot because the build step failed.
- `./smoke/smoke-hv-status-v0.sh`: failed before QEMU boot because the build step failed.

The HV0 transcript path is `smoke/transcripts/latest-hv-status-v0.txt`; it remains empty until Zig 0.14.x is available and the smoke test can boot QEMU.
