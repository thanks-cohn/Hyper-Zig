# ZIGN01D Regression Checklist

Use this checklist before merging any PR. The goal is a boring, repeatable proof ladder with no vague pass claims.

## Required Commands

```sh
git status --short
./smoke/smoke-all.sh
git status --short
```

## Checklist

- [ ] `git status --short` is clean before work, or existing changes are understood and preserved.
- [ ] Build passes.
- [ ] V0 smoke passes.
- [ ] V1 smoke passes.
- [ ] V2 smoke passes.
- [ ] V3 smoke passes.
- [ ] V4 smoke passes.
- [ ] COMM V0 smoke passes.
- [ ] `smoke-all` passes.
- [ ] Generated transcripts are not committed.
- [ ] New commands are documented.
- [ ] New smoke tests are documented.
- [ ] No fake success claims were added.
- [ ] `status` and `help` remain consistent.
- [ ] Limitations remain explicit.

## Reporting Rule

Only claim a pass for commands that were actually run. If a command was skipped, timed out, or failed because of the local environment, report that directly.
