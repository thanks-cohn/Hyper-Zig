# HV03

## The Virtual CPU Lifecycle

PAGE A
IN PLAIN ENGLISH
================

In HV01, Hyper-Zig created the VM Object.

That gave the hypervisor a place to describe a virtual machine.

In HV02, Hyper-Zig reported what it could safely claim about the
machine it was running on.

Now Hyper-Zig needs something that looks like a CPU.

Not a real CPU.

Not yet.

A virtual CPU.

A vCPU is the CPU-shaped part of a virtual machine.

A VM is the container.

A vCPU is the thing inside that container that will eventually hold
execution state.

For now, the vCPU does not run Linux.

It does not execute guest instructions.

It does not enter guest mode.

It simply exists as a managed object with a lifecycle.

That lifecycle is important.

A vCPU should not go from nothing straight to running.

That would be careless.

Instead, Hyper-Zig gives the vCPU a controlled path:

created

initialized

runnable

halted

Each word means something.

created means the vCPU object exists.

initialized means it has been prepared enough to move forward.

runnable means it is in a state where a future run attempt could be
allowed.

halted means it was runnable, but has now stopped.

This is the first major state machine in Hyper-Zig.

A state machine is a system where an object can only move through
allowed states.

Some moves are valid.

Some moves are rejected.

For example:

created to initialized is valid.

initialized to runnable is valid.

runnable to halted is valid.

created directly to halted is not valid.

That is the point.

A hypervisor must not merely store state.

It must control how state changes.

HV03 teaches that control.

The vCPU also remembers which VM owns it.

That matters because a vCPU should not float around by itself.

It belongs to a VM.

This is where HV03 depends directly on HV01.

The VM came first.

The vCPU is attached to that VM.

The machine is starting to gain parts.

===============================================================

TECHNICAL TRANSLATION

Virtual CPU
→ CPU-shaped object owned by a virtual machine

vCPU
→ Short name for virtual CPU

Lifecycle
→ The allowed stages an object moves through

State Machine
→ A system that only allows specific state transitions

created
→ The vCPU object exists

initialized
→ The vCPU has been prepared

runnable
→ The vCPU is ready for a future run attempt

halted
→ The vCPU has stopped after being runnable

Transition
→ Moving from one state to another

Invalid Transition
→ A move the lifecycle refuses

VM ownership
→ The vCPU records which VM it belongs to

===============================================================

The Key Idea

A vCPU is not guest execution.

A vCPU is the object that will eventually make guest execution
possible.

HV03 does not run a guest.

HV03 creates and controls the lifecycle of the CPU-shaped object that
future guest execution will depend on.

If you understand why created cannot jump directly to halted, you
understand HV03.

PAGE B
THE IMPLEMENTATION
==================

File:

kernel/hypervisor/vcpu.zig

The real Hyper-Zig implementation is shown below.

This module depends on the VM Object from HV01.

That is important.

The vCPU belongs to a VM.

The vCPU does not exist as a loose object.

It carries a VM id, a vCPU id, a lifecycle state, transition counters,
and attachment slots for later guest-entry and guest-exit machinery.

Do not try to understand every future-facing field immediately.

Focus first on the lifecycle.

created

initialized

runnable

halted

That is the heart of this module.

---

