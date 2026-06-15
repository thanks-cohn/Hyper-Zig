# ZIGN01D Living Educational Roadmap

ZIGN01D is a proof-driven RISC-V Zig teaching kernel.

ZIGN01D exists to make the invisible parts of a kernel visible.

This roadmap is the living educational plan for the repository. It describes what is proven today, what is planned next, and which future ideas are deliberately not current claims.

## Current identity

ZIGN01D is a small RISC-V kernel for QEMU `virt`, written in Zig, with smoke-test proof requirements. It currently teaches boot, UART diagnostics, machine boundaries, trap/timer readiness, guarded MMIO policy, communication placeholders, ZBUS capability boundaries, stability discipline, educational documentation, MEMORY V0 visibility, BOARD V0 board-profile visibility, VIRTIO DISCOVERY V0 slot-table visibility, HEAP V0 kernel bump-reset allocation, and PMM V0 physical page accounting.

## Current verified foundation

The current verified foundation includes:

- V0 boot.
- V1 diagnostics.
- V2 machine boundary.
- V3 timer/trap readiness.
- V4 guarded MMIO.
- COMM V0.
- ZBUS V0.
- STABILITY V0.
- EDUCATIONAL DOCS V0.
- MEMORY V0.
- BOARD V0.
- VIRTIO DISCOVERY V0.
- HEAP V0.
- PMM V0.

Each item must remain backed by build scripts, smoke tests, and documentation.

## Roadmap rules

- Proof before claims.
- Keep not-implemented features visible.
- Do not remove existing commands without a migration and smoke update.
- Do not add fake internet, SMS, modem, phone, paging, userspace, swap, NUMA, or production PMM claims; heap claims must remain limited to HEAP V0 bump-reset behavior and PMM claims must remain limited to PMM V0 page accounting.
- Preserve legacy planning material under `legacy/` when replacing root-level plans.

## Stability first

Stability means the learner can rerun the same proof ladder and observe the same boundaries. `./scripts/doctor.sh`, `./smoke/smoke-all.sh`, and `./smoke/smoke-stability.sh` are release gates.

## Educational roadmap

The educational track should keep pairing every kernel feature with:

- A user guide.
- A spec.
- An audit.
- Command examples.
- Smoke proof.
- Honest missing-feature notes.

## Kernel milestone roadmap

PMM V0 is the current implemented milestone: it adds physical page accounting over the known qemu-virt RAM range with visible page stats, kernel-reserved page accounting, allocation/free tests, invalid/double-free rejection, and exhaustion rejection. HEAP V0 remains a fixed-size kernel bump-reset heap, not a production allocator.

Later kernel milestones may include trap recovery improvements, scheduler evolution, virtual memory, filesystems, and userspace, but these are not current features.

## Phone/personal-device roadmap

The phone and personal-device vision is future work. ZIGN01D does not currently provide real phone support, real SMS, real internet, real modem support, calls, Android replacement behavior, Linux replacement behavior, production readiness, or flashable phone firmware.

Future phone work must first pass through board profiles, drivers, storage, networking, security boundaries, and hardware-specific proof.

## Documentation roadmap

Documentation should continue to explain the current kernel without overstating it. Every new milestone should add:

- `docs/MILESTONE_<NAME>_USER_GUIDE.md`
- `docs/<NAME>_SPEC.md`
- `docs/<NAME>_AUDIT.md`
- Command reference entries.
- Milestone index entries.
- README links where useful.

## Professor and learner roadmap

Professor material should make grading proof-based. Learner material should provide reproducible commands, expected strings, and questions that connect observed output to source files.

## Student learning path

A student should be able to progress through:

1. Boot and UART output.
2. Shell commands and status.
3. Machine boundary and privilege limits.
4. Timer/trap readiness.
5. Guarded MMIO and device absence.
6. Communication and ZBUS placeholders.
7. Memory visibility.
8. Board profiles.
9. Discovery and allocation foundations.
10. Physical page ownership and PMM accounting.

## Comparative kernel vision

ZIGN01D should stay comparable to historical and modern kernels by showing which responsibilities exist in a kernel and which are still missing here. Comparison must be educational, not a production-readiness claim.

## What ZIGN01D is not yet

ZIGN01D is not yet:

- A production operating system.
- A Linux replacement.
- An Android replacement.
- A flashable phone firmware.
- A real phone stack.
- A real internet stack.
- A real SMS stack.
- A real modem stack.
- A filesystem-capable OS.
- A userspace-capable OS.
- A paged virtual-memory OS.
- A general-purpose heap-backed application platform.

## Near-term priorities

- Keep PMM V0, HEAP V0, MEMORY V0, and VIRTIO DISCOVERY V0 smoke and docs stable.
- Keep generated transcripts out of git status.

## Medium-term priorities

- Safer MMIO discovery.
- Larger allocator discipline after PMM proof.
- Interrupt enablement proof.
- More structured device registry.
- Expanded labs and grading rubrics.

## Long-term priorities

- Virtual memory.
- Userspace processes.
- Filesystem experiments.
- Network stack experiments.
- Hardware board bring-up.
- Personal-device research.

All long-term items are planned work, not present capabilities.

## Release discipline

A release candidate must run doctor, build, every milestone smoke, the full smoke ladder, stability smoke, and docs smoke when present. Any failed command must be recorded honestly.

## Proof requirements

Proof requires exact commands, exact pass/fail status, smoke transcripts in the existing generated locations, and documentation that matches observed output.

## Legacy material

Older root-level plans and future sketches are preserved under `legacy/root-plans/`. They are useful historical material, but this root `ROADMAP.md` is the living roadmap for current educational development.
