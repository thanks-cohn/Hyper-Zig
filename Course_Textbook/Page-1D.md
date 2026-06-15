# HV01

## The Virtual Machine Object

PAGE D
INSTRUCTOR NOTES
================

## Audience

This module assumes no prior virtualization experience.

Students do not need to understand:

* Operating systems
* Hypervisors
* Page tables
* Memory translation
* CPU privilege modes

The only required skills are:

* Basic reading comprehension
* Basic programming familiarity
* Curiosity

The purpose of HV01 is not to teach virtualization.

The purpose of HV01 is to teach state.

## Learning Objective

By the end of HV01, students should understand that:

A virtual machine is not created all at once.

Instead, it is assembled gradually.

Before a machine can execute instructions, it must first have a
place where information about that machine can be stored.

The VM Object is that place.

Students should leave this module understanding that:

"Description comes before execution."

## Key Concepts

This module introduces:

* Identity
* State
* Ownership
* Containers
* Initialization

These ideas will reappear throughout Hyper-Zig.

Future milestones build on these concepts repeatedly.

## Common Misconceptions

Misconception:

"The VM Object is the virtual machine."

Correction:

The VM Object stores information about the virtual machine.

The VM Object is not the machine itself.

---

Misconception:

"Memory must exist before the VM exists."

Correction:

The VM exists conceptually before memory is attached.

---

Misconception:

"A VM becomes useful only when Linux boots."

Correction:

Every subsystem added before Linux boot is part of the eventual
boot process.

Virtualization is built incrementally.

## Discussion Questions

Ask students:

"If a machine has no memory and no CPU, does it still exist?"

Encourage discussion.

The goal is not to produce a correct answer immediately.

The goal is to separate:

The machine itself

from

The description of the machine.

---

Ask students:

"Why does the VM have an ID if there is only one VM?"

This often leads naturally into future discussions about scaling.

---

Ask students:

"What information would you add to the VM Object?"

Accept nearly all answers.

Most suggestions eventually become real subsystems later in the
course.

## Expected Student Outcomes

A successful student should be able to explain:

* What a VM Object is
* Why a VM has an identity
* Why state matters
* Why initialization exists
* Why ownership matters

The student should not merely repeat definitions.

They should be able to explain these ideas using their own words.

## Suggested Demonstration

Draw a folder on a whiteboard.

Label it:

VM 0

Ask students:

"What belongs inside this folder?"

Record their answers.

Examples:

* Memory
* CPU
* Devices
* Operating System

Then explain:

"Today we create the folder."

"Future modules will fill it."

This simple exercise often makes the purpose of the VM Object
immediately clear.

## Connection To Future Modules

HV01 introduces the container.

HV02 introduces capabilities.

HV03 introduces vCPUs.

HV04 introduces guest memory.

HV05 introduces guest address spaces.

Every later subsystem eventually attaches itself to the VM Object.

For this reason, HV01 is one of the most important conceptual
milestones in the entire Hyper-Zig curriculum.

## Assessment

A student has successfully completed HV01 if they can answer:

"What is a VM Object?"

without using the phrase:

"It is a struct."

The desired answer focuses on purpose rather than implementation.

===============================================================

## Instructor Summary

The VM Object is the first box.

Students should understand why the box exists before they begin
placing things inside it.

===============================================================
