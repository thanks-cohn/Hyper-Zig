# ZIGN01D Zig Version Compatibility Audit

Date: 2026-06-08

## 1. Required Version

ZIGN01D targets **Zig 0.14.x**.

Validation environment result:

- Command attempted: `zig version`
- Exact Zig version used for validation: **none available**
- Observed output: `bash: command not found: zig`

Because Zig 0.14.x is not installed in this environment, this audit combines a static compatibility review with attempted command execution. Runtime/compile proof that depends on Zig is labeled `UNKNOWN_NEEDS_TEST` or `NON_VERSION_FAILURE` rather than treated as project success or failure. Zig 0.16 success must not be treated as ZIGN01D success.

## 2. Build System Audit

Inspected paths required by the mission:

- `build.zig`
- `scripts/*`
- `smoke/*`
- `tests/*`
- `README.md`
- `docs/*`

| File path | Line/function if possible | Current behavior | Zig 0.14-compatible? | Appears to require Zig 0.15/0.16? | Recommended fix |
| --- | --- | --- | --- | --- | --- |
| `build.zig` | `build` function, executable options | Uses `b.resolveTargetQuery`, `b.addExecutable` with `.root_source_file`, `b.path`, `exe.addAssemblyFile`, `exe.setLinkerScript`, `exe.entry`, and `exe.bundle_compiler_rt = false`. | UNKNOWN_NEEDS_TEST: these are expected Zig 0.14-era APIs, but no Zig 0.14 compiler is installed in this environment. | No direct 0.15/0.16-only API found; notably no `b.createModule` or `.root_module`. | Validate with `ZIG=/path/to/zig-0.14.x ./scripts/build.sh`; if a field differs, backport in `build.zig` rather than raising the compiler target. |
| `scripts/build.sh` | Zig discovery and build command | Finds `$ZIG`, PATH `zig`, then `/opt/zig/zig`; now invokes `scripts/check-zig-version.sh` before `zig build`. | ZIG14_OK statically for the shell workflow; runtime proof unavailable without Zig. | No. It now rejects Zig 0.16 instead of treating 0.16 success as success. | Keep the guard. |
| `scripts/check-zig-version.sh` | Whole script | Runs `zig version`, accepts only `0.14.*`, and exits nonzero on missing or wrong Zig. | ZIG14_OK for enforcing the project target. | No; it explicitly rejects Zig 0.16. | Use this in future build/smoke entry points. |
| `scripts/doctor.sh` | Toolchain checks | Now calls `scripts/check-zig-version.sh` instead of hard-coding only `/opt/zig/zig version == 0.14.1`. | ZIG14_OK statically; accepts all 0.14.x, as required. | No. | Keep all doctor failures honest as environment/toolchain failures. |
| `scripts/run-qemu.sh`, `scripts/debug-qemu.sh`, `scripts/debug.sh`, `scripts/clean.sh` | Whole scripts | QEMU/debug/cleanup wrappers; do not invoke Zig compiler APIs directly. | ZIG14_OK statically. | No. | No version fix needed. |
| `smoke/*.sh` | Build setup paths | Most smoke scripts call `scripts/build.sh`, so the new guard runs before compilation. `smoke/smoke-docs.sh` is documentation-only and does not build. | UNKNOWN_NEEDS_TEST for full smoke proof because Zig and QEMU are missing here; guard behavior itself is statically OK. | No Zig 0.16-only command found. | Re-run under Zig 0.14.x plus QEMU. |
| `tests/*` | README-only directories | No executable test scripts and no Zig test harness were found under `tests/`; only README milestone notes are present. | ZIG14_OK statically for absence of compiler assumptions. | No. | Add explicit test commands later if tests become executable. |
| `README.md` | Try it / toolchain note | Documented build and smoke commands now state ZIGN01D targets Zig 0.14.x and that Zig 0.16 is not the target. | ZIG14_OK as documentation. | No. | Keep future compiler-specific examples labeled. |
| `docs/COMMAND_REFERENCE.md` | Toolchain note | Now documents the Zig 0.14.x target and backport policy. | ZIG14_OK as documentation. | No. | Keep command docs consistent with the guard. |
| `docs/V5_CSR_V0_AUDIT.md` | Toolchain compatibility note | Now says CSR V0 must remain Zig 0.14.x-compatible and any Zig 0.16-only CSR/codegen change must be labeled and backported. | ZIG14_OK as documentation. | No. | Re-run CSR smoke with Zig 0.14.x and QEMU. |
| `docs/*` | Static documentation sweep | No documented command was found that intentionally selects Zig 0.15/0.16. Existing docs refer to QEMU and smoke scripts. | ZIG14_OK statically, except runtime proof missing for commands. | No. | Continue adding explicit target notes to new docs. |

