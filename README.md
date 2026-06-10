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


Hyper-Zig is a hypervisor-first Zig 0.14.x RISC-V kernel.

Hyper-Zig exists to explore virtualization from first principles while remaining understandable, inspectable, and educational. Every milestone must build successfully, pass validation, and demonstrate a real capability before the next layer is added.

The goal is not to produce impressive claims.

The goal is to produce verifiable progress.



---

## Current Status

Repository State:

* HV0 Status Layer: PASS
* HV1 Capability Reporting: PASS
* HV2 VM/vCPU Object Model: PASS
* HV3 vCPU Lifecycle: PASS when validation passes

Not Yet Implemented:

* Guest Memory Management
* Guest Execution
* Linux Guests
* Hardware Virtualization Support

Current Development Target:

HV4 Guest Memory Object

---

## What Hyper-Zig Is

Hyper-Zig is a hypervisor research project focused on:

* Zig 0.14.x
* Explicit architecture
* Validation-first development
* Educational clarity
* Incremental virtualization milestones

Every completed milestone must be observable and testable.

No milestone is considered complete because code exists.

A milestone is complete only when it can be demonstrated.

---

## Development Ladder

HV0
Status Layer

Produces accurate hypervisor status information and validation output.

HV1
Capability Discovery

Reports host capabilities and exposes hypervisor feature visibility.

HV2
VM/vCPU Objects

Introduces the foundational structures required for virtual machines and virtual CPUs.

HV3
vCPU Lifecycle

Implements typed boot vCPU lifecycle state management: created, initialized, runnable, halted, and reset back to created.

HV4
Guest Memory Object

Will define and validate guest memory ownership and mapping structures.

HV5
Guest Execution

First successful execution of guest code.

HV6
Linux Guest Research

Investigation and implementation of Linux guest boot support.

HV7+
Advanced Virtualization

Future milestones including isolation, device virtualization, and higher-level guest support.

---

## Current Reality

Hyper-Zig is not yet a complete hypervisor.

Current scope is intentionally narrow: Hyper-Zig can report HV0 status, HV1 capability information, HV2 VM/vCPU objects, and HV3 vCPU lifecycle state if validation passes. Guest memory is still missing. Guest execution is still missing. Linux guests are still missing. The next milestone is HV4 guest memory object.


What is proven:

* Status reporting
* Validation infrastructure
* Capability reporting
* VM object creation
* vCPU object creation
* vCPU lifecycle state transitions when HV3 validation passes

What is not yet proven:

* Guest memory
* Guest execution
* Linux boot
* Hardware-assisted virtualization

This repository intentionally distinguishes between completed work and future goals.

---

## Quick Start

Clone the repository:

```bash
git clone git@github.com:thanks-cohn/Hyper-Zig.git
cd Hyper-Zig
```

Build:

```bash
zig build
```

Validate:

```bash
zig build validate-hyperzig
```

Run validation script:

```bash
./scripts/validate-hyperzig.sh
```

If validation passes, the repository is considered healthy.

---

## Example

```text
$ hv status

branch=main
target=zig-0.14.x

hv0=PASS
hv1=PASS
hv2=PASS

guest_memory=not-supported-yet
guest_execution=not-supported-yet
linux_guest=not-supported-yet

next=HV4
```

---

## Philosophy

Hyper-Zig follows a simple rule:

Build the smallest thing that can be proven.

Validate it.

Document it.

Then move forward.

The project values clarity over cleverness, evidence over assumptions, and demonstrated capability over marketing claims.

Every milestone should teach something useful about how virtualization actually works.

---

## Long-Term Vision

The long-term objective is a fully documented hypervisor stack written in Zig.

Future research areas include:

* Linux guest support
* Rust workloads on guests
* WASM guest environments
* Educational virtualization tooling
* Security and isolation research
* Multi-guest execution

These remain goals rather than claims.

The repository advances only when each capability is proven.

---

## Zig Version Policy

Hyper-Zig targets Zig 0.14.x exclusively.

New contributions should maintain compatibility with Zig 0.14.x unless the repository policy changes.

---

## License

See LICENSE.