```zig
const uart = @import("../console/uart.zig");
const vm_model = @import("vm.zig");

pub const VcpuId = u32;

pub const State = enum {
    created,
    initialized,
    runnable,
    halted,
};

pub const HartBinding = enum {
    boot_hart,
};

pub const TransitionResult = enum {
    never_run,
    ok,
    invalid_state,
};

pub const LifecycleStats = struct {
    reset_generation: u64,
    initialize_count: u64,
    prepare_count: u64,
    halt_count: u64,
    reset_count: u64,
    failed_transition_count: u64,
    last_transition_result: TransitionResult,
};

pub const GuestEntryAttachment = struct {
    prepared: bool,
    pc: usize,
    sp: usize,
    status_flags: usize,
    owner_vm_id: vm_model.VmId,
    owner_vcpu_id: VcpuId,
    attach_count: u64,
    clear_count: u64,
};

pub const GuestExitAttachment = struct {
    recorded: bool,
    kind_tag: usize,
    pc: usize,
    sp: usize,
    cause: usize,
    trap_value: usize,
    instruction_bits: usize,
    owner_vm_id: vm_model.VmId,
    owner_vcpu_id: VcpuId,
    record_count: u64,
    clear_count: u64,
};

pub const Vcpu = struct {
    id: VcpuId,
    vm_id: vm_model.VmId,
    state: State,
    hart_binding: HartBinding,
    run_count: u64,
    stats: LifecycleStats,
    guest_entry: GuestEntryAttachment,
    guest_exit: GuestExitAttachment,
};

var boot_vcpu: Vcpu = undefined;
var initialized: bool = false;

pub fn init(vm_id: vm_model.VmId) void {
    boot_vcpu = Vcpu{
        .id = 0,
        .vm_id = vm_id,
        .state = .created,
        .hart_binding = .boot_hart,
        .run_count = 0,
        .stats = LifecycleStats{
            .reset_generation = 0,
            .initialize_count = 0,
            .prepare_count = 0,
            .halt_count = 0,
            .reset_count = 0,
            .failed_transition_count = 0,
            .last_transition_result = .never_run,
        },
        .guest_entry = emptyGuestEntryAttachment(vm_id, 0, 0),
        .guest_exit = emptyGuestExitAttachment(vm_id, 0, 0),
    };
    initialized = true;
}

pub fn object() *const Vcpu {
    if (!initialized) init(vm_model.object().id);
    return &boot_vcpu;
}

fn mutableObject() *Vcpu {
    if (!initialized) init(vm_model.object().id);
    return &boot_vcpu;
}

fn emptyGuestEntryAttachment(owner_vm_id: vm_model.VmId, owner_vcpu_id: VcpuId, clear_count: u64) GuestEntryAttachment {
    return .{
        .prepared = false,
        .pc = 0,
        .sp = 0,
        .status_flags = 0,
        .owner_vm_id = owner_vm_id,
        .owner_vcpu_id = owner_vcpu_id,
        .attach_count = 0,
        .clear_count = clear_count,
    };
}

fn emptyGuestExitAttachment(owner_vm_id: vm_model.VmId, owner_vcpu_id: VcpuId, clear_count: u64) GuestExitAttachment {
    return .{
        .recorded = false,
        .kind_tag = 0,
        .pc = 0,
        .sp = 0,
        .cause = 0,
        .trap_value = 0,
        .instruction_bits = 0,
        .owner_vm_id = owner_vm_id,
        .owner_vcpu_id = owner_vcpu_id,
        .record_count = 0,
        .clear_count = clear_count,
    };
}

pub fn attachGuestEntryFrame(frame: anytype) void {
    const vcpu = mutableObject();
    vcpu.guest_entry.prepared = true;
    vcpu.guest_entry.pc = frame.pc;
    vcpu.guest_entry.sp = frame.sp;
    vcpu.guest_entry.status_flags = frame.status_flags;
    vcpu.guest_entry.owner_vm_id = frame.owner_vm_id;
    vcpu.guest_entry.owner_vcpu_id = frame.owner_vcpu_id;
    vcpu.guest_entry.attach_count += 1;
}

pub fn clearGuestEntryFrame() void {
    const vcpu = mutableObject();
    const attach_count = vcpu.guest_entry.attach_count;
    const clear_count = vcpu.guest_entry.clear_count + 1;
    vcpu.guest_entry = emptyGuestEntryAttachment(vcpu.vm_id, vcpu.id, clear_count);
    vcpu.guest_entry.attach_count = attach_count;
}

pub fn attachGuestExitRecord(frame: anytype, kind_tag: usize, record_count: usize) void {
    const vcpu = mutableObject();
    vcpu.guest_exit.recorded = true;
    vcpu.guest_exit.kind_tag = kind_tag;
    vcpu.guest_exit.pc = frame.pc;
    vcpu.guest_exit.sp = frame.sp;
    vcpu.guest_exit.cause = frame.cause;
    vcpu.guest_exit.trap_value = frame.trap_value;
    vcpu.guest_exit.instruction_bits = frame.instruction_bits;
    vcpu.guest_exit.owner_vm_id = frame.owner_vm_id;
    vcpu.guest_exit.owner_vcpu_id = frame.owner_vcpu_id;
    vcpu.guest_exit.record_count = @intCast(record_count);
}

pub fn clearGuestExitAttachment() void {
    const vcpu = mutableObject();
    const record_count = vcpu.guest_exit.record_count;
    const clear_count = vcpu.guest_exit.clear_count + 1;
    vcpu.guest_exit = emptyGuestExitAttachment(vcpu.vm_id, vcpu.id, clear_count);
    vcpu.guest_exit.record_count = record_count;
}

pub fn initializeLifecycle() TransitionResult {
    const vcpu = mutableObject();
    if (vcpu.state != .created) return reject(vcpu);
    vcpu.state = .initialized;
    vcpu.stats.initialize_count += 1;
    vcpu.stats.last_transition_result = .ok;
    return .ok;
}

pub fn prepareRunnable() TransitionResult {
    const vcpu = mutableObject();
    switch (vcpu.state) {
        .initialized, .halted => {
            vcpu.state = .runnable;
            vcpu.stats.prepare_count += 1;
            vcpu.stats.last_transition_result = .ok;
            return .ok;
        },
        .created, .runnable => return reject(vcpu),
    }
}

pub fn halt() TransitionResult {
    const vcpu = mutableObject();
    if (vcpu.state != .runnable) return reject(vcpu);
    vcpu.state = .halted;
    vcpu.stats.halt_count += 1;
    vcpu.stats.last_transition_result = .ok;
    return .ok;
}

pub fn reset() TransitionResult {
    const vcpu = mutableObject();
    vcpu.state = .created;
    vcpu.stats.reset_generation += 1;
    vcpu.stats.reset_count += 1;
    vcpu.stats.last_transition_result = .ok;
    return .ok;
}

fn reject(vcpu: *Vcpu) TransitionResult {
    vcpu.stats.failed_transition_count += 1;
    vcpu.stats.last_transition_result = .invalid_state;
    return .invalid_state;
}

pub fn canInitialize() bool {
    return object().state == .created;
}

pub fn canPrepareRunnable() bool {
    const state = object().state;
    return state == .initialized or state == .halted;
}

pub fn canHalt() bool {
    return object().state == .runnable;
}

pub fn stateName(state: State) []const u8 {
    return switch (state) {
        .created => "created",
        .initialized => "initialized",
        .runnable => "runnable",
        .halted => "halted",
    };
}

pub fn hartBindingName(binding: HartBinding) []const u8 {
    return switch (binding) {
        .boot_hart => "boot-hart",
    };
}

pub fn transitionResultName(result: TransitionResult) []const u8 {
    return switch (result) {
        .never_run => "never-run",
        .ok => "ok",
        .invalid_state => "invalid-state",
    };
}

pub fn printImplementedMarker() void {
    uart.write("hv: vcpu_object=implemented\r\n");
}

pub fn printObject() void {
    const vcpu = object();
    printImplementedMarker();
    uart.write("hv: vcpu.id=");
    uart.writeDec(vcpu.id);
    uart.write("\r\n");
    uart.write("hv: vcpu.vm_id=");
    uart.writeDec(vcpu.vm_id);
    uart.write("\r\n");
    uart.write("hv: vcpu.state=");
    uart.write(stateName(vcpu.state));
    uart.write("\r\n");
    uart.write("hv: vcpu.hart_binding=");
    uart.write(hartBindingName(vcpu.hart_binding));
    uart.write("\r\n");
    uart.write("hv: vcpu.run_count=");
    uart.writeDec(vcpu.run_count);
    uart.write("\r\n");
    printGuestEntryAttachment();
    printGuestExitAttachment();
}

pub fn printLifecycle() void {
    const vcpu = object();
    uart.write("hv: vcpu.lifecycle.state=");
    uart.write(stateName(vcpu.state));
    uart.write("\r\n");
    uart.write("hv: vcpu.lifecycle.can_initialize=");
    uart.write(boolName(canInitialize()));
    uart.write("\r\n");
    uart.write("hv: vcpu.lifecycle.can_prepare_runnable=");
    uart.write(boolName(canPrepareRunnable()));
    uart.write("\r\n");
    uart.write("hv: vcpu.lifecycle.can_halt=");
    uart.write(boolName(canHalt()));
    uart.write("\r\n");
    uart.write("hv: vcpu.reset_generation=");
    uart.writeDec(vcpu.stats.reset_generation);
    uart.write("\r\n");
    printStats();
}

pub fn printTransition(command_name: []const u8, result: TransitionResult) void {
    const vcpu = object();
    uart.write("hv: vcpu.transition=");
    uart.write(command_name);
    uart.write(" result=");
    uart.write(transitionResultName(result));
    uart.write("\r\n");
    uart.write("hv: vcpu.state=");
    uart.write(stateName(vcpu.state));
    uart.write("\r\n");
    uart.write("hv: vcpu.hart_binding=");
    uart.write(hartBindingName(vcpu.hart_binding));
    uart.write("\r\n");
    uart.write("hv: vcpu.run_count=");
    uart.writeDec(vcpu.run_count);
    uart.write("\r\n");
    uart.write("hv: vcpu.reset_generation=");
    uart.writeDec(vcpu.stats.reset_generation);
    uart.write("\r\n");
    printStats();
}

fn printGuestEntryAttachment() void {
    const attachment = object().guest_entry;
    uart.write("hv: vcpu.guest_entry.prepared=");
    uart.write(if (attachment.prepared) "true" else "false");
    uart.write("\r\n");
    uart.write("hv: vcpu.guest_entry.pc=");
    uart.writeHex(attachment.pc);
    uart.write("\r\n");
    uart.write("hv: vcpu.guest_entry.sp=");
    uart.writeHex(attachment.sp);
    uart.write("\r\n");
    uart.write("hv: vcpu.guest_entry.status_flags=");
    uart.writeHex(attachment.status_flags);
    uart.write("\r\n");
    uart.write("hv: vcpu.guest_entry.owner_vm_id=");
    uart.writeDec(attachment.owner_vm_id);
    uart.write("\r\n");
    uart.write("hv: vcpu.guest_entry.owner_vcpu_id=");
    uart.writeDec(attachment.owner_vcpu_id);
    uart.write("\r\n");
    uart.write("hv: vcpu.guest_entry.attach_count=");
    uart.writeDec(attachment.attach_count);
    uart.write("\r\n");
    uart.write("hv: vcpu.guest_entry.clear_count=");
    uart.writeDec(attachment.clear_count);
    uart.write("\r\n");
}

fn printGuestExitAttachment() void {
    const attachment = object().guest_exit;
    uart.write("hv: vcpu.guest_exit.recorded=");
    uart.write(if (attachment.recorded) "true" else "false");
    uart.write("\r\n");
    uart.write("hv: vcpu.guest_exit.kind_tag=");
    uart.writeDec(attachment.kind_tag);
    uart.write("\r\n");
    uart.write("hv: vcpu.guest_exit.pc=");
    uart.writeHex(attachment.pc);
    uart.write("\r\n");
    uart.write("hv: vcpu.guest_exit.sp=");
    uart.writeHex(attachment.sp);
    uart.write("\r\n");
    uart.write("hv: vcpu.guest_exit.cause=");
    uart.writeHex(attachment.cause);
    uart.write("\r\n");
    uart.write("hv: vcpu.guest_exit.trap_value=");
    uart.writeHex(attachment.trap_value);
    uart.write("\r\n");
    uart.write("hv: vcpu.guest_exit.instruction_bits=");
    uart.writeHex(attachment.instruction_bits);
    uart.write("\r\n");
    uart.write("hv: vcpu.guest_exit.owner_vm_id=");
    uart.writeDec(attachment.owner_vm_id);
    uart.write("\r\n");
    uart.write("hv: vcpu.guest_exit.owner_vcpu_id=");
    uart.writeDec(attachment.owner_vcpu_id);
    uart.write("\r\n");
    uart.write("hv: vcpu.guest_exit.record_count=");
    uart.writeDec(attachment.record_count);
    uart.write("\r\n");
    uart.write("hv: vcpu.guest_exit.clear_count=");
    uart.writeDec(attachment.clear_count);
    uart.write("\r\n");
}

fn printStats() void {
    const stats = object().stats;
    uart.write("hv: vcpu.stats.initialize_count=");
    uart.writeDec(stats.initialize_count);
    uart.write("\r\n");
    uart.write("hv: vcpu.stats.prepare_count=");
    uart.writeDec(stats.prepare_count);
    uart.write("\r\n");
    uart.write("hv: vcpu.stats.halt_count=");
    uart.writeDec(stats.halt_count);
    uart.write("\r\n");
    uart.write("hv: vcpu.stats.reset_count=");
    uart.writeDec(stats.reset_count);
    uart.write("\r\n");
    uart.write("hv: vcpu.stats.failed_transition_count=");
    uart.writeDec(stats.failed_transition_count);
    uart.write("\r\n");
    uart.write("hv: vcpu.stats.last_transition_result=");
    uart.write(transitionResultName(stats.last_transition_result));
    uart.write("\r\n");
}

fn boolName(value: bool) []const u8 {
    return if (value) "true" else "false";
}
```