## 3. Source Compatibility Audit

Static source review covered all Zig files under `kernel/`, `boot/`, `userspace/`, `tools/`, and `tests/`.

Findings:

- No `b.createModule` or `.root_module` usage was found in source or build files.
- No allocator-interface migration, `std.fs`/path API migration, or formatting API usage requiring Zig 0.15/0.16 was found in the reviewed source files.
- Inline assembly appears in RISC-V CPU/CSR/timer/UART paths. The syntax is plausible for Zig 0.14.x, but compile proof is unavailable without Zig 0.14.x.
- `kernel/main.zig` uses the classic panic function signature that is expected for Zig 0.14-era code, not a Zig 0.16-only panic API.
- All source labels below are `UNKNOWN_NEEDS_TEST` because the active environment has no Zig compiler. Static review did not identify any `ZIG16_ONLY` source file.

| File path | Label | Reason | Required follow-up |
| --- | --- | --- | --- |
| `kernel/arch/riscv64/boot.zig` | UNKNOWN_NEEDS_TEST | Static review found no `b.createModule`, `.root_module`, Zig 0.16-only build API, allocator API, `std.fs`/path API, or formatting API usage in this source file; compile proof unavailable because `zig` is missing. | Re-test with Zig 0.14.x. |
| `kernel/arch/riscv64/cpu.zig` | UNKNOWN_NEEDS_TEST | Static review found no `b.createModule`, `.root_module`, Zig 0.16-only build API, allocator API, `std.fs`/path API, or formatting API usage in this source file; compile proof unavailable because `zig` is missing. | Re-test with Zig 0.14.x. |
| `kernel/arch/riscv64/csr.zig` | UNKNOWN_NEEDS_TEST | Static review found no `b.createModule`, `.root_module`, Zig 0.16-only build API, allocator API, `std.fs`/path API, or formatting API usage in this source file; compile proof unavailable because `zig` is missing. | Re-test with Zig 0.14.x. |
| `kernel/arch/riscv64/trap.zig` | UNKNOWN_NEEDS_TEST | Static review found no `b.createModule`, `.root_module`, Zig 0.16-only build API, allocator API, `std.fs`/path API, or formatting API usage in this source file; compile proof unavailable because `zig` is missing. | Re-test with Zig 0.14.x. |
| `kernel/board/board.zig` | UNKNOWN_NEEDS_TEST | Static review found no `b.createModule`, `.root_module`, Zig 0.16-only build API, allocator API, `std.fs`/path API, or formatting API usage in this source file; compile proof unavailable because `zig` is missing. | Re-test with Zig 0.14.x. |
| `kernel/comm/bridge.zig` | UNKNOWN_NEEDS_TEST | Static review found no `b.createModule`, `.root_module`, Zig 0.16-only build API, allocator API, `std.fs`/path API, or formatting API usage in this source file; compile proof unavailable because `zig` is missing. | Re-test with Zig 0.14.x. |
| `kernel/comm/comm.zig` | UNKNOWN_NEEDS_TEST | Static review found no `b.createModule`, `.root_module`, Zig 0.16-only build API, allocator API, `std.fs`/path API, or formatting API usage in this source file; compile proof unavailable because `zig` is missing. | Re-test with Zig 0.14.x. |
| `kernel/comm/modem.zig` | UNKNOWN_NEEDS_TEST | Static review found no `b.createModule`, `.root_module`, Zig 0.16-only build API, allocator API, `std.fs`/path API, or formatting API usage in this source file; compile proof unavailable because `zig` is missing. | Re-test with Zig 0.14.x. |
| `kernel/comm/net.zig` | UNKNOWN_NEEDS_TEST | Static review found no `b.createModule`, `.root_module`, Zig 0.16-only build API, allocator API, `std.fs`/path API, or formatting API usage in this source file; compile proof unavailable because `zig` is missing. | Re-test with Zig 0.14.x. |
| `kernel/comm/sms.zig` | UNKNOWN_NEEDS_TEST | Static review found no `b.createModule`, `.root_module`, Zig 0.16-only build API, allocator API, `std.fs`/path API, or formatting API usage in this source file; compile proof unavailable because `zig` is missing. | Re-test with Zig 0.14.x. |
| `kernel/comm/zbus.zig` | UNKNOWN_NEEDS_TEST | Static review found no `b.createModule`, `.root_module`, Zig 0.16-only build API, allocator API, `std.fs`/path API, or formatting API usage in this source file; compile proof unavailable because `zig` is missing. | Re-test with Zig 0.14.x. |
| `kernel/console/shell.zig` | UNKNOWN_NEEDS_TEST | Static review found no `b.createModule`, `.root_module`, Zig 0.16-only build API, allocator API, `std.fs`/path API, or formatting API usage in this source file; compile proof unavailable because `zig` is missing. | Re-test with Zig 0.14.x. |
| `kernel/console/uart.zig` | UNKNOWN_NEEDS_TEST | Static review found no `b.createModule`, `.root_module`, Zig 0.16-only build API, allocator API, `std.fs`/path API, or formatting API usage in this source file; compile proof unavailable because `zig` is missing. | Re-test with Zig 0.14.x. |
| `kernel/device/device.zig` | UNKNOWN_NEEDS_TEST | Static review found no `b.createModule`, `.root_module`, Zig 0.16-only build API, allocator API, `std.fs`/path API, or formatting API usage in this source file; compile proof unavailable because `zig` is missing. | Re-test with Zig 0.14.x. |
| `kernel/device/mmio_probe.zig` | UNKNOWN_NEEDS_TEST | Static review found no `b.createModule`, `.root_module`, Zig 0.16-only build API, allocator API, `std.fs`/path API, or formatting API usage in this source file; compile proof unavailable because `zig` is missing. | Re-test with Zig 0.14.x. |
| `kernel/diag/breadcrumb.zig` | UNKNOWN_NEEDS_TEST | Static review found no `b.createModule`, `.root_module`, Zig 0.16-only build API, allocator API, `std.fs`/path API, or formatting API usage in this source file; compile proof unavailable because `zig` is missing. | Re-test with Zig 0.14.x. |
| `kernel/fs/ramfs.zig` | UNKNOWN_NEEDS_TEST | Static review found no `b.createModule`, `.root_module`, Zig 0.16-only build API, allocator API, `std.fs`/path API, or formatting API usage in this source file; compile proof unavailable because `zig` is missing. | Re-test with Zig 0.14.x. |
| `kernel/fs/tarfs.zig` | UNKNOWN_NEEDS_TEST | Static review found no `b.createModule`, `.root_module`, Zig 0.16-only build API, allocator API, `std.fs`/path API, or formatting API usage in this source file; compile proof unavailable because `zig` is missing. | Re-test with Zig 0.14.x. |
| `kernel/fs/vfs.zig` | UNKNOWN_NEEDS_TEST | Static review found no `b.createModule`, `.root_module`, Zig 0.16-only build API, allocator API, `std.fs`/path API, or formatting API usage in this source file; compile proof unavailable because `zig` is missing. | Re-test with Zig 0.14.x. |
| `kernel/interrupt/plic.zig` | UNKNOWN_NEEDS_TEST | Static review found no `b.createModule`, `.root_module`, Zig 0.16-only build API, allocator API, `std.fs`/path API, or formatting API usage in this source file; compile proof unavailable because `zig` is missing. | Re-test with Zig 0.14.x. |
| `kernel/interrupt/timer.zig` | UNKNOWN_NEEDS_TEST | Static review found no `b.createModule`, `.root_module`, Zig 0.16-only build API, allocator API, `std.fs`/path API, or formatting API usage in this source file; compile proof unavailable because `zig` is missing. | Re-test with Zig 0.14.x. |
| `kernel/log.zig` | UNKNOWN_NEEDS_TEST | Static review found no `b.createModule`, `.root_module`, Zig 0.16-only build API, allocator API, `std.fs`/path API, or formatting API usage in this source file; compile proof unavailable because `zig` is missing. | Re-test with Zig 0.14.x. |
| `kernel/main.zig` | UNKNOWN_NEEDS_TEST | Static review found no `b.createModule`, `.root_module`, Zig 0.16-only build API, allocator API, `std.fs`/path API, or formatting API usage in this source file; compile proof unavailable because `zig` is missing. | Re-test with Zig 0.14.x. |
| `kernel/memory/allocator.zig` | UNKNOWN_NEEDS_TEST | Static review found no `b.createModule`, `.root_module`, Zig 0.16-only build API, allocator API, `std.fs`/path API, or formatting API usage in this source file; compile proof unavailable because `zig` is missing. | Re-test with Zig 0.14.x. |
| `kernel/memory/heap.zig` | UNKNOWN_NEEDS_TEST | Static review found no `b.createModule`, `.root_module`, Zig 0.16-only build API, allocator API, `std.fs`/path API, or formatting API usage in this source file; compile proof unavailable because `zig` is missing. | Re-test with Zig 0.14.x. |
| `kernel/memory/memory.zig` | UNKNOWN_NEEDS_TEST | Static review found no `b.createModule`, `.root_module`, Zig 0.16-only build API, allocator API, `std.fs`/path API, or formatting API usage in this source file; compile proof unavailable because `zig` is missing. | Re-test with Zig 0.14.x. |
| `kernel/memory/pmm.zig` | UNKNOWN_NEEDS_TEST | Static review found no `b.createModule`, `.root_module`, Zig 0.16-only build API, allocator API, `std.fs`/path API, or formatting API usage in this source file; compile proof unavailable because `zig` is missing. | Re-test with Zig 0.14.x. |
| `kernel/memory/vmm.zig` | UNKNOWN_NEEDS_TEST | Static review found no `b.createModule`, `.root_module`, Zig 0.16-only build API, allocator API, `std.fs`/path API, or formatting API usage in this source file; compile proof unavailable because `zig` is missing. | Re-test with Zig 0.14.x. |
| `kernel/net/net.zig` | UNKNOWN_NEEDS_TEST | Static review found no `b.createModule`, `.root_module`, Zig 0.16-only build API, allocator API, `std.fs`/path API, or formatting API usage in this source file; compile proof unavailable because `zig` is missing. | Re-test with Zig 0.14.x. |
| `kernel/panic/panic.zig` | UNKNOWN_NEEDS_TEST | Static review found no `b.createModule`, `.root_module`, Zig 0.16-only build API, allocator API, `std.fs`/path API, or formatting API usage in this source file; compile proof unavailable because `zig` is missing. | Re-test with Zig 0.14.x. |
| `kernel/phone/phone.zig` | UNKNOWN_NEEDS_TEST | Static review found no `b.createModule`, `.root_module`, Zig 0.16-only build API, allocator API, `std.fs`/path API, or formatting API usage in this source file; compile proof unavailable because `zig` is missing. | Re-test with Zig 0.14.x. |
| `kernel/runtime/mem.zig` | UNKNOWN_NEEDS_TEST | Static review found no `b.createModule`, `.root_module`, Zig 0.16-only build API, allocator API, `std.fs`/path API, or formatting API usage in this source file; compile proof unavailable because `zig` is missing. | Re-test with Zig 0.14.x. |
| `kernel/scheduler/scheduler.zig` | UNKNOWN_NEEDS_TEST | Static review found no `b.createModule`, `.root_module`, Zig 0.16-only build API, allocator API, `std.fs`/path API, or formatting API usage in this source file; compile proof unavailable because `zig` is missing. | Re-test with Zig 0.14.x. |
| `kernel/syscall/syscall.zig` | UNKNOWN_NEEDS_TEST | Static review found no `b.createModule`, `.root_module`, Zig 0.16-only build API, allocator API, `std.fs`/path API, or formatting API usage in this source file; compile proof unavailable because `zig` is missing. | Re-test with Zig 0.14.x. |
| `kernel/task/task.zig` | UNKNOWN_NEEDS_TEST | Static review found no `b.createModule`, `.root_module`, Zig 0.16-only build API, allocator API, `std.fs`/path API, or formatting API usage in this source file; compile proof unavailable because `zig` is missing. | Re-test with Zig 0.14.x. |
| `kernel/virtio/discovery.zig` | UNKNOWN_NEEDS_TEST | Static review found no `b.createModule`, `.root_module`, Zig 0.16-only build API, allocator API, `std.fs`/path API, or formatting API usage in this source file; compile proof unavailable because `zig` is missing. | Re-test with Zig 0.14.x. |
| `userspace/init/init.zig` | UNKNOWN_NEEDS_TEST | Static review found no `b.createModule`, `.root_module`, Zig 0.16-only build API, allocator API, `std.fs`/path API, or formatting API usage in this source file; compile proof unavailable because `zig` is missing. | Re-test with Zig 0.14.x. |

