# V0 Boot Process

The V0 boot path is the first contract for the system.

```text
power on
  -> boot/entry.S
  -> kernel/arch/riscv64/boot.zig
  -> kernel/main.zig
  -> memory online
  -> interrupts online
  -> scheduler online
  -> userspace init
  -> UART shell
```

## Responsibilities

- `boot/entry.S` provides the earliest RISC-V entry point and transfers control
  into Zig.
- `boot/linker.ld` defines the kernel image layout.
- `kernel/arch/riscv64/boot.zig` owns architecture bootstrap handoff.
- `kernel/main.zig` sequences machine initialization.
- `userspace/init/init.zig` is the first userspace program once the scheduler can
  run tasks.
