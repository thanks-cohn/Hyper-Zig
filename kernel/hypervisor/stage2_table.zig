const uart = @import("../console/uart.zig");
const pmm = @import("../memory/pmm.zig");
const vm_model = @import("vm.zig");
const guest_memory = @import("guest_memory.zig");
const second_stage = @import("second_stage.zig");

pub const max_stage2_entries: usize = guest_memory.max_guest_pages;

pub const Stage2TableState = enum {
    empty,
    built,
    validated,
    rejected,
    reset,
};

pub const Stage2TableMode = enum {
    software_table_only,
    inactive_no_hgatp,
    inactive_no_h_extension,
};

pub const Stage2TableError = enum {
    none,
    metadata_not_ready,
    metadata_not_validated,
    metadata_active_forbidden,
    owner_mismatch,
    empty_mapping,
    page_count_too_large,
    page_size_mismatch,
    guest_base_mismatch,
    host_base_mismatch,
    size_mismatch,
    out_of_bounds,
    misaligned,
    malformed_entry,
    read_not_permitted,
    write_not_permitted,
    execute_not_permitted,
    invalid_entry,
    table_not_built,
    arithmetic_overflow,
};

pub const Stage2TableFlags = struct {
    read: bool,
    write: bool,
    execute: bool,
    valid: bool,
};

pub const Stage2TableEntry = struct {
    index: usize,
    guest_page_base: usize,
    host_page_base: usize,
    page_size: usize,
    flags_read: bool,
    flags_write: bool,
    flags_execute: bool,
    flags_valid: bool,
    owner_vm_id: vm_model.VmId,
};

pub const Stage2TableBuildResult = struct {
    result: Stage2TableResult,
    table_error: Stage2TableError,
    built_entry_count: usize,
};

pub const Stage2TableWalkResult = struct {
    result: Stage2TableResult,
    table_error: Stage2TableError,
    guest_address: usize,
    host_address: usize,
    page_index: usize,
    page_offset: usize,
    flags_read: bool,
    flags_write: bool,
    flags_execute: bool,
};

pub const Stage2TableValidateResult = struct {
    result: Stage2TableResult,
    table_error: Stage2TableError,
    checked_entry_count: usize,
};

pub const Stage2TableResetResult = struct {
    result: Stage2TableResult,
    state: Stage2TableState,
    cleared_entry_count: usize,
};

pub const Stage2TableResult = enum {
    ok,
    rejected,
};

pub const Stage2TableStats = struct {
    build_count: usize,
    walk_count: usize,
    validate_count: usize,
    reset_count: usize,
    entry_count: usize,
    bounds_reject_count: usize,
    alignment_reject_count: usize,
    permission_reject_count: usize,
    failed_build_count: usize,
    failed_walk_count: usize,
    last_error: Stage2TableError,
};

pub const Stage2Table = struct {
    owner_vm_id: vm_model.VmId,
    state: Stage2TableState,
    mode: Stage2TableMode,
    active: bool,
    root_host_address: usize,
    page_size: usize,
    entry_count: usize,
    entries: [max_stage2_entries]Stage2TableEntry,
    stats: Stage2TableStats,
};

var boot_table: Stage2Table = undefined;
var initialized: bool = false;

pub fn init(owner_vm_id: vm_model.VmId) void {
    boot_table = emptyObject(owner_vm_id, emptyStats());
    initialized = true;
}

pub fn object() *const Stage2Table {
    return mutableObject();
}

fn mutableObject() *Stage2Table {
    if (!initialized) init(vm_model.object().id);
    return &boot_table;
}

fn emptyObject(owner_vm_id: vm_model.VmId, stats: Stage2TableStats) Stage2Table {
    return .{
        .owner_vm_id = owner_vm_id,
        .state = .empty,
        .mode = .software_table_only,
        .active = false,
        .root_host_address = 0,
        .page_size = pmm.page_size,
        .entry_count = 0,
        .entries = emptyEntries(owner_vm_id),
        .stats = stats,
    };
}

