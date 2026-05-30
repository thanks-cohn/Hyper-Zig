# Professor Quickstart

## What this repo is

ZIGN01D is a proof-driven RISC-V Zig teaching kernel. It is a small kernel laboratory for demonstrating boot, UART output, shell dispatch, machine boundaries, traps, timers, guarded MMIO scaffolding, communication scaffolds, and smoke-test proof.

## What this repo is not

It is not a production OS, a Linux replacement, a finished phone stack, or a proven real-hardware target. It does not provide real internet, SMS, modem, calls, or Wi-Fi calling support.

## Why a professor might care

The repository is small enough for students to inspect and structured enough for labs. It emphasizes proof over claims, which makes it useful for teaching engineering discipline as well as kernel mechanics.

## Required tools

- `git`
- Zig toolchain compatible with the repository build
- `qemu-system-riscv64`
- POSIX shell environment

## 15-minute demo path

```sh
git clone git@github.com:thanks-cohn/zign01d.git
cd zign01d
./scripts/build.sh
./smoke/smoke-v0.sh
./smoke/smoke-v1.sh
./smoke/smoke-v2.sh
./smoke/smoke-v3.sh
./smoke/smoke-v4.sh
./smoke/smoke-comm-v0.sh
./smoke/smoke-all.sh
```

If your environment lacks QEMU or the expected Zig version, use the failure as a setup lesson rather than treating it as kernel proof.

## What output proves it works

Passing smoke output such as:

- `PASS ZIGN01D V0 smoke`
- `PASS ZIGN01D V1 smoke`
- `PASS ZIGN01D V2 smoke`
- `PASS ZIGN01D V3 smoke`
- `PASS ZIGN01D V4 smoke`
- `PASS ZIGN01D COMM V0 smoke`
- `PASS ZIGN01D full smoke ladder`

proves that the checked strings appeared in controlled QEMU smoke runs. It does not prove production readiness or hardware support.

## What to show students first

1. `docs/WHAT_IS_ZIGN01D.md`
2. `docs/PROOF_CONTRACT.md`
3. `kernel/console/shell.zig`
4. one smoke script and its expected PASS line
5. a command that honestly reports `not-implemented`

## What not to overclaim

Do not claim real internet, SMS, modem, calls, filesystem, userspace isolation, broad hardware support, or production readiness. The educational value comes from named boundaries and reproducible proof.

## Next docs to read

- `docs/COURSE_MAP.md`
- `docs/LAB_MANUAL.md`
- `docs/ASSIGNMENTS.md`
- `docs/GRADING_RUBRIC.md`
- `docs/AI_ASSISTANCE_POLICY.md`
