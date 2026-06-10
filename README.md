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

# Hyper-Zig

Hyper-Zig is a small Zig 0.14.x RISC-V kernel being grown into a hypervisor one proven milestone at a time.

It is a research and teaching project. It is not a Linux host yet.

## Copy-paste quickstart

This downloads the current repo, checks the toolchain, builds the kernel, runs the hypervisor proof ladder, and shows the latest validation log.

```bash
git clone https://github.com/thanks-cohn/Hyper-Zig.git
cd Hyper-Zig

zig version
./scripts/check-zig-version.sh
zig build
zig build hyperzig-status
./scripts/validate-hyperzig.sh

tail -n 240 logs/latest/validate-hyperzig.log
```

Need to use a specific Zig 0.14.x binary?

```bash
export ZIG=/path/to/zig-0.14.x/zig
export PATH="$(dirname "$ZIG"):$PATH"
./scripts/check-zig-version.sh
zig build
./scripts/validate-hyperzig.sh
```

## What the commands prove

Run everything:

```bash
./scripts/validate-hyperzig.sh
```

Run one proof at a time:

```bash
./smoke/smoke-hv-status-v0.sh
./smoke/smoke-hv-capability-v0.sh
./smoke/smoke-hv-vm-vcpu-v0.sh
./smoke/smoke-hv-vcpu-lifecycle-v0.sh
./smoke/smoke-hv-guest-memory-v0.sh
./smoke/smoke-hv-address-space-v0.sh
./smoke/smoke-hv-guest-image-v0.sh
```

Read the latest evidence:

```bash
cat smoke/transcripts/latest-hv-status-v0.txt
cat smoke/transcripts/latest-hv-capability-v0.txt
cat smoke/transcripts/latest-hv-vm-vcpu-v0.txt
cat smoke/transcripts/latest-hv-vcpu-lifecycle-v0.txt
cat smoke/transcripts/latest-hv-guest-memory-v0.txt
cat smoke/transcripts/latest-hv-address-space-v0.txt
cat smoke/transcripts/latest-hv-guest-image-v0.txt
tail -n 240 logs/latest/validate-hyperzig.log
```

If the validation script passes, the current hypervisor ladder is healthy.

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
| HV7 | Next | Guest entry research. |

## What Hyper-Zig can do today

Hyper-Zig can:

- Build a small freestanding RISC-V kernel.
- Boot under QEMU through the smoke scripts.
- Print hypervisor status and capability information.
- Create and inspect VM/vCPU data objects.
- Move a boot vCPU through lifecycle states.
- Allocate, free, reset, and reject invalid guest-memory operations.
- Map simple guest physical address metadata for two guest pages.
- Load a tiny static guest payload into guest memory and verify it by reading the bytes back.
- Produce logs and transcripts that prove the above behavior.

## What Hyper-Zig cannot do yet

Hyper-Zig cannot yet:

- Enter a guest.
- Execute guest code.
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

1. **HV7 guest entry**: enter guest context and return safely.
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

The next target is **HV7 guest entry research**.

## Useful files

- `docs/hypervisor/DEVELOPER_START_HERE.md` — guided developer walkthrough.
- `COMMANDS.md` — shell and proof command reference.
- `docs/hypervisor/HV_MILESTONE_LADDER.md` — hypervisor milestone ladder.
- `logs/latest/validate-hyperzig.log` — latest validation output after running validation.
- `smoke/transcripts/` — latest smoke-test transcripts.