fn emptyEntries(owner_vm_id: vm_model.VmId) [max_stage2_entries]Stage2TableEntry {
    var entries: [max_stage2_entries]Stage2TableEntry = undefined;
    var i: usize = 0;
    while (i < max_stage2_entries) : (i += 1) {
        entries[i] = emptyEntry(owner_vm_id);
        entries[i].index = i;
    }
    return entries;
}

fn emptyEntry(owner_vm_id: vm_model.VmId) Stage2TableEntry {
    return .{
        .index = 0,
        .guest_page_base = 0,
        .host_page_base = 0,
        .page_size = pmm.page_size,
        .flags_read = false,
        .flags_write = false,
        .flags_execute = false,
        .flags_valid = false,
        .owner_vm_id = owner_vm_id,
    };
}

fn emptyStats() Stage2TableStats {
    return .{
        .build_count = 0,
        .walk_count = 0,
        .validate_count = 0,
        .reset_count = 0,
        .entry_count = 0,
        .bounds_reject_count = 0,
        .alignment_reject_count = 0,
        .permission_reject_count = 0,
        .failed_build_count = 0,
        .failed_walk_count = 0,
        .last_error = .none,
    };
}

pub fn buildFromSecondStageMetadata() Stage2TableBuildResult {
    const table = mutableObject();
    table.stats.build_count += 1;
    table.active = false;
    table.root_host_address = 0;
    table.mode = .software_table_only;

    const metadata = second_stage.object();
    if (metadata.state != .metadata_ready) return rejectBuild(table, .metadata_not_ready, 0);
    if (!metadata.mapping.validated) return rejectBuild(table, .metadata_not_validated, 0);
    if (metadata.mapping.active) return rejectBuild(table, .metadata_active_forbidden, 0);
    if (metadata.owner_vm_id != vm_model.object().id or metadata.mapping.owner_vm_id != metadata.owner_vm_id) {
        return rejectBuild(table, .owner_mismatch, 0);
    }
    if (metadata.mapping.page_size != pmm.page_size) return rejectBuild(table, .page_size_mismatch, 0);
    if (metadata.mapping.guest_base != 0) return rejectBuild(table, .guest_base_mismatch, 0);
    if (metadata.mapping.guest_page_count == 0) return rejectBuild(table, .empty_mapping, 0);
    if (metadata.mapping.guest_page_count > max_stage2_entries) return rejectBuild(table, .page_count_too_large, 0);
    if (!metadata.mapping.flags_read) return rejectBuild(table, .read_not_permitted, 0);
    if (!metadata.mapping.flags_write) return rejectBuild(table, .write_not_permitted, 0);
    if (metadata.mapping.flags_execute) return rejectBuild(table, .execute_not_permitted, 0);

    const expected_size = checkedMul(metadata.mapping.guest_page_count, metadata.mapping.page_size) orelse {
        return rejectBuild(table, .arithmetic_overflow, 0);
    };
    if (metadata.mapping.guest_size_bytes != expected_size or metadata.mapping.host_size_bytes != expected_size) {
        return rejectBuild(table, .size_mismatch, 0);
    }
    if (!isAligned(metadata.mapping.guest_base, metadata.mapping.page_size) or !isAligned(metadata.mapping.host_base, metadata.mapping.page_size)) {
        return rejectBuild(table, .misaligned, 0);
    }

    clearEntries(table);
    table.owner_vm_id = metadata.owner_vm_id;
    table.page_size = metadata.mapping.page_size;

    var i: usize = 0;
    while (i < metadata.mapping.guest_page_count) : (i += 1) {
        const guest_page_base = checkedAdd(metadata.mapping.guest_base, checkedMul(i, metadata.mapping.page_size) orelse {
            return rejectBuild(table, .arithmetic_overflow, i);
        }) orelse return rejectBuild(table, .arithmetic_overflow, i);
        const host_page_base = guest_memory.pageAtIndex(i) orelse return rejectBuild(table, .out_of_bounds, i);
        const entry = Stage2TableEntry{
            .index = i,
            .guest_page_base = guest_page_base,
            .host_page_base = host_page_base,
            .page_size = metadata.mapping.page_size,
            .flags_read = metadata.mapping.flags_read,
            .flags_write = metadata.mapping.flags_write,
            .flags_execute = false,
            .flags_valid = true,
            .owner_vm_id = metadata.owner_vm_id,
        };
        const checked = validateEntryAgainstMetadata(entry, metadata.mapping, i);
        if (checked != .none) return rejectBuild(table, checked, i);
        table.entries[i] = entry;
    }

    table.entry_count = metadata.mapping.guest_page_count;
    table.stats.entry_count = table.entry_count;
    table.stats.last_error = .none;
    table.state = .built;
    return .{ .result = .ok, .table_error = .none, .built_entry_count = table.entry_count };
}

