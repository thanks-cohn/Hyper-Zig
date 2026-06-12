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
| HV8 | Next | Guest trap/exit handling research. |

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

## What Hyper-Zig cannot do yet

Hyper-Zig cannot yet:

- Enter a guest.
- Execute guest code. HV7 only prepares metadata and never jumps to the guest.
- Boot Linux as a guest.
- Host Linux.
- Provide second-stage address translation.
- Safely claim RISC-V H-extension support.
- Virtualize guest devices.
- Mediate guest SBI calls.
- Provide production isolation or security.

## How far from hosting Linux?

Not close yet. Hyper-Zig is still before guest entry.

The missing pieces are large and explicit:

1. **HV8 guest trap/exit handling**: design a safe, honest entry-attempt and exit classification path after HV7 metadata preparation.
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

The next target is **HV8 guest trap/exit handling research**, still without Linux or guest-execution support claims.

## Useful files

- `docs/hypervisor/DEVELOPER_START_HERE.md` — guided developer walkthrough.
- `COMMANDS.md` — shell and proof command reference.
- `docs/hypervisor/HV_MILESTONE_LADDER.md` — hypervisor milestone ladder.
- `logs/latest/validate-hyperzig.log` — latest validation output after running validation.
- `smoke/transcripts/` — latest smoke-test transcripts.