---

What To Notice

1. The vCPU imports the VM module.

   This is not accidental.

   The vCPU belongs to a VM.

2. The lifecycle has allowed states.

   created, initialized, runnable, halted.

3. The lifecycle rejects invalid transitions.

   A vCPU cannot simply become anything at any time.

4. The module keeps statistics.

   Hyper-Zig records transition counts and failed transitions.

5. Future guest-entry and guest-exit fields already have places to
   attach.

   The vCPU is becoming the center of guest execution state.

Key Structures

* Vcpu
* State
* LifecycleStats
* TransitionResult
* GuestEntryAttachment
* GuestExitAttachment

Key Functions

* init()
* object()
* initializeLifecycle()
* prepareRunnable()
* halt()
* reset()
* reject()
* printLifecycle()
* printTransition()

If you can explain why invalid transitions are rejected, you understand
the implementation.

PAGE C
THE EXERCISE
============

In HV01, you built a VM Object.

In HV02, you built a capability report.

Now you will build a tiny vCPU lifecycle in C.

The goal is not to build a real CPU.

The goal is to model a CPU-shaped object that belongs to a VM and moves
through a controlled lifecycle.

This exercise is about state machines.

A state machine is a system where an object can only move through
allowed states.

The concepts required for this exercise are:

* Structures
* Enumerations
* State transitions
* Ownership
* Counters
* Rejected operations
* Diagnostic output

