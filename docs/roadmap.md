# Roadmap

## V0: The Machine Exists

Target: RISC-V under QEMU.

V0 proves the boot path and kernel foundation:

1. Enter the kernel from firmware/boot code.
2. Bring memory management online.
3. Bring traps, interrupts, and timers online.
4. Start the scheduler.
5. Launch userspace init.
6. Present an interactive shell over UART.
7. Support `help`, `mem`, `uptime`, `reboot`, and `shutdown`.

## V1: The Machine Becomes a Phone

V1 adds the minimum phone capabilities:

- Calls.
- SMS.
- Internet access.
- Local storage.

## vX: The Machine Outlives Its Manufacturer

Future versions should preserve V0's inspectability while adding hardware
support, application models, runtime hosting, graphical interfaces, and stronger
security. Each layer must justify its complexity and keep the kernel of the idea
small: people should own the machines they depend on.
