```text
Section: 4A
Module: Guest Memory
Type: Concept
Source: guest_memory.zig
```
# Guest Memory

### In Plain English

In HV01, Hyper-Zig created the VM Object.

In HV02, Hyper-Zig learned how to report what it knows.

In HV03, Hyper-Zig created a virtual CPU.

Now the virtual machine needs somewhere to store things.

A VM without memory cannot hold code.

A VM without memory cannot hold data.

A VM without memory cannot hold a stack.

A VM without memory cannot eventually hold Linux.

So before we worry about loading programs, we first need a safe place to put them.

That place is Guest Memory.

Guest Memory belongs to a VM.

The memory does not exist by itself.

The VM owns it.

Because memory is dangerous, Hyper-Zig does not simply allocate memory and hope everything works.

Instead it tracks:

- ownership
- allocation state
- page count
- size
- allocation failures
- free failures
- bounds violations
- overflow attempts

Hyper-Zig treats memory as a managed resource.

Not a pile of bytes.

A resource.

The most important lesson in HV04 is that memory must be controlled before it becomes useful.

Memory is the first major resource that the VM owns.

Future modules will build directly on top of it.

Memory comes before address spaces.

Memory comes before guest images.

Memory comes before guest execution.

If the memory system is wrong, everything built on top of it will also be wrong.

That is why HV04 exists.

```
Section: 4B
Type: Implementation
```

# Guest Memory

### The Implementation

File:

kernel/hypervisor/guest_memory.zig

The real Hyper-Zig implementation belongs here.

This page is intentionally reserved for the source code of the module.

