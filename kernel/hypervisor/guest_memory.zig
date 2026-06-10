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
    uart.write("hv: guest_entry=MISSING\r\n");
    uart.write("hv: guest_execution=not-supported-yet\r\n");
    uart.write("hv: linux_guest=not-supported-yet\r\n");
    uart.write("hv: second_stage_translation=MISSING\r\n");
}
