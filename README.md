<div align="center">

<pre>
 ██╗  ██╗██╗   ██╗██████╗ ███████╗██████╗       ███████╗██╗ ██████╗
 ██║  ██║╚██╗ ██╔╝██╔══██╗██╔════╝██╔══██╗      ╚══███╔╝██║██╔════╝
 ███████║ ╚████╔╝ ██████╔╝█████╗  ██████╔╝█████╗  ███╔╝ ██║██║  ███╗
 ██╔══██║  ╚██╔╝  ██╔═══╝ ██╔══╝  ██╔══██╗╚════╝ ███╔╝  ██║██║   ██║
 ██║  ██║   ██║   ██║     ███████╗██║  ██║      ███████╗██║╚██████╔╝
 ╚═╝  ╚═╝   ╚═╝   ╚═╝     ╚══════╝╚═╝  ╚═╝      ╚══════╝╚═╝ ╚═════╝
</pre>

</div>

<p align="center">
  <img src="da_zoid.png" alt="ZIGN01D 1980s banner" width="720">
</p>


## Quick Start (Fresh Machine)

Hyper-Zig targets Zig 0.14.x.

The commands below assume a Linux machine with no existing Zig installation.

### Install Zig 0.14.0

```bash
mkdir -p ~/tools
cd ~/tools

wget https://ziglang.org/download/0.14.0/zig-linux-x86_64-0.14.0.tar.xz

tar -xf zig-linux-x86_64-0.14.0.tar.xz

export ZIG=$HOME/tools/zig-linux-x86_64-0.14.0/zig
```

### Verify the installation

```bash
echo $ZIG
$ZIG version
```

Expected output:

```text
/home/<user>/tools/zig-linux-x86_64-0.14.0/zig
0.14.0
```

### Install QEMU

Ubuntu/Debian:

```bash
sudo apt update
sudo apt install qemu-system-misc
```

Arch:

```bash
sudo pacman -S qemu-full
```

Verify:

```bash
qemu-system-riscv64 --version
```

### Clone Hyper-Zig

```bash
git clone https://github.com/thanks-cohn/Hyper-Zig.git
cd Hyper-Zig
```

### Verify the toolchain

```bash
./scripts/check-zig-version.sh
```

### Build Hyper-Zig

```bash
./scripts/build.sh
```

### Run full validation

```bash
./scripts/validate-hyperzig.sh
```

### Inspect the latest validation log

```bash
tail -n 240 logs/latest/validate-hyperzig.log
```

> IMPORTANT
>
> The `ZIG` environment variable must point to a real Zig 0.14.x compiler.
>
> Do not use placeholder paths such as:
>
> ```bash
> export ZIG=/path/to/zig-0.14.x/zig
> ```
>
> Validation will fail if `ZIG` points to a nonexistent location.

## Validation and Proof Commands

Run the complete validation ladder:

```bash
./scripts/validate-hyperzig.sh
```

Run individual milestone proofs:

```bash
./smoke/smoke-hv-status-v0.sh
./smoke/smoke-hv-capability-v0.sh
./smoke/smoke-hv-vm-vcpu-v0.sh
./smoke/smoke-hv-vcpu-lifecycle-v0.sh
./smoke/smoke-hv-guest-memory-v0.sh
./smoke/smoke-hv-address-space-v0.sh
./smoke/smoke-hv-guest-image-v0.sh
./smoke/smoke-hv-guest-entry-v0.sh
./smoke/smoke-hv-guest-exit-v0.sh
./smoke/smoke-hv-guest-run-attempt-v0.sh
./smoke/smoke-hv-guest-execution-v0.sh
./smoke/smoke-hv-second-stage-v0.sh
```

Inspect proof transcripts:

