# ZIGN01D V2 Machine Boundary Audit

## Boot and CPU

- Hart id is captured from the RISC-V firmware handoff register before BSS clearing stores kernel state.
- The `machine`/`cpu` shell command reports hart id, QEMU `virt` assumptions, `rdtime`, `stvec`, `sie`, and `sip`.
- The kernel avoids reading machine-mode CSRs from supervisor mode because doing so would intentionally fault before trap recovery is robust.

## Trap boundary

- `trap.init()` writes `stvec` to `zign01d_trap_vector`.
- The assembly vector records `scause`, `sepc`, and `stval`, then dispatches to `zign01d_handle_trap`.
- Unhandled traps report diagnostic evidence and halt through the panic boundary.

## Device boundary

The static device registry remains by design. V2 adds explicit status classes:

- `active`: used by a real kernel path now.
- `detected`: reserved for hardware identified by a real probe.
- `placeholder`: named boundary exists but no driver operation is claimed.
- `missing`: required driver or stack is absent.
- `unknown`: unsafe or unimplemented probe means the kernel cannot classify the device yet.

Virtio MMIO is `unknown`/`missing`, not `detected`, because the current kernel does not yet have safe load-fault recovery for absent MMIO slots. This prevents fake driver success.

## Interrupts and timer

- Timer source is `rdtime` polling.
- PLIC is honestly reported as a placeholder.
- `sie`/`sip` are reported for inspection, but interrupts are not claimed as enabled or handled.

## Userspace and syscalls

V2 does not add userspace. Existing syscall output remains diagnostic state only. Missing userspace features must continue to warn rather than pretend to run.
