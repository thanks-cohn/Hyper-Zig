```
===============================================================================
HYPER-ZIG ROAD TO UBUNTU
HV7 THROUGH HV20
EVERY MILESTONE MUST BE SMOKE PROVEN
EVERY CLAIM MUST APPEAR IN MINIMUS-LOG
======================================

## CURRENT STATE

HV0 PASS  Hypervisor Status
HV1 PASS  Hypervisor Capabilities
HV2 PASS  VM/vCPU Model
HV3 PASS  vCPU Lifecycle
HV4 PASS  Guest Memory Ownership
HV5 PASS  Guest Address Metadata
HV6 PASS  Guest Image Loader

NEXT:
HV7 Guest Entry Framework

===============================================================================
HV7 - GUEST ENTRY FRAMEWORK
===========================

GOAL:
Execute guest code for the first time.

SMOKE TESTS

[ ] HV7.1 Guest entry succeeds
[ ] HV7.2 Guest exit succeeds
[ ] HV7.3 Guest PC captured
[ ] HV7.4 Guest PC advances
[ ] HV7.5 Guest register capture
[ ] HV7.6 Guest register restore
[ ] HV7.7 Repeated entry/exit cycle
[ ] HV7.8 Guest state survives cycle
[ ] HV7.9 Guest execution counter
[ ] HV7.10 Minimus-log proof

PASS CRITERIA

host -> guest -> host

===============================================================================
HV8 - GUEST EXIT FRAMEWORK
==========================

GOAL:
Reliable guest trap and exit handling.

SMOKE TESTS

[ ] HV8.1 ECALL exit
[ ] HV8.2 Illegal instruction exit
[ ] HV8.3 Breakpoint exit
[ ] HV8.4 Timer exit
[ ] HV8.5 External interrupt exit
[ ] HV8.6 Exit reason reporting
[ ] HV8.7 Exit counters
[ ] HV8.8 Resume after exit
[ ] HV8.9 Multiple exits per run
[ ] HV8.10 Minimus-log proof

PASS CRITERIA

Guest can execute repeatedly.

===============================================================================
HV9 - SBI FOUNDATION
====================

GOAL:
Provide minimal services Linux expects.

SMOKE TESTS

[ ] HV9.1 SBI trap interception
[ ] HV9.2 SBI dispatch table
[ ] HV9.3 Console putchar
[ ] HV9.4 Console getchar
[ ] HV9.5 Timer query
[ ] HV9.6 Shutdown request
[ ] HV9.7 Error reporting
[ ] HV9.8 SBI counters
[ ] HV9.9 Transcript validation
[ ] HV9.10 Minimus-log proof

PASS CRITERIA

Linux can communicate with Hyper-Zig.

===============================================================================
HV10 - LINUX BOOT FOUNDATION
============================

GOAL:
Load a real Linux kernel.

SMOKE TESTS

[ ] HV10.1 Linux image loader
[ ] HV10.2 Device tree loader
[ ] HV10.3 Initramfs loader
[ ] HV10.4 Kernel entry discovery
[ ] HV10.5 Boot parameter setup
[ ] HV10.6 Memory map generation
[ ] HV10.7 Image checksum validation
[ ] HV10.8 Guest ownership validation
[ ] HV10.9 Transcript proof
[ ] HV10.10 Minimus-log proof

PASS CRITERIA

Linux image prepared for execution.

===============================================================================
HV11 - LINUX FIRST INSTRUCTION
==============================

GOAL:
Linux executes.

SMOKE TESTS

[ ] HV11.1 Linux entry attempted
[ ] HV11.2 First instruction executed
[ ] HV11.3 Guest PC advances
[ ] HV11.4 First trap observed
[ ] HV11.5 First SBI call observed
[ ] HV11.6 Resume after trap
[ ] HV11.7 Linux execution counter
[ ] HV11.8 Transcript proof
[ ] HV11.9 Stable repetition
[ ] HV11.10 Minimus-log proof

PASS CRITERIA

Linux is alive.

===============================================================================
HV12 - EARLY LINUX BOOT
=======================

GOAL:
Linux begins initialization.

SMOKE TESTS

[ ] HV12.1 Early printk
[ ] HV12.2 Device tree parse
[ ] HV12.3 Memory discovery
[ ] HV12.4 CPU discovery
[ ] HV12.5 Scheduler init
[ ] HV12.6 Interrupt init
[ ] HV12.7 Timer init
[ ] HV12.8 Transcript proof
[ ] HV12.9 Stable repetition
[ ] HV12.10 Minimus-log proof

PASS CRITERIA

Linux boot sequence starts.

===============================================================================
HV13 - BUILDROOT BOOT
=====================

GOAL:
Boot first Linux distribution.

SMOKE TESTS

[ ] HV13.1 Buildroot image load
[ ] HV13.2 Buildroot kernel start
[ ] HV13.3 BusyBox launch
[ ] HV13.4 /init execution
[ ] HV13.5 Console output
[ ] HV13.6 Userland visible
[ ] HV13.7 Shutdown works
[ ] HV13.8 Transcript proof
[ ] HV13.9 Stable repetition
[ ] HV13.10 Minimus-log proof

PASS CRITERIA

First Linux distribution booted.

===============================================================================
HV14 - BUILDROOT SHELL
======================

GOAL:
Interactive shell.

SMOKE TESTS

[ ] HV14.1 Shell prompt
[ ] HV14.2 Echo command
[ ] HV14.3 uname command
[ ] HV14.4 Process listing
[ ] HV14.5 File creation
[ ] HV14.6 File deletion
[ ] HV14.7 Shutdown command
[ ] HV14.8 Transcript proof
[ ] HV14.9 Stable repetition
[ ] HV14.10 Minimus-log proof

PASS CRITERIA

Interactive Linux achieved.

===============================================================================
HV15 - ALPINE BOOT
==================

GOAL:
Boot modern Linux userspace.

SMOKE TESTS

[ ] HV15.1 Alpine image load
[ ] HV15.2 Alpine kernel boot
[ ] HV15.3 Login prompt
[ ] HV15.4 Root login
[ ] HV15.5 Package manager visible
[ ] HV15.6 Filesystem writable
[ ] HV15.7 Shutdown works
[ ] HV15.8 Transcript proof
[ ] HV15.9 Stable repetition
[ ] HV15.10 Minimus-log proof

PASS CRITERIA

Modern Linux distribution booted.

===============================================================================
HV16 - C TOOLCHAIN
==================

GOAL:
Compile software.

SMOKE TESTS

[ ] HV16.1 GCC install
[ ] HV16.2 hello.c compile
[ ] HV16.3 hello.c execute
[ ] HV16.4 Multi-file compile
[ ] HV16.5 Static link
[ ] HV16.6 Dynamic link
[ ] HV16.7 Makefile build
[ ] HV16.8 Transcript proof
[ ] HV16.9 Stable repetition
[ ] HV16.10 Minimus-log proof

PASS CRITERIA

Guest compiles C.

===============================================================================
HV17 - C++ TOOLCHAIN
====================

GOAL:
Compile C++.

SMOKE TESTS

[ ] HV17.1 G++ install
[ ] HV17.2 hello.cpp compile
[ ] HV17.3 STL usage
[ ] HV17.4 Templates
[ ] HV17.5 Exceptions
[ ] HV17.6 Multi-file build
[ ] HV17.7 Make build
[ ] HV17.8 Transcript proof
[ ] HV17.9 Stable repetition
[ ] HV17.10 Minimus-log proof

PASS CRITERIA

Guest compiles C++.

===============================================================================
HV18 - RUST TOOLCHAIN
=====================

GOAL:
Compile Rust.

SMOKE TESTS

[ ] HV18.1 rustc install
[ ] HV18.2 cargo install
[ ] HV18.3 hello-rust build
[ ] HV18.4 cargo build
[ ] HV18.5 release build
[ ] HV18.6 dependency fetch
[ ] HV18.7 execution proof
[ ] HV18.8 Transcript proof
[ ] HV18.9 Stable repetition
[ ] HV18.10 Minimus-log proof

PASS CRITERIA

Guest compiles Rust.

===============================================================================
HV19 - DEBIAN BOOT
==================

GOAL:
Boot a full development Linux.

SMOKE TESTS

[ ] HV19.1 Debian image load
[ ] HV19.2 Debian kernel boot
[ ] HV19.3 Login prompt
[ ] HV19.4 Root login
[ ] HV19.5 Package manager
[ ] HV19.6 Networking
[ ] HV19.7 Filesystem persistence
[ ] HV19.8 Transcript proof
[ ] HV19.9 Stable repetition
[ ] HV19.10 Minimus-log proof

PASS CRITERIA

Full Linux development environment.

======================================
HV20 - UBUNTU DEVELOPMENT WORKSTATION
=====================================

GOAL:
Ubuntu guest capable of software development.

SMOKE TESTS

[ ] HV20.1 Ubuntu boot
[ ] HV20.2 Login prompt
[ ] HV20.3 GCC compile
[ ] HV20.4 G++ compile
[ ] HV20.5 Rust compile
[ ] HV20.6 Cargo build
[ ] HV20.7 Dotnet SDK install
[ ] HV20.8 C# compile
[ ] HV20.9 Transcript proof
[ ] HV20.10 Minimus-log proof

PASS CRITERIA

Ubuntu guest boots and compiles:

* C
* C++
* Rust
* C#

MISSION COMPLETE

# Hyper-Zig hosts a real Ubuntu development workstation.

```
```

===============================================================================
HYPER-ZIG NORTH STAR
HV21 THROUGH HV35
THE PATH BEYOND UBUNTU
NO LESS IMPORTANT THAN HV0-HV20
===============================

HV20 IS NOT THE FINISH LINE.

HV20 proves Hyper-Zig can host a real Linux development workstation.

That achievement is significant.

It is not the final objective.

The objective is to build a hypervisor platform whose capabilities,
observability, validation, and educational value establish a new standard.

===============================================================================
HV21 - VIRTUAL DEVICE FOUNDATION
================================

GOAL:
Establish production-grade guest device interfaces.

SMOKE TESTS

[ ] HV21.1 Virtual console
[ ] HV21.2 Virtual timer
[ ] HV21.3 Virtual block device
[ ] HV21.4 Virtual network device
[ ] HV21.5 Device enumeration
[ ] HV21.6 Device reset
[ ] HV21.7 Device error reporting
[ ] HV21.8 Device validation
[ ] HV21.9 Transcript proof
[ ] HV21.10 Minimus-log proof

PASS CRITERIA

Linux uses Hyper-Zig virtual devices.

===============================================================================
HV22 - NETWORKING FOUNDATION
============================

GOAL:
Provide real guest networking.

SMOKE TESTS

[ ] HV22.1 Guest network device
[ ] HV22.2 DHCP acquisition
[ ] HV22.3 Static IP support
[ ] HV22.4 ICMP ping
[ ] HV22.5 DNS lookup
[ ] HV22.6 HTTP request
[ ] HV22.7 Sustained traffic
[ ] HV22.8 Packet counters
[ ] HV22.9 Transcript proof
[ ] HV22.10 Minimus-log proof

PASS CRITERIA

Linux guest reaches external networks.

===============================================================================
HV23 - STORAGE FOUNDATION
=========================

GOAL:
Persistent guest storage.

SMOKE TESTS

[ ] HV23.1 Virtual disk
[ ] HV23.2 Partition creation
[ ] HV23.3 Filesystem creation
[ ] HV23.4 Mount operation
[ ] HV23.5 Write persistence
[ ] HV23.6 Read persistence
[ ] HV23.7 Reboot persistence
[ ] HV23.8 Integrity validation
[ ] HV23.9 Transcript proof
[ ] HV23.10 Minimus-log proof

PASS CRITERIA

Guest data survives reboot.

===============================================================================
HV24 - SNAPSHOT FRAMEWORK
=========================

GOAL:
Capture complete VM state.

SMOKE TESTS

[ ] HV24.1 Snapshot creation
[ ] HV24.2 Memory capture
[ ] HV24.3 Register capture
[ ] HV24.4 Device capture
[ ] HV24.5 Metadata capture
[ ] HV24.6 Snapshot verification
[ ] HV24.7 Snapshot enumeration
[ ] HV24.8 Snapshot deletion
[ ] HV24.9 Transcript proof
[ ] HV24.10 Minimus-log proof

PASS CRITERIA

VM state can be preserved.

===============================================================================
HV25 - RESTORE FRAMEWORK
========================

GOAL:
Return VM to previous state.

SMOKE TESTS

[ ] HV25.1 Snapshot restore
[ ] HV25.2 Register restore
[ ] HV25.3 Memory restore
[ ] HV25.4 Device restore
[ ] HV25.5 Filesystem restore
[ ] HV25.6 Integrity verification
[ ] HV25.7 Repeat restore
[ ] HV25.8 Rollback validation
[ ] HV25.9 Transcript proof
[ ] HV25.10 Minimus-log proof

PASS CRITERIA

VM rollback succeeds.

===============================================================================
HV26 - MULTI-VM EXECUTION
=========================

GOAL:
Run multiple Linux guests simultaneously.

SMOKE TESTS

[ ] HV26.1 Two guests
[ ] HV26.2 Three guests
[ ] HV26.3 CPU scheduling
[ ] HV26.4 Memory isolation
[ ] HV26.5 Device isolation
[ ] HV26.6 Guest restart
[ ] HV26.7 Guest shutdown
[ ] HV26.8 Stability validation
[ ] HV26.9 Transcript proof
[ ] HV26.10 Minimus-log proof

PASS CRITERIA

Hyper-Zig becomes a true multi-VM hypervisor.

===============================================================================
HV27 - VM NETWORK FABRIC
========================

GOAL:
Allow guests to communicate.

SMOKE TESTS

[ ] HV27.1 VM-to-VM ping
[ ] HV27.2 VM-to-VM SSH
[ ] HV27.3 VM-to-VM file transfer
[ ] HV27.4 Network isolation
[ ] HV27.5 Routing validation
[ ] HV27.6 Throughput validation
[ ] HV27.7 Multiple guest traffic
[ ] HV27.8 Error handling
[ ] HV27.9 Transcript proof
[ ] HV27.10 Minimus-log proof

PASS CRITERIA

Guests operate as a virtual network.

===============================================================================
HV28 - HOST/GUEST INTEGRATION
=============================

GOAL:
Efficient host and guest interaction.

SMOKE TESTS

[ ] HV28.1 Host file share
[ ] HV28.2 Guest file share
[ ] HV28.3 Copy host->guest
[ ] HV28.4 Copy guest->host
[ ] HV28.5 Shared directory
[ ] HV28.6 Integrity validation
[ ] HV28.7 Large file transfer
[ ] HV28.8 Permission validation
[ ] HV28.9 Transcript proof
[ ] HV28.10 Minimus-log proof

PASS CRITERIA

Host and guest cooperate naturally.

===============================================================================
HV29 - DETERMINISTIC REPLAY
===========================

GOAL:
Record and replay execution.

SMOKE TESTS

[ ] HV29.1 Recording begins
[ ] HV29.2 Recording ends
[ ] HV29.3 Replay begins
[ ] HV29.4 Replay ends
[ ] HV29.5 Register equivalence
[ ] HV29.6 Memory equivalence
[ ] HV29.7 Device equivalence
[ ] HV29.8 Repeatability validation
[ ] HV29.9 Transcript proof
[ ] HV29.10 Minimus-log proof

PASS CRITERIA

Guest execution becomes reproducible.

===============================================================================
HV30 - LIVE MIGRATION
=====================

GOAL:
Move a running guest between hosts.

SMOKE TESTS

[ ] HV30.1 Migration start
[ ] HV30.2 Memory transfer
[ ] HV30.3 Register transfer
[ ] HV30.4 Device transfer
[ ] HV30.5 Resume target host
[ ] HV30.6 Guest continuity
[ ] HV30.7 Network continuity
[ ] HV30.8 Stability validation
[ ] HV30.9 Transcript proof
[ ] HV30.10 Minimus-log proof

PASS CRITERIA

Running guests move between machines.

===============================================================================
HV31 - VM INTROSPECTION
=======================

GOAL:
Observe guest internals safely.

PASS CRITERIA

Guest state becomes inspectable.

===============================================================================
HV32 - HYPER-ZIG DEBUGGER
=========================

GOAL:
Inspect guests in real time.

PASS CRITERIA

Hyper-Zig becomes a teaching and debugging platform.

===============================================================================
HV33 - SECURITY HARDENING
=========================

GOAL:
Audit and strengthen isolation.

PASS CRITERIA

Security posture becomes measurable.

===============================================================================
HV34 - PERFORMANCE VALIDATION
=============================

GOAL:
Benchmark everything.

PASS CRITERIA

Performance claims become provable.

===============================================================================
HV35 - HYPER-ZIG PLATFORM
=========================

GOAL:
A complete hypervisor ecosystem.

PASS CRITERIA

Hyper-Zig is no longer merely a project.

It is a platform.

===============================================================================
ULTIMATE OBJECTIVE
==================

Not:

"Boot Linux."

Not:

"Boot Ubuntu."

Not:

"Match Diosix."

The objective is:

Build a hypervisor whose capabilities, validation,
reproducibility, transparency, and educational value
establish a standard that future systems projects aspire to.

HV20 proves Linux can live inside Hyper-Zig.

# HV35 proves Hyper-Zig can stand on its own.
```