fn rejectBuild(table: *Stage2Table, err: Stage2TableError, built_entry_count: usize) Stage2TableBuildResult {
    table.state = .rejected;
    table.active = false;
    table.mode = .software_table_only;
    table.stats.failed_build_count += 1;
    table.stats.last_error = err;
    table.stats.entry_count = table.entry_count;
    noteReject(table, err);
    return .{ .result = .rejected, .table_error = err, .built_entry_count = built_entry_count };
}

pub fn validateCurrent() Stage2TableValidateResult {
    const table = mutableObject();
    table.stats.validate_count += 1;
    const result = validateInternal(table.*);
    table.stats.last_error = result.table_error;
    if (result.result == .ok) {
        table.state = .validated;
    } else {
        table.state = .rejected;
        noteReject(table, result.table_error);
    }
    return result;
}

fn validateInternal(table: Stage2Table) Stage2TableValidateResult {
    if (table.active) return validateRejected(.metadata_active_forbidden, 0);
    if (table.state != .built and table.state != .validated) return validateRejected(.table_not_built, 0);
    if (table.mode != .software_table_only) return validateRejected(.metadata_active_forbidden, 0);
    if (table.page_size != pmm.page_size) return validateRejected(.page_size_mismatch, 0);
    if (table.entry_count == 0) return validateRejected(.empty_mapping, 0);
    if (table.entry_count > max_stage2_entries) return validateRejected(.page_count_too_large, 0);

    const metadata = second_stage.object();
    if (metadata.state != .metadata_ready or !metadata.mapping.validated) return validateRejected(.metadata_not_ready, 0);
    if (metadata.mapping.active) return validateRejected(.metadata_active_forbidden, 0);
    if (table.owner_vm_id != metadata.owner_vm_id) return validateRejected(.owner_mismatch, 0);
    if (table.entry_count != metadata.mapping.guest_page_count) return validateRejected(.size_mismatch, 0);

    var i: usize = 0;
    while (i < table.entry_count) : (i += 1) {
        const err = validateEntryAgainstMetadata(table.entries[i], metadata.mapping, i);
        if (err != .none) return validateRejected(err, i);
    }
    return .{ .result = .ok, .table_error = .none, .checked_entry_count = table.entry_count };
}

fn validateRejected(err: Stage2TableError, checked_entry_count: usize) Stage2TableValidateResult {
    return .{ .result = .rejected, .table_error = err, .checked_entry_count = checked_entry_count };
}

