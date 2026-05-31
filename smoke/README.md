# ZIGN01D Smoke Tests

Smoke tests are evidence-producing boot tests. They build the kernel, launch QEMU in a controlled serial session, capture the transcript, and verify milestone markers plus honest not-implemented boundaries.

Run the PMM V0 proof from the repository root:

```sh
./smoke/smoke-pmm-v0.sh
```

Run the full ladder:

```sh
./smoke/smoke-all.sh
```

PMM V0 runs after HEAP V0 in the full ladder and proves page accounting, allocation/free counter changes, invalid-free rejection, double-free rejection, and exhaustion rejection.

Artifacts are written under:

- `smoke/transcripts/`
- `logs/latest/`