```bash
cat smoke/transcripts/latest-hv-status-v0.txt
cat smoke/transcripts/latest-hv-capability-v0.txt
cat smoke/transcripts/latest-hv-vm-vcpu-v0.txt
cat smoke/transcripts/latest-hv-vcpu-lifecycle-v0.txt
cat smoke/transcripts/latest-hv-guest-memory-v0.txt
cat smoke/transcripts/latest-hv-address-space-v0.txt
cat smoke/transcripts/latest-hv-guest-image-v0.txt
cat smoke/transcripts/latest-hv-guest-entry-v0.txt
cat smoke/transcripts/latest-hv-guest-exit-v0.txt
cat smoke/transcripts/latest-hv-guest-run-attempt-v0.txt
cat smoke/transcripts/latest-hv-guest-execution-v0.txt
cat smoke/transcripts/latest-hv-second-stage-v0.txt
```

Inspect validation evidence:

```bash
tail -n 240 logs/latest/validate-hyperzig.log
```

When validation passes, the currently implemented hypervisor milestones have been proven by the project's evidence ladder.

## Current state

Proven when validation passes:

| Milestone | Status | Meaning |
| --- | --- | --- |
| HV0 | Done | Honest hypervisor status output. |
| HV1 | Done | Capability reporting. H-extension status stays `unknown` until safely proven. |
| HV2 | Done | VM and vCPU object model. |
| HV3 | Done | vCPU lifecycle states: created, initialized, runnable, halted, reset. |
| HV4 | Done | PMM-backed guest-memory ownership object for VM 0. |
| HV5 | Done | Guest physical address metadata lookup for configured guest pages. |
| HV6 | Done | Tiny `tiny-flat-v0` guest image load and readback verification. |
| HV7 | Done | Guest-entry preparation metadata only: PC/SP/register frame for VM 0 / vCPU 0, with no guest execution. |
| HV8 | Done | Guest trap/exit metadata and classification for simulated exits, attached to VM 0 / vCPU 0, with no guest execution. |
| HV9 | Done | Controlled guest-entry attempt safety gate and no-execute arming metadata, with no guest execution. |
| HV10 | Done | Hardware-gated execution preparation object that validates software prerequisites and refuses execution at real hardware blockers. |
| HV11 | Done | Second-stage translation metadata and validation only: derives active=false, execute=false mapping metadata from HV4/HV5; hardware translation remains inactive. |

## What Hyper-Zig can do today

Hyper-Zig can:

- Build a small freestanding RISC-V kernel.
- Boot under QEMU through the smoke scripts.
- Print hypervisor status and capability information.
- Create and inspect VM/vCPU data objects.
- Move a boot vCPU through lifecycle states.
- Allocate, free, reset, and reject invalid guest-memory operations.
- Map simple guest physical address metadata for two guest pages.
- Prepare a guest-entry metadata object for VM 0 / vCPU 0 from the loaded HV6 image entry point and configured guest memory stack bounds.
- Record and classify simulated guest exits using the prepared HV7 PC/SP metadata without entering guest code.
- Check and arm controlled HV9 guest-run-attempt metadata while refusing execution because second-stage translation is missing, H-extension is unknown, and guest execution is disabled.
- Evaluate an HV10 hardware-gated execution preparation object that captures prerequisite state, execution-frame metadata, blockers, state transitions, and counters while still refusing instruction execution.
- Produce logs and transcripts that prove the above behavior.

## HV7 Guest Entry Preparation

HV7 adds a real guest-entry preparation object, not guest execution. The object derives `pc` from the HV6 `tiny-flat-v0` guest-image entry point (`0x0`), derives `sp` inside the configured HV4/HV5 guest memory span, builds a `GuestRegisterFrame`, and attaches that prepared frame to VM 0 / vCPU 0.

HV7 shell proof commands:

```bash
hv guest-entry
hv-entry
hv guest-entry prepare
hv guest-entry reset
hv guest-entry bounds-test
hv guest-entry require-image-test
```

Exact validation commands include:

```bash
./smoke/smoke-hv-guest-entry-v0.sh
./scripts/validate-hyperzig.sh
zig build validate-hyperzig
```

