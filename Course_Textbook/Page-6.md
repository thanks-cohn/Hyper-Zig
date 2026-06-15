# HV06

## Guest Entry

```text
Section: 6A
Module: Guest Entry
Type: Concept
Source: guest_entry.zig
```

### In Plain English

In HV05, the hypervisor learned how to load a Guest Image.

Now a new question appears.

The image exists.

The image has been validated.

The image has been placed into memory.

But where does execution begin?

That is the purpose of Guest Entry.

Guest Entry describes the first moment a guest would begin running.

Think about launching a rocket.

Before launch, engineers must know:

* where the rocket is
* what fuel it contains
* what destination it targets

But they also need to know:

```text
Where does ignition begin?
```

Guest Entry answers a similar question.

A hypervisor must know:

* the first instruction address
* the initial execution state
* the VM that owns the entry point
* the vCPU that will receive control

Before execution can occur, the hypervisor must prepare an entry frame.

The entry frame is a description of the world that the guest expects to see when execution begins.

At HV06:

* no guest code executes
* Linux does not boot
* BusyBox does not boot
* Alpine does not boot

The hypervisor is only preparing.

Preparation comes before execution.

That rule appears repeatedly throughout Hyper-Zig.

### Key Idea

A Guest Image answers:

```text
What should run?
```

Guest Entry answers:

```text
Where should execution begin?
```

Those are different questions.

The hypervisor must answer both before guest execution becomes possible.

---

```text
Section: 6B
Module: Guest Entry
Type: Implementation
Source: guest_entry.zig
```

## The Real Hyper-Zig Module

File:

```text
kernel/hypervisor/guest_entry.zig
```

