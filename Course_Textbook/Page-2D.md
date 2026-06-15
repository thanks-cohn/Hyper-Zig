# HV02

## Capability Detection

PAGE D
INSTRUCTOR NOTES
================

## Audience

Students should have completed HV01.

Students should already understand:

* VM Objects
* Identity
* State
* Initialization

This module introduces a new concept:

Evidence.

The central lesson is simple:

A system should report what it knows.

A system should not pretend to know more than it does.

## Learning Objective

By the end of HV02, students should understand that capability
detection is not about enabling features.

It is about understanding the environment in which those features
might eventually run.

Students should understand that:

```text
unknown
```

is often a more correct answer than:

```text
present
```

or

```text
absent
```

when evidence does not exist.

## Key Concepts

This module introduces:

* Capability Detection
* Evidence
* Unknown State
* Reporting
* Diagnostic Output

These ideas become increasingly important as Hyper-Zig approaches
guest execution.

## Common Misconceptions

Misconception:

"Unknown means failure."

Correction:

Unknown means insufficient evidence.

---

Misconception:

"Unknown and absent are the same."

Correction:

Absent means the feature is known not to exist.

Unknown means the feature has not yet been proven one way or the
other.

---

Misconception:

"Diagnostics are only for debugging."

Correction:

Diagnostics are also evidence.

A system that reports its state clearly is easier to verify, test,
and teach.

## Discussion Questions

Ask students:

"If you were building an airplane, would you rather have a sensor
report:

present

or

unknown

when it is unsure?"

Why?

---

Ask students:

"What is more dangerous:

a missing feature

or

a feature incorrectly reported as present?"

---

Ask students:

"Why should software explain its reasoning?"

## Expected Student Outcomes

A successful student should be able to explain:

* What capability detection is
* Why evidence matters
* Why unknown exists
* Why reasons are attached to status reports
* Why diagnostics improve trust

Students should be able to distinguish between:

```text
I know
```

and

```text
I think
```

inside a software system.

## Suggested Demonstration

Write three words on a whiteboard:

```text
present
absent
unknown
```

Then present several scenarios.

Example:

"Can we prove the hardware supports virtualization?"

Ask students which answer should be selected.

Focus discussion on evidence rather than assumptions.

## Connection To Future Modules

HV01 created the VM Object.

HV02 begins describing the environment around that VM.

Future milestones will eventually:

* Detect hardware capabilities
* Configure virtual CPUs
* Build guest memory
* Prepare guest execution

Capability detection becomes more valuable as the hypervisor grows.

## Assessment

A student has successfully completed HV02 if they can answer:

"What is the difference between absent and unknown?"

without referring to the code.

===============================================================

## Instructor Summary

HV01 taught students how to describe a machine.

HV02 teaches students how to describe certainty.

A trustworthy hypervisor reports what it knows.

A trustworthy hypervisor also reports what it does not know.

===============================================================