HV7 explicitly does **not** execute the guest, does **not** use `sret`/`hret`/`mret` to enter a guest, does **not** boot Linux, does **not** implement second-stage translation, and does **not** prove RISC-V H-extension support.

## HV8 Guest Trap / Exit Metadata

HV8 adds a real `GuestExit` metadata subsystem for VM 0 / vCPU 0. It classifies simulated instruction-trap, memory-fault, timer-interrupt, and explicit-halt exits; records PC/SP from the already prepared HV7 guest-entry frame; stores cause, trap value, instruction bits, owner IDs, counters, and last error; and attaches the latest exit frame to the vCPU object.

HV8 shell proof commands:

```bash
hv guest-exit
hv-exit
hv guest-exit record-instruction
hv guest-exit record-memory-fault
hv guest-exit record-timer
hv guest-exit record-halt
hv guest-exit reset
hv guest-exit require-entry-test
```

Exact validation commands include:

```bash
./smoke/smoke-hv-guest-exit-v0.sh
./smoke/smoke-hv-guest-run-attempt-v0.sh
./smoke/smoke-hv-guest-execution-v0.sh
./smoke/smoke-hv-second-stage-v0.sh
./scripts/validate-hyperzig.sh
zig build validate-hyperzig
```

HV8 is trap/exit metadata and classification only. It does **not** execute the guest, does **not** jump to guest code, does **not** use `sret`/`hret`/`mret` for guest execution, does **not** boot Linux, does **not** implement second-stage translation, and does **not** prove RISC-V H-extension support.


## HV9 Controlled Guest-Entry Attempt Research

HV9 adds a real `GuestRunAttempt` safety-gate object for VM 0 / vCPU 0. It inspects the proven HV4 guest-memory object, HV5 address-space metadata, HV6 tiny image state, HV7 prepared entry frame, and HV8 exit model. `hv guest-run check` records deterministic blockers, and `hv guest-run arm-no-execute` may arm metadata only after entry/exit metadata are ready. It still refuses actual execution because second-stage translation is missing, H-extension support is unknown, and guest execution remains disabled.

HV9 shell proof commands:

```bash
hv guest-run
hv-run
hv guest-run check
hv guest-run arm-no-execute
hv guest-run reset
hv guest-run require-entry-test
hv guest-run require-exit-test
```

Exact validation commands include:

```bash
./smoke/smoke-hv-guest-run-attempt-v0.sh
./smoke/smoke-hv-guest-execution-v0.sh
./smoke/smoke-hv-second-stage-v0.sh
./scripts/validate-hyperzig.sh
zig build validate-hyperzig
```

HV9 explicitly does **not** execute the guest, does **not** jump to guest code, does **not** use `sret`/`hret`/`mret` for guest execution, does **not** boot Linux, does **not** implement second-stage translation, and does **not** prove RISC-V H-extension support.


## HV10 Hardware-Gated Guest Execution Preparation

HV10 adds a real `GuestExecutionGate` object for VM 0 / vCPU 0. It gathers the software prerequisites future guest execution will require: VM/vCPU ownership, HV4 guest memory, HV5 address-space metadata, HV6 loaded tiny image, HV7 entry frame, HV8 exit metadata, and HV9 no-execute run-attempt arming. It then exposes hardware-gate blockers for missing second-stage translation, unproven H-extension support, and disabled guest instruction execution.

HV10 shell proof commands:

```bash
hv exec
hv-exec
hv execution
hv exec-status
hv exec-check
hv exec-arm
hv exec-blockers
hv exec-reset
hv exec-require-prereq-test
```

Exact validation commands include:

```bash
./smoke/smoke-hv-guest-execution-v0.sh
./smoke/smoke-hv-second-stage-v0.sh
./scripts/validate-hyperzig.sh
zig build validate-hyperzig
```

HV10 explicitly does **not** execute guest instructions, does **not** jump to guest memory, does **not** increment `vcpu.run_count`, does **not** boot Linux, does **not** implement second-stage translation, and does **not** prove RISC-V H-extension support.

