# ZIGN01D Source Map

This map links actual repository files to teaching concepts. It avoids invented files and avoids treating scaffolds as completed subsystems.

## Boot

- **File path:** `boot/entry.S`, `kernel/arch/riscv64/boot.zig`
- **What it teaches:** reset entry, stack setup, boot hart handoff, early boot markers.
- **What to read first:** `boot/entry.S`, then `kernel/main.zig`.
- **What not to assume:** Do not assume board-generic boot or real hardware support.

## Linker

- **File path:** `boot/linker.ld`
- **What it teaches:** kernel placement, section layout, stack symbols.
- **What to read first:** memory origin and entry symbol definitions.
- **What not to assume:** Do not assume virtual memory layout or userspace separation.

## Kernel main

- **File path:** `kernel/main.zig`
- **What it teaches:** subsystem initialization order and shell handoff.
- **What to read first:** `kmain()`.
- **What not to assume:** Init calls may initialize scaffolds, not complete drivers.

## UART

- **File path:** `kernel/console/uart.zig`
- **What it teaches:** polling MMIO serial I/O for QEMU virt.
- **What to read first:** init, byte read, byte write helpers.
- **What not to assume:** Do not assume interrupt-driven serial or hardware portability.

## Shell

- **File path:** `kernel/console/shell.zig`
- **What it teaches:** line input, command matching, diagnostic dispatch.
- **What to read first:** `start()`, `readLine()`, and `handle()`.
- **What not to assume:** The shell is not a userspace shell and has no process model.

## Commands

- **File path:** `kernel/console/shell.zig`, subsystem files called from `handle()`
- **What it teaches:** commands as explicit kernel diagnostics.
- **What to read first:** command comparisons in `handle()`.
- **What not to assume:** A command name is not proof that the named subsystem is implemented.

## Logging/breadcrumbs

- **File path:** `kernel/log.zig`, `kernel/diag/breadcrumb.zig`, `docs/LOGGING_AND_BREADCRUMBS.md`
- **What it teaches:** structured serial diagnostics.
- **What to read first:** breadcrumb write format.
- **What not to assume:** There is no durable log ring buffer yet.

## Machine/status

- **File path:** `kernel/arch/riscv64/cpu.zig`, `docs/V2_MACHINE_BOUNDARY_AUDIT.md`
- **What it teaches:** supervisor-visible CPU status and QEMU assumptions.
- **What to read first:** `printMachineStatus()`.
- **What not to assume:** The kernel does not read unsafe machine-mode CSRs from supervisor mode.

## Traps

- **File path:** `boot/entry.S`, `kernel/arch/riscv64/trap.zig`, `kernel/panic/panic.zig`, `docs/TRAPS_AND_PANIC.md`, `docs/V3_TIMER_AND_TRAP_AUDIT.md`
- **What it teaches:** trap-vector scaffold, cause naming, controlled panic reporting.
- **What to read first:** trap init, `printStatus()`, `syntheticTrapTest()`.
- **What not to assume:** Live trap recovery is limited and synthetic trap tests are not live fault injection.

## Timer

- **File path:** `kernel/interrupt/timer.zig`
- **What it teaches:** `rdtime` polling, ticks, heartbeat diagnostics.
- **What to read first:** `ticks()` and print diagnostic functions.
- **What not to assume:** Timer interrupts and preemptive scheduling are not enabled.

## MMIO/devices

- **File path:** `kernel/device/device.zig`, `kernel/device/mmio_probe.zig`, `docs/V4_GUARDED_MMIO_AUDIT.md`
- **What it teaches:** device registry, guarded probe policy, fixed QEMU virt MMIO windows.
- **What to read first:** `fixed_qemu_virtio_mmio_addresses`, `LIVE_PROBE_ENABLED`, `printReport()`.
- **What not to assume:** Live MMIO probing, virtio negotiation, queues, and interrupts are not implemented.

## COMM

- **File path:** `kernel/comm/comm.zig`, `kernel/comm/bridge.zig`, `kernel/comm/net.zig`, `kernel/comm/sms.zig`, `kernel/comm/modem.zig`, `kernel/comm/zbus.zig`, `docs/COMM_V0_AUDIT.md`
- **What it teaches:** communication boundaries and honest not-implemented states.
- **What to read first:** `comm.status()` and each `printStatus()` function.
- **What not to assume:** There is no real internet, SMS, modem, call, or host transport support.

## Smoke tests

- **File path:** `smoke/smoke-v0.sh`, `smoke/smoke-v1.sh`, `smoke/smoke-v2.sh`, `smoke/smoke-v3.sh`, `smoke/smoke-v4.sh`, `smoke/smoke-comm-v0.sh`, `smoke/smoke-all.sh`, `smoke/smoke-zbus-v0.sh`, `smoke/README.md`
- **What it teaches:** executable proof and stable output checks.
- **What to read first:** one milestone smoke script and `docs/PROOF_CONTRACT.md`.
- **What not to assume:** A smoke PASS proves only the checked behavior for that run.

## Docs

- **File path:** `docs/README.md` and linked documents.
- **What it teaches:** how the project turns source and smoke proof into course material.
- **What to read first:** `docs/WHAT_IS_ZIGN01D.md`.
- **What not to assume:** Documentation is not a substitute for smoke proof.
