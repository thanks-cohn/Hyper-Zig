# HV05

## Guest Images

```text
Section: 5A
Module: Guest Images
Type: Concept
Source: guest_image.zig
```

### In Plain English

In HV04, the virtual machine received memory.

That was important.

A VM without memory cannot hold anything.

But memory by itself is not enough.

An empty hard drive is still empty.

An empty notebook is still blank.

An empty VM is still empty.

The next question becomes:

```text
What are we putting into memory?
```

The answer is:

```text
A Guest Image.
```

A Guest Image is simply data that the hypervisor intends to load into a virtual machine.

Today that image is not Linux.

Today that image is not BusyBox.

Today that image is not Alpine.

At this stage, Hyper-Zig is learning how to describe an image.

Before we can execute a guest, we must know:

* where the image starts
* how large it is
* whether it has been loaded
* whether it belongs to a VM
* whether it passed validation

The Guest Image module exists to answer those questions.

A useful comparison is a shipping container.

The VM is the ship.

Guest Memory is the cargo hold.

The Guest Image is the cargo.

Before the cargo can be moved, inspected, or delivered, the system must know what it is carrying.

That is the purpose of HV05.

We are not running the image.

We are describing the image.

A careful hypervisor always knows what it is about to load.

### Key Idea

Guest execution begins with Guest Images.

Before a VM can run code, the hypervisor must know what code it intends to run.

---

```text
Section: 5B
Module: Guest Images
Type: Implementation
Source: guest_image.zig
```

# Page-5B

## The Real Hyper-Zig Module

File:

```text
kernel/hypervisor/guest_image.zig
```

The complete Hyper-Zig implementation belongs below.