fn validateEntryAgainstMetadata(entry: Stage2TableEntry, mapping: second_stage.SecondStageMapping, expected_index: usize) Stage2TableError {
    if (!entry.flags_valid) return .invalid_entry;
    if (entry.index != expected_index) return .malformed_entry;
    if (entry.owner_vm_id != mapping.owner_vm_id) return .owner_mismatch;
    if (entry.page_size != mapping.page_size or entry.page_size != pmm.page_size) return .page_size_mismatch;
    if (!isAligned(entry.guest_page_base, entry.page_size) or !isAligned(entry.host_page_base, entry.page_size)) return .misaligned;
    const guest_delta = checkedMul(expected_index, mapping.page_size) orelse return .arithmetic_overflow;
    const expected_guest = checkedAdd(mapping.guest_base, guest_delta) orelse return .arithmetic_overflow;
    if (entry.guest_page_base != expected_guest) return .guest_base_mismatch;
    const expected_host = guest_memory.pageAtIndex(expected_index) orelse return .out_of_bounds;
    if (entry.host_page_base != expected_host) return .host_base_mismatch;
    if (!entry.flags_read or !mapping.flags_read) return .read_not_permitted;
    if (!entry.flags_write or !mapping.flags_write) return .write_not_permitted;
    if (entry.flags_execute or mapping.flags_execute) return .execute_not_permitted;
    return .none;
}

pub fn walk(gpa: usize, require_execute: bool) Stage2TableWalkResult {
    const table = mutableObject();
    table.stats.walk_count += 1;
    if (table.state != .built and table.state != .validated) return rejectWalk(table, gpa, .table_not_built);
    if ((gpa % table.page_size) != 0) return rejectWalk(table, gpa, .misaligned);
    const entry = entryForGuestAddress(table.*, gpa) orelse return rejectWalk(table, gpa, .out_of_bounds);
    if (!entry.flags_valid) return rejectWalk(table, gpa, .invalid_entry);
    if (require_execute and !entry.flags_execute) return rejectWalk(table, gpa, .execute_not_permitted);
    const page_offset = gpa - entry.guest_page_base;
    const host_address = checkedAdd(entry.host_page_base, page_offset) orelse return rejectWalk(table, gpa, .arithmetic_overflow);
    table.stats.last_error = .none;
    return .{
        .result = .ok,
        .table_error = .none,
        .guest_address = gpa,
        .host_address = host_address,
        .page_index = entry.index,
        .page_offset = page_offset,
        .flags_read = entry.flags_read,
        .flags_write = entry.flags_write,
        .flags_execute = entry.flags_execute,
    };
}

fn rejectWalk(table: *Stage2Table, gpa: usize, err: Stage2TableError) Stage2TableWalkResult {
    table.stats.failed_walk_count += 1;
    table.stats.last_error = err;
    noteReject(table, err);
    return .{
        .result = .rejected,
        .table_error = err,
        .guest_address = gpa,
        .host_address = 0,
        .page_index = 0,
        .page_offset = 0,
        .flags_read = false,
        .flags_write = false,
        .flags_execute = false,
    };
}

fn entryForGuestAddress(table: Stage2Table, gpa: usize) ?Stage2TableEntry {
    var i: usize = 0;
    while (i < table.entry_count) : (i += 1) {
        const entry = table.entries[i];
        const end = checkedAdd(entry.guest_page_base, entry.page_size) orelse return null;
        if (gpa >= entry.guest_page_base and gpa < end) return entry;
    }
    return null;
}

pub fn reset() Stage2TableResetResult {
    const table = mutableObject();
    const cleared = table.entry_count;
    const stats = table.stats;
    const owner = table.owner_vm_id;
    boot_table = emptyObject(owner, stats);
    initialized = true;
    const next = mutableObject();
    next.stats.reset_count += 1;
    next.stats.entry_count = 0;
    next.stats.last_error = .none;
    next.state = .empty;
    return .{ .result = .ok, .state = next.state, .cleared_entry_count = cleared };
}

fn clearEntries(table: *Stage2Table) void {
    var i: usize = 0;
    while (i < max_stage2_entries) : (i += 1) {
        table.entries[i] = emptyEntry(table.owner_vm_id);
        table.entries[i].index = i;
    }
    table.entry_count = 0;
    table.stats.entry_count = 0;
}

fn noteReject(table: *Stage2Table, err: Stage2TableError) void {
    if (err == .out_of_bounds) table.stats.bounds_reject_count += 1;
    if (err == .misaligned or err == .malformed_entry) table.stats.alignment_reject_count += 1;
    if (err == .read_not_permitted or err == .write_not_permitted or err == .execute_not_permitted) {
        table.stats.permission_reject_count += 1;
    }
}

