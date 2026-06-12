const uart = @import("../console/uart.zig");
const pmm = @import("../memory/pmm.zig");
const vm_model = @import("vm.zig");
const guest_memory = @import("guest_memory.zig");
const guest_address_space = @import("guest_address_space.zig");

pub const SecondStageState = enum {
    inactive,
    metadata_ready,
    rejected,
    reset,
};

pub const SecondStageMode = enum {
    metadata_only,
    inactive_no_h_extension,
    inactive_no_hgatp,
};

pub const SecondStageError = enum {
    none,
    guest_memory_not_configured,
    address_space_not_configured,
    owner_mismatch,
    empty_mapping,
    page_size_mismatch,
    guest_base_mismatch,
    guest_size_mismatch,
    guest_page_count_mismatch,
    host_base_mismatch,
    host_size_mismatch,
    out_of_bounds,
    misaligned,
    execute_not_permitted,
    mapping_inactive,
    metadata_not_ready,
    active_mapping_forbidden,
    arithmetic_overflow,
};

pub const SecondStageMapResult = enum {
    ok,
    rejected,
};

pub const SecondStageLookupResult = struct {
    result: SecondStageMapResult,
    guest_address: usize,
    host_address: usize,
    page_index: usize,
    page_offset: usize,
    stage_error: SecondStageError,
};

pub const SecondStageValidateResult = struct {
    result: SecondStageMapResult,
    stage_error: SecondStageError,
    checked_page_count: usize,
};

pub const SecondStageResetResult = struct {
    result: SecondStageMapResult,
    state: SecondStageState,
};

pub const SecondStageStats = struct {
    configure_count: usize,
    lookup_count: usize,
    validate_count: usize,
    reset_count: usize,
    bounds_reject_count: usize,
    alignment_reject_count: usize,
    permission_reject_count: usize,
    failed_configure_count: usize,
    failed_lookup_count: usize,
    last_error: SecondStageError,
};

pub const SecondStageMapping = struct {
    owner_vm_id: vm_model.VmId,
    guest_base: usize,
    guest_size_bytes: usize,
    guest_page_count: usize,
    host_base: usize,
    host_size_bytes: usize,
    page_size: usize,
    flags_read: bool,
    flags_write: bool,
    flags_execute: bool,
    active: bool,
    validated: bool,
};

pub const SecondStage = struct {
    owner_vm_id: vm_model.VmId,
    state: SecondStageState,
    mode: SecondStageMode,
    mapping: SecondStageMapping,
    stats: SecondStageStats,
};

var boot_second_stage: SecondStage = undefined;
var initialized: bool = false;

pub fn init(owner_vm_id: vm_model.VmId) void {
    boot_second_stage = emptyObject(owner_vm_id, emptyStats());
    initialized = true;
}

pub fn object() *const SecondStage {
    return mutableObject();
}

fn mutableObject() *SecondStage {
    if (!initialized) init(vm_model.object().id);
    return &boot_second_stage;
}

fn emptyObject(owner_vm_id: vm_model.VmId, stats: SecondStageStats) SecondStage {
    return .{
        .owner_vm_id = owner_vm_id,
        .state = .inactive,
        .mode = .metadata_only,
        .mapping = emptyMapping(owner_vm_id),
        .stats = stats,
    };
}

fn emptyStats() SecondStageStats {
    return .{
        .configure_count = 0,
        .lookup_count = 0,
        .validate_count = 0,
        .reset_count = 0,
        .bounds_reject_count = 0,
        .alignment_reject_count = 0,
        .permission_reject_count = 0,
        .failed_configure_count = 0,
        .failed_lookup_count = 0,
        .last_error = .none,
    };
}

fn emptyMapping(owner_vm_id: vm_model.VmId) SecondStageMapping {
    return .{
        .owner_vm_id = owner_vm_id,
        .guest_base = 0,
        .guest_size_bytes = 0,
        .guest_page_count = 0,
        .host_base = 0,
        .host_size_bytes = 0,
        .page_size = pmm.page_size,
        .flags_read = false,
        .flags_write = false,
        .flags_execute = false,
        .active = false,
        .validated = false,
    };
}