### Source label summary

- ZIG14_OK: none compile-confirmed in this environment.
- ZIG14_SUSPECT: none singled out as API-suspect beyond missing compile proof.
- ZIG16_ONLY: none found.
- UNKNOWN_NEEDS_TEST: all reviewed Zig source files, because Zig 0.14.x was unavailable for direct compile proof.

## 4. Test Matrix

| Command run | Pass/fail | Failure output summary | Suspected Zig version cause or non-version cause |
| --- | --- | --- | --- |
| `zig version` | FAIL | `bash: command not found: zig`; exit 127. | NON_VERSION_FAILURE: Zig missing from PATH. |
| `zig build` | FAIL | `bash: command not found: zig`; exit 127. | NON_VERSION_FAILURE: Zig missing; not evidence of Zig 0.14 incompatibility. |
| `zig build test` | FAIL | `bash: command not found: zig`; exit 127. | NON_VERSION_FAILURE: Zig missing; also no custom test step was observed in `build.zig`. |
| `./scripts/build.sh` | FAIL | Logged `zig executable not found; tried PATH zig and /opt/zig/zig`; after guard addition this remains a clear Zig 0.14.x toolchain failure. | NON_VERSION_FAILURE: Zig missing. |
| `./scripts/doctor.sh` | FAIL | `git` passed; Zig guard failed because no Zig executable was found; `qemu-system-riscv64` missing. | NON_VERSION_FAILURE: missing Zig and QEMU. |
| `./smoke/smoke-docs.sh` | PASS | Printed `PASS ZIGN01D docs smoke`. | No Zig version cause; docs-only smoke passed. |
| Every other executable `smoke/*.sh` | FAIL | Each build-dependent smoke failed at `scripts/build.sh` before QEMU proof could run. `smoke-stability.sh` failed through doctor. | NON_VERSION_FAILURE: missing Zig; QEMU is also missing for later smoke stages. |
| Executable `tests/*` scripts | NOT RUN | No executable test scripts were found under `tests/`. | No version cause. |
| README documented `./scripts/doctor.sh` | FAIL | Same doctor result: Zig and QEMU missing. | NON_VERSION_FAILURE. |
| README documented `./smoke/smoke-all.sh` | FAIL | Failed at build step due missing Zig. | NON_VERSION_FAILURE. |
| README documented `./smoke/smoke-stability.sh` | FAIL | Failed at doctor due missing Zig/QEMU. | NON_VERSION_FAILURE. |
| README documented `./smoke/smoke-pmm-v0.sh` | FAIL | Failed at build step due missing Zig. | NON_VERSION_FAILURE. |
| README documented `./smoke/smoke-csr-v0.sh` | FAIL | Failed at build step due missing Zig. | NON_VERSION_FAILURE. |