```zig
const uart = @import("../console/uart.zig");
const pmm = @import("../memory/pmm.zig");
const vm_model = @import("vm.zig");

pub const backing_name = "pmm-bitmap-v0";
pub const default_page_count: usize = 2;
pub const max_guest_pages: usize = 8;

pub const State = enum {
    not_configured,
    configured,
};

pub const Error = enum {
    none,
    already_configured,
    not_configured,
    invalid_page_count,
    pmm_allocation_failed,
    pmm_free_failed,
    double_free,
    out_of_bounds,
    size_overflow,
};

pub const AccessResult = enum {
    ok,
    rejected,
};

pub const ConfigureResult = enum {
    ok,
    rejected,
};

pub const FreeResult = enum {
    ok,
    rejected,
};

pub const GuestMemory = struct {
    owner_vm_id: vm_model.VmId,
    state: State,
    backing: []const u8,
    base: usize,
    page_count: usize,
    size_bytes: usize,
    pages: [max_guest_pages]usize,
    alloc_count: usize,
    free_count: usize,
    reset_count: usize,
    failed_allocation_count: usize,
    invalid_free_count: usize,
    double_free_count: usize,
    overflow_reject_count: usize,
    bounds_reject_count: usize,
    last_error: Error,
};

var boot_guest_memory: GuestMemory = undefined;
var initialized: bool = false;

pub fn init(owner_vm_id: vm_model.VmId) void {
    boot_guest_memory = emptyObject(owner_vm_id, 0);
    initialized = true;
    vm_model.setGuestMemoryConfigured(false);
}

pub fn object() *const GuestMemory {
    return mutableObject();
}

fn mutableObject() *GuestMemory {
    if (!initialized) init(vm_model.object().id);
    return &boot_guest_memory;
}

fn emptyObject(owner_vm_id: vm_model.VmId, reset_count: usize) GuestMemory {
    return .{
        .owner_vm_id = owner_vm_id,
        .state = .not_configured,
        .backing = backing_name,
        .base = 0,
        .page_count = 0,
        .size_bytes = 0,
        .pages = [_]usize{0} ** max_guest_pages,
        .alloc_count = 0,
        .free_count = 0,
        .reset_count = reset_count,
        .failed_allocation_count = 0,
        .invalid_free_count = 0,
        .double_free_count = 0,
        .overflow_reject_count = 0,
        .bounds_reject_count = 0,
        .last_error = .none,
    };
}

pub fn configureDefault() ConfigureResult {
    return configure(vm_model.object().id, default_page_count);
}

pub fn configure(owner_vm_id: vm_model.VmId, requested_pages: usize) ConfigureResult {
    const gm = mutableObject();
    gm.owner_vm_id = owner_vm_id;

    if (gm.state == .configured) {
        gm.failed_allocation_count += 1;
        gm.last_error = .already_configured;
        return .rejected;
    }
    if (requested_pages == 0 or requested_pages > max_guest_pages) {
        gm.failed_allocation_count += 1;
        gm.overflow_reject_count += 1;
        gm.last_error = .invalid_page_count;
        return .rejected;
    }
    const size = checkedByteSize(requested_pages) orelse {
        gm.failed_allocation_count += 1;
        gm.overflow_reject_count += 1;
        gm.last_error = .size_overflow;
        return .rejected;
    };

    var allocated: usize = 0;
    while (allocated < requested_pages) : (allocated += 1) {
        const page = pmm.allocPage() orelse {
            rollbackAllocated(gm, allocated);
            gm.failed_allocation_count += 1;
            gm.last_error = .pmm_allocation_failed;
            vm_model.setGuestMemoryConfigured(false);
            return .rejected;
        };
        gm.pages[allocated] = page;
    }

    gm.state = .configured;
    gm.base = gm.pages[0];
    gm.page_count = requested_pages;
    gm.size_bytes = size;
    gm.alloc_count += 1;
    gm.last_error = .none;
    vm_model.setGuestMemoryConfigured(true);
    return .ok;
}

pub fn free() FreeResult {
    const gm = mutableObject();
    if (gm.state != .configured) {
        gm.double_free_count += 1;
        gm.invalid_free_count += 1;
        gm.last_error = .double_free;
        vm_model.setGuestMemoryConfigured(false);
        return .rejected;
    }

    var i: usize = 0;
    var failed = false;
    while (i < gm.page_count) : (i += 1) {
        if (gm.pages[i] == 0 or !pmm.freePage(gm.pages[i])) {
            failed = true;
            gm.invalid_free_count += 1;
            gm.last_error = .pmm_free_failed;
        }
        gm.pages[i] = 0;
    }

    gm.state = .not_configured;
    gm.base = 0;
    gm.page_count = 0;
    gm.size_bytes = 0;
    gm.free_count += 1;
    vm_model.setGuestMemoryConfigured(false);
    if (failed) return .rejected;
    gm.last_error = .none;
    return .ok;
}

pub fn reset() void {
    const gm = mutableObject();
    const owner = gm.owner_vm_id;
    var next_reset = gm.reset_count + 1;
    if (gm.state == .configured) {
        _ = free();
        next_reset = mutableObject().reset_count + 1;
    }
    boot_guest_memory = emptyObject(owner, next_reset);
    initialized = true;
    vm_model.setGuestMemoryConfigured(false);
}

pub fn validateAccess(offset: usize, length: usize) AccessResult {
    const gm = mutableObject();
    if (gm.state != .configured) {
        gm.bounds_reject_count += 1;
        gm.last_error = .not_configured;
        return .rejected;
    }
    const end = checkedAdd(offset, length) orelse {
        gm.bounds_reject_count += 1;
        gm.overflow_reject_count += 1;
        gm.last_error = .size_overflow;
        return .rejected;
    };
    if (length == 0 or offset >= gm.size_bytes or end > gm.size_bytes) {
        gm.bounds_reject_count += 1;
        gm.last_error = .out_of_bounds;
        return .rejected;
    }
    gm.last_error = .none;
    return .ok;
}


pub fn pageAtIndex(index: usize) ?usize {
    const gm = mutableObject();
    if (gm.state != .configured or index >= gm.page_count) {
        gm.bounds_reject_count += 1;
        gm.last_error = .out_of_bounds;
        return null;
    }
    const page = gm.pages[index];
    if (page == 0) {
        gm.bounds_reject_count += 1;
        gm.last_error = .out_of_bounds;
        return null;
    }
    gm.last_error = .none;
    return page;
}

pub fn printState() void {
    printImplementedMarker();
    printFields();
    printNonClaims();
}

pub fn printAllocCommand() void {
    const result = configureDefault();
    uart.write("hv: guest_memory.alloc_result=");
    uart.write(resultName(result));
    uart.write("\r\n");
    printFields();
    printNonClaims();
}

pub fn printFreeCommand() void {
    const result = free();
    uart.write("hv: guest_memory.free_result=");
    uart.write(freeResultName(result));
    uart.write("\r\n");
    printFields();
    printNonClaims();
}

pub fn printResetCommand() void {
    reset();
    uart.write("hv: guest_memory.reset_result=ok\r\n");
    printFields();
    printNonClaims();
}

pub fn printBoundsTest() void {
    if (mutableObject().state != .configured) _ = configureDefault();
    const gm_before = object();
    const offset = gm_before.size_bytes;
    const result = validateAccess(offset, 1);
    uart.write("hv: guest_memory.bounds_test=");
    uart.write(if (result == .rejected) "rejected" else "failed-to-reject");
    uart.write("\r\n");
    uart.write("hv: guest_memory.bounds_test_offset=");
    uart.writeDec(offset);
    uart.write("\r\n");
    printFields();
    printNonClaims();
}

pub fn printDoubleFreeTest() void {
    if (mutableObject().state != .configured) _ = configureDefault();
    const first = free();
    const second = free();
    uart.write("hv: guest_memory.double_free_test=");
    uart.write(if (first == .ok and second == .rejected) "rejected" else "failed-to-reject");
    uart.write("\r\n");
    uart.write("hv: guest_memory.double_free_first=");
    uart.write(freeResultName(first));
    uart.write("\r\n");
    uart.write("hv: guest_memory.double_free_second=");
    uart.write(freeResultName(second));
    uart.write("\r\n");
    printFields();
    printNonClaims();
}

pub fn printOverflowTest() void {
    const result = configure(vm_model.object().id, max_guest_pages + 1);
    uart.write("hv: guest_memory.overflow_test=");
    uart.write(if (result == .rejected) "rejected" else "failed-to-reject");
    uart.write("\r\n");
    uart.write("hv: guest_memory.overflow_requested_pages=");
    uart.writeDec(max_guest_pages + 1);
    uart.write("\r\n");
    printFields();
    printNonClaims();
}

pub fn printImplementedMarker() void {
    uart.write("hv: guest_memory=implemented\r\n");
}

fn printFields() void {
    const gm = object();
    uart.write("hv: guest_memory.owner_vm_id=");
    uart.writeDec(gm.owner_vm_id);
    uart.write("\r\n");
    uart.write("hv: guest_memory.state=");
    uart.write(stateName(gm.state));
    uart.write("\r\n");
    uart.write("hv: guest_memory.backing=");
    uart.write(gm.backing);
    uart.write("\r\n");
    uart.write("hv: guest_memory.base=");
    uart.writeHex(gm.base);
    uart.write("\r\n");
    uart.write("hv: guest_memory.page_count=");
    uart.writeDec(gm.page_count);
    uart.write("\r\n");
    uart.write("hv: guest_memory.size_bytes=");
    uart.writeDec(gm.size_bytes);
    uart.write("\r\n");
    uart.write("hv: guest_memory.alloc_count=");
    uart.writeDec(gm.alloc_count);
    uart.write("\r\n");
    uart.write("hv: guest_memory.free_count=");
    uart.writeDec(gm.free_count);
    uart.write("\r\n");
    uart.write("hv: guest_memory.reset_count=");
    uart.writeDec(gm.reset_count);
    uart.write("\r\n");
    uart.write("hv: guest_memory.failed_allocation_count=");
    uart.writeDec(gm.failed_allocation_count);
    uart.write("\r\n");
    uart.write("hv: guest_memory.invalid_free_count=");
    uart.writeDec(gm.invalid_free_count);
    uart.write("\r\n");
    uart.write("hv: guest_memory.double_free_count=");
    uart.writeDec(gm.double_free_count);
    uart.write("\r\n");
    uart.write("hv: guest_memory.overflow_reject_count=");
    uart.writeDec(gm.overflow_reject_count);
    uart.write("\r\n");
    uart.write("hv: guest_memory.bounds_reject_count=");
    uart.writeDec(gm.bounds_reject_count);
    uart.write("\r\n");
    uart.write("hv: guest_memory.last_error=");
    uart.write(errorName(gm.last_error));
    uart.write("\r\n");
}

fn rollbackAllocated(gm: *GuestMemory, count: usize) void {
    var i: usize = 0;
    while (i < count) : (i += 1) {
        if (gm.pages[i] != 0) _ = pmm.freePage(gm.pages[i]);
        gm.pages[i] = 0;
    }
    gm.state = .not_configured;
    gm.base = 0;
    gm.page_count = 0;
    gm.size_bytes = 0;
}

fn checkedByteSize(page_count: usize) ?usize {
    return checkedMul(page_count, pmm.page_size);
}

fn checkedMul(a: usize, b: usize) ?usize {
    if (a != 0 and b > (@as(usize, ~@as(usize, 0)) / a)) return null;
    return a * b;
}

fn checkedAdd(a: usize, b: usize) ?usize {
    if (b > (@as(usize, ~@as(usize, 0)) - a)) return null;
    return a + b;
}

fn stateName(state: State) []const u8 {
    return switch (state) {
        .not_configured => "not-configured",
        .configured => "configured",
    };
}

fn resultName(result: ConfigureResult) []const u8 {
    return switch (result) {
        .ok => "ok",
        .rejected => "rejected",
    };
}

fn freeResultName(result: FreeResult) []const u8 {
    return switch (result) {
        .ok => "ok",
        .rejected => "rejected",
    };
}

fn errorName(err: Error) []const u8 {
    return switch (err) {
        .none => "none",
        .already_configured => "already-configured",
        .not_configured => "not-configured",
        .invalid_page_count => "invalid-page-count",
        .pmm_allocation_failed => "pmm-allocation-failed",
        .pmm_free_failed => "pmm-free-failed",
        .double_free => "double-free",
        .out_of_bounds => "out-of-bounds",
        .size_overflow => "size-overflow",
    };
}

fn printNonClaims() void {
    uart.write("hv: guest_entry=implemented\r\n");
    uart.write("hv: guest_execution=not-supported-yet\r\n");
    uart.write("hv: linux_guest=not-supported-yet\r\n");
    uart.write("hv: second_stage_translation=MISSING\r\n");
}
```