---

Starting Point

Complete the implementation below.

Only model the vCPU lifecycle.

```c
#include <stdio.h>

typedef unsigned int VmId;
typedef unsigned int VcpuId;

typedef enum
{
    VCPU_CREATED,
    VCPU_INITIALIZED,
    VCPU_RUNNABLE,
    VCPU_HALTED
} VcpuState;

typedef enum
{
    TRANSITION_NEVER_RUN,
    TRANSITION_OK,
    TRANSITION_INVALID_STATE
} TransitionResult;

typedef struct
{
    unsigned long reset_generation;
    unsigned long initialize_count;
    unsigned long prepare_count;
    unsigned long halt_count;
    unsigned long reset_count;
    unsigned long failed_transition_count;
    TransitionResult last_transition_result;
} LifecycleStats;

typedef struct
{
    VcpuId id;
    VmId vm_id;
    VcpuState state;
    unsigned long run_count;
    LifecycleStats stats;
} Vcpu;

Vcpu boot_vcpu;

void vcpu_init(VmId vm_id)
{
    boot_vcpu.id = 0;
    boot_vcpu.vm_id = vm_id;
    boot_vcpu.state = VCPU_CREATED;
    boot_vcpu.run_count = 0;

    boot_vcpu.stats.reset_generation = 0;
    boot_vcpu.stats.initialize_count = 0;
    boot_vcpu.stats.prepare_count = 0;
    boot_vcpu.stats.halt_count = 0;
    boot_vcpu.stats.reset_count = 0;
    boot_vcpu.stats.failed_transition_count = 0;
    boot_vcpu.stats.last_transition_result = TRANSITION_NEVER_RUN;
}

TransitionResult reject_transition(void)
{
    boot_vcpu.stats.failed_transition_count += 1;
    boot_vcpu.stats.last_transition_result = TRANSITION_INVALID_STATE;
    return TRANSITION_INVALID_STATE;
}

TransitionResult vcpu_initialize(void)
{
    /* Only allow CREATED -> INITIALIZED */

    return TRANSITION_INVALID_STATE;
}

TransitionResult vcpu_prepare_runnable(void)
{
    /* Only allow INITIALIZED -> RUNNABLE */
    /* Also allow HALTED -> RUNNABLE */

    return TRANSITION_INVALID_STATE;
}

TransitionResult vcpu_halt(void)
{
    /* Only allow RUNNABLE -> HALTED */

    return TRANSITION_INVALID_STATE;
}

TransitionResult vcpu_reset(void)
{
    /* Always return the vCPU to CREATED */

    return TRANSITION_INVALID_STATE;
}

const char *vcpu_state_name(VcpuState state)
{
    switch (state)
    {
        case VCPU_CREATED:
            return "created";
        case VCPU_INITIALIZED:
            return "initialized";
        case VCPU_RUNNABLE:
            return "runnable";
        case VCPU_HALTED:
            return "halted";
    }

    return "unknown";
}

const char *transition_result_name(TransitionResult result)
{
    switch (result)
    {
        case TRANSITION_NEVER_RUN:
            return "never-run";
        case TRANSITION_OK:
            return "ok";
        case TRANSITION_INVALID_STATE:
            return "invalid-state";
    }

    return "unknown";
}

void vcpu_print(void)
{
    printf("vcpu.id=%u\n", boot_vcpu.id);
    printf("vcpu.vm_id=%u\n", boot_vcpu.vm_id);
    printf("vcpu.state=%s\n", vcpu_state_name(boot_vcpu.state));
    printf("vcpu.run_count=%lu\n", boot_vcpu.run_count);
    printf("vcpu.stats.initialize_count=%lu\n", boot_vcpu.stats.initialize_count);
    printf("vcpu.stats.prepare_count=%lu\n", boot_vcpu.stats.prepare_count);
    printf("vcpu.stats.halt_count=%lu\n", boot_vcpu.stats.halt_count);
    printf("vcpu.stats.reset_count=%lu\n", boot_vcpu.stats.reset_count);
    printf("vcpu.stats.failed_transition_count=%lu\n", boot_vcpu.stats.failed_transition_count);
    printf("vcpu.stats.last_transition_result=%s\n",
        transition_result_name(boot_vcpu.stats.last_transition_result));
}

int main(void)
{
    vcpu_init(0);

    vcpu_print();

    return 0;
}
```

