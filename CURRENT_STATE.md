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


