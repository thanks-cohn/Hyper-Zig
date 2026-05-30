# ZIGN01D Stability Contract

ZIGN01D prioritizes repeatable proof over feature speed. A milestone is only useful when it preserves the proof that came before it.

## Stability Doctrine

- Every milestone must keep older smoke tests passing.
- No feature is accepted if it breaks the proof ladder.
- Honest `not implemented` output is better than fake success.
- Generated transcripts are proof artifacts, but they should not pollute `git status` or be committed as source changes.
- The Zig version must be explicit when reporting proof.
- QEMU machine assumptions must be explicit when reporting proof.
- A clean `git status --short` after tests is part of stability.

## Required Local Proof

Run the full smoke ladder before claiming a stable change:

```sh
./smoke/smoke-all.sh
```

Expected final output:

```text
PASS ZIGN01D full smoke ladder
```

## Proof Ladder Rule

The full smoke ladder is the local stability contract. If a new milestone needs new smoke coverage, add the new smoke after older smoke tests instead of replacing them. Older milestones remain part of the acceptance proof.

## No Fake Success

A command may report that a subsystem is absent, stubbed, guarded, or not implemented. It must not pretend that real internet, real SMS, real modem access, or other unavailable capabilities work.
