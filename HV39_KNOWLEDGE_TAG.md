Hyper-Zig Knowledge Tag
=======================

Tag
---

v0.39.0-hv39-hgatp-csr-write-eligibility-executor-KNOWLEDGE

Project
-------

Hyper-Zig

Language
--------

Zig 0.14.x only

Purpose
-------

Hyper-Zig is an educational RISC-V hypervisor built from first principles.

The project is intentionally developed as a visible, incremental progression from:

VM foundations
→ vCPU management
→ guest memory ownership
→ guest image loading
→ stage-2 translation preparation
→ HGATP activation pipeline
→ Linux guest boot preparation

Every milestone must execute real code, expose observable behavior, and be backed by smoke validation.

Current Repository State
------------------------

Repository branch: main

Merge Commit: 0f93260

Milestone: HV39 CSR Write Eligibility Executor

Implemented Through
-------------------

HV0-HV39

HV39 adds:

- CSR write eligibility evaluation
- eligibility request validation
- execution decision tracking
- blocker propagation
- corruption detection
- denial-before-hardware enforcement
- telemetry inspection
- shell-visible eligibility state

Safety Guarantees
-----------------

The following remain false:

hgatp_write_attempted=false

hgatp_write_performed=false

csr_write_called=false

raw_write_called=false

active_stage2=false

guest_entered=false

first_guest_instruction_executed=false

trap_observed=false

readback_attempted=false

readback_valid=false

Current HGATP Activation Chain
------------------------------

HV25 Software Candidate Foundation

↓

HV26-HV34 Validation and Activation Construction

↓

HV35 Execution Dry Run

↓

HV36 Executor Skeleton

↓

HV37 Policy Enforcement

↓

HV38 CSR Write Boundary Validation

↓

HV39 CSR Write Eligibility Executor

↓

Future Direct CSR Write Propagation

↓

Future Guarded CSR Execution

↓

Future HGATP Write Experiments

↓

Future Stage-2 Translation Activation

↓

Future Guest Entry

↓

Future Linux Boot

Validation
----------

zig build

./scripts/validate-hyperzig.sh

./smoke/smoke-hv39-hgatp-csr-write-eligibility-v0.sh

./smoke/smoke-hv39-hgatp-csr-write-eligibility-negative-v0.sh

Repository Reality
------------------

Hyper-Zig is not yet:

- Linux guest capable
- guest executing
- stage-2 active
- production ready

Hyper-Zig currently contains:

- VM lifecycle
- vCPU lifecycle
- guest memory ownership
- guest image infrastructure
- HGATP preparation pipeline
- execution policy chain
- write boundary enforcement
- eligibility evaluation

Long-Term Goal
--------------

Boot a Linux guest through a RISC-V hypervisor built incrementally from first principles with every stage observable, inspectable, and validated.
