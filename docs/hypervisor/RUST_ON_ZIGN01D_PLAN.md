# Rust on ZIGN01D Plan

The fastest Rust path is inside a Linux guest after Linux actually boots. HV0 does not boot Linux and does not provide a Rust guest toolchain.

## Layer ownership

- Zig owns boot, memory, traps, VM data structures, hypervisor entry/return, and the core kernel/hypervisor boundary.
- Rust and RIG-powered services should sit above the Zig kernel/hypervisor core later, after the memory and guest boundaries are real and observable.
- Native Rust-on-ZIGN01D is later than Linux guest Rust because it requires a runtime, allocation model, ABI decisions, build integration, and safety boundaries that do not exist yet.
- WASM can become a sandboxed app or plugin layer later, after the kernel has real isolation and loading semantics.

## Practical route

1. Build the Zig hypervisor substrate honestly through HV0-HV11.
2. Boot Linux as a guest and reach a shell.
3. Add C compilation proof inside the Linux guest.
4. Add Rust tooling proof inside the Linux guest.
5. Only after those proofs, revisit native Rust services and RIG integration above explicit kernel interfaces.

Rust/RIG should not replace the Zig boot, memory, trap, VM, or hypervisor core. They should consume honest, memory-observable services once the lower layers exist.
