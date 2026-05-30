# ZIGN01D V1 Foundation Audit

This audit rejects decorative subsystems. Each section identifies owned state, storage, init path, shell exposure, smoke proof, placeholders, and the next file to inspect.

## BOOT

- Real state: boot stage is represented by ordered breadcrumbs from kernel entry through boot completion.
- Stored in: serial transcript; boot stage is emitted by `kernel/arch/riscv64/boot.zig` and `kernel/main.zig`.
- Init path: `_start` transfers to `kmain`, then `boot.markKernelEntry()` and `diag.bootStep("BOOT090", ...)` run.
- Shell command: `status` reports `boot_stage=complete`; `breadcrumbs` documents the breadcrumb rules.
- Smoke proof: `smoke/smoke-v1.sh` requires `BOOT001`, `BOOT002`, and the shell prompt.
- Placeholder: assembly-level `BOOT000`, `BOOT010`, `BOOT011`, `BOOT020`, and `BOOT030` were not added in V1 because writing UART from assembly before the Zig UART path would duplicate MMIO assumptions and risk the proven V0 entry path.
- Inspect next: `boot/entry.S`, `kernel/arch/riscv64/boot.zig`, `kernel/main.zig`.

## UART

- Real state: QEMU virt UART MMIO constants and polling transmit/receive operations.
- Stored in: `kernel/console/uart.zig` constants and functions.
- Init path: `uart.init()` logs `UART001`.
- Shell command: every shell command uses UART; `status` reports UART active.
- Smoke proof: V0 and V1 smoke require `UART001` and processed shell commands.
- Placeholder: interrupt-driven UART is not implemented.
- Inspect next: `kernel/console/uart.zig`.

## MEM

- Real state: DRAM base and linker-provided kernel/BSS symbols.
- Stored in: linker symbols from `boot/linker.ld`, reported by `kernel/memory/pmm.zig`.
- Init path: `memory.init()` logs `MEM001` and calls `report()`.
- Shell command: `mem` prints the live linker-symbol report.
- Smoke proof: V0 smoke sends `mem`; V1 status includes memory state.
- Placeholder: no real allocator or page management policy is active in V1.
- Inspect next: `kernel/memory/pmm.zig`, `kernel/memory/allocator.zig`, `boot/linker.ld`.

## TIMER

- Real state: live RISC-V `rdtime` values.
- Stored in: hardware counter read by `kernel/interrupt/timer.zig`.
- Init path: `timer.init()` logs `TIMER001` degraded polling mode.
- Shell command: `uptime` reads `rdtime` and prints a non-canned tick value.
- Smoke proof: `smoke/smoke-v1.sh` extracts `uptime ticks=` and fails on missing or zero values.
- Placeholder: timer interrupts and scheduler ticks are missing.
- Inspect next: `kernel/interrupt/timer.zig`.

## TASK

- Real state: a static cooperative task table with `pid=0 kernel running` and `pid=1 init ready`.
- Stored in: `kernel/task/task.zig` static `tasks` array plus initialized/running state.
- Init path: `task.init()` sets module state and logs `TASK001`.
- Shell command: `tasks` prints from the static task table.
- Smoke proof: V1 smoke requires `TASK001` and `tasks:` output.
- Placeholder: no preemption, context switching, or scheduler rewrite.
- Inspect next: `kernel/task/task.zig`, then `kernel/scheduler/scheduler.zig`.

## DEV

- Real state: static device registry for UART, timer, PLIC, RAM, virtio-net placeholder, virtio-blk placeholder, and modem placeholder.
- Stored in: `kernel/device/device.zig` static `devices` array.
- Init path: `device.init()` marks the registry initialized and logs `DEV001`.
- Shell command: `devices` prints registry records and inspect hints.
- Smoke proof: V1 smoke requires `DEV001` and `devices:` output.
- Placeholder: virtio-net, virtio-blk, PLIC interrupt operation, and modem driver are not implemented.
- Inspect next: `kernel/device/device.zig`.

## SYSCALL

- Real state: static syscall table records for `write`, `read`, `uptime`, `device_list`, `net_status`, and `phone_status`.
- Stored in: `kernel/syscall/syscall.zig` static `syscalls` array.
- Init path: `syscall.init()` marks the table initialized and logs `SYS001`.
- Shell command: `syscalls` prints the table and explicitly says the trap boundary is not implemented.
- Smoke proof: V1 smoke requires `SYS001` and `syscalls:` output.
- Placeholder: full userspace trap handling is not implemented.
- Inspect next: `kernel/syscall/syscall.zig`, `kernel/arch/riscv64/trap.zig`.

## NET

- Real state: network state enum with current state `driver_missing` after init.
- Stored in: `kernel/net/net.zig` module state.
- Init path: `net.init()` sets `driver_missing` and logs `NET001`.
- Shell command: `net` prints the current state; `ping` emits `NET002` and refuses fake success.
- Smoke proof: V1 smoke requires `NET001`, `network driver not implemented`, and rejects fake success strings.
- Placeholder: virtio-net transport and packet I/O are missing.
- Inspect next: `kernel/net/net.zig`, then a future virtio-mmio driver.

## PHONE

- Real state: explicit modem, cellular, audio call path, and SMS component states.
- Stored in: `kernel/phone/phone.zig` module state.
- Init path: `phone.init()` sets all components missing and logs `PHONE001`.
- Shell command: `phone`, `call`, and `sms` expose missing component state and refuse fake success.
- Smoke proof: V1 smoke requires `PHONE001`, `modem driver missing`, `cellular stack missing`, `audio path missing`, and `sms stack missing`.
- Placeholder: all phone hardware and service paths are missing.
- Inspect next: `kernel/phone/phone.zig`, then modem transport, cellular control, audio route, and security model.

## SHELL

- Real state: command dispatch table and UART input line buffer.
- Stored in: `kernel/console/shell.zig`.
- Init path: `shell.start()` logs `SHELL001` and enters the prompt loop.
- Shell command: all V1 commands are shell-visible.
- Smoke proof: V0 and V1 smoke require prompt output and command responses.
- Placeholder: no command history, quoting, or structured argument parser.
- Inspect next: `kernel/console/shell.zig`.

## SMOKE

- Real state: controlled QEMU sessions, transcripts, marker assertions, and uptime extraction.
- Stored in: `smoke/smoke-v0.sh`, `smoke/smoke-v1.sh`, and generated transcripts under `smoke/transcripts/`.
- Init path: smoke scripts run `./scripts/build.sh`, launch QEMU, send shell commands, and capture serial output.
- Shell command: smoke exercises real shell commands rather than checking only boot text.
- Smoke proof: `smoke/smoke-v1.sh` fails on missing shell prompt, missing command responses, fake placeholder success, or absent/non-live uptime.
- Placeholder: smoke does not yet attach a debugger or validate memory side effects beyond serial proof.
- Inspect next: `smoke/smoke-v1.sh`, `smoke/smoke-v0.sh`, `scripts/build.sh`, `scripts/run-qemu.sh`.
