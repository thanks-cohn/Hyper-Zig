# V0 Smoke Test

The smoke test is the definition of done for V0.

## Required Sequence

```text
power on
  -> kernel entry
  -> memory online
  -> interrupts online
  -> scheduler online
  -> userspace init
  -> shell
```

## Required Commands

- `help`
- `mem`
- `uptime`
- `reboot`
- `shutdown`

## Pass Criteria

- Boots every run.
- Shell appears.
- Commands respond.
- Reboot works.
- Shutdown works.

Until implementation lands, `smoke/expected-boot.txt` records the target
transcript and `scripts/run-qemu.sh` documents the intended QEMU invocation.
