# ZIGN01D Documentation Contract

Every ZIGN01D milestone must include user-facing documentation. A milestone is not complete until its behavior, command surface, smoke proof, limitations, changed files, and next step are documented.

## Required rules

- Every milestone must include user-facing documentation.
- Every new command must be documented.
- Every new smoke test must be documented.
- Every new subsystem must have a technical spec or audit doc.
- Every milestone must state what is intentionally not implemented.
- Every milestone must include a manual verification checklist.
- Every milestone must include expected passing output.
- Every milestone must avoid fake success language.
- Generated transcripts and logs are proof artifacts but should not be committed unless explicitly intended.

## Required future milestone doc pattern

Milestones must use this pattern:

```text
docs/MILESTONE_<NAME>_USER_GUIDE.md
docs/<SUBSYSTEM>_SPEC.md when adding a subsystem
docs/<SUBSYSTEM>_AUDIT.md when changing a subsystem
```

## Required user-guide content

Each milestone user guide must explain:

- What was added.
- What commands were added.
- How to use the commands.
- How to run the smoke test.
- What passing output looks like.
- What is intentionally not implemented.
- What files changed.
- What future milestone comes next.

## Examples

MEMORY V0 should create:

```text
docs/MILESTONE_MEMORY_V0_USER_GUIDE.md
docs/MEMORY_V0_SPEC.md
docs/MEMORY_V0_AUDIT.md
```

BOARD V0 should create:

```text
docs/MILESTONE_BOARD_V0_USER_GUIDE.md
docs/BOARD_V0_SPEC.md
docs/BOARD_V0_AUDIT.md
```

## Proof language

Documentation should describe proof in concrete terms: command names, exact strings, smoke scripts, and expected pass lines. Documentation must not say a feature works unless a smoke test or equivalent proof demonstrates that specific claim.
