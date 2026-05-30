# Traps and Panic Diagnostics

## Trap vector

V2 installs a supervisor trap vector during kernel initialization. The vector is intentionally small: it reads `scause`, `sepc`, and `stval`, then enters the Zig trap boundary. There is not yet a full saved register frame or trap recovery path.

## Panic report fields

The panic boundary prints:

- subsystem
- diagnostic code
- message
- numeric cause
- stage or breadcrumb hint
- inspect hints for the relevant source files and docs

This is designed for serial transcript inspection first. Stack unwinding and full trap-frame dumping are explicitly missing.

## `panic-test`

The shell command `panic-test` emits a controlled panic report and returns to the shell. This is deliberate so smoke tests can prove diagnostic evidence without halting before `shutdown` runs. It must not be interpreted as a recovered kernel panic.

Real unhandled traps dispatch through the trap handler and then halt via the panic boundary.

## Missing next work

- Save a complete trap frame.
- Distinguish interrupts from exceptions in dispatch.
- Add recoverable probe faults for optional device MMIO.
- Add stack unwinding or at least frame-pointer breadcrumbs.
