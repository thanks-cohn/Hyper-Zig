# ZIGN01D Lab Manual

Each lab is designed for a small, explainable change or report. Do not begin with unsafe kernel changes. Do not enable live MMIO probing, invent internet/SMS support, or remove smoke checks.

## Lab 0: Build and smoke-test the kernel

- **Objective:** Prove the baseline builds and boots under smoke.
- **Estimated time:** 30-45 minutes.
- **Files to read:** `README.md`, `scripts/build.sh`, `smoke/smoke-v0.sh`, `docs/PROOF_CONTRACT.md`.
- **Commands to run:** `./scripts/build.sh`; `./smoke/smoke-v0.sh`.
- **Task:** Capture the command list and PASS output in a short proof report.
- **Expected output:** Build exits successfully; `PASS ZIGN01D V0 smoke`.
- **Required documentation update:** Add your proof notes to your submitted report, not to generated transcripts.
- **Required smoke/proof update:** None for a baseline-only lab.
- **Submission checklist:** Commands listed; PASS line listed; environment noted; no generated transcript committed.
- **What not to do:** Do not edit source just to make the first smoke pass.

## Lab 1: Read boot output and identify breadcrumbs

- **Objective:** Connect boot output to breadcrumb source.
- **Estimated time:** 45 minutes.
- **Files to read:** `kernel/main.zig`, `kernel/diag/breadcrumb.zig`, `kernel/log.zig`, `docs/LOGGING_AND_BREADCRUMBS.md`.
- **Commands to run:** `./smoke/smoke-v1.sh`.
- **Task:** Identify at least five boot or diagnostic markers and explain level, subsystem, code, and message.
- **Expected output:** `PASS ZIGN01D V1 smoke` and visible `[ZIGN01D][...]` markers.
- **Required documentation update:** Add marker explanations to your lab report.
- **Required smoke/proof update:** Include the smoke command and PASS line.
- **Submission checklist:** Five markers; source file citations; PASS output; limitation note.
- **What not to do:** Do not claim breadcrumbs are a persistent ring buffer.

## Lab 2: Trace a shell command

- **Objective:** Trace one command from input string to output.
- **Estimated time:** 45-60 minutes.
- **Files to read:** `kernel/console/shell.zig` and the subsystem file used by your chosen command.
- **Commands to run:** `./smoke/smoke-v1.sh` or the milestone smoke that covers the command.
- **Task:** Pick `status`, `machine`, `time`, `mmio`, or `comm` and write a command trace.
- **Expected output:** The chosen command appears in smoke transcript or manual QEMU output.
- **Required documentation update:** Submit a trace diagram or bullet list.
- **Required smoke/proof update:** Include the smoke or manual command used to prove output.
- **Submission checklist:** Command path; functions called; output strings; limitations.
- **What not to do:** Do not rewrite the shell parser for this lab.

## Lab 3: Add a harmless diagnostic command

- **Objective:** Add a small command that reports static educational information.
- **Estimated time:** 1-2 hours.
- **Files to read:** `kernel/console/shell.zig`, `docs/COMMAND_REFERENCE.md`, `smoke/README.md`.
- **Commands to run:** `./scripts/build.sh`; the relevant smoke script.
- **Task:** Add a command that prints a harmless diagnostic line and no device side effects.
- **Expected output:** The new command prints the documented line and existing smoke tests still pass.
- **Required documentation update:** Update `docs/COMMAND_REFERENCE.md` and any milestone guide required by the instructor.
- **Required smoke/proof update:** Add or update a smoke check only if the command is part of the milestone proof.
- **Submission checklist:** Minimal code change; docs updated; build passes; smoke passes; no overclaim.
- **What not to do:** Do not add commands that pretend to contact hardware, networks, SMS, or modems.

## Lab 4: Add a boot/status marker