## 5. Required Labels

### ZIG14_OK

Files/workflows statically confirmed as not requiring Zig 0.15/0.16-only behavior:

- `scripts/check-zig-version.sh`
- `scripts/build.sh` guard workflow
- `scripts/doctor.sh` guard workflow
- `scripts/run-qemu.sh`
- `scripts/debug-qemu.sh`
- `scripts/debug.sh`
- `scripts/clean.sh`
- `README.md` target documentation
- `docs/COMMAND_REFERENCE.md` target documentation
- `docs/V5_CSR_V0_AUDIT.md` target documentation
- Documentation-only smoke path: `smoke/smoke-docs.sh`

### ZIG14_SUSPECT

No file was labeled `ZIG14_SUSPECT` after static review. The audit instead uses `UNKNOWN_NEEDS_TEST` for files that need compile/runtime proof solely because Zig is unavailable.

### ZIG16_ONLY

No file was labeled `ZIG16_ONLY`. No Zig 0.15/0.16-only API assumption was found.

### UNKNOWN_NEEDS_TEST

All Zig source files listed in the Source Compatibility Audit need direct Zig 0.14.x compile proof.

### NON_VERSION_FAILURE

The following failures are environment/tooling failures, not evidence of Zig 0.14 incompatibility:

- Missing `zig` executable.
- Missing `/opt/zig/zig`.
- Missing `qemu-system-riscv64`.
- Build-dependent smoke failures caused by the missing Zig compiler before QEMU execution.

