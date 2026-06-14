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

Hyper-Zig is a proof-driven RISC-V hypervisor project written in Zig.

It is not a Linux host yet. It is not a production hypervisor yet. It is a deliberately incremental hypervisor laboratory that builds the pieces required for Linux guest boot one proven milestone at a time.

The long-term target is Linux guest boot capability. The deeper purpose is to become one of the clearest public references for how modern virtualization works from first principles.

Most mature hypervisors are too large to learn from easily. Hyper-Zig is built in the open as a readable ladder: VM objects, vCPUs, guest memory, guest address spaces, guest images, boot contracts, FDT/DTB handoff, SBI foundations, virtual timer metadata, stage-2 translation metadata, trap plans, and guest-entry preparation.

The rule is simple: if a capability is not backed by executing code, validation commands, and reproducible transcripts, Hyper-Zig does not claim it.

## Why Hyper-Zig Matters

Hyper-Zig is important because it treats virtualization as something developers should be able to see, run, inspect, and understand.

Instead of hiding behind vague status updates or fake milestone labels, every step must be demonstrable. That makes the project useful even before Linux boots: it becomes a map of the hypervisor construction path.

The intended end state is a real Zig/RISC-V hypervisor path toward Linux guests. The educational value starts now: Hyper-Zig shows the scaffolding that has to exist before a responsible guest-entry claim can be made.

## Current Status

Current milestone: **HV23 Guest Entry Assembly Preparation Foundation**

Hyper-Zig currently smoke-proves HV0 through HV23 when the full validation ladder passes.

Today Hyper-Zig can:

- Boot a diagnostic RISC-V kernel under QEMU with Zig 0.14.x.
- Create and inspect VM and vCPU objects.
- Move a boot vCPU through lifecycle states.
- Allocate, reset, validate, and reject invalid guest-memory operations.
- Model guest physical address-space metadata.
- Load and verify a tiny guest image.
- Prepare guest-entry metadata without entering the guest.
- Record and classify simulated guest exits.
- Gate guest-run attempts and safely deny execution.
- Build second-stage translation metadata and software-only stage-2 tables.
- Build guest boot package and DTB/FDT contract metadata.
- Model SBI foundation, SBI console mediation, SBI dispatch, and virtual timer prerequisites.
- Build Linux-shaped handoff validation objects.
- Prepare guarded trap-return and entry-stub metadata.
- Produce logs and transcripts that prove the behavior above.

Today Hyper-Zig does **not**:

- Boot Linux.
- Provide Linux guest support.
- Execute guest instructions.
- Enter guest mode.
- Execute `sret`, `hret`, or `mret` into a guest.
- Activate hardware second-stage translation.
- Write `hgatp`.
- Claim RISC-V H-extension support.
- Provide full SBI services.
- Inject real timer interrupts into a running guest.
- Boot Buildroot, BusyBox, Alpine, Ubuntu, or any other Linux distribution.
- Provide production isolation or production virtualization.

## Quick Start (Fresh Machine)

Hyper-Zig targets Zig 0.14.x only.

The commands below assume a Linux machine with no existing Zig installation.

### Install Zig 0.14.0

```bash
mkdir -p ~/tools
cd ~/tools

wget https://ziglang.org/download/0.14.0/zig-linux-x86_64-0.14.0.tar.xz

tar -xf zig-linux-x86_64-0.14.0.tar.xz

export ZIG=$HOME/tools/zig-linux-x86_64-0.14.0/zig
export PATH=$HOME/tools/zig-linux-x86_64-0.14.0:$PATH
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

### Build and validate

```bash
./scripts/check-zig-version.sh
zig build
./scripts/validate-hyperzig.sh
zig build validate-hyperzig
```

### Run the diagnostic kernel manually

```bash
qemu-system-riscv64 \
  -machine virt \
  -cpu rv64 \
  -smp 1 \
  -m 128M \
  -nographic \
  -monitor none \
  -serial stdio \
  -kernel zig-out/bin/zign01d-v0
