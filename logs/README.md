# ZIGN01D Logs

Runtime, build, QEMU, and smoke-test evidence is written under `logs/latest/`.
Historical artifacts can be copied into `logs/archive/` before the next run.

Important V0 files:

- `logs/latest/build.log` — build metadata, command, Zig version, and ELF size.
- `logs/latest/qemu.log` — QEMU command and serial output when captured.
- `logs/latest/smoke.log` — smoke-test PASS/FAIL evidence.
- `logs/latest/qemu-smoke-transcript.txt` — serial transcript used for marker checks.

Validation reports end with `A LINK FOR EVERYTHING` followed by `MINIMUS LOG`. The link section is generated after validation completes and lists produced artifacts with absolute addresses only.