Hyper-Zig is not merely a hypervisor.

Hyper-Zig is an attempt to build the most understandable systems project ever created.

The goal is not simply to create a machine that works.

The goal is to create a machine that explains itself.

Every capability should be visible.

Every claim should be proven.

Every failure should be understandable.

Every milestone should leave behind evidence.

---

One day a developer should be able to type:

```
zig build
```

and receive:

```
working system
validation report
minimus log
proof index
transcript archive
diagnostic map
```

The system should not merely report success.

It should explain why success occurred.

The system should not merely report failure.

It should explain where failure occurred.

---

The minimus log is the heartbeat of Hyper-Zig.

Every smoke test contributes a single sentence.

Example:

```
HV7.1 PASS Guest entry succeeds
HV7.2 PASS Guest exit succeeds
HV7.3 PASS Guest PC advances correctly
HV7.4 PASS Guest register capture validated
```

Hundreds of tests may exist.

The minimus log remains readable.

A person should be able to understand the health of the entire system in minutes rather than hours.

---

Every smoke test generates a proof file.

Example:

```
HV7.1-guest-entry.txt
HV12.4-cpu-discovery.txt
HV20.8-csharp-compile.txt
```

Every proof file contains:

```
what was tested
what was expected
what was observed
which command executed
which transcript contains evidence
which source files are involved
where to begin debugging
```

