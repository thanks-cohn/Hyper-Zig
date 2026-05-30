# ZIGN01D V3 Timer and Trap Audit

This audit documents what the V3 timer, trap, and device-boundary diagnostics prove, and what they intentionally avoid claiming.

## Timer diagnostics

The V3 shell exposes three polling diagnostics:

- `time` prints `timer: source=rdtime-polling value=<number>`.
- `ticks` prints `ticks: source=rdtime-polling value=<number>`.
- `heartbeat` samples `rdtime` twice and prints whether the second sample is monotonic relative to the first sample.

These commands prove that the kernel can read `rdtime` through polling. They do not enable or prove timer interrupts. V3 output must continue to say `timer: interrupts=not-enabled`, and scheduler output must continue to say preemption is not implemented.

## Trap cause names

V3 maps common RISC-V exception causes to readable strings:

- `2`: illegal instruction.
- `3`: breakpoint.
- `5`: load access fault.
- `7`: store access fault.
- `8`: ecall from U-mode.
- `9`: ecall from S-mode.
- `12`: instruction page fault.
- `13`: load page fault.
- `15`: store page fault.
- any unmapped exception: unknown cause.

The live trap vector still follows the V2 safety policy: unhandled traps are reported and then routed to the panic path. V3 improves classification and status readability; it does not implement safe live recovery or instruction-skip/resume.

## `trap-test` safety

The `trap-test` shell command is synthetic by design. It prints representative cause-name mappings and states:

- recovery is not implemented;
- live fault injection is deferred until safe recovery exists.

It must not execute an illegal instruction or deliberately touch absent MMIO in V3, because the kernel cannot yet recover and resume safely.

## Guarded MMIO probing design

Virtio-mmio probing remains deferred. Before any V4 probe may scan optional MMIO windows, the kernel needs all of the following:

1. A guarded load/store API that marks a single MMIO access as recoverable.
2. Trap state that can distinguish expected guarded load/store faults from unhandled traps.
3. A trap frame or equivalent resume mechanism that can advance past the faulting instruction only for approved guarded probes.
4. Clear status output that reports real detected transport devices separately from absent slots.
5. Smoke tests that prove both present-device and absent-slot paths survive without pretending success.

Until those requirements are met, `virtio-mmio-transport` must remain `boundary_status=unknown` and its detail must say probing is deferred until guarded load/store fault recovery is proven.

## Explicit non-goals for V3

V3 does not prove timer interrupts, preemptive scheduling, userspace syscalls through traps, virtio networking, virtio block, filesystems, a real modem/phone stack, stack unwinding, full trap-frame dumps, or safe live trap recovery.