---

Questions

1.

Why does the vCPU store a VM id?

What would be lost if the vCPU did not know which VM owned it?

---

2.

What is the difference between:

created

and

initialized

?

Why not use only one state?

---

3.

Why should created not be allowed to jump directly to runnable?

What preparation might be missing?

---

4.

Implement:

```c
TransitionResult vcpu_initialize(void);
```

It should only allow:

created to initialized

Every other starting state should be rejected.

---

5.

Implement:

```c
TransitionResult vcpu_prepare_runnable(void);
```

It should allow:

initialized to runnable

halted to runnable

It should reject:

created to runnable

runnable to runnable

---

6.

Implement:

```c
TransitionResult vcpu_halt(void);
```

It should only allow:

runnable to halted

---

7.

Implement:

```c
TransitionResult vcpu_reset(void);
```

It should return the vCPU to:

created

It should also increment:

reset_generation

reset_count

---

8.

After each successful transition, update:

last_transition_result

with:

ok

After each failed transition, update it with:

invalid-state

---

9.

Write a test sequence:

initialize

prepare_runnable

halt

prepare_runnable

reset

Then print the vCPU.

What state should it end in?

---

10.

Write an invalid sequence:

halt immediately after init

What should happen?

Which counter should increase?

---

Challenge Question

A hypervisor lets a vCPU become runnable without initialization.