```

> IMPORTANT
>
> The `ZIG` environment variable must point to a real Zig 0.14.x compiler.
>
> Do not leave it as a placeholder path such as `/path/to/zig-0.14.x/zig`.

## HV23 Entry-Stub Commands

Inside the diagnostic shell, the current milestone exposes these command paths:

```text
hv entry-stub
hv-entry-stub
hv entry-stub status
hv entry-stub prepare
hv entry-stub validate
hv entry-stub blockers
hv entry-stub registers
hv entry-stub gates
hv entry-stub descriptor
hv entry-stub checksum
hv entry-stub attempt
hv entry-stub require-plan-test
hv entry-stub pc-bounds-test
hv entry-stub sp-bounds-test
hv entry-stub fdt-bounds-test
hv entry-stub active-stage2-test
hv entry-stub reset
```

Validate HV23 directly:

```bash
./scripts/check-zig-version.sh
zig build
./smoke/smoke-hv-entry-stub-v0.sh
./scripts/validate-hyperzig.sh
zig build validate-hyperzig
```

HV23 consumes the HV22 guarded trap-return plan and derives a validated software-only guest entry-stub preparation object. It records owner VM/vCPU IDs, planned `pc`, `sp`, `a0`, `a1`, `a2`, status and privilege metadata, trap-return kind metadata, entry-mode metadata, stub address/size/checksum metadata, guest memory bounds, stage-2 readiness metadata, active-stage2 and `hgatp` forbidden flags, H-extension unknown/not-claimed state, execution gate state, SBI dispatch readiness, counters, deterministic blockers, rejection paths, reset behavior, and a guarded attempt that is always safely denied.

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
./smoke/smoke-hv-stage2-table-v0.sh
./smoke/smoke-hv-boot-package-v0.sh
./smoke/smoke-hv-dtb-contract-v0.sh
./smoke/smoke-hv-sbi-foundation-v0.sh
./smoke/smoke-hv-virtual-timer-v0.sh
./smoke/smoke-hv-entry-stub-v0.sh
```

Inspect proof transcripts:

```bash
ls smoke/transcripts/
tail -n 240 logs/latest/validate-hyperzig.log
```

When validation passes, the implemented hypervisor milestones have been proven by the project's evidence ladder.

## Milestone Ladder

| Milestone | Status | Meaning |
| --- | --- | --- |
| HV0 | Done | Honest hypervisor status output. |
| HV1 | Done | Capability reporting. H-extension status remains `unknown` until safely proven. |
| HV2 | Done | VM and vCPU object model. |
| HV3 | Done | vCPU lifecycle states: created, initialized, runnable, halted, reset. |
| HV4 | Done | PMM-backed guest-memory ownership object for VM 0. |
| HV5 | Done | Guest physical address metadata lookup for configured guest pages. |
| HV6 | Done | Tiny `tiny-flat-v0` guest image load and readback verification. |
| HV7 | Done | Guest-entry metadata only, with no guest execution. |
| HV8 | Done | Guest trap/exit metadata and simulated exit classification. |
| HV9 | Done | Controlled no-execute guest-run attempt gate. |
| HV10 | Done | Hardware-gated execution preparation object. |
| HV11 | Done | Second-stage translation metadata only. |
| HV12 | Done | Software-only second-stage page-table-like builder. |
| HV13 | Done | Guest boot package contract. |
| HV14 | Done | Guest DTB contract and device-tree payload foundation. |
| HV15 | Done | Metadata-only SBI foundation. |
| HV16 | Done | Virtual timer and SBI timer mediation prerequisites. |
| HV17+ | Done through HV23 | FDT, Linux-shaped handoff, SBI console/dispatch, guest context, trap-plan, and entry-stub preparation foundations. |

## What Comes Next

The next honest milestones should move toward active stage-2 activation prerequisites, guarded first-instruction infrastructure, or real trap-entry/trap-return assembly preparation.

The project should continue to preserve strict non-claims until each capability is separately implemented and smoke-proven.

Near-term missing pieces include:

1. Hardware-backed stage-2 activation.
2. Safe `hgatp` preparation and write path.
3. H-extension detection or a documented non-H path.
4. Real guest entry/exit assembly.
5. Real trap handling and resume behavior.
6. Linux kernel/initrd/DTB handoff that Linux accepts.
7. SBI services Linux actually requires during early boot.
8. A repeatable Linux smoke test.

Until those exist, Hyper-Zig should be described as **hypervisor groundwork progressing toward Linux guest boot**, not as a Linux host.

<p align="center">
  <img src="who_needs_anything_else_2.png" alt="we're gona make it!" width="720">
</p>

## Project Goal

The goal is to build a readable, verifiable hypervisor path in Zig:

1. Build the smallest useful piece.
2. Prove it with a command.
3. Save the transcript.
4. State exactly what works and what does not.
5. Move to the next milestone.

That is the Hyper-Zig standard: no placeholder code, no fake implementations, no status-only milestones, and no claims without executing proof.

## Useful Files

- `docs/hypervisor/DEVELOPER_START_HERE.md` - guided developer walkthrough.
- `COMMANDS.md` - shell and proof command reference.
- `docs/hypervisor/HV_MILESTONE_LADDER.md` - hypervisor milestone ladder.
- `logs/latest/validate-hyperzig.log` - latest validation output after running validation.
- `smoke/transcripts/` - latest smoke-test transcripts.

## Historical Notes

Older milestone writeups for HV7 through HV16 described important steps in the ladder, but they are now superseded by the HV23 status above. The implementation history remains visible through tags, transcripts, validation logs, and milestone documentation. The README now keeps the front door focused on what Hyper-Zig is, why it matters, how to run it, what is proven today, and what remains unclaimed.