### Things To Notice

1. Guest Memory belongs to a VM.

2. Memory starts unconfigured.

3. Memory allocation can fail.

4. Memory freeing can fail.

5. Bounds checks exist.

6. Overflow checks exist.

7. Rollback exists.

8. Diagnostic counters exist.

10. Every major subsystem has observable state.

11. Guest Memory updates VM state when configuration changes.

12. Invalid operations are rejected instead of silently accepted.

13. The module records failures instead of hiding them.
```
Section: 4C
Type: Exercise
```


# Guest Memory

### The Exercise

In HV03 you built a vCPU lifecycle.

Now you will build a Guest Memory object.

The goal is not to build Linux.

The goal is not to build a real allocator.

The goal is to model ownership and memory management.

### Concepts Required

- Structures
- Enumerations
- Arrays
- State
- Ownership
- Validation
- Counters

### Questions

1.

Why does Guest Memory need an owner_vm_id?

What could go wrong if memory had no owner?

2.

Why does memory begin as:

```text
not-configured
```

instead of:

```text
configured
```

3.

Create a function:

```c
int configure_memory(
    unsigned int page_count
);
```

Requirements:

- Reject page_count = 0
- Reject page_count > 8
- Accept valid values

4.

Create a function:

```c
int free_memory(void);
```

