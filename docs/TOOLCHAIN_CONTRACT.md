# ZIGN01D Toolchain Contract

This document records the known-good local toolchain for the current ZIGN01D proof ladder.

## Known-Good Toolchain

- Host: Linux
- Zig: 0.14.1
- Zig path: `/opt/zig/zig`
- QEMU binary: `qemu-system-riscv64`
- QEMU machine: `virt`
- CPU: `rv64`
- Memory: `128M`
- Serial: `stdio`
- Monitor: `none`

The smoke tests launch QEMU with the RISC-V `virt` machine and serial console so the proof remains scriptable.

## Exact Local Checks

```sh
/opt/zig/zig version
qemu-system-riscv64 --version
uname -a
```

## Version Rule

Other Zig versions may work, but Zig 0.14.1 is the known-good version. If another Zig version fails, that is not automatically a kernel bug. First reproduce with `/opt/zig/zig` at version `0.14.1`, then document any toolchain difference in the change or issue.

Toolchain changes should be documented because they can change build output, warning behavior, emulator behavior, or smoke-test timing.
