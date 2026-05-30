# ZIGn01d

A phone should be a machine.

Modern phones are increasingly difficult to understand, modify, repair, or own. Most software assumes permanent dependence on large vendors, proprietary ecosystems, and continuously changing platforms.

ZIGN01D is an attempt to build a phone operating system from first principles.

Goals:

- User ownership.
- Long-term maintainability.
- Portable architecture.
- Open runtime hosting.
- Native RISC-V support.
- Clear and inspectable design.

ZIGN01D is not tied to a single language ecosystem.

The system should eventually be capable of hosting:

- Zig
- C
- C++
- Java
- Kotlin
- C#

and any future runtime that can be supported through stable system interfaces.

Milestones:

V0
- Boot on RISC-V under QEMU.
- Memory management.
- Interrupts.
- Scheduler.
- Shell.

V1
- Calls.
- SMS.
- Internet access.
- Local storage.

If V1 can call, text, and access the internet, it is a phone.

Everything else can be built on top.

Long term:

The objective is not merely to create another phone operating system.

The objective is to create a durable foundation for personal computing, one capable of scaling from phones to workstations, clusters, and future hardware while remaining understandable by the people who use it.

A machine should outlive its manufacturer.

We intend to find out how far that idea can be taken.
