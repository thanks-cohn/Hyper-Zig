# ZIGN01D Proof Contract

The central rule is:

- no claim without proof;
- no proof without command;
- no command without expected output;
- no milestone without smoke test;
- no smoke test without documentation.

## What PASS means

A smoke PASS means the smoke script ran in the current environment and observed the expected strings or conditions it checks. PASS is evidence for those checked claims only.

## What PASS does not mean

PASS does not mean production readiness, real hardware support, security, performance, full driver support, internet access, SMS support, modem support, or a finished operating system.

## How smoke tests are used

Smoke tests build or run the kernel under controlled QEMU conditions, drive enough input to reach a milestone, and verify stable markers. They are executable documentation for the milestone.

Required baseline commands:

```sh
./scripts/build.sh
./smoke/smoke-v0.sh
./smoke/smoke-v1.sh
./smoke/smoke-v2.sh
./smoke/smoke-v3.sh
./smoke/smoke-v4.sh
./smoke/smoke-comm-v0.sh
./smoke/smoke-all.sh
```

## How transcripts are used

Transcripts are proof artifacts. They help students inspect what QEMU printed during a run. Generated transcripts usually should not be committed because they are environment-specific and can become stale. Commit expected strings and smoke scripts instead.

## How to triage a failure

1. Re-run the exact command once to rule out a local interruption.
2. Check whether the build failed before QEMU started.
3. Check whether QEMU is installed and runnable.
4. Read the generated transcript or log if one was produced.
5. Identify the first missing expected marker.
6. Trace that marker to source.
7. Fix the code, test, or documentation; do not remove the check to hide the failure.

## Why honest not-implemented output is valuable

A not-implemented line tells students where the boundary is. It prevents a placeholder from becoming a false feature claim. In ZIGN01D, honest scaffolds are valid educational milestones when they are documented and smoke-tested.
