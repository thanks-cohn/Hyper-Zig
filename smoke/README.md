# ZIGN01D V0 Smoke

`smoke-v0.sh` is an evidence-producing boot test. It builds the kernel, launches QEMU in a controlled serial session, captures the transcript, and verifies every marker in `expected-markers.txt`.

Run from the repository root:

```sh
./smoke/smoke-v0.sh
```

Artifacts:

- `smoke/transcripts/latest.txt`
- `logs/latest/smoke.log`
- `logs/latest/qemu.log`
- `logs/latest/qemu-smoke-transcript.txt`