```zig


const uart = @import("../console/uart.zig");
const pmm = @import("../memory/pmm.zig");
const vm_model = @import("vm.zig");
const vcpu_model = @import("vcpu.zig");
const guest_memory = @import("guest_memory.zig");
const guest_address_space = @import("guest_address_space.zig");
const guest_image = @import("guest_image.zig");

pub const default_stack_size_bytes: usize = pmm.page_size;
pub const stack_alignment_bytes: usize = 16;

pub const GuestEntryState = enum {
    not_prepared,
    prepared,
};

pub const GuestEntryError = enum {
    none,
    guest_memory_not_configured,
    address_space_not_configured,
    guest_image_not_loaded,
    owner_mismatch,
    invalid_guest_memory,
    invalid_address_space,
    invalid_entry_point,
    invalid_stack_size,
    stack_out_of_bounds,
    stack_overflow,
};

pub const GuestRegisterFrame = struct {
    pc: usize,
    sp: usize,
    a0: usize,
    a1: usize,
    status_flags: usize,
    owner_vm_id: vm_model.VmId,
    owner_vcpu_id: vcpu_model.VcpuId,
};

pub const GuestEntryPrepareResult = struct {
    result: CommandResult,
    state: GuestEntryState,
    frame: GuestRegisterFrame,
    pc: usize,
    sp: usize,
    stack_top: usize,
    stack_size_bytes: usize,
    entry_error: GuestEntryError,
};

pub const GuestEntryResetResult = struct {
    result: CommandResult,
    state: GuestEntryState,
    reset_count: usize,
    entry_error: GuestEntryError,
};

pub const CommandResult = enum {
    ok,
    rejected,
};

pub const GuestEntry = struct {
    owner_vm_id: vm_model.VmId,
    owner_vcpu_id: vcpu_model.VcpuId,
    state: GuestEntryState,
    frame_valid: bool,
    frame: GuestRegisterFrame,
    pc: usize,
    sp: usize,
    image_entry_point: usize,
    guest_memory_base: usize,
    guest_memory_size_bytes: usize,
    stack_top: usize,
    stack_size_bytes: usize,
    prepare_count: usize,
    reset_count: usize,
    failed_prepare_count: usize,
    bounds_reject_count: usize,
    last_error: GuestEntryError,
};

var boot_guest_entry: GuestEntry = undefined;
var initialized: bool = false;

pub fn init(owner_vm_id: vm_model.VmId, owner_vcpu_id: vcpu_model.VcpuId) void {
    boot_guest_entry = emptyObject(owner_vm_id, owner_vcpu_id, 0, 0, 0, 0);
    initialized = true;
    vcpu_model.clearGuestEntryFrame();
}

pub fn object() *const GuestEntry {
    return mutableObject();
}

fn mutableObject() *GuestEntry {
    if (!initialized) init(vm_model.object().id, vcpu_model.object().id);
    return &boot_guest_entry;
}

fn emptyFrame(owner_vm_id: vm_model.VmId, owner_vcpu_id: vcpu_model.VcpuId) GuestRegisterFrame {
    return .{
        .pc = 0,
        .sp = 0,
        .a0 = 0,
        .a1 = 0,
        .status_flags = 0,
        .owner_vm_id = owner_vm_id,
        .owner_vcpu_id = owner_vcpu_id,
    };
}

fn emptyObject(
    owner_vm_id: vm_model.VmId,
    owner_vcpu_id: vcpu_model.VcpuId,
    reset_count: usize,
    prepare_count: usize,
    failed_prepare_count: usize,
    bounds_reject_count: usize,
) GuestEntry {
    return .{
        .owner_vm_id = owner_vm_id,
        .owner_vcpu_id = owner_vcpu_id,
        .state = .not_prepared,
        .frame_valid = false,
        .frame = emptyFrame(owner_vm_id, owner_vcpu_id),
        .pc = 0,
        .sp = 0,
        .image_entry_point = 0,
        .guest_memory_base = 0,
        .guest_memory_size_bytes = 0,
        .stack_top = 0,
        .stack_size_bytes = 0,
        .prepare_count = prepare_count,
        .reset_count = reset_count,
        .failed_prepare_count = failed_prepare_count,
        .bounds_reject_count = bounds_reject_count,
        .last_error = .none,
    };
}

pub fn prepare() GuestEntryPrepareResult {
    return prepareWithStack(default_stack_size_bytes, null);
}

fn prepareWithStack(requested_stack_size: usize, forced_stack_top: ?usize) GuestEntryPrepareResult {
    const entry = mutableObject();
    entry.owner_vm_id = vm_model.object().id;
    entry.owner_vcpu_id = vcpu_model.object().id;
    clearPreparedFields(entry);

    if (guest_memory.object().state != .configured) {
        if (guest_memory.configureDefault() != .ok) return failPrepare(.guest_memory_not_configured, false);
    }
    const gm = guest_memory.object();
    if (gm.owner_vm_id != entry.owner_vm_id or gm.base == 0 or gm.size_bytes == 0) return failPrepare(.invalid_guest_memory, false);

    if (guest_address_space.object().state != .configured) {
        if (guest_address_space.createFromGuestMemory() != .ok) return failPrepare(.address_space_not_configured, false);
    }
    const as = guest_address_space.object();
    if (as.owner_vm_id != entry.owner_vm_id or as.guest_size_bytes == 0 or as.translated_page_count == 0) return failPrepare(.invalid_address_space, false);

    const image = guest_image.object();
    if (image.state != .loaded) return failPrepare(.guest_image_not_loaded, false);
    if (image.owner_vm_id != entry.owner_vm_id) return failPrepare(.owner_mismatch, false);

    const pc = image.entry_point.gpa;
    if (!gpaWithinAddressSpace(as, pc)) return failPrepare(.invalid_entry_point, true);

    const stack_size = normalizeStackSize(requested_stack_size, as.page_size) orelse return failPrepare(.invalid_stack_size, true);
    const natural_stack_top = checkedAdd(as.guest_base.value, as.guest_size_bytes) orelse return failPrepare(.stack_overflow, true);
    const stack_top = forced_stack_top orelse natural_stack_top;
    const sp = deriveStackPointer(as.guest_base.value, as.guest_size_bytes, stack_top, stack_size) orelse return failPrepare(.stack_out_of_bounds, true);
    if (!validateStackWindow(as.guest_base.value, as.guest_size_bytes, sp, stack_top, stack_size)) return failPrepare(.stack_out_of_bounds, true);

    const frame = GuestRegisterFrame{
        .pc = pc,
        .sp = sp,
        .a0 = entry.owner_vm_id,
        .a1 = entry.owner_vcpu_id,
        .status_flags = makeStatusFlags(image.loaded_byte_count, as.translated_page_count),
        .owner_vm_id = entry.owner_vm_id,
        .owner_vcpu_id = entry.owner_vcpu_id,
    };

    entry.state = .prepared;
    entry.frame_valid = true;
    entry.frame = frame;
    entry.pc = pc;
    entry.sp = sp;
    entry.image_entry_point = image.entry_point.gpa;
    entry.guest_memory_base = as.guest_base.value;
    entry.guest_memory_size_bytes = as.guest_size_bytes;
    entry.stack_top = stack_top;
    entry.stack_size_bytes = stack_size;
    entry.prepare_count += 1;
    entry.last_error = .none;
    vcpu_model.attachGuestEntryFrame(frame);

    return .{
        .result = .ok,
        .state = entry.state,
        .frame = frame,
        .pc = pc,
        .sp = sp,
        .stack_top = stack_top,
        .stack_size_bytes = stack_size,
        .entry_error = .none,
    };
}

pub fn reset() GuestEntryResetResult {
    const entry = mutableObject();
    const owner_vm_id = entry.owner_vm_id;
    const owner_vcpu_id = entry.owner_vcpu_id;
    const next_reset_count = entry.reset_count + 1;
    const prepare_count = entry.prepare_count;
    const failed_prepare_count = entry.failed_prepare_count;
    const bounds_reject_count = entry.bounds_reject_count;
    boot_guest_entry = emptyObject(owner_vm_id, owner_vcpu_id, next_reset_count, prepare_count, failed_prepare_count, bounds_reject_count);
    initialized = true;
    vcpu_model.clearGuestEntryFrame();
    return .{
        .result = .ok,
        .state = .not_prepared,
        .reset_count = next_reset_count,
        .entry_error = .none,
    };
}

pub fn boundsTest() CommandResult {
    if (guest_memory.object().state != .configured) {
        if (guest_memory.configureDefault() != .ok) return noteRejectedBounds(.guest_memory_not_configured);
    }
    if (guest_address_space.object().state != .configured) {
        if (guest_address_space.createFromGuestMemory() != .ok) return noteRejectedBounds(.address_space_not_configured);
    }
    if (guest_image.object().state != .loaded) {
        const loaded = guest_image.loadTiny();
        if (loaded.result != .ok) return noteRejectedBounds(.guest_image_not_loaded);
    }
    const as = guest_address_space.object();
    const invalid_top = checkedAdd(as.guest_base.value, as.guest_size_bytes + stack_alignment_bytes) orelse return noteRejectedBounds(.stack_overflow);
    const result = prepareWithStack(default_stack_size_bytes, invalid_top);
    return if (result.result == .rejected and result.entry_error == .stack_out_of_bounds) .rejected else .ok;
}

pub fn requireImageTest() CommandResult {
    _ = reset();
    guest_image.reset();
    if (guest_memory.object().state != .configured) _ = guest_memory.configureDefault();
    if (guest_address_space.object().state != .configured) _ = guest_address_space.createFromGuestMemory();
    const result = prepare();
    return if (result.result == .rejected and result.entry_error == .guest_image_not_loaded) .rejected else .ok;
}

fn failPrepare(err: GuestEntryError, bounds_related: bool) GuestEntryPrepareResult {
    const entry = mutableObject();
    entry.state = .not_prepared;
    entry.frame_valid = false;
    entry.failed_prepare_count += 1;
    if (bounds_related) entry.bounds_reject_count += 1;
    entry.last_error = err;
    vcpu_model.clearGuestEntryFrame();
    return .{
        .result = .rejected,
        .state = entry.state,
        .frame = emptyFrame(entry.owner_vm_id, entry.owner_vcpu_id),
        .pc = 0,
        .sp = 0,
        .stack_top = 0,
        .stack_size_bytes = 0,
        .entry_error = err,
    };
}

fn noteRejectedBounds(err: GuestEntryError) CommandResult {
    const entry = mutableObject();
    entry.failed_prepare_count += 1;
    entry.bounds_reject_count += 1;
    entry.last_error = err;
    return .rejected;
}

fn clearPreparedFields(entry: *GuestEntry) void {
    entry.state = .not_prepared;
    entry.frame_valid = false;
    entry.frame = emptyFrame(entry.owner_vm_id, entry.owner_vcpu_id);
    entry.pc = 0;
    entry.sp = 0;
    entry.image_entry_point = 0;
    entry.guest_memory_base = 0;
    entry.guest_memory_size_bytes = 0;
    entry.stack_top = 0;
    entry.stack_size_bytes = 0;
    vcpu_model.clearGuestEntryFrame();
}

fn normalizeStackSize(requested_stack_size: usize, page_size: usize) ?usize {
    if (requested_stack_size == 0) return null;
    const capped = if (requested_stack_size > page_size) page_size else requested_stack_size;
    return alignDown(capped, stack_alignment_bytes);
}

fn deriveStackPointer(guest_base: usize, guest_size: usize, stack_top: usize, stack_size: usize) ?usize {
    if (stack_size == 0) return null;
    const guest_end = checkedAdd(guest_base, guest_size) orelse return null;
    if (stack_top <= guest_base or stack_top > guest_end) return null;
    const raw_sp = checkedSub(stack_top, stack_alignment_bytes) orelse return null;
    const sp = alignDown(raw_sp, stack_alignment_bytes);
    const stack_bottom = checkedSub(stack_top, stack_size) orelse return null;
    if (sp < stack_bottom) return null;
    return sp;
}

fn validateStackWindow(guest_base: usize, guest_size: usize, sp: usize, stack_top: usize, stack_size: usize) bool {
    const guest_end = checkedAdd(guest_base, guest_size) orelse return false;
    if (stack_size == 0) return false;
    if (stack_top <= guest_base or stack_top > guest_end) return false;
    const stack_bottom = checkedSub(stack_top, stack_size) orelse return false;
    if (stack_bottom < guest_base) return false;
    if (sp < stack_bottom or sp >= stack_top) return false;
    if (sp < guest_base or sp >= guest_end) return false;
    return true;
}

fn gpaWithinAddressSpace(as: *const guest_address_space.GuestAddressSpace, gpa: usize) bool {
    const end = checkedAdd(as.guest_base.value, as.guest_size_bytes) orelse return false;
    return gpa >= as.guest_base.value and gpa < end;
}

fn makeStatusFlags(loaded_byte_count: usize, translated_page_count: usize) usize {
    const loaded_bit: usize = if (loaded_byte_count > 0) 1 else 0;
    const address_space_bit: usize = if (translated_page_count > 0) 2 else 0;
    return loaded_bit | address_space_bit;
}

fn alignDown(value: usize, alignment: usize) usize {
    return value & ~(alignment - 1);
}

fn checkedAdd(a: usize, b: usize) ?usize {
    if (b > (@as(usize, ~@as(usize, 0)) - a)) return null;
    return a + b;
}

fn checkedSub(a: usize, b: usize) ?usize {
    if (b > a) return null;
    return a - b;
}

pub fn printState() void {
    printImplementedMarker();
    printFields();
    printFrameFields();
    printNonClaims();
}

pub fn printPrepareCommand() void {
    const result = prepare();
    uart.write("hv: guest_entry.prepare_result=");
    uart.write(resultName(result.result));
    uart.write("\r\n");
    uart.write("hv: guest_entry.prepare_result.error=");
    uart.write(errorName(result.entry_error));
    uart.write("\r\n");
    printFields();
    printFrameFields();
    printNonClaims();
}

pub fn printResetCommand() void {
    const result = reset();
    uart.write("hv: guest_entry.reset_result=");
    uart.write(resultName(result.result));
    uart.write("\r\n");
    uart.write("hv: guest_entry.reset_result.error=");
    uart.write(errorName(result.entry_error));
    uart.write("\r\n");
    printFields();
    printFrameFields();
    printNonClaims();
}

pub fn printBoundsTestCommand() void {
    const result = boundsTest();
    uart.write("hv: guest_entry.bounds_test=");
    uart.write(if (result == .rejected) "rejected" else "failed-to-reject");
    uart.write("\r\n");
    printFields();
    printFrameFields();
    printNonClaims();
}

pub fn printRequireImageTestCommand() void {
    const result = requireImageTest();
    uart.write("hv: guest_entry.require_image_test=");
    uart.write(if (result == .rejected) "rejected" else "failed-to-reject");
    uart.write("\r\n");
    printFields();
    printFrameFields();
    printNonClaims();
}

pub fn printImplementedMarker() void {
    uart.write("hv: guest_entry=implemented\r\n");
}

fn printFields() void {
    const entry = object();
    uart.write("hv: guest_entry.owner_vm_id=");
    uart.writeDec(entry.owner_vm_id);
    uart.write("\r\n");
    uart.write("hv: guest_entry.owner_vcpu_id=");
    uart.writeDec(entry.owner_vcpu_id);
    uart.write("\r\n");
    uart.write("hv: guest_entry.state=");
    uart.write(stateName(entry.state));
    uart.write("\r\n");
    uart.write("hv: guest_entry.pc=");
    uart.writeHex(entry.pc);
    uart.write("\r\n");
    uart.write("hv: guest_entry.sp=");
    uart.writeHex(entry.sp);
    uart.write("\r\n");
    uart.write("hv: guest_entry.image_entry_point=");
    uart.writeHex(entry.image_entry_point);
    uart.write("\r\n");
    uart.write("hv: guest_entry.guest_memory_base=");
    uart.writeHex(entry.guest_memory_base);
    uart.write("\r\n");
    uart.write("hv: guest_entry.guest_memory_size_bytes=");
    uart.writeDec(entry.guest_memory_size_bytes);
    uart.write("\r\n");
    uart.write("hv: guest_entry.stack_top=");
    uart.writeHex(entry.stack_top);
    uart.write("\r\n");
    uart.write("hv: guest_entry.stack_size_bytes=");
    uart.writeDec(entry.stack_size_bytes);
    uart.write("\r\n");
    uart.write("hv: guest_entry.prepare_count=");
    uart.writeDec(entry.prepare_count);
    uart.write("\r\n");
    uart.write("hv: guest_entry.reset_count=");
    uart.writeDec(entry.reset_count);
    uart.write("\r\n");
    uart.write("hv: guest_entry.failed_prepare_count=");
    uart.writeDec(entry.failed_prepare_count);
    uart.write("\r\n");
    uart.write("hv: guest_entry.bounds_reject_count=");
    uart.writeDec(entry.bounds_reject_count);
    uart.write("\r\n");
    uart.write("hv: guest_entry.last_error=");
    uart.write(errorName(entry.last_error));
    uart.write("\r\n");
}

fn printFrameFields() void {
    const entry = object();
    uart.write("hv: guest_entry.frame.valid=");
    uart.write(if (entry.frame_valid) "true" else "false");
    uart.write("\r\n");
    uart.write("hv: guest_entry.frame.pc=");
    uart.writeHex(entry.frame.pc);
    uart.write("\r\n");
    uart.write("hv: guest_entry.frame.sp=");
    uart.writeHex(entry.frame.sp);
    uart.write("\r\n");
    uart.write("hv: guest_entry.frame.a0=");
    uart.writeHex(entry.frame.a0);
    uart.write("\r\n");
    uart.write("hv: guest_entry.frame.a1=");
    uart.writeHex(entry.frame.a1);
    uart.write("\r\n");
    uart.write("hv: guest_entry.frame.status_flags=");
    uart.writeHex(entry.frame.status_flags);
    uart.write("\r\n");
    uart.write("hv: guest_entry.frame.owner_vm_id=");
    uart.writeDec(entry.frame.owner_vm_id);
    uart.write("\r\n");
    uart.write("hv: guest_entry.frame.owner_vcpu_id=");
    uart.writeDec(entry.frame.owner_vcpu_id);
    uart.write("\r\n");
}

fn stateName(state: GuestEntryState) []const u8 {
    return switch (state) {
        .not_prepared => "not-prepared",
        .prepared => "prepared",
    };
}

fn resultName(result: CommandResult) []const u8 {
    return switch (result) {
        .ok => "ok",
        .rejected => "rejected",
    };
}

fn errorName(err: GuestEntryError) []const u8 {
    return switch (err) {
        .none => "none",
        .guest_memory_not_configured => "guest-memory-not-configured",
        .address_space_not_configured => "address-space-not-configured",
        .guest_image_not_loaded => "guest-image-not-loaded",
        .owner_mismatch => "owner-mismatch",
        .invalid_guest_memory => "invalid-guest-memory",
        .invalid_address_space => "invalid-address-space",
        .invalid_entry_point => "invalid-entry-point",
        .invalid_stack_size => "invalid-stack-size",
        .stack_out_of_bounds => "stack-out-of-bounds",
        .stack_overflow => "stack-overflow",
    };
}

fn printNonClaims() void {
    uart.write("hv: guest_execution=not-supported-yet\r\n");
    uart.write("hv: linux_guest=not-supported-yet\r\n");
    uart.write("hv: second_stage_translation=MISSING\r\n");
    uart.write("hv: h_extension=unknown reason=no-safe-detection-yet\r\n");
}


```