The objective is immediate understanding.

The objective is immediate diagnosis.

The objective is immediate trust.

---

Most operating systems are difficult to learn.

Most hypervisors are difficult to learn.

Most educational resources stop where implementation begins.

Hyper-Zig attempts to bridge that gap.

Every major milestone should answer:

```
what happened
why it matters
how it was proven
```

A student should be able to move from:

```
guest image loading
```

to:

```
guest execution
```

to:

```
Linux boot
```

to:

```
Ubuntu development workstation
```

while observing evidence at every stage.

Learning should come from observation, not guesswork.

---

For educators, Hyper-Zig provides a complete progression from bare-metal execution to a modern Linux environment.

Each step is independently demonstrable.

Each step is independently testable.

Each step is independently explainable.

Instead of teaching theory alone, educators can point directly to working implementations and validated proof chains.

Every lesson can be accompanied by evidence.

---

For developers, Hyper-Zig aims to make debugging radically cheaper.

Most debugging consists of searching for information that should have been available from the beginning.

A failure should reveal:

```
what failed
why it failed
where it failed
which files are involved
which evidence was expected
which evidence was missing
```

The objective is to reduce investigation time from hours to minutes.

Eventually a developer should be able to locate most faults by reading a single proof file.

---

For future generations of engineers, Hyper-Zig seeks to preserve both implementation and explanation.