```zig
const uart = @import("../console/uart.zig");
const vm_model = @import("vm.zig");
const guest_memory = @import("guest_memory.zig");
const guest_address_space = @import("guest_address_space.zig");

pub const tiny_flat_v0_name = "tiny-flat-v0";
pub const tiny_load_base: usize = 0;
pub const tiny_entry_point: usize = 0;

const tiny_flat_v0_payload = [_]u8{
    0x13, 0x00, 0x00, 0x00, // addi x0, x0, 0 (nop)
    0x13, 0x00, 0x00, 0x00, // addi x0, x0, 0 (nop)
    0x13, 0x00, 0x00, 0x00, // addi x0, x0, 0 (nop)
    0x13, 0x00, 0x00, 0x00, // addi x0, x0, 0 (nop)
    0x93, 0x00, 0x10, 0x00, // addi x1, x0, 1
    0x13, 0x81, 0x10, 0x00, // addi x2, x1, 1
    0x93, 0x81, 0x11, 0x00, // addi x3, x3, 1
    0x6f, 0x00, 0x00, 0x00, // jal x0, 0 (self-loop if ever entered)
};

pub const GuestImageState = enum {
    not_loaded,
    loaded,
};

pub const GuestImageFormat = enum {
    none,
    tiny_flat_v0,
};

pub const GuestImageError = enum {
    none,
    guest_memory_unavailable,
    address_space_unavailable,
    unsupported_format,
    invalid_image,
    out_of_bounds,
    write_mismatch,
    read_mismatch,
    checksum_mismatch,
    byte_count_mismatch,
    size_overflow,
    not_loaded,
};

pub const GuestImageEntryPoint = struct {
    gpa: usize,
};

pub const GuestImageLoadResult = struct {
    result: CommandResult,
    format: GuestImageFormat,
    guest_load_base: usize,
    entry_point: GuestImageEntryPoint,
    image_size_bytes: usize,
    loaded_byte_count: usize,
    checksum: usize,
    image_error: GuestImageError,
};

pub const GuestImageVerifyResult = struct {
    result: CommandResult,
    format: GuestImageFormat,
    guest_load_base: usize,
    entry_point: GuestImageEntryPoint,
    expected_byte_count: usize,
    verified_byte_count: usize,
    expected_checksum: usize,
    actual_checksum: usize,
    image_error: GuestImageError,
};

pub const GuestImage = struct {
    owner_vm_id: vm_model.VmId,
    state: GuestImageState,
    format: GuestImageFormat,
    guest_load_base: usize,
    entry_point: GuestImageEntryPoint,
    image_size_bytes: usize,
    loaded_byte_count: usize,
    checksum: usize,
    load_count: usize,
    verify_count: usize,
    failed_load_count: usize,
    failed_verify_count: usize,
    bounds_reject_count: usize,
    last_error: GuestImageError,
};

pub const CommandResult = enum {
    ok,
    rejected,
};

var boot_guest_image: GuestImage = undefined;
var initialized: bool = false;

pub fn init(owner_vm_id: vm_model.VmId) void {
    boot_guest_image = emptyObject(owner_vm_id);
    initialized = true;
}

pub fn object() *const GuestImage {
    return mutableObject();
}

fn mutableObject() *GuestImage {
    if (!initialized) init(vm_model.object().id);
    return &boot_guest_image;
}

fn emptyObject(owner_vm_id: vm_model.VmId) GuestImage {
    return .{
        .owner_vm_id = owner_vm_id,
        .state = .not_loaded,
        .format = .tiny_flat_v0,
        .guest_load_base = tiny_load_base,
        .entry_point = .{ .gpa = tiny_entry_point },
        .image_size_bytes = 0,
        .loaded_byte_count = 0,
        .checksum = 0,
        .load_count = 0,
        .verify_count = 0,
        .failed_load_count = 0,
        .failed_verify_count = 0,
        .bounds_reject_count = 0,
        .last_error = .none,
    };
}

pub fn reset() void {
    const owner = mutableObject().owner_vm_id;
    boot_guest_image = emptyObject(owner);
    initialized = true;
}

pub fn loadTiny() GuestImageLoadResult {
    return loadStatic(.tiny_flat_v0, tiny_load_base, .{ .gpa = tiny_entry_point }, tiny_flat_v0_payload[0..]);
}

fn loadStatic(format: GuestImageFormat, guest_load_base: usize, entry_point: GuestImageEntryPoint, payload: []const u8) GuestImageLoadResult {
    const image = mutableObject();
    image.owner_vm_id = vm_model.object().id;
    image.format = format;
    image.guest_load_base = guest_load_base;
    image.entry_point = entry_point;
    image.image_size_bytes = payload.len;
    image.loaded_byte_count = 0;
    image.checksum = 0;

    if (format != .tiny_flat_v0) return failLoad(.unsupported_format, format, guest_load_base, entry_point, payload.len, 0, 0);
    if (payload.len == 0) return failLoad(.invalid_image, format, guest_load_base, entry_point, payload.len, 0, 0);
    if (ensureBackingReady() != .ok) return failLoad(image.last_error, format, guest_load_base, entry_point, payload.len, 0, 0);
    if (validateSpan(guest_load_base, payload.len) != .ok) return failLoad(.out_of_bounds, format, guest_load_base, entry_point, payload.len, 0, 0);

    var checksum = checksumSeed();
    var written: usize = 0;
    while (written < payload.len) : (written += 1) {
        const gpa = guest_load_base + written;
        if (writeByte(gpa, payload[written]) != .ok) {
            return failLoad(image.last_error, format, guest_load_base, entry_point, payload.len, written, checksumFinalize(checksum));
        }
        checksum = checksumByte(checksum, payload[written]);
    }

    const final_checksum = checksumFinalize(checksum);
    image.state = .loaded;
    image.format = format;
    image.guest_load_base = guest_load_base;
    image.entry_point = entry_point;
    image.image_size_bytes = payload.len;
    image.loaded_byte_count = written;
    image.checksum = final_checksum;
    image.load_count += 1;
    image.last_error = .none;

    return .{
        .result = .ok,
        .format = format,
        .guest_load_base = guest_load_base,
        .entry_point = entry_point,
        .image_size_bytes = payload.len,
        .loaded_byte_count = written,
        .checksum = final_checksum,
        .image_error = .none,
    };
}

pub fn verifyLoaded() GuestImageVerifyResult {
    const image = mutableObject();
    if (image.state != .loaded) return failVerify(.not_loaded, 0, 0);
    if (image.format != .tiny_flat_v0) return failVerify(.unsupported_format, 0, 0);
    if (image.image_size_bytes != tiny_flat_v0_payload.len or image.loaded_byte_count != tiny_flat_v0_payload.len) return failVerify(.byte_count_mismatch, 0, 0);
    if (ensureBackingReady() != .ok) return failVerify(image.last_error, 0, 0);
    if (validateSpan(image.guest_load_base, image.image_size_bytes) != .ok) return failVerify(.out_of_bounds, 0, 0);

    var checksum = checksumSeed();
    var verified: usize = 0;
    while (verified < image.image_size_bytes) : (verified += 1) {
        const byte = readByte(image.guest_load_base + verified) orelse return failVerify(image.last_error, verified, checksumFinalize(checksum));
        if (byte != tiny_flat_v0_payload[verified]) return failVerify(.read_mismatch, verified, checksumFinalize(checksum));
        checksum = checksumByte(checksum, byte);
    }

    const actual = checksumFinalize(checksum);
    if (actual != image.checksum) return failVerify(.checksum_mismatch, verified, actual);

    image.verify_count += 1;
    image.last_error = .none;
    return .{
        .result = .ok,
        .format = image.format,
        .guest_load_base = image.guest_load_base,
        .entry_point = image.entry_point,
        .expected_byte_count = image.loaded_byte_count,
        .verified_byte_count = verified,
        .expected_checksum = image.checksum,
        .actual_checksum = actual,
        .image_error = .none,
    };
}

pub fn boundsTest() CommandResult {
    const image = mutableObject();
    if (ensureBackingReady() != .ok) {
        image.failed_load_count += 1;
        return .rejected;
    }
    const as = guest_address_space.object();
    const oversized_len = as.guest_size_bytes + 1;
    const result = validateSpan(as.guest_base.value, oversized_len);
    if (result == .rejected) {
        image.failed_load_count += 1;
        image.bounds_reject_count += 1;
        image.last_error = .out_of_bounds;
        return .rejected;
    }
    image.last_error = .none;
    return .ok;
}

fn ensureBackingReady() CommandResult {
    const image = mutableObject();
    if (guest_memory.object().state != .configured) {
        if (guest_memory.configureDefault() != .ok) {
            image.last_error = .guest_memory_unavailable;
            return .rejected;
        }
    }
    if (guest_address_space.object().state != .configured) {
        if (guest_address_space.createFromGuestMemory() != .ok) {
            image.last_error = .address_space_unavailable;
            return .rejected;
        }
    }
    image.last_error = .none;
    return .ok;
}

fn validateSpan(guest_load_base: usize, len: usize) CommandResult {
    const image = mutableObject();
    if (len == 0) {
        image.last_error = .invalid_image;
        return .rejected;
    }
    const last_offset = len - 1;
    const last_gpa = checkedAdd(guest_load_base, last_offset) orelse {
        image.bounds_reject_count += 1;
        image.last_error = .size_overflow;
        return .rejected;
    };
    const first = guest_address_space.lookupByte(.{ .value = guest_load_base });
    if (first.result != .ok) {
        image.bounds_reject_count += 1;
        image.last_error = .out_of_bounds;
        return .rejected;
    }
    const last = guest_address_space.lookupByte(.{ .value = last_gpa });
    if (last.result != .ok) {
        image.bounds_reject_count += 1;
        image.last_error = .out_of_bounds;
        return .rejected;
    }
    if (guest_memory.validateAccess(guest_load_base, len) != .ok) {
        image.bounds_reject_count += 1;
        image.last_error = .out_of_bounds;
        return .rejected;
    }
    image.last_error = .none;
    return .ok;
}

fn writeByte(gpa: usize, byte: u8) CommandResult {
    const image = mutableObject();
    const lookup = guest_address_space.lookupByte(.{ .value = gpa });
    if (lookup.result != .ok) {
        image.last_error = .out_of_bounds;
        return .rejected;
    }
    const ptr: *volatile u8 = @ptrFromInt(lookup.host_address.value);
    ptr.* = byte;
    if (ptr.* != byte) {
        image.last_error = .write_mismatch;
        return .rejected;
    }
    image.last_error = .none;
    return .ok;
}

fn readByte(gpa: usize) ?u8 {
    const image = mutableObject();
    const lookup = guest_address_space.lookupByte(.{ .value = gpa });
    if (lookup.result != .ok) {
        image.last_error = .out_of_bounds;
        return null;
    }
    const ptr: *volatile u8 = @ptrFromInt(lookup.host_address.value);
    image.last_error = .none;
    return ptr.*;
}

fn failLoad(err: GuestImageError, format: GuestImageFormat, guest_load_base: usize, entry_point: GuestImageEntryPoint, image_size_bytes: usize, loaded_byte_count: usize, checksum: usize) GuestImageLoadResult {
    const image = mutableObject();
    image.state = .not_loaded;
    image.loaded_byte_count = loaded_byte_count;
    image.checksum = checksum;
    image.failed_load_count += 1;
    if (err == .out_of_bounds or err == .size_overflow) image.bounds_reject_count += 1;
    image.last_error = err;
    return .{
        .result = .rejected,
        .format = format,
        .guest_load_base = guest_load_base,
        .entry_point = entry_point,
        .image_size_bytes = image_size_bytes,
        .loaded_byte_count = loaded_byte_count,
        .checksum = checksum,
        .image_error = err,
    };
}

fn failVerify(err: GuestImageError, verified_byte_count: usize, actual_checksum: usize) GuestImageVerifyResult {
    const image = mutableObject();
    image.failed_verify_count += 1;
    if (err == .out_of_bounds or err == .size_overflow) image.bounds_reject_count += 1;
    image.last_error = err;
    return .{
        .result = .rejected,
        .format = image.format,
        .guest_load_base = image.guest_load_base,
        .entry_point = image.entry_point,
        .expected_byte_count = image.loaded_byte_count,
        .verified_byte_count = verified_byte_count,
        .expected_checksum = image.checksum,
        .actual_checksum = actual_checksum,
        .image_error = err,
    };
}

fn checksumSeed() usize {
    return 0xcbf29ce484222325;
}

fn checksumByte(current: usize, byte: u8) usize {
    return (current ^ @as(usize, byte)) *% 0x100000001b3;
}

fn checksumFinalize(current: usize) usize {
    return current ^ (current >> 32);
}

fn checkedAdd(a: usize, b: usize) ?usize {
    if (b > (@as(usize, ~@as(usize, 0)) - a)) return null;
    return a + b;
}

pub fn printState() void {
    printImplementedMarker();
    printFields();
    printNonClaims();
}

pub fn printLoadTinyCommand() void {
    const result = loadTiny();
    uart.write("hv: guest_image.load_result=");
    uart.write(resultName(result.result));
    uart.write("\r\n");
    uart.write("hv: guest_image.load_result.error=");
    uart.write(errorName(result.image_error));
    uart.write("\r\n");
    printFields();
    printNonClaims();
}

pub fn printVerifyCommand() void {
    const result = verifyLoaded();
    uart.write("hv: guest_image.verify_result=");
    uart.write(resultName(result.result));
    uart.write("\r\n");
    uart.write("hv: guest_image.verify_result.expected_byte_count=");
    uart.writeDec(result.expected_byte_count);
    uart.write("\r\n");
    uart.write("hv: guest_image.verify_result.verified_byte_count=");
    uart.writeDec(result.verified_byte_count);
    uart.write("\r\n");
    uart.write("hv: guest_image.verify_result.expected_checksum=");
    uart.writeHex(result.expected_checksum);
    uart.write("\r\n");
    uart.write("hv: guest_image.verify_result.actual_checksum=");
    uart.writeHex(result.actual_checksum);
    uart.write("\r\n");
    uart.write("hv: guest_image.verify_result.error=");
    uart.write(errorName(result.image_error));
    uart.write("\r\n");
    printFields();
    printNonClaims();
}

pub fn printResetCommand() void {
    reset();
    uart.write("hv: guest_image.reset_result=ok\r\n");
    printFields();
    printNonClaims();
}

pub fn printBoundsTestCommand() void {
    const result = boundsTest();
    uart.write("hv: guest_image.bounds_test=");
    uart.write(if (result == .rejected) "rejected" else "failed-to-reject");
    uart.write("\r\n");
    printFields();
    printNonClaims();
}

pub fn printImplementedMarker() void {
    uart.write("hv: guest_image=implemented\r\n");
}

fn printFields() void {
    const image = object();
    uart.write("hv: guest_image.owner_vm_id=");
    uart.writeDec(image.owner_vm_id);
    uart.write("\r\n");
    uart.write("hv: guest_image.state=");
    uart.write(stateName(image.state));
    uart.write("\r\n");
    uart.write("hv: guest_image.format=");
    uart.write(formatName(image.format));
    uart.write("\r\n");
    uart.write("hv: guest_image.guest_load_base=");
    uart.writeHex(image.guest_load_base);
    uart.write("\r\n");
    uart.write("hv: guest_image.entry_point=");
    uart.writeHex(image.entry_point.gpa);
    uart.write("\r\n");
    uart.write("hv: guest_image.image_size_bytes=");
    uart.writeDec(image.image_size_bytes);
    uart.write("\r\n");
    uart.write("hv: guest_image.loaded_byte_count=");
    uart.writeDec(image.loaded_byte_count);
    uart.write("\r\n");
    uart.write("hv: guest_image.checksum=");
    uart.writeHex(image.checksum);
    uart.write("\r\n");
    uart.write("hv: guest_image.load_count=");
    uart.writeDec(image.load_count);
    uart.write("\r\n");
    uart.write("hv: guest_image.verify_count=");
    uart.writeDec(image.verify_count);
    uart.write("\r\n");
    uart.write("hv: guest_image.failed_load_count=");
    uart.writeDec(image.failed_load_count);
    uart.write("\r\n");
    uart.write("hv: guest_image.failed_verify_count=");
    uart.writeDec(image.failed_verify_count);
    uart.write("\r\n");
    uart.write("hv: guest_image.bounds_reject_count=");
    uart.writeDec(image.bounds_reject_count);
    uart.write("\r\n");
    uart.write("hv: guest_image.last_error=");
    uart.write(errorName(image.last_error));
    uart.write("\r\n");
}

fn stateName(state: GuestImageState) []const u8 {
    return switch (state) {
        .not_loaded => "not-loaded",
        .loaded => "loaded",
    };
}

fn formatName(format: GuestImageFormat) []const u8 {
    return switch (format) {
        .none => "none",
        .tiny_flat_v0 => tiny_flat_v0_name,
    };
}

fn resultName(result: CommandResult) []const u8 {
    return switch (result) {
        .ok => "ok",
        .rejected => "rejected",
    };
}

fn errorName(err: GuestImageError) []const u8 {
    return switch (err) {
        .none => "none",
        .guest_memory_unavailable => "guest-memory-unavailable",
        .address_space_unavailable => "address-space-unavailable",
        .unsupported_format => "unsupported-format",
        .invalid_image => "invalid-image",
        .out_of_bounds => "out-of-bounds",
        .write_mismatch => "write-mismatch",
        .read_mismatch => "read-mismatch",
        .checksum_mismatch => "checksum-mismatch",
        .byte_count_mismatch => "byte-count-mismatch",
        .size_overflow => "size-overflow",
        .not_loaded => "not-loaded",
    };
}

fn printNonClaims() void {
    uart.write("hv: guest_execution=not-supported-yet\r\n");
    uart.write("hv: linux_guest=not-supported-yet\r\n");
    uart.write("hv: guest_entry=implemented\r\n");
    uart.write("hv: second_stage_translation=MISSING\r\n");
}
```