What kinds of later bugs could this create?

Think about:

* missing register state
* missing guest entry information
* missing ownership
* unsafe execution attempts

===============================================================

Completion Check

Before moving to HV04, make sure you can explain:

* What a vCPU is
* Why it belongs to a VM
* What a lifecycle is
* Why invalid transitions are rejected
* Why transition statistics are useful
* Why runnable does not mean running yet

If you can explain those concepts in your own words, you have
completed HV03.

PAGE D
INSTRUCTOR NOTES
================

## Audience

Students should have completed HV01 and HV02.

Students should understand:

* VM Objects
* Identity
* Ownership
* Capability reporting
* Basic enums and structs

HV03 introduces the first major lifecycle system.

This is an important jump.

Students are no longer only storing information.

They are now controlling how information changes.

## Learning Objective

By the end of HV03, students should understand that a vCPU is not the
same thing as execution.

A vCPU is the object that will eventually carry execution state.

Students should understand that state transitions must be controlled.

The main lesson is:

A system should not merely know what state it is in.

It should know which states are allowed to come next.

## Key Concepts

This module introduces:

* vCPU ownership
* Lifecycle state
* State machines
* Valid transitions
* Invalid transitions
* Transition counters
* Reset behavior

These concepts become essential before guest execution.

## Common Misconceptions