- **Objective:** Add one clear diagnostic marker to an existing status path.
- **Estimated time:** 1 hour.
- **Files to read:** `kernel/diag/breadcrumb.zig`, `kernel/main.zig`, `kernel/console/shell.zig`.
- **Commands to run:** `./scripts/build.sh`; smoke script covering the marker.
- **Task:** Add one marker that improves explanation without changing behavior.
- **Expected output:** Marker appears where documented.
- **Required documentation update:** Explain the marker code and when it appears.
- **Required smoke/proof update:** Add expected string only if the marker is required proof.
- **Submission checklist:** Unique code; clear subsystem; smoke proof; limitation note.
- **What not to do:** Do not add noisy markers that obscure existing proof.

## Lab 5: Extend a smoke test

- **Objective:** Turn one existing output claim into checked proof.
- **Estimated time:** 1-2 hours.
- **Files to read:** relevant `smoke/smoke-*.sh`, `docs/PROOF_CONTRACT.md`, `docs/smoke-test.md`.
- **Commands to run:** The edited smoke script and `./scripts/build.sh` if needed.
- **Task:** Add one stable expected string to a smoke script.
- **Expected output:** The edited smoke script prints its PASS line.
- **Required documentation update:** Document what the new check proves and does not prove.
- **Required smoke/proof update:** Commit the smoke script change, not generated transcripts.
- **Submission checklist:** Stable string; PASS output; docs updated; no transcript committed.
- **What not to do:** Do not remove failing checks to hide a regression.

## Lab 6: Document a limitation

- **Objective:** Improve honesty around a missing subsystem.
- **Estimated time:** 45 minutes.
- **Files to read:** `docs/COMMAND_REFERENCE.md`, `docs/MILESTONE_INDEX.md`, source file for the subsystem.
- **Commands to run:** Smoke script covering the subsystem.
- **Task:** Pick a not-implemented output and document what it means.
- **Expected output:** Smoke still passes and docs state the limitation clearly.
- **Required documentation update:** Update the relevant doc with an explicit limitation.
- **Required smoke/proof update:** Include the existing proof command and PASS line.
- **Submission checklist:** Limitation named; no fake roadmap promise; proof included.
- **What not to do:** Do not change code unless the assignment explicitly requires it.

## Lab 7: Compare two milestone outputs

- **Objective:** Learn how proof evolves across milestones.
- **Estimated time:** 1 hour.
- **Files to read:** `docs/MILESTONE_INDEX.md`, two smoke scripts, relevant audits.
- **Commands to run:** Two milestone smoke scripts, such as `./smoke/smoke-v2.sh` and `./smoke/smoke-v3.sh`.
- **Task:** Compare added commands, markers, and limitations.
- **Expected output:** Both selected smoke scripts print PASS.
- **Required documentation update:** Submit a comparison table.
- **Required smoke/proof update:** Include exact commands and PASS lines.
- **Submission checklist:** Two milestones; differences; limitations; proof.
- **What not to do:** Do not claim a later milestone completes an earlier placeholder unless proof says so.

## Lab 8: Design a future milestone

- **Objective:** Practice milestone design without implementing unsafe features.
- **Estimated time:** 1-2 hours.
- **Files to read:** `docs/DOCUMENTATION_CONTRACT.md`, `docs/PROOF_CONTRACT.md`, `docs/COMPARATIVE_KERNEL_VISION.md`.
- **Commands to run:** `./smoke/smoke-docs.sh`.
- **Task:** Propose a future milestone with commands, docs, smoke proof, and limitations.
- **Expected output:** `PASS ZIGN01D docs smoke` for the educational documentation baseline.
- **Required documentation update:** Submit a proposed user guide outline, spec outline, audit outline, and smoke plan.
- **Required smoke/proof update:** No kernel smoke change unless implementation is assigned separately.
- **Submission checklist:** Scope; docs; proof plan; not-implemented list; no code claims.
- **What not to do:** Do not implement ZBUS, network, SMS, or modem support as part of this design lab.
