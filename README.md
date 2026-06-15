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

Build a Hypervisor.
Understand a Hypervisor.
Watch a Hypervisor Come Into Existence.

Hyper-Zig is a proof-driven RISC-V hypervisor project written in Zig.

Its goal is simple and ambitious:

Create a complete, understandable path from a tiny educational kernel to Linux guest boot.

Most operating systems are too large to study completely.

Most hypervisors are too complex to understand from the beginning.

Hyper-Zig is an attempt to bridge that gap.

The project is being built in public as both a serious hypervisor effort and a living record of how virtualization systems are constructed. Every subsystem, milestone, validation, failure, and success is preserved so readers can follow the entire journey from VM creation to guest execution.

Hyper-Zig is one of a small handful of serious Zig hypervisor projects aiming at real guest-boot capability instead of toy status output. It is not trying to look finished before it is finished. It is trying to make every step toward real virtualization visible, testable, and understandable.

Today Hyper-Zig has completed more than thirty consecutive hypervisor milestones.

It already contains:

- VM infrastructure.
- vCPU infrastructure.
- Guest memory systems.
- Guest address-space management.
- Guest image loading.
- Guest boot package construction.
- DTB/FDT handoff preparation.
- SBI foundations.
- SBI console and dispatch foundations.
- Virtual timer prerequisites.
- Linux-shaped handoff validation objects.
- Guest exit accounting.
- Trap planning infrastructure.
- H-extension discovery.
- Hypervisor CSR safety infrastructure.
- HGATP candidate derivation.
- Guarded HGATP write planning.
- Guarded HGATP write gating.
- Hardware-facing HGATP boundary preparation.
- HGATP CSR result and fault accounting.

Tomorrow it aims for:

- Safe hardware-backed `hgatp` write activation.
- Second-stage translation activation.
- Guest-mode entry.
- First real guest traps.
- BusyBox boot.
- Alpine boot.
- Linux guest boot.

The promise of Hyper-Zig is not merely the destination.

The promise is that every step toward that destination is visible, reproducible, and understandable.

## What Hyper-Zig Is

Hyper-Zig is a deliberately incremental hypervisor laboratory that builds the pieces required for Linux guest boot one proven milestone at a time.

It is not a Linux host yet. It is not a production hypervisor yet. It does not claim guest execution before guest execution is real.

The long-term target is Linux guest boot capability. The deeper purpose is to become one of the clearest public references for how modern virtualization works from first principles.

Most mature hypervisors are too large to learn from easily. Hyper-Zig is built in the open as a readable ladder: VM objects, vCPUs, guest memory, guest address spaces, guest images, boot contracts, FDT/DTB handoff, SBI foundations, virtual timer metadata, stage-2 translation metadata, trap plans, hypervisor CSR handling, and guest-entry preparation.

## Why Hyper-Zig Exists

Hyper-Zig exists because virtualization should be readable, inspectable, and teachable without being fake.

The project is advancing toward Linux guest boot through real hypervisor development. Each milestone must add observable behavior, validation output, or execution evidence.

The result is not just a kernel. It is a public construction path for a RISC-V hypervisor: small enough to study, strict enough to trust, and ambitious enough to grow toward real Linux guest execution.

## Current State

Current verified milestone chain:

```text
HV0 -> HV32
```

Hyper-Zig currently provides:

- VM lifecycle infrastructure.
- vCPU lifecycle infrastructure.
- Guest memory ownership and validation.
- Guest address-space modeling.
- Guest image loading and verification.
- Guest boot package construction.
- DTB/FDT handoff preparation.
- SBI foundation infrastructure.
- SBI console mediation foundations.
- SBI dispatch foundations.
- Virtual timer prerequisites.
- Linux-shaped handoff validation objects.
- Guest exit accounting.
- Trap planning infrastructure.
- Guarded trap-return and entry-stub metadata.
- H-extension discovery and CSR safety infrastructure.
- HGATP candidate derivation.
- HGATP activation readiness observation.
- Guarded HGATP write planning.
- Guarded HGATP write gating.
- Hardware-facing HGATP boundary preparation.
- Guarded HGATP write-attempt accounting.
- Guarded HGATP CSR interface preparation.
- HGATP CSR result and fault accounting.

Validation currently proves:

- Zig 0.14.x build success.
- Full Hyper-Zig validation success.
- HV0 through HV32 smoke validation success.
- HV32 positive smoke coverage.
- HV32 negative smoke coverage.
- Deterministic checksum and source-integrity checks across the guarded HGATP path.
- Explicit no-write and no-activation policy preservation where hardware action is not yet safe to claim.

## What Hyper-Zig Does Not Yet Do

Hyper-Zig does not currently:

- Boot Linux.
- Boot BusyBox.
- Boot Alpine.
- Provide Linux guest support.
- Execute guest instructions.
- Enter guest mode.
- Execute `sret`, `hret`, or `mret` into a guest.
- Write `hgatp`.
- Activate hardware second-stage translation.
- Prove active virtualization.
- Provide production isolation.

Those are future milestones. The README says this plainly because Hyper-Zig is built around proof.

## What Makes Hyper-Zig Different

### Evidence Driven

### Hypervisor First

Hyper-Zig is not a general-purpose toy kernel with virtualization glued on later.

The project is intentionally organized around the pieces needed for guest execution: VM state, vCPU state, guest memory, guest address spaces, boot handoff metadata, stage-2 translation planning, H-extension discovery, hypervisor CSR safety, HGATP preparation, and trap-entry structure.

### Built for Learning

The codebase is meant to expose the box-and-plumbing structure of a hypervisor.

Each subsystem has inputs, outputs, invariants, counters, checksums, and validation behavior. The goal is for a reader to understand what crosses each boundary and what stays inside it.

That makes Hyper-Zig useful even before Linux boots. It teaches the path instead of pretending the final result already exists.

### Reproducible by Design

Milestones are supported by:

- versioned tags
- smoke tests
- validation scripts
- diagnostic shell commands
- execution transcripts
- proof artifacts
- negative tests


## Roadmap

Near-term work:

1. Evolve guarded HGATP CSR result handling.
2. Move from denied HGATP preparation toward a safe real write path.
3. Activate second-stage translation only when the evidence supports it.
4. Enter guest mode through a guarded, validated path.
5. Handle first guest traps honestly.
6. Bring up a minimal Linux-shaped guest path.

Major targets:

1. Linux guest boot.
2. BusyBox boot.
3. Alpine boot.
4. Educational hypervisor curriculum.
5. Advanced RISC-V virtualization research.

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
> Do not leave it as a placeholder path such as `/path/to/zig-0.14.x/zig`.


<p align="center">
  <img src="who_needs_anything_else_2.png" alt="we're gonna make it!" width="720">
</p>