Misconception:

"The vCPU is already running guest code."

Correction:

No guest code is running.

The vCPU is only being modeled and prepared.

---

Misconception:

"Runnable means running."

Correction:

Runnable means the object is prepared for a future run attempt.

It does not mean execution has happened.

---

Misconception:

"Invalid transitions are errors in the code."

Correction:

Invalid transitions are expected cases that the lifecycle must reject
safely.

A good state machine knows how to say no.

---

Misconception:

"The statistics are just extra noise."

Correction:

The statistics are evidence.

They show how the lifecycle has actually been used.

## Discussion Questions

Ask students:

"Should a CPU be allowed to run before it is initialized?"

This sounds simple, but it opens the door to discussions about register
state, ownership, memory, and safety.

---

Ask students:

"What is the difference between runnable and running?"

This distinction becomes important later when Hyper-Zig adds controlled
run attempts and execution gates.

---

Ask students:

"Why do we count failed transitions?"

Guide them toward the idea that failed operations are part of the
system's history.

## Expected Student Outcomes

A successful student should be able to explain:

* What a vCPU represents
* Why the vCPU belongs to a VM
* Why lifecycle states exist
* Why some transitions are rejected
* Why reset returns the vCPU to created
* Why runnable is not the same as running

## Suggested Demonstration

Draw this state machine on a board:

created

↓ initialize

initialized

↓ prepare

runnable

↓ halt

halted

Then draw another arrow:

created to halted

Ask students whether that arrow should exist.

Let them argue.

Then explain:

A lifecycle is not just a list of states.

A lifecycle is a set of permitted movements.

## Connection To Future Modules

HV01 created the VM Object.

HV02 reported what Hyper-Zig could safely claim.

HV03 creates the vCPU lifecycle.

HV04 will introduce guest memory.

This order matters.

The VM exists first.

The vCPU belongs to the VM.

Memory will later belong to the VM.

Eventually, guest entry, guest exit, and execution will depend on this
vCPU state machine.

## Assessment

A student has successfully completed HV03 if they can answer:

"Why can't a vCPU go directly from created to halted?"

without referring to the code.

The desired answer should focus on lifecycle meaning, not syntax.

===============================================================

## Instructor Summary

HV03 is where Hyper-Zig starts to feel alive.

The VM now has a CPU-shaped object.

That object does not execute yet.

But it has identity, ownership, state, rules, and memory of its own
transitions.

That is the beginning of controlled guest execution.
