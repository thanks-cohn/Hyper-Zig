# ZIGN01D Release Checklist

Use this checklist to cut a stable tag from a proven main branch.

## Stable Tag Steps

1. Pull latest `main`.
2. Verify the recent git history.
3. Run the full smoke ladder.
4. Verify clean git status after proof.
5. Create an annotated tag.
6. Push the tag.

## Commands

```sh
git checkout main
git pull --ff-only origin main
git log --oneline --decorate -n 12
./smoke/smoke-all.sh
git status --short
```

Example local/dev tag replacement:

```sh
git tag -f -a v4-comm-v0-clean \
  -m "ZIGN01D V4 and COMM V0 clean: passing full smoke ladder"

git push -f origin v4-comm-v0-clean
```

Use force only when intentionally replacing a local/dev tag. Prefer new immutable tags for public teaching releases later.

## Release Claim Rule

A release note should name the exact proof command and the final pass line observed. Do not claim a stable release from an unrun smoke ladder.
