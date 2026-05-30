# ZIGN01D Assignments

## Assignment 1: Build and proof report

- **Goal:** Demonstrate reproducible baseline setup.
- **Starter instructions:** Clone the repo, install tools, read `docs/PROOF_CONTRACT.md`.
- **Deliverables:** One report with environment, commands, and PASS output.
- **Required commands:** `./scripts/build.sh`; `./smoke/smoke-v0.sh`.
- **Required proof output:** Build success and `PASS ZIGN01D V0 smoke`.
- **Required docs:** Cite `docs/WHAT_IS_ZIGN01D.md` and `docs/PROOF_CONTRACT.md`.
- **Grading checklist:** Commands exact; output exact; no transcript committed; limitation stated.
- **Common mistakes:** Saying "works" without output; omitting QEMU/Zig version; committing generated logs.

## Assignment 2: Command trace report

- **Goal:** Explain a shell command from parser to subsystem output.
- **Starter instructions:** Read `kernel/console/shell.zig` and choose one command.
- **Deliverables:** Trace report and proof command.
- **Required commands:** Relevant smoke script, such as `./smoke/smoke-v2.sh` or `./smoke/smoke-v3.sh`.
- **Required proof output:** PASS line plus the command's expected output snippet.
- **Required docs:** Reference `docs/COMMAND_REFERENCE.md`.
- **Grading checklist:** Correct path; source understanding; limitation statement.
- **Common mistakes:** Treating placeholders as implemented services; ignoring helper functions.

## Assignment 3: Add a diagnostic command

- **Goal:** Add a harmless, documented shell diagnostic.
- **Starter instructions:** Study command matching in `kernel/console/shell.zig`.
- **Deliverables:** Code patch, command reference update, proof output.
- **Required commands:** `./scripts/build.sh`; relevant smoke script.
- **Required proof output:** Build success and smoke PASS.
- **Required docs:** `docs/COMMAND_REFERENCE.md` update and instructor-required milestone note.
- **Grading checklist:** Minimality; readable output; docs; smoke proof; no side effects.
- **Common mistakes:** Adding untested output; making network/hardware claims; changing unrelated code.

## Assignment 4: Add a smoke-test marker

- **Goal:** Extend proof for one existing stable output.
- **Starter instructions:** Read `docs/PROOF_CONTRACT.md` and one smoke script.
- **Deliverables:** Smoke script patch and documentation note.
- **Required commands:** Edited smoke script plus `./scripts/build.sh` if the kernel changed.
- **Required proof output:** PASS from the edited smoke script.
- **Required docs:** Note what the marker proves and does not prove.
- **Grading checklist:** Stable expected output; no removed checks; no generated transcript commit.
- **Common mistakes:** Checking timing-sensitive values; weakening smoke tests.

## Assignment 5: Write a milestone user guide

- **Goal:** Turn a small milestone into teachable documentation.
- **Starter instructions:** Read `docs/DOCUMENTATION_CONTRACT.md`.
- **Deliverables:** `docs/MILESTONE_<NAME>_USER_GUIDE.md` draft.
- **Required commands:** Commands used by the milestone.
- **Required proof output:** Expected PASS line or manual verification output.
- **Required docs:** User guide with limitations and file map.
- **Grading checklist:** Clear usage; expected output; limitations; no fake success language.
- **Common mistakes:** Writing a roadmap instead of a guide; omitting smoke instructions.

## Assignment 6: Design a comparative kernel milestone

- **Goal:** Design a controlled comparison without creating a sibling repo.
- **Starter instructions:** Read `docs/COMPARATIVE_KERNEL_VISION.md`.
- **Deliverables:** Design memo comparing same milestone across language or architecture.
- **Required commands:** `./smoke/smoke-docs.sh` for the documentation baseline.
- **Required proof output:** `PASS ZIGN01D docs smoke`.
- **Required docs:** Comparative milestone plan with proof contract.
- **Grading checklist:** Controlled variables; same proof standard; planned status clear.
- **Common mistakes:** Claiming sibling kernels already exist; mixing languages into ZIGN01D without a boundary.

## Assignment 7: Final mini-milestone

- **Goal:** Complete one small, documented, smoke-tested improvement.
- **Starter instructions:** Propose scope and proof plan before coding.
- **Deliverables:** Code/docs patch, smoke update if needed, final proof report.
- **Required commands:** `./scripts/build.sh` plus all smoke scripts affected by the change.
- **Required proof output:** Exact PASS lines for affected tests.
- **Required docs:** User-facing docs, limitation statement, source map update if relevant.
- **Grading checklist:** Build reproducibility; smoke proof; minimality; explanation; honest limitation.
- **Common mistakes:** Large unreviewable changes; unsupported feature claims; missing docs.
