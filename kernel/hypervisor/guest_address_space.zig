const uart = @import("../console/uart.zig");
const pmm = @import("../memory/pmm.zig");
const vm_model = @import("vm.zig");
const guest_memory = @import("guest_memory.zig");

pub const GuestPhysicalAddress = struct {
    value: usize,
};

pub const HostPhysicalAddress = struct {
    value: usize,
};

pub const State = enum {
    not_configured,
    configured,
};

pub const AddressSpaceError = enum {
    none,
    guest_memory_not_configured,
    invalid_guest_memory,
    already_configured,
    not_configured,
    out_of_bounds,
    misaligned,
    size_overflow,
};

pub const CommandResult = enum {
    ok,
    rejected,
};

pub const GuestRegion = struct {
    guest_base: GuestPhysicalAddress,
    guest_size_bytes: usize,
    host_base: HostPhysicalAddress,
    page_size: usize,
    page_count: usize,
};

pub const AddressLookupResult = struct {
    result: CommandResult,
    guest_address: GuestPhysicalAddress,
    host_address: HostPhysicalAddress,
    page_index: usize,
    lookup_error: AddressSpaceError,
};

pub const GuestAddressSpace = struct {
    owner_vm_id: vm_model.VmId,
    state: State,
    region_count: usize,
    page_size: usize,
    guest_base: GuestPhysicalAddress,
    guest_size_bytes: usize,
    host_base: HostPhysicalAddress,
    translated_page_count: usize,
    lookup_count: usize,
    successful_lookup_count: usize,
    failed_lookup_count: usize,
    bounds_reject_count: usize,
    alignment_reject_count: usize,
    last_error: AddressSpaceError,
    region: GuestRegion,
};

const guest_base_value: usize = 0;

var boot_address_space: GuestAddressSpace = undefined;
var initialized: bool = false;

pub fn init(owner_vm_id: vm_model.VmId) void {
    boot_address_space = emptyObject(owner_vm_id);
    initialized = true;
}

pub fn object() *const GuestAddressSpace {
    return mutableObject();
}

fn mutableObject() *GuestAddressSpace {
    if (!initialized) init(vm_model.object().id);
    return &boot_address_space;
}

fn emptyObject(owner_vm_id: vm_model.VmId) GuestAddressSpace {
    return .{
        .owner_vm_id = owner_vm_id,
        .state = .not_configured,
        .region_count = 0,
        .page_size = pmm.page_size,
        .guest_base = .{ .value = guest_base_value },
        .guest_size_bytes = 0,
        .host_base = .{ .value = 0 },
        .translated_page_count = 0,
        .lookup_count = 0,
        .successful_lookup_count = 0,
        .failed_lookup_count = 0,
        .bounds_reject_count = 0,
        .alignment_reject_count = 0,
        .last_error = .none,
        .region = .{
            .guest_base = .{ .value = guest_base_value },
            .guest_size_bytes = 0,
            .host_base = .{ .value = 0 },
            .page_size = pmm.page_size,
            .page_count = 0,
        },
    };
}

pub fn createFromGuestMemory() CommandResult {
    const as = mutableObject();
    if (as.state == .configured) {
        as.last_error = .already_configured;
        return .rejected;
    }

    const gm = guest_memory.object();
    if (gm.state != .configured) {
        as.last_error = .guest_memory_not_configured;
        return .rejected;
    }
    if (gm.page_count == 0 or gm.size_bytes == 0 or gm.base == 0) {
        as.last_error = .invalid_guest_memory;
        return .rejected;
    }

    const expected_size = checkedMul(gm.page_count, pmm.page_size) orelse {
        as.last_error = .size_overflow;
        return .rejected;
    };
    if (expected_size != gm.size_bytes) {
        as.last_error = .invalid_guest_memory;
        return .rejected;
    }

    as.owner_vm_id = gm.owner_vm_id;
    as.state = .configured;
    as.region_count = 1;
    as.page_size = pmm.page_size;
    as.guest_base = .{ .value = guest_base_value };
    as.guest_size_bytes = gm.size_bytes;
    as.host_base = .{ .value = gm.base };
    as.translated_page_count = gm.page_count;
    as.last_error = .none;
    as.region = .{
        .guest_base = .{ .value = guest_base_value },
        .guest_size_bytes = gm.size_bytes,
        .host_base = .{ .value = gm.base },
        .page_size = pmm.page_size,
        .page_count = gm.page_count,
    };
    return .ok;
}