## 6. Repair Plan

1. **P0: Zig 0.14.x build proof**
   - Install or select Zig 0.14.x.
   - Run `ZIG=/path/to/zig-0.14.x ./scripts/check-zig-version.sh`.
   - Run `ZIG=/path/to/zig-0.14.x ./scripts/build.sh`.
   - If `build.zig` fails under Zig 0.14.x, backport the exact failing API in `build.zig`; do not move the project target to Zig 0.16.
2. **P1: Smoke test proof**
   - Install `qemu-system-riscv64`.
   - Run `ZIG=/path/to/zig-0.14.x ./smoke/smoke-all.sh`.
   - Run milestone-specific smoke scripts, especially `./smoke/smoke-pmm-v0.sh` and `./smoke/smoke-csr-v0.sh`.
3. **P2: Docs/scripts cleanup**
   - Keep README and docs target statements synchronized.
   - Add `scripts/check-zig-version.sh` to any new build entry point.
   - Avoid hard-coding only `0.14.1`; accept all `0.14.x` unless a later audit narrows the target.
4. **P3: Optional compatibility hardening**
   - Add a CI job that runs `scripts/check-zig-version.sh`, `zig build`, and smoke tests using Zig 0.14.x.
   - Add a simple static check that flags `b.createModule`, `.root_module`, or other explicitly banned Zig 0.16-only constructs unless they are labeled for backport.