## What Hyper-Zig cannot do yet

Hyper-Zig cannot yet:

- Enter a guest.
- Execute guest code. HV7 prepares entry metadata, HV8 records exit metadata, HV9 arms no-execute run-attempt metadata, and HV10 evaluates hardware-gated execution preparation only.
- Boot Linux as a guest.
- Host Linux.
- Provide second-stage address translation.
- Safely claim RISC-V H-extension support.
- Virtualize guest devices.
- Mediate guest SBI calls.
- Provide production isolation or security.

## How far from hosting Linux?

Not close yet. Hyper-Zig is still before guest entry and before guest instruction execution.

The missing pieces are large and explicit:

1. **HV11 continued hardware-gated guest execution research**: build on HV10 gate state without claiming Linux support.
2. **Trap and exit handling**: handle guest exits, faults, interrupts, and lifecycle transitions.
3. **Second-stage translation**: isolate guest physical memory with real hardware-backed mappings.
4. **H-extension proof**: safely detect and use the RISC-V hypervisor extension, or clearly document any non-H path.
5. **Linux image loading**: load a real Linux kernel image, device tree, initramfs, and boot parameters.
6. **SBI mediation**: provide or forward the calls Linux expects during boot.
7. **Virtual devices**: timer, console, block, network, and interrupt paths that Linux can use.
8. **Repeatable Linux smoke test**: one command that boots Linux far enough to prove the claim.


Until those are implemented and smoke-proven, this project should be described as **hypervisor groundwork**, not a Linux host.

## Project goal

The goal is to build a readable, verifiable hypervisor path in Zig:

1. Build the smallest useful piece.
2. Prove it with a command.
3. Save the transcript.
4. State exactly what works and what does not.
5. Move to the next milestone.

The next target is **HV12 real second-stage page-table activation research**, still without Linux or unsupported execution claims.

## Useful files

- `docs/hypervisor/DEVELOPER_START_HERE.md` — guided developer walkthrough.
- `COMMANDS.md` — shell and proof command reference.
- `docs/hypervisor/HV_MILESTONE_LADDER.md` — hypervisor milestone ladder.
- `logs/latest/validate-hyperzig.log` — latest validation output after running validation.
- `smoke/transcripts/` — latest smoke-test transcripts.

## Exact HV11 Validation Command Set

```bash
export ZIG=/home/big-bro/dev/zig-zag/.tools/zig-x86_64-linux-0.14.1/zig
export PATH=/home/big-bro/dev/zig-zag/.tools/zig-x86_64-linux-0.14.1:$PATH

git status
git branch --show-current
zig version
./scripts/check-zig-version.sh
zig build
zig build hyperzig-status
./smoke/smoke-hv-status-v0.sh
./smoke/smoke-hv-capability-v0.sh
./smoke/smoke-hv-vm-vcpu-v0.sh
./smoke/smoke-hv-vcpu-lifecycle-v0.sh
./smoke/smoke-hv-guest-memory-v0.sh
./smoke/smoke-hv-address-space-v0.sh
./smoke/smoke-hv-guest-image-v0.sh
./smoke/smoke-hv-guest-entry-v0.sh
./smoke/smoke-hv-guest-exit-v0.sh
./smoke/smoke-hv-guest-run-attempt-v0.sh
./smoke/smoke-hv-guest-execution-v0.sh
./smoke/smoke-hv-second-stage-v0.sh
./scripts/validate-hyperzig.sh
zig build validate-hyperzig
tail -n 300 logs/latest/validate-hyperzig.log
```


## HV11 scope note

HV11 is second-stage translation metadata research only. It adds executing code for `SecondStage` mapping metadata, validation, metadata lookups, and rejection tests. It does not activate hardware second-stage translation, does not write `hgatp`, does not prove H-extension support, does not execute guest code, and does not support Linux guests.

Exact validation commands for HV0-HV11:

