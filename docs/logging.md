# ZIGN01D Logging Standard

Every project log line uses this format:

```text
[ZIGN01D][LEVEL][SUBSYSTEM][CODE] message
```

Example:

```text
[ZIGN01D][INFO][BOOT][BOOT001] kernel entry reached
```

## Levels

- `INFO` — expected progress or state.
- `WARN` — intentionally stubbed V0 component or recoverable limitation.
- `ERROR` — failure evidence, panic, or script failure.

## Subsystems

V0 reserves these subsystem names:

- `BOOT`
- `UART`
- `MEM`
- `IRQ`
- `TIMER`
- `SCHED`
- `SHELL`
- `PANIC`
- `SMOKE`
- `BUILD`
- `QEMU`

## Code Naming Scheme

Codes use the subsystem prefix plus a three-digit number. Examples:

- `BOOT001` — kernel entry reached.
- `UART001` — UART initialized.
- `MEM001` — memory map initialized.
- `PANIC001` — panic path reached.

Keep codes stable so boot transcripts can be compared across runs.

## How to Read Logs

Read left to right:

1. Confirm the prefix is `[ZIGN01D]`.
2. Check `LEVEL` for failure severity.
3. Use `SUBSYSTEM` to find the responsible component.
4. Use `CODE` to compare against expected boot markers.
5. Read the message for concrete status or failure evidence.

## Diagnosing a Failed Boot

1. Open `logs/latest/build.log` and confirm the ELF was produced.
2. Open `logs/latest/qemu.log` and confirm the QEMU command launched.
3. Open `logs/latest/qemu-smoke-transcript.txt` and find the last emitted marker.
4. If `PANIC001` appears, inspect the following `PANIC002` line for subsystem, code, and message.
5. If the transcript is empty, QEMU likely failed before the kernel wrote to UART.
6. If the prompt is missing, inspect `SHELL001` and the last initialization log before it.

## Storage Locations

- Latest evidence: `logs/latest/`
- Archived evidence: `logs/archive/`
- Smoke transcripts: `smoke/transcripts/`