## 7. Optional Guard

Added `scripts/check-zig-version.sh`.

Behavior:

- Runs `zig version` using `$ZIG`, PATH `zig`, or `/opt/zig/zig`.
- Accepts only versions matching `0.14.*`.
- Prints a clear error for missing Zig or non-0.14.x Zig.
- Exits nonzero on wrong or missing version.

Wiring:

- `scripts/build.sh` calls the guard before `zig build`.
- Build-dependent smoke scripts already call `scripts/build.sh`, so they inherit the guard without duplicating version logic.
- `scripts/doctor.sh` calls the guard and reports the result.

## 8. Documentation Updates

Updated:

- `README.md`
- `docs/COMMAND_REFERENCE.md`
- `docs/V5_CSR_V0_AUDIT.md`

Required policy now documented:

- ZIGN01D currently targets Zig 0.14.x.
- Zig 0.16 is not the target.
- Any Zig 0.16-only code must be labeled and backported, not accepted silently.

## 9. Final Report

- Exact Zig version used: none; `zig version` failed because no Zig executable is installed.
- Files inspected: `build.zig`, `scripts/*`, `smoke/*`, `tests/*`, `README.md`, `docs/*`, and all Zig files under `kernel/`, `boot/`, `userspace/`, `tools/`, and `tests/`.
- Files labeled `ZIG16_ONLY`: none.
- Files labeled `ZIG14_SUSPECT`: none.
- Files labeled `UNKNOWN_NEEDS_TEST`: all reviewed Zig source files listed in section 3.
- Commands run: all commands listed in section 4.
- Passed: `smoke/smoke-docs.sh`.
- Failed: Zig/build/smoke commands that require Zig, and doctor/stability commands that require Zig and QEMU.
- Next exact command to run:

```sh
ZIG=/path/to/zig-0.14.x ./scripts/check-zig-version.sh && ZIG=/path/to/zig-0.14.x ./scripts/build.sh
```