pub fn ensureCreatedWithGuestMemory() CommandResult {
    const as = mutableObject();
    if (as.state == .configured) return .ok;
    if (guest_memory.object().state != .configured) {
        if (guest_memory.configureDefault() != .ok) {
            as.last_error = .guest_memory_not_configured;
            return .rejected;
        }
    }
    return createFromGuestMemory();
}

pub fn reset() void {
    const owner = mutableObject().owner_vm_id;
    boot_address_space = emptyObject(owner);
    initialized = true;
}

pub fn lookupPage(gpa: GuestPhysicalAddress) AddressLookupResult {
    return lookup(gpa, true);
}

pub fn lookupByte(gpa: GuestPhysicalAddress) AddressLookupResult {
    return lookup(gpa, false);
}

fn lookup(gpa: GuestPhysicalAddress, require_page_alignment: bool) AddressLookupResult {
    const as = mutableObject();
    as.lookup_count += 1;

    if (as.state != .configured) {
        as.failed_lookup_count += 1;
        as.last_error = .not_configured;
        return rejected(gpa, .not_configured);
    }

    if (require_page_alignment and (gpa.value % as.page_size) != 0) {
        as.failed_lookup_count += 1;
        as.alignment_reject_count += 1;
        as.last_error = .misaligned;
        return rejected(gpa, .misaligned);
    }

    if (!withinRegion(as, gpa.value)) {
        as.failed_lookup_count += 1;
        as.bounds_reject_count += 1;
        as.last_error = .out_of_bounds;
        return rejected(gpa, .out_of_bounds);
    }

    const offset = gpa.value - as.guest_base.value;
    const page_index = offset / as.page_size;
    const page_offset = offset % as.page_size;
    const host_page = guest_memory.pageAtIndex(page_index) orelse {
        as.failed_lookup_count += 1;
        as.last_error = .invalid_guest_memory;
        return rejected(gpa, .invalid_guest_memory);
    };
    const host_value = checkedAdd(host_page, page_offset) orelse {
        as.failed_lookup_count += 1;
        as.last_error = .size_overflow;
        return rejected(gpa, .size_overflow);
    };

    as.successful_lookup_count += 1;
    as.last_error = .none;
    return .{
        .result = .ok,
        .guest_address = gpa,
        .host_address = .{ .value = host_value },
        .page_index = page_index,
        .lookup_error = .none,
    };
}

fn withinRegion(as: *const GuestAddressSpace, gpa: usize) bool {
    const end = checkedAdd(as.guest_base.value, as.guest_size_bytes) orelse return false;
    return gpa >= as.guest_base.value and gpa < end;
}

fn rejected(gpa: GuestPhysicalAddress, err: AddressSpaceError) AddressLookupResult {
    return .{
        .result = .rejected,
        .guest_address = gpa,
        .host_address = .{ .value = 0 },
        .page_index = 0,
        .lookup_error = err,
    };
}

pub fn printState() void {
    printImplementedMarker();
    printFields();
    printNonClaims();
}

pub fn printCreateCommand() void {
    const result = ensureCreatedWithGuestMemory();
    uart.write("hv: address_space.create_result=");
    uart.write(resultName(result));
    uart.write("\r\n");
    printFields();
    printNonClaims();
}

pub fn printResetCommand() void {
    reset();
    uart.write("hv: address_space.reset_result=ok\r\n");
    printFields();
    printNonClaims();
}

pub fn printLookupZeroCommand() void {
    if (ensureCreatedWithGuestMemory() != .ok) {
        uart.write("hv: address_space.lookup_result=rejected\r\n");
        printFields();
        printNonClaims();
        return;
    }
    const result = lookupPage(.{ .value = 0 });
    printLookup("lookup_zero", result);
    printFields();
    printNonClaims();
}

pub fn printLookupPageCommand() void {
    if (ensureCreatedWithGuestMemory() != .ok) {
        uart.write("hv: address_space.lookup_result=rejected\r\n");
        printFields();
        printNonClaims();
        return;
    }
    const result = lookupPage(.{ .value = pmm.page_size });
    printLookup("lookup_page", result);
    printFields();
    printNonClaims();
}

pub fn printBoundsTestCommand() void {
    if (ensureCreatedWithGuestMemory() != .ok) {
        uart.write("hv: address_space.bounds_test=rejected\r\n");
        printFields();
        printNonClaims();
        return;
    }
    const as = object();
    const out_of_range = as.guest_base.value + as.guest_size_bytes;
    const result = lookupPage(.{ .value = out_of_range });
    uart.write("hv: address_space.bounds_test=");
    uart.write(if (result.result == .rejected and result.lookup_error == .out_of_bounds) "rejected" else "failed-to-reject");
    uart.write("\r\n");
    printLookup("bounds_lookup", result);
    printFields();
    printNonClaims();
}