pub fn printState() void {
    printImplementedMarker();
    printFields();
    printEntries();
    printStats();
    printNonClaims();
}

pub fn printBuildCommand() void {
    const result = buildFromSecondStageMetadata();
    uart.write("hv: stage2_table.build_result=");
    uart.write(resultName(result.result));
    uart.write("\r\n");
    uart.write("hv: stage2_table.build.entry_count=");
    uart.writeDec(result.built_entry_count);
    uart.write("\r\n");
    uart.write("hv: stage2_table.build.error=");
    uart.write(errorName(result.table_error));
    uart.write("\r\n");
    printFields();
    printEntries();
    printStats();
    printNonClaims();
}

pub fn printValidateCommand() void {
    const result = validateCurrent();
    uart.write("hv: stage2_table.validate_result=");
    uart.write(resultName(result.result));
    uart.write("\r\n");
    uart.write("hv: stage2_table.validate.checked_entry_count=");
    uart.writeDec(result.checked_entry_count);
    uart.write("\r\n");
    uart.write("hv: stage2_table.validate.error=");
    uart.write(errorName(result.table_error));
    uart.write("\r\n");
    printFields();
    printEntries();
    printStats();
    printNonClaims();
}

pub fn printWalkZeroCommand() void {
    const result = walk(0, false);
    uart.write("hv: stage2_table.walk_zero_result=");
    uart.write(resultName(result.result));
    uart.write("\r\n");
    printWalk("walk_zero", result);
    printFields();
    printNonClaims();
}

pub fn printWalkPageCommand() void {
    const result = walk(pmm.page_size, false);
    uart.write("hv: stage2_table.walk_page_result=");
    uart.write(resultName(result.result));
    uart.write("\r\n");
    printWalk("walk_page", result);
    printFields();
    printNonClaims();
}

pub fn printBoundsTestCommand() void {
    const table = object();
    const gpa = checkedMul(table.entry_count + 1, table.page_size) orelse table.page_size;
    const result = walk(gpa, false);
    uart.write("hv: stage2_table.bounds_test=");
    uart.write(if (result.result == .rejected and result.table_error == .out_of_bounds) "rejected" else "failed-to-reject");
    uart.write("\r\n");
    printWalk("bounds_test", result);
    printFields();
    printNonClaims();
}

pub fn printAlignmentTestCommand() void {
    const result = walk(1, false);
    uart.write("hv: stage2_table.alignment_test=");
    uart.write(if (result.result == .rejected and result.table_error == .misaligned) "rejected" else "failed-to-reject");
    uart.write("\r\n");
    printWalk("alignment_test", result);
    printFields();
    printNonClaims();
}

pub fn printExecutePermissionTestCommand() void {
    const result = walk(0, true);
    uart.write("hv: stage2_table.execute_permission_test=");
    uart.write(if (result.result == .rejected and result.table_error == .execute_not_permitted) "rejected" else "failed-to-reject");
    uart.write("\r\n");
    printWalk("execute_permission_test", result);
    printFields();
    printEntries();
    printNonClaims();
}

pub fn printResetCommand() void {
    const result = reset();
    uart.write("hv: stage2_table.reset_result=");
    uart.write(resultName(result.result));
    uart.write("\r\n");
    uart.write("hv: stage2_table.reset.cleared_entry_count=");
    uart.writeDec(result.cleared_entry_count);
    uart.write("\r\n");
    uart.write("hv: stage2_table.reset.state=");
    uart.write(stateName(result.state));
    uart.write("\r\n");
    printFields();
    printStats();
    printNonClaims();
}

pub fn printImplementedMarker() void {
    uart.write("hv: stage2_table=implemented-software-only\r\n");
}

