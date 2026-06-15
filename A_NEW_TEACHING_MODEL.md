Hyper-Zig Academy: Learning Hypervisors Through Independent Reconstruction

Overview

Most operating systems and hypervisor courses suffer from a fundamental weakness:

Students are shown working code.

Students study working code.

Students modify working code.

Students submit working code.

The result is often familiarity without understanding.

A student may pass the course while never truly understanding why a VM exists, why stage-2 translation exists, why trap returns matter, why guest context must be preserved, or why a hypervisor refuses to enter a guest before prerequisites are satisfied.

The Hyper-Zig Academy model addresses this problem by separating implementation language from architectural understanding.

Core Principle

Students may study Hyper-Zig.

Students may inspect Hyper-Zig.

Students may execute Hyper-Zig.

Students may not port Hyper-Zig line-for-line.

Instead, students must independently reconstruct each milestone in C using only the architectural principles demonstrated by the corresponding Hyper-Zig milestone.

This creates a translation barrier.

The translation barrier is intentional.

Because Zig syntax cannot be pasted directly into C, students must identify:

* What state exists
* Why that state exists
* What invariants are being protected
* What conditions invalidate the subsystem
* What validation logic is required
* What behavior must be preserved

The student is forced to separate concept from implementation.

Educational Problem

Traditional systems courses frequently reward memorization and reproduction.

Students often learn:

* API names
* Function names
* File layouts
* Coding patterns

without understanding the underlying architecture.

Similarly, projects distributed as reference codebases often encourage copy-and-paste learning.

A student can reproduce behavior without understanding the reasoning that created it.

This becomes especially problematic in operating systems and hypervisor development, where correctness depends upon understanding invariants rather than syntax.

Educational Solution

Hyper-Zig serves as a living architectural reference.

Students observe:

* VM lifecycle creation
* Guest memory ownership
* Address-space construction
* Guest context preparation
* Stage-2 translation metadata
* FDT generation
* SBI mediation
* HGATP preparation
* Guest-entry planning

For every Hyper-Zig milestone, students create an independent C implementation.

The objective is not identical code.

The objective is architectural equivalence.

For example:

Hyper-Zig may contain a GuestMemory structure.

Students must create their own GuestMemory structure in C.

Hyper-Zig may validate memory ownership.

Students must design and implement their own validation rules.

Hyper-Zig may introduce a write gate.

Students must independently justify and implement a write gate in C.

Learning Outcome

A student who copies Hyper-Zig learns Zig.

A student who reconstructs Hyper-Zig learns hypervisors.

The goal is not language proficiency.

The goal is architectural understanding.

Why C?

C acts as an educational forcing function.

The language is sufficiently different from Zig that direct transcription becomes difficult.

Students must reinterpret the design rather than replicate syntax.

This process naturally exposes:

* Memory ownership models
* State-machine design
* Validation methodology
* Privilege transitions
* Hypervisor architecture

Students must answer:

"What problem is this subsystem solving?"

before they can successfully implement it.

Semester Structure

15 Weeks

2 Meetings Per Week

30 Classroom Sessions

40 Hyper-Zig Milestones

Classroom sessions focus on:

* Architectural analysis
* Hyper-Zig subsystem review
* Design discussion
* Validation reasoning

Independent labs focus on:

* C implementation
* Validation design
* State-machine construction
* Milestone completion

Final Outcome

By the end of the semester each student possesses:

1. A complete understanding of Hyper-Zig's architectural progression.

2. A personally authored hypervisor prototype implemented in C.

3. A deep understanding of virtualization concepts independent of programming language.

4. The ability to explain every major subsystem from VM creation through Linux guest preparation.

The final deliverable is not merely functioning code.

The final deliverable is demonstrated architectural understanding.

Success is measured by the student's ability to explain and reconstruct the design rather than reproduce the original implementation.

This transforms Hyper-Zig from a software project into a hypervisor apprenticeship system.