Requirements:

- Reject double free
- Return memory to not-configured

5.

Create a function:

```c
int validate_access(
    unsigned int offset,
    unsigned int length
);
```

Requirements:

- Reject out-of-bounds access
- Reject zero-length access

6.

Add counters:

- alloc_count
- free_count
- invalid_free_count
- bounds_reject_count

When should each counter increase?

7.

What is rollback?

Suppose four pages are requested.

The first three succeed.

The fourth fails.

What should happen to the first three?

Why?

### Challenge Question

Which is more dangerous?

A memory allocation that fails safely.

or

A memory allocation that partially succeeds and leaves resources behind.

Explain why.

### Practical Challenge

Draw the lifecycle of Guest Memory.

Start with:

```text
not-configured
```

Then show:

```text
configure
↓
configured
↓
free
↓
not-configured
```

Now add every failure path.

Which operations should be rejected?

Why?

```
Section: 4D
Type: Instructor Notes
```

# Guest Memory

### Instructor Notes

### Audience

Students should have completed:

- HV01 VM Object
- HV02 Capability Detection
- HV03 vCPU Lifecycle

### Learning Objective

Students should understand that memory is a managed resource.

The key lesson is not allocation.

The key lesson is ownership and failure handling.

### Key Concepts

- Ownership
- Allocation
- Freeing
- Validation
- Bounds Checking
- Overflow Protection
- Rollback
- Resource Management

### Common Misconceptions

Misconception:

Memory is just storage.

Correction:

Memory is a resource that must be managed.

Misconception:

Allocation is the hard part.

Correction:

Cleanup is often harder than allocation.

Misconception:

If allocation fails, just return an error.

Correction:

Partially allocated resources must be cleaned up.

Misconception:

Bounds checking is only a security feature.

Correction:

Bounds checking is also a correctness feature.

A hypervisor must know where memory begins and ends.

### Discussion Questions

Ask students:

Who owns guest memory?

Ask students:

Why does memory start unconfigured?

Ask students:

Why is double-free considered a bug?

Ask students:

Why are bounds checks important?

Ask students:

Why is rollback necessary?

### Expected Outcomes

Students should be able to explain:

- What guest memory is
- Why ownership exists
- Why bounds checks exist
- Why double-free is rejected
- Why rollback exists
- Why allocation failure must be handled carefully

### Connection To Future Modules

HV04 creates memory.

HV05 will describe how the guest sees that memory.

Memory comes first.

Address spaces come second.

That dependency chain is fundamental to virtualization.

Later modules will use Guest Memory to:

- load guest images
- prepare guest entry
- build address spaces
- construct stage-two mappings
- eventually support guest execution

### Instructor Summary

The VM now has a CPU.

The VM now has memory.

Hyper-Zig is beginning to resemble a machine.

But every new resource introduces new failure modes.

HV04 teaches students how to manage those failures safely.

Memory is the first major resource owned by the VM.

Future modules will build on top of this foundation.