pub fn configureFromCurrentGuest() SecondStageMapResult {
    const ss = mutableObject();
    ss.stats.configure_count += 1;

    const vm = vm_model.object();
    const gm = guest_memory.object();
    const as = guest_address_space.object();

    if (gm.state != .configured or gm.size_bytes == 0 or gm.page_count == 0) {
        return rejectConfigure(ss, .guest_memory_not_configured);
    }
    if (as.state != .configured or as.guest_size_bytes == 0 or as.translated_page_count == 0) {
        return rejectConfigure(ss, .address_space_not_configured);
    }
    if (gm.owner_vm_id != vm.id or as.owner_vm_id != vm.id or gm.owner_vm_id != as.owner_vm_id) {
        return rejectConfigure(ss, .owner_mismatch);
    }
    if (as.page_size != pmm.page_size or as.region.page_size != pmm.page_size) {
        return rejectConfigure(ss, .page_size_mismatch);
    }
    if (as.guest_base.value != 0 or as.region.guest_base.value != as.guest_base.value) {
        return rejectConfigure(ss, .guest_base_mismatch);
    }
    if (as.guest_size_bytes != gm.size_bytes or as.region.guest_size_bytes != gm.size_bytes) {
        return rejectConfigure(ss, .guest_size_mismatch);
    }
    if (as.translated_page_count != gm.page_count or as.region.page_count != gm.page_count) {
        return rejectConfigure(ss, .guest_page_count_mismatch);
    }
    if (as.host_base.value != gm.base or as.region.host_base.value != gm.base) {
        return rejectConfigure(ss, .host_base_mismatch);
    }
    const expected_size = checkedMul(gm.page_count, pmm.page_size) orelse {
        return rejectConfigure(ss, .arithmetic_overflow);
    };
    if (expected_size != gm.size_bytes) {
        return rejectConfigure(ss, .guest_size_mismatch);
    }

    ss.owner_vm_id = vm.id;
    ss.mode = .metadata_only;
    ss.mapping = .{
        .owner_vm_id = vm.id,
        .guest_base = as.guest_base.value,
        .guest_size_bytes = as.guest_size_bytes,
        .guest_page_count = as.translated_page_count,
        .host_base = as.host_base.value,
        .host_size_bytes = gm.size_bytes,
        .page_size = pmm.page_size,
        .flags_read = true,
        .flags_write = true,
        .flags_execute = false,
        .active = false,
        .validated = false,
    };

    const validation = validateMappingInternal(ss.mapping, false);
    if (validation.result != .ok) {
        ss.mapping.validated = false;
        return rejectConfigure(ss, validation.stage_error);
    }

    ss.mapping.validated = true;
    ss.state = .metadata_ready;
    ss.stats.last_error = .none;
    return .ok;
}

fn rejectConfigure(ss: *SecondStage, err: SecondStageError) SecondStageMapResult {
    ss.state = .rejected;
    ss.mode = .metadata_only;
    ss.mapping.active = false;
    ss.mapping.validated = false;
    ss.stats.failed_configure_count += 1;
    ss.stats.last_error = err;
    if (err == .misaligned) ss.stats.alignment_reject_count += 1;
    if (err == .out_of_bounds) ss.stats.bounds_reject_count += 1;
    return .rejected;
}

pub fn validateCurrent() SecondStageValidateResult {
    const ss = mutableObject();
    ss.stats.validate_count += 1;
    if (ss.state != .metadata_ready) {
        ss.mapping.validated = false;
        ss.stats.last_error = .metadata_not_ready;
        return .{ .result = .rejected, .stage_error = .metadata_not_ready, .checked_page_count = 0 };
    }
    const result = validateMappingInternal(ss.mapping, true);
    ss.mapping.validated = result.result == .ok;
    ss.stats.last_error = result.stage_error;
    if (result.stage_error == .misaligned) ss.stats.alignment_reject_count += 1;
    if (result.stage_error == .out_of_bounds) ss.stats.bounds_reject_count += 1;
    if (result.result != .ok) ss.state = .rejected;
    return result;
}