Many projects survive.

Their reasoning does not.

Years later the source code remains while the original design decisions disappear.

Future developers inherit complexity without context.

Hyper-Zig seeks to preserve:

```
what was built
why it was built
when it was built
how it was validated
```

The evidence should survive alongside the code.

---

Hyper-Zig does not seek distinction merely by booting Linux.

Many projects boot Linux.

Hyper-Zig seeks distinction through visibility.

A mature Hyper-Zig system should eventually provide:

```
complete validation chains
complete proof archives
complete transcript archives
complete diagnostic maps
complete milestone histories
```

The system should be inspectable from top to bottom.

Nothing should require faith.

Everything should provide evidence.

---

Imagine if Microsoft had shipped the entire history of Windows with every subsystem explained, every milestone documented, every design decision preserved, every failure diagnosable, and every capability backed by proof.

Imagine if x86 history had come with a map.

Imagine if every layer taught the next layer.

Imagine if every subsystem explained itself.

Imagine if every failure immediately revealed its cause.

Imagine if a newcomer could begin at the first milestone and follow a complete path all the way to a modern Ubuntu development workstation.

That is the long-term objective.

Not merely software that works.

Software that teaches.

Software that proves.

Software that remembers.

Software that explains itself.

Hyper-Zig is not attempting to become another hypervisor.

Hyper-Zig is attempting to become the most understandable hypervisor ever built.

If successful, Hyper-Zig will not merely preserve code.

It will preserve understanding.