pub fn printAlignmentTestCommand() void {
    if (ensureCreatedWithGuestMemory() != .ok) {
        uart.write("hv: address_space.alignment_test=rejected\r\n");
        printFields();
        printNonClaims();
        return;
    }
    const result = lookupPage(.{ .value = 1 });
    uart.write("hv: address_space.alignment_test=");
    uart.write(if (result.result == .rejected and result.lookup_error == .misaligned) "rejected" else "failed-to-reject");
    uart.write("\r\n");
    printLookup("alignment_lookup", result);
    printFields();
    printNonClaims();
}

pub fn printImplementedMarker() void {
    uart.write("hv: address_space=implemented\r\n");
}

fn printLookup(prefix: []const u8, result: AddressLookupResult) void {
    uart.write("hv: address_space.lookup_result=");
    uart.write(resultName(result.result));
    uart.write("\r\n");
    uart.write("hv: address_space.");
    uart.write(prefix);
    uart.write(".gpa=");
    uart.writeHex(result.guest_address.value);
    uart.write("\r\n");
    uart.write("hv: address_space.");
    uart.write(prefix);
    uart.write(".hpa=");
    uart.writeHex(result.host_address.value);
    uart.write("\r\n");
    uart.write("hv: address_space.");
    uart.write(prefix);
    uart.write(".page_index=");
    uart.writeDec(result.page_index);
    uart.write("\r\n");
    uart.write("hv: address_space.");
    uart.write(prefix);
    uart.write(".error=");
    uart.write(errorName(result.lookup_error));
    uart.write("\r\n");
}

fn printFields() void {
    const as = object();
    uart.write("hv: address_space.owner_vm_id=");
    uart.writeDec(as.owner_vm_id);
    uart.write("\r\n");
    uart.write("hv: address_space.state=");
    uart.write(stateName(as.state));
    uart.write("\r\n");
    uart.write("hv: address_space.region_count=");
    uart.writeDec(as.region_count);
    uart.write("\r\n");
    uart.write("hv: address_space.page_size=");
    uart.writeDec(as.page_size);
    uart.write("\r\n");
    uart.write("hv: address_space.guest_base=");
    uart.writeHex(as.guest_base.value);
    uart.write("\r\n");
    uart.write("hv: address_space.guest_size_bytes=");
    uart.writeDec(as.guest_size_bytes);
    uart.write("\r\n");
    uart.write("hv: address_space.host_base=");
    uart.writeHex(as.host_base.value);
    uart.write("\r\n");
    uart.write("hv: address_space.translated_page_count=");
    uart.writeDec(as.translated_page_count);
    uart.write("\r\n");
    uart.write("hv: address_space.lookup_count=");
    uart.writeDec(as.lookup_count);
    uart.write("\r\n");
    uart.write("hv: address_space.successful_lookup_count=");
    uart.writeDec(as.successful_lookup_count);
    uart.write("\r\n");
    uart.write("hv: address_space.failed_lookup_count=");
    uart.writeDec(as.failed_lookup_count);
    uart.write("\r\n");
    uart.write("hv: address_space.bounds_reject_count=");
    uart.writeDec(as.bounds_reject_count);
    uart.write("\r\n");
    uart.write("hv: address_space.alignment_reject_count=");
    uart.writeDec(as.alignment_reject_count);
    uart.write("\r\n");
    uart.write("hv: address_space.last_error=");
    uart.write(errorName(as.last_error));
    uart.write("\r\n");
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

fn resultName(result: CommandResult) []const u8 {
    return switch (result) {
        .ok => "ok",
        .rejected => "rejected",
    };
}

fn errorName(err: AddressSpaceError) []const u8 {
    return switch (err) {
        .none => "none",
        .guest_memory_not_configured => "guest-memory-not-configured",
        .invalid_guest_memory => "invalid-guest-memory",
        .already_configured => "already-configured",
        .not_configured => "not-configured",
        .out_of_bounds => "out-of-bounds",
        .misaligned => "misaligned",
        .size_overflow => "size-overflow",
    };
}

fn printNonClaims() void {
    uart.write("hv: guest_execution=not-supported-yet\r\n");
    uart.write("hv: linux_guest=not-supported-yet\r\n");
    uart.write("hv: second_stage_translation=MISSING\r\n");
    uart.write("hv: guest_entry=MISSING\r\n");
}