fn validateMappingInternal(mapping: SecondStageMapping, require_current_objects: bool) SecondStageValidateResult {
    if (mapping.active) return validateRejected(.active_mapping_forbidden, 0);
    if (mapping.page_size != pmm.page_size) return validateRejected(.page_size_mismatch, 0);
    if (mapping.guest_size_bytes == 0 or mapping.host_size_bytes == 0 or mapping.guest_page_count == 0) return validateRejected(.empty_mapping, 0);
    if (!isAligned(mapping.guest_base, mapping.page_size) or !isAligned(mapping.host_base, mapping.page_size)) return validateRejected(.misaligned, 0);
    const expected_size = checkedMul(mapping.guest_page_count, mapping.page_size) orelse return validateRejected(.arithmetic_overflow, 0);
    if (expected_size != mapping.guest_size_bytes) return validateRejected(.guest_size_mismatch, 0);
    if (expected_size != mapping.host_size_bytes) return validateRejected(.host_size_mismatch, 0);
    if (!mapping.flags_read or !mapping.flags_write) return validateRejected(.execute_not_permitted, 0);
    if (mapping.flags_execute) return validateRejected(.execute_not_permitted, 0);
    _ = checkedAdd(mapping.guest_base, mapping.guest_size_bytes) orelse return validateRejected(.arithmetic_overflow, 0);
    _ = checkedAdd(mapping.host_base, mapping.host_size_bytes) orelse return validateRejected(.arithmetic_overflow, 0);

    if (require_current_objects) {
        const gm = guest_memory.object();
        const as = guest_address_space.object();
        if (gm.state != .configured) return validateRejected(.guest_memory_not_configured, 0);
        if (as.state != .configured) return validateRejected(.address_space_not_configured, 0);
        if (mapping.owner_vm_id != gm.owner_vm_id or mapping.owner_vm_id != as.owner_vm_id) return validateRejected(.owner_mismatch, 0);
        if (mapping.guest_base != as.guest_base.value) return validateRejected(.guest_base_mismatch, 0);
        if (mapping.guest_size_bytes != as.guest_size_bytes or mapping.guest_size_bytes != gm.size_bytes) return validateRejected(.guest_size_mismatch, 0);
        if (mapping.guest_page_count != as.translated_page_count or mapping.guest_page_count != gm.page_count) return validateRejected(.guest_page_count_mismatch, 0);
        if (mapping.host_base != as.host_base.value or mapping.host_base != gm.base) return validateRejected(.host_base_mismatch, 0);
        var i: usize = 0;
        while (i < mapping.guest_page_count) : (i += 1) {
            const page = guest_memory.pageAtIndex(i) orelse return validateRejected(.out_of_bounds, i);
            if (!isAligned(page, mapping.page_size)) return validateRejected(.misaligned, i);
        }
        return .{ .result = .ok, .stage_error = .none, .checked_page_count = mapping.guest_page_count };
    }

    return .{ .result = .ok, .stage_error = .none, .checked_page_count = mapping.guest_page_count };
}

fn validateRejected(err: SecondStageError, checked_page_count: usize) SecondStageValidateResult {
    return .{ .result = .rejected, .stage_error = err, .checked_page_count = checked_page_count };
}

pub fn lookup(gpa: usize) SecondStageLookupResult {
    const ss = mutableObject();
    ss.stats.lookup_count += 1;

    if (ss.state != .metadata_ready or !ss.mapping.validated) {
        ss.stats.failed_lookup_count += 1;
        ss.stats.last_error = .metadata_not_ready;
        return lookupRejected(gpa, .metadata_not_ready);
    }
    if ((gpa % ss.mapping.page_size) != 0) {
        ss.stats.failed_lookup_count += 1;
        ss.stats.alignment_reject_count += 1;
        ss.stats.last_error = .misaligned;
        return lookupRejected(gpa, .misaligned);
    }
    if (!gpaWithinMapping(ss.mapping, gpa)) {
        ss.stats.failed_lookup_count += 1;
        ss.stats.bounds_reject_count += 1;
        ss.stats.last_error = .out_of_bounds;
        return lookupRejected(gpa, .out_of_bounds);
    }
    const offset = gpa - ss.mapping.guest_base;
    const page_index = offset / ss.mapping.page_size;
    const page_offset = offset % ss.mapping.page_size;
    const host_page = guest_memory.pageAtIndex(page_index) orelse {
        ss.stats.failed_lookup_count += 1;
        ss.stats.bounds_reject_count += 1;
        ss.stats.last_error = .out_of_bounds;
        return lookupRejected(gpa, .out_of_bounds);
    };
    const host_address = checkedAdd(host_page, page_offset) orelse {
        ss.stats.failed_lookup_count += 1;
        ss.stats.last_error = .arithmetic_overflow;
        return lookupRejected(gpa, .arithmetic_overflow);
    };
    ss.stats.last_error = .none;
    return .{
        .result = .ok,
        .guest_address = gpa,
        .host_address = host_address,
        .page_index = page_index,
        .page_offset = page_offset,
        .stage_error = .none,
    };
}