### Things To Notice

1. Guest Entry belongs to a VM.

2. Guest Entry belongs to a vCPU.

3. Entry preparation happens before execution.

4. Entry information is tracked explicitly.

5. Ownership is recorded.

6. Entry state is observable.

7. The hypervisor remains in control.

8. Guest Entry does not execute code.

9. Guest Entry prepares execution.

10. Preparation and execution are separate concepts.

---

```text
Section: 6C
Module: Guest Entry
Type: Exercise
Source: guest_entry.zig
```

## Build It Yourself

In HV05, you created a Guest Image.

Now create a Guest Entry object.

The goal is not to execute code.

The goal is to describe where execution would begin.

### Concepts Required

* Structures
* Ownership
* State
* Validation
* Entry Points

### C Skeleton

```c
#include <stdio.h>

typedef unsigned int VmId;
typedef unsigned int VcpuId;

typedef enum
{
    ENTRY_NOT_PREPARED,
    ENTRY_PREPARED
}
GuestEntryState;

typedef struct
{
    unsigned long pc;
}
EntryPoint;

typedef struct
{
    VmId owner_vm_id;

    VcpuId owner_vcpu_id;

    GuestEntryState state;

    EntryPoint entry_point;

    unsigned long prepare_count;

    unsigned long reject_count;
}
GuestEntry;

static GuestEntry guest_entry;

void guest_entry_init(
    VmId vm_id,
    VcpuId vcpu_id)
{
    /*
        TODO
    */
}

int guest_entry_prepare(
    unsigned long entry_pc)
{
    /*
        TODO

        Validate entry address.

        Record preparation.

        Change state.
    */

    return 0;
}

void guest_entry_print(void)
{
    /*
        TODO
    */
}

int main(void)
{
    guest_entry_init(0, 0);

    /*
        TODO

        Prepare entry.

        Print state.
    */

    return 0;
}
```