fn printFields() void {
    const table = object();
    uart.write("hv: stage2_table.state=");
    uart.write(stateName(table.state));
    uart.write("\r\n");
    uart.write("hv: stage2_table.mode=");
    uart.write(modeName(table.mode));
    uart.write("\r\n");
    uart.write("hv: stage2_table.owner_vm_id=");
    uart.writeDec(table.owner_vm_id);
    uart.write("\r\n");
    uart.write("hv: stage2_table.active=");
    uart.write(boolName(table.active));
    uart.write("\r\n");
    uart.write("hv: stage2_table.entry_count=");
    uart.writeDec(table.entry_count);
    uart.write("\r\n");
    uart.write("hv: stage2_table.page_size=");
    uart.writeDec(table.page_size);
    uart.write("\r\n");
    uart.write("hv: stage2_table.root_host_address=");
    uart.writeHex(table.root_host_address);
    uart.write("\r\n");
}

fn printEntries() void {
    const table = object();
    var i: usize = 0;
    while (i < table.entry_count) : (i += 1) {
        printEntry(table.entries[i]);
    }
}

fn printEntry(entry: Stage2TableEntry) void {
    uart.write("hv: stage2_table.entry");
    uart.writeDec(entry.index);
    uart.write(".guest_page_base=");
    uart.writeHex(entry.guest_page_base);
    uart.write("\r\n");
    uart.write("hv: stage2_table.entry");
    uart.writeDec(entry.index);
    uart.write(".host_page_base=");
    uart.writeHex(entry.host_page_base);
    uart.write("\r\n");
    uart.write("hv: stage2_table.entry");
    uart.writeDec(entry.index);
    uart.write(".page_size=");
    uart.writeDec(entry.page_size);
    uart.write("\r\n");
    uart.write("hv: stage2_table.entry");
    uart.writeDec(entry.index);
    uart.write(".flags_read=");
    uart.write(boolName(entry.flags_read));
    uart.write("\r\n");
    uart.write("hv: stage2_table.entry");
    uart.writeDec(entry.index);
    uart.write(".flags_write=");
    uart.write(boolName(entry.flags_write));
    uart.write("\r\n");
    uart.write("hv: stage2_table.entry");
    uart.writeDec(entry.index);
    uart.write(".flags_execute=");
    uart.write(boolName(entry.flags_execute));
    uart.write("\r\n");
    uart.write("hv: stage2_table.entry");
    uart.writeDec(entry.index);
    uart.write(".flags_valid=");
    uart.write(boolName(entry.flags_valid));
    uart.write("\r\n");
}

fn printStats() void {
    const stats = object().stats;
    uart.write("hv: stage2_table.stats.build_count=");
    uart.writeDec(stats.build_count);
    uart.write("\r\n");
    uart.write("hv: stage2_table.stats.walk_count=");
    uart.writeDec(stats.walk_count);
    uart.write("\r\n");
    uart.write("hv: stage2_table.stats.validate_count=");
    uart.writeDec(stats.validate_count);
    uart.write("\r\n");
    uart.write("hv: stage2_table.stats.reset_count=");
    uart.writeDec(stats.reset_count);
    uart.write("\r\n");
    uart.write("hv: stage2_table.stats.entry_count=");
    uart.writeDec(stats.entry_count);
    uart.write("\r\n");
    uart.write("hv: stage2_table.stats.bounds_reject_count=");
    uart.writeDec(stats.bounds_reject_count);
    uart.write("\r\n");
    uart.write("hv: stage2_table.stats.alignment_reject_count=");
    uart.writeDec(stats.alignment_reject_count);
    uart.write("\r\n");
    uart.write("hv: stage2_table.stats.permission_reject_count=");
    uart.writeDec(stats.permission_reject_count);
    uart.write("\r\n");
    uart.write("hv: stage2_table.stats.failed_build_count=");
    uart.writeDec(stats.failed_build_count);
    uart.write("\r\n");
    uart.write("hv: stage2_table.stats.failed_walk_count=");
    uart.writeDec(stats.failed_walk_count);
    uart.write("\r\n");
    uart.write("hv: stage2_table.stats.last_error=");
    uart.write(errorName(stats.last_error));
    uart.write("\r\n");
}

