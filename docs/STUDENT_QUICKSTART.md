# Student Quickstart

## Prerequisites

Install:

- `git`
- Zig compatible with this repository
- `qemu-system-riscv64`
- a POSIX shell

## Clone

```sh
git clone git@github.com:thanks-cohn/zign01d.git
cd zign01d
```

## Build

```sh
./scripts/build.sh
```

Expected result: the build completes and produces the kernel image under `zig-out/bin/`.

## Run smoke tests

```sh
./smoke/smoke-v0.sh
./smoke/smoke-v1.sh
./smoke/smoke-v2.sh
./smoke/smoke-v3.sh
./smoke/smoke-v4.sh
./smoke/smoke-comm-v0.sh
```

If present and supported by your environment, run:

```sh
./smoke/smoke-all.sh
```

Expected result: each smoke script prints its PASS line.

## Read transcripts

Smoke runs may generate local transcripts under smoke/log paths. Treat them as proof artifacts. Do not commit generated transcripts unless your instructor explicitly asks for them.

## Find boot markers

Read:

```sh
sed -n '1,200p' kernel/main.zig
sed -n '1,200p' kernel/diag/breadcrumb.zig
```

Look for `BOOT090` and the breadcrumb format.

## Use the shell

Run QEMU manually if your environment supports it:

```sh
./scripts/run-qemu.sh
```

At the `zign01d>` prompt, try:

```text
help
status
breadcrumbs
machine
time
mmio
comm
```

## Trace one command

For `status`:

```sh
sed -n '1,240p' kernel/console/shell.zig
```

Find where `status` is matched, then find `statusCommand()` and list every subsystem it prints.

## Modify one harmless command

Start with a harmless diagnostic-only change, such as adding one extra explanatory line to an existing status command. Do not change trap behavior, MMIO live probing, or boot assembly for an early exercise.

## Update docs

If you change command output, update:

- `docs/COMMAND_REFERENCE.md`
- the relevant milestone or lab document
- any smoke expected strings if your output becomes required proof

## Rerun proof

```sh
./scripts/build.sh
./smoke/smoke-v0.sh
```

Run additional smoke tests for any milestone you touched. Your report should include exact commands and exact PASS lines.
