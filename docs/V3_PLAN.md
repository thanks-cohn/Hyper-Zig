# ZIGN01D V3 Timer + Trap Recovery Readiness Plan

V3 keeps the V0 boot path, V1 diagnostic shell, and V2 machine boundary intact while adding an honest timer and trap-readiness foundation. The output binary remains `zig-out/bin/zign01d-v0` so existing build and smoke scripts continue to exercise the same kernel entry.

## V3 adds

- Shell commands `time`, `ticks`, and `heartbeat` that read `rdtime` directly and label the source as polling.
- Timer diagnostics that explicitly say timer interrupts are not enabled and scheduler preemption is not implemented.
- Trap cause-name classification for common RISC-V supervisor exception causes.
- More readable trap status that reports numeric cause, readable cause name, EPC, TVAL, recovery policy, and handler name.
- A smoke-safe `trap-test` command that emits synthetic cause-name diagnostics and clearly says live recovery is not implemented.
- Guarded virtio-mmio probing design scaffolding without probing absent MMIO slots.
- Smoke proof in `smoke/smoke-v3.sh` covering V3 boot, shell help, timer/heartbeat diagnostics, trap status, trap-test, and deferred virtio probing.

## V3 proves

- `rdtime` polling diagnostics are available.
- The shell can report timer and heartbeat state.
- Trap cause names are available for common RISC-V causes.
- Trap status is more readable than V2.
- `trap-test` emits controlled diagnostics without crashing QEMU.
- Guarded MMIO probing is designed but not falsely claimed.

## V3 does not prove

- Timer interrupts.
- Preemptive scheduling.
- A userspace trap/syscall boundary.
- Virtio-mmio probing.
- Virtio-net.
- Virtio-blk.
- A filesystem.
- A real phone/modem stack.
- Stack unwinding.
- A full trap-frame dump.
- Safe live trap recovery.

## Acceptance proof

The V3 proof is the existing build and smoke set plus the new V3 smoke:

```sh
./scripts/build.sh
./smoke/smoke-v0.sh
./smoke/smoke-v1.sh
./smoke/smoke-v2.sh
./smoke/smoke-v3.sh
```

## Next milestone

If V3 passes, the next logical milestone is V4: guarded virtio-mmio probe foundation. V4 should not start until the trap path can safely classify and recover from load/store faults around explicit guarded MMIO reads.