fn printWalk(prefix: []const u8, result: Stage2TableWalkResult) void {
    uart.write("hv: stage2_table.");
    uart.write(prefix);
    uart.write(".gpa=");
    uart.writeHex(result.guest_address);
    uart.write("\r\n");
    uart.write("hv: stage2_table.");
    uart.write(prefix);
    uart.write(".hpa=");
    uart.writeHex(result.host_address);
    uart.write("\r\n");
    uart.write("hv: stage2_table.");
    uart.write(prefix);
    uart.write(".page_index=");
    uart.writeDec(result.page_index);
    uart.write("\r\n");
    uart.write("hv: stage2_table.");
    uart.write(prefix);
    uart.write(".page_offset=");
    uart.writeDec(result.page_offset);
    uart.write("\r\n");
    uart.write("hv: stage2_table.");
    uart.write(prefix);
    uart.write(".flags_execute=");
    uart.write(boolName(result.flags_execute));
    uart.write("\r\n");
    uart.write("hv: stage2_table.");
    uart.write(prefix);
    uart.write(".table_error=");
    uart.write(errorName(result.table_error));
    uart.write("\r\n");
}

fn printNonClaims() void {
    uart.write("hv: second_stage_translation=MISSING\r\n");
    uart.write("hv: guest_execution=not-supported-yet\r\n");
    uart.write("hv: linux_guest=not-supported-yet\r\n");
    uart.write("hv: h_extension=unknown reason=no-safe-detection-yet\r\n");
}

fn checkedMul(a: usize, b: usize) ?usize {
    if (a != 0 and b > (@as(usize, ~@as(usize, 0)) / a)) return null;
    return a * b;
}

fn checkedAdd(a: usize, b: usize) ?usize {
    if (b > (@as(usize, ~@as(usize, 0)) - a)) return null;
    return a + b;
}

fn isAligned(value: usize, alignment: usize) bool {
    return alignment != 0 and (value % alignment) == 0;
}

fn boolName(value: bool) []const u8 {
    return if (value) "true" else "false";
}

fn stateName(state: Stage2TableState) []const u8 {
    return switch (state) {
        .empty => "empty",
        .built => "built",
        .validated => "validated",
        .rejected => "rejected",
        .reset => "reset",
    };
}

fn modeName(mode: Stage2TableMode) []const u8 {
    return switch (mode) {
        .software_table_only => "software-table-only",
        .inactive_no_hgatp => "inactive-no-hgatp",
        .inactive_no_h_extension => "inactive-no-h-extension",
    };
}

fn resultName(result: Stage2TableResult) []const u8 {
    return switch (result) {
        .ok => "ok",
        .rejected => "rejected",
    };
}

fn errorName(err: Stage2TableError) []const u8 {
    return switch (err) {
        .none => "none",
        .metadata_not_ready => "metadata-not-ready",
        .metadata_not_validated => "metadata-not-validated",
        .metadata_active_forbidden => "metadata-active-forbidden",
        .owner_mismatch => "owner-mismatch",
        .empty_mapping => "empty-mapping",
        .page_count_too_large => "page-count-too-large",
        .page_size_mismatch => "page-size-mismatch",
        .guest_base_mismatch => "guest-base-mismatch",
        .host_base_mismatch => "host-base-mismatch",
        .size_mismatch => "size-mismatch",
        .out_of_bounds => "out-of-bounds",
        .misaligned => "misaligned",
        .malformed_entry => "malformed-entry",
        .read_not_permitted => "read-not-permitted",
        .write_not_permitted => "write-not-permitted",
        .execute_not_permitted => "execute-not-permitted",
        .invalid_entry => "invalid-entry",
        .table_not_built => "table-not-built",
        .arithmetic_overflow => "arithmetic-overflow",
    };
}