### Questions

1.

Why is an entry point required?

2.

What happens if the hypervisor does not know where execution begins?

3.

Why should Guest Entry belong to a vCPU?

4.

Why separate:

```text
prepared
```

from:

```text
executing
```

?

5.

Can an entry point exist before execution?

Why?

6.

Why should entry preparation be observable?

### Challenge Question

Suppose a guest image loads correctly.

However, the entry point is invalid.

Should execution begin?

Why?

### Completion Check

Before moving to HV07, make sure you can explain:

* what Guest Entry is
* why entry points exist
* why preparation happens before execution
* why ownership matters
* why execution and preparation are separate concepts

---

```text
Section: 6D
Module: Guest Entry
Type: Instructor Notes
Source: guest_entry.zig
```

## Instructor Notes

### Audience

Students should have completed:

* HV01 VM Object
* HV02 Capability Detection
* HV03 vCPU Lifecycle
* HV04 Guest Memory
* HV05 Guest Images

### Learning Objective

Students should understand that loading an image and executing an image are different operations.

Many beginners assume:

```text
Loaded = Running
```

This module teaches that those are separate states.

Before execution begins, the hypervisor must know where execution begins.

That information is represented by Guest Entry.

### Key Concepts

* Entry Points
* Ownership
* Preparation
* Execution Readiness
* Validation

### Common Misconceptions

Misconception:

```text
Loaded means executable.
```

Correction:

A loaded image may still lack valid execution information.

---

Misconception:

```text
Preparation and execution are the same thing.
```

Correction:

Preparation happens first.

Execution may never occur.

---

Misconception:

```text
The CPU automatically knows where to start.
```

Correction:

The hypervisor must explicitly provide that information.

### Discussion Questions

Ask students:

```text
How does a CPU know which instruction executes first?
```

---

Ask students:

```text
Can a valid image still have an invalid entry point?
```

Why?

### Expected Outcomes

Students should be able to explain:

* what a Guest Entry is
* why entry points exist
* why preparation precedes execution
* why ownership is recorded
* why execution readiness is observable

### Connection To Future Modules

HV04 created memory.

HV05 created images.

HV06 creates execution starting points.

The chain now becomes:

```text
VM
↓
Memory
↓
Image
↓
Entry
↓
Address Space
↓
Execution
```

### Key Idea

Before a machine can run, it must know where to begin.

HV06 teaches the hypervisor how to answer that question.