```bash
export ZIG=/home/big-bro/dev/zig-zag/.tools/zig-x86_64-linux-0.14.1/zig
export PATH=/home/big-bro/dev/zig-zag/.tools/zig-x86_64-linux-0.14.1:$PATH
zig version
./scripts/check-zig-version.sh
zig build
zig build hyperzig-status
./smoke/smoke-hv-status-v0.sh
./smoke/smoke-hv-capability-v0.sh
./smoke/smoke-hv-vm-vcpu-v0.sh
./smoke/smoke-hv-vcpu-lifecycle-v0.sh
./smoke/smoke-hv-guest-memory-v0.sh
./smoke/smoke-hv-address-space-v0.sh
./smoke/smoke-hv-guest-image-v0.sh
./smoke/smoke-hv-guest-entry-v0.sh
./smoke/smoke-hv-guest-exit-v0.sh
./smoke/smoke-hv-guest-run-attempt-v0.sh
./smoke/smoke-hv-guest-execution-v0.sh
./smoke/smoke-hv-second-stage-v0.sh
./scripts/validate-hyperzig.sh
zig build validate-hyperzig
tail -n 300 logs/latest/validate-hyperzig.log
```

Current scope: HV0-HV11 are smoke-proven only when the validation ladder passes. Guest execution is still not supported. Linux guests are still not supported. Active second-stage translation is still missing.

## Current hypervisor scope through HV12

Hyper-Zig targets Zig 0.14.x only. The currently validated hypervisor ladder is HV0 through HV12 when the canonical validation suite passes:

- HV0 status smoke
- HV1 capability smoke
- HV2 VM/vCPU object smoke
- HV3 vCPU lifecycle smoke
- HV4 PMM-backed guest memory smoke
- HV5 guest physical address-space metadata smoke
- HV6 tiny guest-image loading/readback smoke
- HV7 guest-entry preparation metadata smoke
- HV8 guest trap/exit metadata smoke
- HV9 controlled no-execute guest-run attempt gate smoke
- HV10 hardware-gated guest execution preparation smoke
- HV11 second-stage translation metadata smoke
- HV12 software-only second-stage page-table-like builder smoke

HV12 builds a software-owned second-stage table from HV11 metadata. For the current two-page guest region it creates one entry for GPA `0x0` and one entry for GPA `0x1000`, preserves read/write permissions, denies execute permission, supports software walks, validates entries, and can reset back to empty.

Scope boundaries remain strict: second-stage translation is not active, no `hgatp` write occurs, H-extension support is not claimed, guest execution is still not supported, and Linux guests are still not supported.

Exact validation commands:

```sh
export ZIG=/home/big-bro/dev/zig-zag/.tools/zig-x86_64-linux-0.14.1/zig
export PATH=/home/big-bro/dev/zig-zag/.tools/zig-x86_64-linux-0.14.1:$PATH
git status
git branch --show-current
zig version
./scripts/check-zig-version.sh
zig build
zig build hyperzig-status
./smoke/smoke-hv-status-v0.sh
./smoke/smoke-hv-capability-v0.sh
./smoke/smoke-hv-vm-vcpu-v0.sh
./smoke/smoke-hv-vcpu-lifecycle-v0.sh
./smoke/smoke-hv-guest-memory-v0.sh
./smoke/smoke-hv-address-space-v0.sh
./smoke/smoke-hv-guest-image-v0.sh
./smoke/smoke-hv-guest-entry-v0.sh
./smoke/smoke-hv-guest-exit-v0.sh
./smoke/smoke-hv-guest-run-attempt-v0.sh
./smoke/smoke-hv-guest-execution-v0.sh
./smoke/smoke-hv-second-stage-v0.sh
./smoke/smoke-hv-stage2-table-v0.sh
./scripts/validate-hyperzig.sh
zig build validate-hyperzig
tail -n 300 logs/latest/validate-hyperzig.log
```

<p align="center">
  <img src="who_needs_anything_else.png" alt="we're gona make it!" width="720">
</p>