fn lookupRejected(gpa: usize, err: SecondStageError) SecondStageLookupResult {
    return .{
        .result = .rejected,
        .guest_address = gpa,
        .host_address = 0,
        .page_index = 0,
        .page_offset = 0,
        .stage_error = err,
    };
}

pub fn boundsTest() SecondStageLookupResult {
    const ss = mutableObject();
    if (ss.state != .metadata_ready) return lookup(ss.mapping.guest_base);
    const out_of_bounds = checkedAdd(ss.mapping.guest_base, ss.mapping.guest_size_bytes) orelse ss.mapping.guest_base;
    return lookup(out_of_bounds);
}

pub fn alignmentTest() SecondStageValidateResult {
    const ss = mutableObject();
    ss.stats.validate_count += 1;
    var mapping = ss.mapping;
    if (mapping.page_size == 0) mapping.page_size = pmm.page_size;
    mapping.guest_base = mapping.guest_base + 1;
    mapping.active = false;
    mapping.flags_read = true;
    mapping.flags_write = true;
    mapping.flags_execute = false;
    if (mapping.guest_size_bytes == 0) mapping.guest_size_bytes = pmm.page_size;
    if (mapping.host_size_bytes == 0) mapping.host_size_bytes = pmm.page_size;
    if (mapping.guest_page_count == 0) mapping.guest_page_count = 1;
    const result = validateMappingInternal(mapping, false);
    if (result.stage_error == .misaligned) {
        ss.stats.alignment_reject_count += 1;
        ss.stats.last_error = .misaligned;
    } else {
        ss.stats.last_error = result.stage_error;
    }
    return result;
}

pub fn executePermissionTest() SecondStageMapResult {
    const ss = mutableObject();
    if (ss.mapping.flags_execute) {
        ss.stats.last_error = .execute_not_permitted;
        ss.stats.permission_reject_count += 1;
        return .rejected;
    }
    ss.stats.last_error = .execute_not_permitted;
    ss.stats.permission_reject_count += 1;
    return .rejected;
}

pub fn reset() SecondStageResetResult {
    const ss = mutableObject();
    const owner = ss.owner_vm_id;
    var stats = ss.stats;
    stats.reset_count += 1;
    stats.last_error = .none;
    boot_second_stage = emptyObject(owner, stats);
    boot_second_stage.state = .inactive;
    initialized = true;
    return .{ .result = .ok, .state = boot_second_stage.state };
}

fn gpaWithinMapping(mapping: SecondStageMapping, gpa: usize) bool {
    const end = checkedAdd(mapping.guest_base, mapping.guest_size_bytes) orelse return false;
    return gpa >= mapping.guest_base and gpa < end;
}

fn isAligned(value: usize, alignment: usize) bool {
    return alignment != 0 and (value % alignment) == 0;
}

fn checkedAdd(a: usize, b: usize) ?usize {
    const overflow = @addWithOverflow(a, b);
    if (overflow[1] != 0) return null;
    return overflow[0];
}

fn checkedMul(a: usize, b: usize) ?usize {
    const overflow = @mulWithOverflow(a, b);
    if (overflow[1] != 0) return null;
    return overflow[0];
}

pub fn printState() void {
    printImplementedMarker();
    printFields();
    printStats();
    printNonClaims();
}

pub fn printConfigureCommand() void {
    const result = configureFromCurrentGuest();
    uart.write("hv: second_stage.configure_result=");
    uart.write(mapResultName(result));
    uart.write("\r\n");
    printFields();
    printStats();
    printNonClaims();
}

pub fn printValidateCommand() void {
    const result = validateCurrent();
    uart.write("hv: second_stage.validate_result=");
    uart.write(mapResultName(result.result));
    uart.write("\r\n");
    uart.write("hv: second_stage.validate.checked_page_count=");
    uart.writeDec(result.checked_page_count);
    uart.write("\r\n");
    uart.write("hv: second_stage.validate.stage_error=");
    uart.write(errorName(result.stage_error));
    uart.write("\r\n");
    printFields();
    printStats();
    printNonClaims();
}

