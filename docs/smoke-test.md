# V0 Smoke Test

Run the V0 smoke test from the repository root:

```sh
./smoke/smoke-v0.sh
```

## What It Proves

The smoke test proves that:

- `./scripts/build.sh` produced `zig-out/bin/zign01d-v0.elf`.
- `qemu-system-riscv64 -machine virt -nographic` launched the produced ELF.
- The kernel emitted the required boot log markers over the real QEMU virt UART.
- The interactive shell reached the `zign01d>` prompt.
- The shell accepts real typed commands from the test harness.
- The transcript used for validation is saved as failure evidence.

## What It Does Not Prove

The smoke test does not prove that:

- Memory management has a complete allocator or page-frame database.
- Interrupts are fully enabled and dispatched.
- The timer is programmed for scheduler ticks.
- The scheduler runs multiple tasks.
- Userspace isolation exists.

Those systems are explicitly marked as V0 stubs where applicable.

## Failure Evidence

On failure, inspect:

- `logs/latest/build.log`
- `logs/latest/qemu.log`
- `logs/latest/smoke.log`
- `smoke/transcripts/latest.txt`
- `logs/latest/qemu-smoke-transcript.txt`

The smoke script prints PASS or FAIL for every marker in `smoke/expected-markers.txt` and returns nonzero if any marker is missing.