### Things To Notice

1. Guest Images belong to a VM.

2. Guest Images have ownership.

3. Guest Images have size.

4. Guest Images have load state.

5. Guest Images can be validated.

6. Guest Images can be rejected.

7. Guest Images do not execute themselves.

8. The hypervisor remains in control.

### What are the key structures

### What are the key functions?

If you can explain the difference between a Guest Image and Guest Memory, you understand the purpose of this module.

---

```text
Section: 5C
Module: Guest Images
Type: Exercise
Source: guest_image.zig
```

# Page-5C

## Build It Yourself

In HV04, you created Guest Memory.

Now create a Guest Image.

The goal is not to load Linux.

The goal is not to boot a guest.

The goal is to model how a hypervisor tracks an image.

### Concepts Required

* Structures
* Enumerations
* Ownership
* State
* Validation
* Diagnostic Output

### C Skeleton

```c
#include <stdio.h>
#include <stddef.h>

typedef unsigned int VmId;

typedef enum
{
    IMAGE_NOT_LOADED,
    IMAGE_LOADED
}
GuestImageState;

typedef struct
{
    VmId owner_vm_id;

    GuestImageState state;

    size_t image_size;

    unsigned long load_count;

    unsigned long validation_count;

    int valid;
}
GuestImage;

static GuestImage guest_image;

void guest_image_init(VmId owner_vm_id)
{
    /*
        TODO
    */
}

int guest_image_load(size_t image_size)
{
    /*
        TODO

        Reject invalid image sizes.

        Record successful loads.

        Update state.
    */

    return 0;
}

int guest_image_validate(void)
{
    /*
        TODO

        Validate image metadata.

        Record validation attempts.
    */

    return 0;
}

void guest_image_print(void)
{
    /*
        TODO
    */
}

int main(void)
{
    guest_image_init(0);

    /*
        TODO

        Load an image.

        Validate it.

        Print status.
    */

    return 0;
}
```

