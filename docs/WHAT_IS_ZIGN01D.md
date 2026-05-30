# What is ZIGN01D?

ZIGN01D is a proof-driven RISC-V Zig teaching kernel.

It is a small, readable kernel laboratory for studying how a kernel starts, speaks over UART, dispatches shell commands, names machine boundaries, reports traps, reads a polling timer, protects itself around MMIO assumptions, and records proof through smoke tests. ZIGN01D exists to make the invisible parts of a kernel visible.

## Why does it exist?

ZIGN01D exists because kernel ideas are often hidden behind large codebases, hardware-specific assumptions, and undocumented success claims. This repository keeps the scope small enough that a student can trace a path from reset entry to shell output and from shell command text to diagnostic output.

The project values:

- readable source over broad feature claims;
- reproducible smoke proof over narrative claims;
- explicit scaffolds over fake subsystems;
- honest limitations over incomplete demonstrations that pretend to be complete.

## What does it teach?

ZIGN01D currently teaches the bones of a small kernel:

- boot entry and linker placement;
- UART initialization and serial output;
- a polling UART shell;
- command dispatch and diagnostics;
- memory-map assumptions for QEMU virt;
- machine/CPU boundary reporting;
- trap-vector installation and synthetic trap reporting;
- `rdtime` polling timer diagnostics;
- guarded MMIO probe policy;
- communication scaffolds with not-implemented output;
- smoke tests as executable proof;
- documentation as part of the implementation.

## Why RISC-V?

RISC-V gives the project a clean teaching target. The architecture is public, widely taught, and supported by QEMU. Students can discuss privilege boundaries, CSRs, trap causes, timer reads, and memory-mapped devices without beginning from a proprietary platform.

ZIGN01D does not claim broad real hardware support. Its proven target is the repository's QEMU RISC-V path.

## Why Zig?

Zig is explicit about memory, targets, linking, and freestanding builds. It lets students inspect a kernel without first accepting a large runtime. The project uses Zig as the teaching implementation language, not as a claim that every kernel should be written in Zig.

## Why QEMU first?

QEMU provides a repeatable classroom machine. It makes smoke tests practical, keeps the first milestones independent of fragile boards, and lets students reproduce the same transcript on development machines.

QEMU-first does not mean hardware-never. It means the project proves the educational foundation in an emulator before making any hardware claim.

## Why smoke tests?

Smoke tests turn claims into commands. A milestone is easier to trust when the repository contains the exact command used to boot the kernel, drive the shell, and check expected strings.

A passing smoke test means the checked strings appeared in that controlled run. It does not mean the subsystem is complete, safe for production, or supported on every machine.

## Why breadcrumbs?

Breadcrumbs give students a stable way to read boot and diagnostic progress. The `[ZIGN01D][LEVEL][SUBSYSTEM][CODE] message` format teaches that kernel output should carry enough context to support debugging and proof review.

## Why documentation matters?

In ZIGN01D, documentation is part of the kernel. A command that exists but is undocumented is not ready for students. A smoke test that passes but has no explanation is not course material. A limitation that is not named becomes a misleading claim.

## What is intentionally not implemented?

The current educational foundation does not implement:

- production scheduling;
- userspace isolation;
- a filesystem;
- real internet access;
- real SMS send or receive;
- a real modem driver;
- phone calls;
- virtio network or block drivers;
- broad MMIO scanning;
- safe recovery from arbitrary live MMIO faults;
- real hardware support beyond the proven QEMU path.

Some commands intentionally report placeholders or not-implemented states. Those outputs are useful because they teach subsystem boundaries without pretending the subsystem exists.

## What would make this useful in a classroom?

A classroom can use ZIGN01D when each lab has:

- source files small enough to read;
- commands that build and run consistently;
- expected output that students can compare;
- assignments that ask for minimal, explainable changes;
- grading that rewards proof and honest limitation statements;
- documentation that maps code to concepts.

## Long-term educational vision

The long-term vision is an educational operating-system foundation that can support comparative kernel study. ZIGN01D should remain the RISC-V Zig kernel lab, while possible future sibling repositories may compare the same milestones across languages or architectures.

The project should grow by adding small, documented, smoke-tested milestones rather than by making broad unsupported claims.