pub fn printLookupZeroCommand() void {
    const result = lookup(0);
    uart.write("hv: second_stage.lookup_zero_result=");
    uart.write(mapResultName(result.result));
    uart.write("\r\n");
    printLookup("lookup_zero", result);
    printFields();
    printStats();
    printNonClaims();
}

pub fn printLookupPageCommand() void {
    const result = lookup(pmm.page_size);
    uart.write("hv: second_stage.lookup_page_result=");
    uart.write(mapResultName(result.result));
    uart.write("\r\n");
    printLookup("lookup_page", result);
    printFields();
    printStats();
    printNonClaims();
}

pub fn printBoundsTestCommand() void {
    const result = boundsTest();
    uart.write("hv: second_stage.bounds_test=");
    uart.write(if (result.result == .rejected and result.stage_error == .out_of_bounds) "rejected" else "failed-to-reject");
    uart.write("\r\n");
    printLookup("bounds_test", result);
    printFields();
    printStats();
    printNonClaims();
}

pub fn printAlignmentTestCommand() void {
    const result = alignmentTest();
    uart.write("hv: second_stage.alignment_test=");
    uart.write(if (result.result == .rejected and result.stage_error == .misaligned) "rejected" else "failed-to-reject");
    uart.write("\r\n");
    uart.write("hv: second_stage.alignment_test.stage_error=");
    uart.write(errorName(result.stage_error));
    uart.write("\r\n");
    printFields();
    printStats();
    printNonClaims();
}

pub fn printExecutePermissionTestCommand() void {
    const result = executePermissionTest();
    uart.write("hv: second_stage.execute_permission_test=");
    uart.write(if (result == .rejected) "rejected" else "failed-to-reject");
    uart.write("\r\n");
    printFields();
    printStats();
    printNonClaims();
}

pub fn printResetCommand() void {
    const result = reset();
    uart.write("hv: second_stage.reset_result=");
    uart.write(mapResultName(result.result));
    uart.write("\r\n");
    printFields();
    printStats();
    printNonClaims();
}

pub fn printImplementedMarker() void {
    uart.write("hv: second_stage=implemented-metadata\r\n");
}

fn printLookup(prefix: []const u8, result: SecondStageLookupResult) void {
    uart.write("hv: second_stage.");
    uart.write(prefix);
    uart.write(".gpa=");
    uart.writeHex(result.guest_address);
    uart.write("\r\n");
    uart.write("hv: second_stage.");
    uart.write(prefix);
    uart.write(".hpa=");
    uart.writeHex(result.host_address);
    uart.write("\r\n");
    uart.write("hv: second_stage.");
    uart.write(prefix);
    uart.write(".page_index=");
    uart.writeDec(result.page_index);
    uart.write("\r\n");
    uart.write("hv: second_stage.");
    uart.write(prefix);
    uart.write(".page_offset=");
    uart.writeDec(result.page_offset);
    uart.write("\r\n");
    uart.write("hv: second_stage.");
    uart.write(prefix);
    uart.write(".stage_error=");
    uart.write(errorName(result.stage_error));
    uart.write("\r\n");
}

fn printFields() void {
    const ss = object();
    const mapping = ss.mapping;
    uart.write("hv: second_stage.state=");
    uart.write(stateName(ss.state));
    uart.write("\r\n");
    uart.write("hv: second_stage.mode=");
    uart.write(modeName(ss.mode));
    uart.write("\r\n");
    uart.write("hv: second_stage.owner_vm_id=");
    uart.writeDec(ss.owner_vm_id);
    uart.write("\r\n");
    uart.write("hv: second_stage.mapping.active=");
    uart.write(boolName(mapping.active));
    uart.write("\r\n");
    uart.write("hv: second_stage.mapping.validated=");
    uart.write(boolName(mapping.validated));
    uart.write("\r\n");
    uart.write("hv: second_stage.mapping.guest_base=");
    uart.writeHex(mapping.guest_base);
    uart.write("\r\n");
    uart.write("hv: second_stage.mapping.guest_size_bytes=");
    uart.writeDec(mapping.guest_size_bytes);
    uart.write("\r\n");
    uart.write("hv: second_stage.mapping.guest_page_count=");
    uart.writeDec(mapping.guest_page_count);
    uart.write("\r\n");
    uart.write("hv: second_stage.mapping.host_base=");
    uart.writeHex(mapping.host_base);
    uart.write("\r\n");
    uart.write("hv: second_stage.mapping.host_size_bytes=");
    uart.writeDec(mapping.host_size_bytes);
    uart.write("\r\n");
    uart.write("hv: second_stage.mapping.page_size=");
    uart.writeDec(mapping.page_size);
    uart.write("\r\n");
    uart.write("hv: second_stage.mapping.flags_read=");
    uart.write(boolName(mapping.flags_read));
    uart.write("\r\n");
    uart.write("hv: second_stage.mapping.flags_write=");
    uart.write(boolName(mapping.flags_write));
    uart.write("\r\n");
    uart.write("hv: second_stage.mapping.flags_execute=");
    uart.write(boolName(mapping.flags_execute));
    uart.write("\r\n");
}