### Questions

1.

Why does a Guest Image belong to a VM?

2.

Why track image size?

3.

Why separate:

```text
loaded
```

from:

```text
valid
```

?

4.

Can an image be loaded but still be invalid?

Why?

5.

Why should validation be observable?

6.

What information would a hypervisor need before loading Linux?

### Challenge Question

Suppose a Guest Image claims to be:

```text
64 MB
```

but only:

```text
8 MB
```

actually exists.

Should the hypervisor trust the image?

Why?

### Completion Check

Before moving to HV06, make sure you can explain:

* what a Guest Image is
* why ownership matters
* why validation exists
* why load state exists
* why images must be inspected before execution

---

```text
Section: 5D
Module: Guest Images
Type: Instructor Notes
Source: guest_image.zig
```

# Page-5D

## Instructor Notes

### Audience

Students should have completed:

* HV01 VM Object
* HV02 Capability Detection
* HV03 vCPU Lifecycle
* HV04 Guest Memory

### Learning Objective

Students should understand the difference between:

```text
Memory
```

and

```text
Content placed into memory
```

Guest Memory stores data.

Guest Images describe the data that will be loaded.

This distinction becomes increasingly important as Hyper-Zig approaches guest execution.

### Key Concepts

* Ownership
* Image Metadata
* Validation
* Load State
* Diagnostic Reporting

### Common Misconceptions

Misconception:

```text
Memory and Images are the same thing.
```

Correction:

Memory stores data.

Images are data.

They are related, but not identical.

---

Misconception:

```text
Loaded means valid.
```

Correction:

An image can be loaded and still fail validation.

---

Misconception:

```text
If an image exists, it should run.
```

Correction:

Hypervisors must inspect and validate images before execution.

### Discussion Questions

Ask students:

```text
What is the difference between a box and the thing inside the box?
```

Relate this to:

```text
Guest Memory
vs
Guest Image
```

---

Ask students:

```text
Why should a hypervisor distrust external input?
```

### Expected Outcomes

Students should be able to explain:

* what a Guest Image is
* why images require validation
* why ownership exists
* why load state exists
* why execution comes later

### Connection To Future Modules

HV04 created memory.

HV05 creates something worth placing into memory.

HV06 will begin preparing that image for execution.

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
Execution
```

### Key Idea

A hypervisor should always know what it is about to run.

HV05 is the first step toward that goal.
