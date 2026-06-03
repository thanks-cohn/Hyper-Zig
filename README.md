# ZIGN01D

<p align="center">
  <img src="da_zoid.png" alt="ZIGN01D 1980s banner" width="720"> 
</p>

A small operating-system laboratory for learning how a machine comes alive. 

ZIGN01D boots on RISC-V under QEMU, speaks through a serial shell, and grows one proven step at a time. It is simple on purpose. Each milestone should make the machine a little more real, while keeping the reader curious instead of buried.

This project is not trying to impress you with a wall of complexity. It is trying to let you see the hidden parts of a kernel clearly enough that they become exciting.

## Why Zig?

ZIGn01d is written in Zig because Zig gives low-level systems code a rare mix of control and readability.

Zig lets the project work close to memory without hiding what is happening. Allocation is explicit. Pointers are visible. Compile-time code can help build simple tables and constants without turning the kernel into magic. There is no required garbage collector, no required runtime, and no large framework sitting between the reader and the machine.

That matters here. A teaching kernel should not feel like a sealed box. It should feel like a workbench.

Zig was chosen because it can make memory, layout, build steps, and bare-metal boundaries easier to inspect while still feeling modern enough to enjoy.

## Why RISC-V?

RISC-V was chosen because it is open, clean, and teachable.

The instruction set is not owned by one vendor. The architecture is easier to discuss than many older platforms. QEMU can emulate a RISC-V `virt` machine well enough for repeatable experiments. That gives ZIGN01D a stable place to begin: a small machine, a clear boot path, and enough room to grow.

RISC-V makes the project feel like a doorway. You are not just learning old PC habits. You are looking at a machine shape that could matter for phones, boards, labs, workstations, and future hardware.

## What ZIGN01D is today

ZIGN01D is a proof-driven RISC-V Zig teaching kernel.

Today it can:

- boot under QEMU RISC-V
- initialize UART output
- expose an interactive shell
- report machine, memory, board, heap, and PMM state
- compute expected virtio-mmio slots from the board profile
- run milestone smoke tests
- explain what is not implemented yet

The current milestone is **PMM V0**.

PMM V0 adds physical page accounting over the known QEMU `virt` RAM range. The kernel reserves kernel-owned pages, tracks total/free/used/reserved pages, allocates and frees single physical pages, rejects invalid frees and double frees, and proves allocation exhaustion rejection through shell commands and smoke tests.

This is not production memory management yet. It does not add paging, virtual memory, userspace memory, process isolation, swap, real phone hardware, real internet, real SMS, or real modem support.

## Try it

Build the kernel:

```sh
./scripts/build.sh
```

Run the main proof ladder:

```sh
./scripts/doctor.sh
./smoke/smoke-all.sh
./smoke/smoke-stability.sh
```

Run the current milestone proof:

```sh
./smoke/smoke-pmm-v0.sh
```

A good run ends with lines like:

```text
PASS ZIGN01D doctor
PASS ZIGN01D full smoke ladder
PASS ZIGN01D stability smoke
PASS ZIGN01D PMM V0 smoke
```

## How the project grows

ZIGN01D grows by proof, not by pretending.

Every serious milestone should add:

- one visible kernel capability
- one shell surface for inspecting it
- one smoke test that proves it
- one short guide for humans
- one audit of what changed
- clear limits on what is still missing

The goal is not to fake a finished operating system. The goal is to make each layer understandable, testable, and alive.

## Current capability ladder

- V0: bootable RISC-V QEMU kernel
- V1: diagnostic shell foundation
- V2: machine and CPU boundary reporting
- V3: timer and trap readiness
- V4: guarded MMIO foundation
- COMM V0: honest communication placeholders
- ZBUS V0: host capability bus scaffold
- MEMORY V0: fixed QEMU memory visibility
- BOARD V0: explicit QEMU `virt` board profile
- VIRTIO DISCOVERY V0: computed virtio-mmio slot table
- HEAP V0: constrained kernel heap proof
- PMM V0: physical page accounting and page allocation proof

See [docs/MILESTONE_INDEX.md](docs/MILESTONE_INDEX.md) for the full ladder.

## Important documents

Start here:

- [What is ZIGN01D?](docs/WHAT_IS_ZIGN01D.md)
- [Professor Quickstart](docs/PROFESSOR_QUICKSTART.md)
- [Student Quickstart](docs/STUDENT_QUICKSTART.md)
- [Lab Manual](docs/LAB_MANUAL.md)
- [Proof Contract](docs/PROOF_CONTRACT.md)
- [Milestone Index](docs/MILESTONE_INDEX.md)
- [Roadmap](ROADMAP.md)

Current memory and machine docs:

- [PMM V0](docs/PMM_V0.md)
- [HEAP V0 User Guide](docs/MILESTONE_HEAP_V0_USER_GUIDE.md)
- [HEAP V0 Spec](docs/HEAP_V0_SPEC.md)
- [HEAP V0 Audit](docs/HEAP_V0_AUDIT.md)
- [BOARD V0 User Guide](docs/MILESTONE_BOARD_V0_USER_GUIDE.md)
- [VIRTIO DISCOVERY V0 User Guide](docs/MILESTONE_VIRTIO_DISCOVERY_V0_USER_GUIDE.md)
- [MEMORY V0 User Guide](docs/MILESTONE_MEMORY_V0_USER_GUIDE.md)
- [Stability Contract](docs/STABILITY_CONTRACT.md)

## What ZIGN01D is not yet

ZIGN01D is not a phone yet.

It does not yet have:

- filesystem support
- real networking
- real internet access
- modem support
- SMS support
- calls
- GUI
- touchscreen
- audio
- applications
- userspace isolation
- production paging
- broad real-hardware support

Those are future goals. They must be earned by proof.

## The larger dream

A phone should be a machine you can understand.

A computer should not become mysterious just because it fits in your hand. ZIGN01D begins with a tiny kernel because tiny things can be understood. Once something can be understood, it can be loved, repaired, taught, changed, and carried forward.

The long-term dream is a durable foundation for personal computing: a system that can grow from a teaching kernel into a clear, inspectable, user-owned machine.

Maybe that machine begins in QEMU. Maybe one day it reaches boards, phones, workstations, and stranger hardware.

For now, the mission is simple:

```text
Make the machine visible.
Make each step real.
Make the proof repeatable.
Keep the wonder alive.
```

## Stability

Known-good local Zig version: `0.14.1` at `/opt/zig/zig`.

Health check and smoke commands:

```sh
./scripts/doctor.sh
./smoke/smoke-all.sh
./smoke/smoke-stability.sh
```

Latest build, QEMU, smoke, and transcript evidence is stored under `logs/latest/`.

## Repository

```text
zign01d/
├── build.zig
├── kernel/
├── scripts/
├── smoke/
├── docs/
├── ROADMAP.md
└── README.md
```

If something breaks, the project should leave tracks: logs, smoke transcripts, proof markers, and clear next places to inspect.
