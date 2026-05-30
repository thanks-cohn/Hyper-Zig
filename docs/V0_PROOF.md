# ZIGN01D V0 Proof Record

V0 established that a tiny RISC-V 64 freestanding Zig kernel can build, boot under QEMU `virt`, reach Zig `kmain`, use the QEMU 16550 UART at MMIO `0x10000000`, run an interactive shell, and shut QEMU down through the virt finisher.

## Known V0 commit

The local V0 commit recorded for this mission is:

```text
035558b Bring up ZIGN01D V0 RISC-V QEMU shell
```

## Build proof command

```sh
./scripts/build.sh
```

The build output binary is:

```text
zig-out/bin/zign01d-v0
```

It is not `zig-out/bin/zign01d-v0.elf`. Smoke scripts must use the real output path.

## QEMU proof command

```sh
./scripts/run-qemu.sh
```

The QEMU launch model is `qemu-system-riscv64 -machine virt -cpu rv64 -smp 1 -m 128M -nographic -monitor none -serial stdio -kernel zig-out/bin/zign01d-v0`.

## Manual transcript summary

Commands manually proven in V0:

- `help`: shell command list printed.
- `mem`: linker-backed memory report printed, including DRAM base and kernel/BSS symbols.
- `uptime`: live `rdtime` polling value printed.
- `shutdown`: QEMU virt finisher shutdown path worked.

## V0 boot markers recorded

```text
[ZIGN01D][INFO][BOOT][BOOT001] kernel entry reached
[ZIGN01D][INFO][BOOT][BOOT002] ZIGN01D V0
[ZIGN01D][INFO][UART][UART001] uart initialized at qemu virt mmio 0x10000000
[ZIGN01D][INFO][MEM][MEM001] memory map initialized for qemu virt dram
[ZIGN01D][INFO][MEM][MEM002] dram base=0x80000000 kernel_start=0x80200000 kernel_end=0x80212000 bss=0x80202000..0x80202000
[ZIGN01D][WARN][IRQ][IRQ002] trap vector stub active
[ZIGN01D][WARN][IRQ][IRQ001] interrupt controller stub active; polling uart shell enabled
[ZIGN01D][WARN][TIMER][TIMER001] timer stub active; uptime uses rdtime polling
[ZIGN01D][INFO][SCHED][SCHED001] scheduler stub active
[ZIGN01D][WARN][INIT][INIT001] userspace init stub active
[ZIGN01D][INFO][SHELL][SHELL001] shell ready
```
