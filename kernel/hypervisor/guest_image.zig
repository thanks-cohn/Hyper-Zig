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
