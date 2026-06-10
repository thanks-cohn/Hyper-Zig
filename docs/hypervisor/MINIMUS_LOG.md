# Minimus-Log for Hyper-Zig

Minimus-Log is the Hyper-Zig rule that the final 200 to 500 lines of any major validation run must be enough for an advanced developer to understand the state of the project at a glance.

Hyper-Zig is the hypervisor-first repository. Validation evidence belongs to this repo and must target Zig 0.14.x only. A successful Zig 0.15, Zig 0.16, or newer run is not Hyper-Zig compatibility proof.

## Why the tail matters

Validation logs are long because they include build output, QEMU transcripts, and smoke-test evidence. Developers should not need to read the entire log to answer basic state questions. The bottom of the output must therefore preserve a dense, readable summary that explains what passed, what failed, what is missing, and what should happen next.

This also prevents fake green checks: a PASS is only credible when the final summary points to the command output, smoke output, transcript markers, or build output that produced it.

## Required fields

Every major validation script must end with a Minimus-Log summary containing:

- repository name
- branch
- commit
- Zig path
- Zig version
- Zig target policy, which is Zig 0.14.x only
- build status
- all smoke-test statuses, including required, optional, discovered, failed, and missing tests
- transcript paths
- log paths
- completed milestones/evidence
- missing milestones and explicit non-claims
- current blockers
- next milestone
- overall readiness: `PASS`, `FAIL`, or `BLOCKED`
- one clear reason for the final `PASS`, `FAIL`, or `BLOCKED` result

## Required non-claims

Major validation summaries must keep these boundaries visible until smoke evidence proves otherwise:

- no Linux guest support yet
- no guest execution yet
- no smoke-proven VM/vCPU support beyond implemented status/capability reporting

## Inspection commands

Use the latest validator log tail to inspect the current project state:

```sh
tail -n 200 logs/latest/validate-hyperzig.log
tail -n 500 logs/latest/validate-hyperzig.log
```

The canonical command that produces this summary is:

```sh
./scripts/validate-hyperzig.sh
```

The build-system entry point is:

```sh
zig build validate-hyperzig
```