fn printStats() void {
    const stats = object().stats;
    uart.write("hv: second_stage.stats.configure_count=");
    uart.writeDec(stats.configure_count);
    uart.write("\r\n");
    uart.write("hv: second_stage.stats.lookup_count=");
    uart.writeDec(stats.lookup_count);
    uart.write("\r\n");
    uart.write("hv: second_stage.stats.validate_count=");
    uart.writeDec(stats.validate_count);
    uart.write("\r\n");
    uart.write("hv: second_stage.stats.reset_count=");
    uart.writeDec(stats.reset_count);
    uart.write("\r\n");
    uart.write("hv: second_stage.stats.bounds_reject_count=");
    uart.writeDec(stats.bounds_reject_count);
    uart.write("\r\n");
    uart.write("hv: second_stage.stats.alignment_reject_count=");
    uart.writeDec(stats.alignment_reject_count);
    uart.write("\r\n");
    uart.write("hv: second_stage.stats.permission_reject_count=");
    uart.writeDec(stats.permission_reject_count);
    uart.write("\r\n");
    uart.write("hv: second_stage.stats.failed_configure_count=");
    uart.writeDec(stats.failed_configure_count);
    uart.write("\r\n");
    uart.write("hv: second_stage.stats.failed_lookup_count=");
    uart.writeDec(stats.failed_lookup_count);
    uart.write("\r\n");
    uart.write("hv: second_stage.stats.last_error=");
    uart.write(errorName(stats.last_error));
    uart.write("\r\n");
}

fn printNonClaims() void {
    uart.write("hv: second_stage_translation=MISSING\r\n");
    uart.write("hv: guest_execution=not-supported-yet\r\n");
    uart.write("hv: linux_guest=not-supported-yet\r\n");
    uart.write("hv: h_extension=unknown reason=no-safe-detection-yet\r\n");
}

fn boolName(value: bool) []const u8 {
    return if (value) "true" else "false";
}

fn stateName(state: SecondStageState) []const u8 {
    return switch (state) {
        .inactive => "inactive",
        .metadata_ready => "metadata-ready",
        .rejected => "rejected",
        .reset => "reset",
    };
}

fn modeName(mode: SecondStageMode) []const u8 {
    return switch (mode) {
        .metadata_only => "metadata-only",
        .inactive_no_h_extension => "inactive-no-h-extension",
        .inactive_no_hgatp => "inactive-no-hgatp",
    };
}

fn mapResultName(result: SecondStageMapResult) []const u8 {
    return switch (result) {
        .ok => "ok",
        .rejected => "rejected",
    };
}

fn errorName(err: SecondStageError) []const u8 {
    return switch (err) {
        .none => "none",
        .guest_memory_not_configured => "guest-memory-not-configured",
        .address_space_not_configured => "address-space-not-configured",
        .owner_mismatch => "owner-mismatch",
        .empty_mapping => "empty-mapping",
        .page_size_mismatch => "page-size-mismatch",
        .guest_base_mismatch => "guest-base-mismatch",
        .guest_size_mismatch => "guest-size-mismatch",
        .guest_page_count_mismatch => "guest-page-count-mismatch",
        .host_base_mismatch => "host-base-mismatch",
        .host_size_mismatch => "host-size-mismatch",
        .out_of_bounds => "out-of-bounds",
        .misaligned => "misaligned",
        .execute_not_permitted => "execute-not-permitted",
        .mapping_inactive => "mapping-inactive",
        .metadata_not_ready => "metadata-not-ready",
        .active_mapping_forbidden => "active-mapping-forbidden",
        .arithmetic_overflow => "arithmetic-overflow",
    };
}
