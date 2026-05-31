# ZIGN01D V0 Status

## Implemented:

- RISC-V `_start` assembly entry that sets the stack, clears BSS, and calls `kmain`.
- QEMU virt UART polling output and input at MMIO address `0x10000000`.
- Kernel boot logs using `[ZIGN01D][LEVEL][SUBSYSTEM][CODE] message`.
- Memory reporting for QEMU virt DRAM and kernel linker symbols.
- PMM V0 physical page accounting for the known QEMU virt RAM range, with kernel-owned pages reserved and shell-visible counters.
- Interactive UART shell with `help`, `mem`, `uptime`, `reboot`, `shutdown`, `log`, and `status`.
- Panic path that logs panic evidence and halts.
- Build, run, debug, clean, and smoke-test scripts with logs under `logs/latest/`.

## Stubbed but wired:

- IRQ/trap setup is logged as a stub.
- Timer initialization is logged as a stub; `uptime` reads `rdtime` directly.
- Scheduler initialization is logged as a stub.
- Userspace init is logged as a stub.

## Not started:

- Networking.
- Storage/filesystem.
- Modem, SMS, and calls.
- GUI, touchscreen, audio, and applications.
- Real process isolation and virtual memory.
- Production PMM behavior, swap, and NUMA.
