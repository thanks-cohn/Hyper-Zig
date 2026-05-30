# ZIGN01D Troubleshooting Guide

This guide covers practical failures seen while proving the ZIGN01D smoke ladder.

## Zig not found

- Symptom: build output says `zig executable not found`, or `./scripts/doctor.sh` reports `/opt/zig/zig` missing.
- Likely cause: Zig is not installed at the known-good path and is not available on `PATH`.
- Inspect:

  ```sh
  command -v zig
  test -x /opt/zig/zig && /opt/zig/zig version
  ```

- Safe fix: install or unpack Zig 0.14.1 at `/opt/zig/zig`, or set `ZIG=/path/to/zig` for local build experiments. Re-run `./scripts/doctor.sh` before claiming stability.

## Wrong Zig version

- Symptom: `./scripts/doctor.sh` reports a Zig version other than `0.14.1`, or a build fails only under a different Zig.
- Likely cause: the local Zig binary does not match the known-good contract.
- Inspect:

  ```sh
  /opt/zig/zig version
  command -v zig && zig version
  ```

- Safe fix: reproduce with `/opt/zig/zig` version `0.14.1`. If another version is intentionally used, document it and do not treat version-specific failure as automatically a kernel bug.

## qemu-system-riscv64 not found

- Symptom: smoke scripts fail with `qemu-system-riscv64 not found`.
- Likely cause: QEMU RISC-V system emulator is not installed or not on `PATH`.
- Inspect:

  ```sh
  command -v qemu-system-riscv64
  qemu-system-riscv64 --version
  ```

- Safe fix: install the QEMU system package that provides `qemu-system-riscv64`, then run `./scripts/doctor.sh`.

## Smoke test times out

- Symptom: a smoke script exits after `timeout` instead of printing its pass line.
- Likely cause: QEMU did not exit, the shell did not receive input, or boot output changed enough that the scripted session cannot complete.
- Inspect:

  ```sh
  tail -n 120 logs/latest/smoke.log
  tail -n 120 logs/latest/qemu.log
  ```

- Safe fix: check the transcript for the last visible kernel line, fix the underlying boot or shell regression, and re-run the failing smoke script before `./smoke/smoke-all.sh`.

## Shell prompt not found

- Symptom: smoke output reports a missing shell marker or prompt marker.
- Likely cause: boot stopped before userspace, shell text changed without updating expected markers, or UART output is broken.
- Inspect:

  ```sh
  cat smoke/expected-markers.txt
  tail -n 160 smoke/transcripts/latest-v0.txt
  ```

- Safe fix: if behavior changed intentionally, update tests and docs together. If not intentional, restore shell startup or prompt output.

## Forbidden phrase detector trips

- Symptom: COMM or ZBUS smoke fails because a transcript contains a forbidden real-capability phrase.
- Likely cause: command output claimed real internet, SMS, modem, or host capability success instead of an explicit limitation.
- Inspect:

  ```sh
  tail -n 160 logs/latest/smoke.log
  tail -n 160 logs/latest/qemu.log
  ```

- Safe fix: change output to honest limitation language such as `not implemented`, `stub`, or `guarded`, then re-run the relevant smoke.

## Generated transcript appears in git status

- Symptom: `git status --short` shows files under `smoke/transcripts/` or `logs/latest/` after tests.
- Likely cause: a generated proof artifact is not ignored or was created with a new name.
- Inspect:

  ```sh
  git status --short
  git check-ignore -v smoke/transcripts/latest-v0.txt logs/latest/qemu.log
  ```

- Safe fix: remove unneeded generated files from the worktree or add the generated pattern to `.gitignore`. Do not commit generated transcripts.

## git pull conflicts

- Symptom: `git pull --ff-only` fails or reports local changes would be overwritten.
- Likely cause: local edits diverged from `main` or generated files are tracked in the worktree.
- Inspect:

  ```sh
  git status --short
  git log --oneline --decorate --graph -n 20
  ```

- Safe fix: commit or stash intentional local work, remove generated artifacts, then pull again. Do not discard another contributor's changes without review.

## QEMU hangs

- Symptom: manual QEMU run or smoke run appears stuck with no prompt or shutdown.
- Likely cause: kernel boot regression, QEMU invocation mismatch, or a lost serial console.
- Inspect:

  ```sh
  tail -n 160 logs/latest/qemu.log
  ./scripts/run-qemu.sh
  ```

- Safe fix: use the documented `virt` machine, `rv64` CPU, `128M` memory, `-serial stdio`, and `-monitor none` assumptions. Fix the first missing boot line before changing smoke timeouts.

## Build output missing

- Symptom: `zig-out/bin/zign01d-v0` is absent after build, or smoke reports `missing ELF`.
- Likely cause: build failed, output path changed, or `zig-out/` was cleaned.
- Inspect:

  ```sh
  ./scripts/build.sh
  tail -n 120 logs/latest/build.log
  test -f zig-out/bin/zign01d-v0 && file zig-out/bin/zign01d-v0
  ```

- Safe fix: fix the build error first. If the output path intentionally changes, update scripts and docs in the same PR.
