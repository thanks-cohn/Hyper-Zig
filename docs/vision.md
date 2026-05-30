# ZIGN01D Vision

A phone should be a machine: understandable, repairable, portable, and owned by
its user.

ZIGN01D starts with a small RISC-V kernel written in Zig. V0 is intentionally
narrow: prove that a kernel can boot, initialize the essential machine services,
start userspace, and expose a shell. A future vX can only be a success if this
kernel stays simple enough to inspect and strong enough to host everything that
comes next.

## Principles

- **User ownership:** the owner can inspect, replace, and extend the system.
- **Durable interfaces:** runtimes and applications should target stable system
  boundaries rather than vendor-specific platforms.
- **Portable architecture:** RISC-V is the first target, not the last possible
  architecture.
- **Small trusted core:** the kernel should do the minimum required to provide
  memory, interrupts, scheduling, device access, and process isolation.
- **Runtime neutrality:** Zig is the implementation language for the kernel, but
  the system should eventually host Zig, C, C++, Java, Kotlin, C#, and future
  runtimes through explicit interfaces.

## North Star

V1 is a phone when it can call, text, and reach the internet. vX is the durable
personal-computing foundation that can grow from phones to workstations,
clusters, and future hardware without becoming impossible for its owners to
understand.
