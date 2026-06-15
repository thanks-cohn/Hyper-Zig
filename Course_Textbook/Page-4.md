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
````markdown
```text
Section: 4C
Module: Guest Memory
Type: Exercise
Source: guest_memory.zig
```

# Guest Memory

### The Exercise

In HV03, you built a vCPU lifecycle.

Now you will build a small Guest Memory model in C.

The goal is not to build Linux.

The goal is not to build a real allocator.

The goal is to rebuild the ideas from the Hyper-Zig module in a smaller form:

- ownership
- configuration state
- page count
- byte size
- allocation
- freeing
- invalid access rejection
- failure counters

A VM now has a CPU.

This exercise gives that VM memory.

Not magical memory.

Managed memory.

Memory with rules.

### Concepts Required

- `struct`
- `enum`
- global state
- function return values
- counters
- bounds checks
- basic failure handling

### C Skeleton

```c
#include <stdio.h>
#include <stddef.h>

#define PAGE_SIZE 4096
#define MAX_GUEST_PAGES 8

typedef unsigned int VmId;

typedef enum
{
    GUEST_MEMORY_NOT_CONFIGURED,
    GUEST_MEMORY_CONFIGURED
} GuestMemoryState;

typedef enum
{
    GUEST_MEMORY_ERROR_NONE,
    GUEST_MEMORY_ERROR_ALREADY_CONFIGURED,
    GUEST_MEMORY_ERROR_NOT_CONFIGURED,
    GUEST_MEMORY_ERROR_INVALID_PAGE_COUNT,
    GUEST_MEMORY_ERROR_DOUBLE_FREE,
    GUEST_MEMORY_ERROR_OUT_OF_BOUNDS
} GuestMemoryError;

typedef enum
{
    GUEST_MEMORY_OK,
    GUEST_MEMORY_REJECTED
} GuestMemoryResult;

typedef struct
{
    VmId owner_vm_id;

    GuestMemoryState state;

    size_t page_count;

    size_t size_bytes;

    unsigned long alloc_count;

    unsigned long free_count;

    unsigned long failed_allocation_count;

    unsigned long invalid_free_count;

    unsigned long bounds_reject_count;

    GuestMemoryError last_error;
} GuestMemory;

static GuestMemory guest_memory;

void guest_memory_init(VmId owner_vm_id)
{
    guest_memory.owner_vm_id = owner_vm_id;
    guest_memory.state = GUEST_MEMORY_NOT_CONFIGURED;
    guest_memory.page_count = 0;
    guest_memory.size_bytes = 0;

    guest_memory.alloc_count = 0;
    guest_memory.free_count = 0;
    guest_memory.failed_allocation_count = 0;
    guest_memory.invalid_free_count = 0;
    guest_memory.bounds_reject_count = 0;

    guest_memory.last_error = GUEST_MEMORY_ERROR_NONE;
}

GuestMemoryResult guest_memory_configure(size_t requested_pages)
{
    /*
        TODO:

        Reject this operation if memory is already configured.

        Reject this operation if requested_pages is 0.

        Reject this operation if requested_pages is greater than
        MAX_GUEST_PAGES.

        If accepted:

        - set state to GUEST_MEMORY_CONFIGURED
        - set page_count
        - set size_bytes
        - increment alloc_count
        - clear last_error
    */

    return GUEST_MEMORY_REJECTED;
}

GuestMemoryResult guest_memory_free(void)
{
    /*
        TODO:

        Reject this operation if memory is not configured.

        If rejected:

        - increment invalid_free_count
        - set last_error to GUEST_MEMORY_ERROR_DOUBLE_FREE

        If accepted:

        - set state to GUEST_MEMORY_NOT_CONFIGURED
        - clear page_count
        - clear size_bytes
        - increment free_count
        - clear last_error
    */

    return GUEST_MEMORY_REJECTED;
}

GuestMemoryResult guest_memory_validate_access(
    size_t offset,
    size_t length)
{
    /*
        TODO:

        Reject this operation if memory is not configured.

        Reject this operation if length is 0.

        Reject this operation if offset is outside the configured memory.

        Reject this operation if offset + length goes past size_bytes.

        If rejected:

        - increment bounds_reject_count
        - set last_error to the appropriate error

        If accepted:

        - clear last_error
    */

    return GUEST_MEMORY_REJECTED;
}

const char *guest_memory_state_name(GuestMemoryState state)
{
    switch (state)
    {
        case GUEST_MEMORY_NOT_CONFIGURED:
            return "not-configured";

        case GUEST_MEMORY_CONFIGURED:
            return "configured";
    }

    return "unknown";
}

const char *guest_memory_error_name(GuestMemoryError error)
{
    switch (error)
    {
        case GUEST_MEMORY_ERROR_NONE:
            return "none";

        case GUEST_MEMORY_ERROR_ALREADY_CONFIGURED:
            return "already-configured";

        case GUEST_MEMORY_ERROR_NOT_CONFIGURED:
            return "not-configured";

        case GUEST_MEMORY_ERROR_INVALID_PAGE_COUNT:
            return "invalid-page-count";

        case GUEST_MEMORY_ERROR_DOUBLE_FREE:
            return "double-free";

        case GUEST_MEMORY_ERROR_OUT_OF_BOUNDS:
            return "out-of-bounds";
    }

    return "unknown";
}

void guest_memory_print(void)
{
    printf("guest_memory.owner_vm_id=%u\n", guest_memory.owner_vm_id);
    printf("guest_memory.state=%s\n",
        guest_memory_state_name(guest_memory.state));
    printf("guest_memory.page_count=%zu\n", guest_memory.page_count);
    printf("guest_memory.size_bytes=%zu\n", guest_memory.size_bytes);
    printf("guest_memory.alloc_count=%lu\n", guest_memory.alloc_count);
    printf("guest_memory.free_count=%lu\n", guest_memory.free_count);
    printf("guest_memory.failed_allocation_count=%lu\n",
        guest_memory.failed_allocation_count);
    printf("guest_memory.invalid_free_count=%lu\n",
        guest_memory.invalid_free_count);
    printf("guest_memory.bounds_reject_count=%lu\n",
        guest_memory.bounds_reject_count);
    printf("guest_memory.last_error=%s\n",
        guest_memory_error_name(guest_memory.last_error));
}

int main(void)
{
    guest_memory_init(0);

    /*
        TODO:

        1. Configure guest memory with 2 pages.

        2. Validate an access inside the memory.

        3. Validate an access outside the memory.

        4. Free the memory.

        5. Try to free it again.

        6. Print the final state.
    */

    return 0;
}

````

### Required Behavior

Your C version should reject:

- configuring memory twice
- configuring zero pages
- configuring more than `MAX_GUEST_PAGES`
- freeing memory before it is configured
- freeing memory twice
- accessing memory before it is configured
- zero-length accesses
- accesses beyond `size_bytes`

Your C version should accept:

- a valid page count
- a valid access inside memory
- a valid free after configuration

### Questions

1.

Why does Guest Memory need an `owner_vm_id`?

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

Why is `page_count = 0` rejected?

What does zero pages mean for a guest?

4.

Why does the model track both:

```text
page_count
```

and

```text
size_bytes
```

?

5.

Why should a second call to `guest_memory_free()` be rejected?

6.

Why should a zero-length access be rejected?

7.

Why should invalid operations update counters instead of silently failing?

8.

What does this exercise teach that a plain array would not teach?

### Challenge Question

Suppose the real Hyper-Zig module asks the physical memory manager for four pages.

The first three allocations succeed.

The fourth allocation fails.

What should happen to the first three pages?

Why?

### Completion Check

Before moving to HV05, make sure you can explain:

- what Guest Memory is
- why memory belongs to a VM
- why memory starts unconfigured
- why page limits exist
- why invalid accesses are rejected
- why double-free is rejected
- why failure counters are useful
```
````



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
