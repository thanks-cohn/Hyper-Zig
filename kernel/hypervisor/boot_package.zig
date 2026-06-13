const uart = @import("../console/uart.zig");
const vm_model = @import("vm.zig");
const guest_memory = @import("guest_memory.zig");
const guest_image = @import("guest_image.zig");

pub const max_cmdline_bytes: usize = 96;
pub const default_initrd_gpa: usize = 0x1000;
pub const default_initrd_size: usize = 512;
pub const default_dtb_gpa: usize = 0x1800;
pub const default_dtb_size: usize = 256;

pub const State = enum { empty, collecting, ready };
pub const Result = enum { ok, rejected };
pub const Error = enum {
    none,
    guest_memory_missing,
    missing_kernel,
    missing_entry,
    invalid_cmdline,
    cmdline_too_long,
    range_zero,
    range_overflow,
    range_out_of_bounds,
    range_overlap,
};

const RangeKind = enum { kernel, initrd, dtb };

pub const GpaRange = struct {
    present: bool,
    start: usize,
    size: usize,

    fn endExclusive(self: GpaRange) usize {
        return self.start + self.size;
    }
};

pub const Blockers = struct {
    missing_guest_memory: bool,
    missing_kernel: bool,
    missing_entry: bool,
    invalid_kernel_bounds: bool,
    invalid_entry_bounds: bool,
    invalid_initrd_bounds: bool,
    invalid_dtb_bounds: bool,
    kernel_initrd_overlap: bool,
    kernel_dtb_overlap: bool,
    initrd_dtb_overlap: bool,
    invalid_cmdline: bool,

    fn any(self: Blockers) bool {
        return self.missing_guest_memory or self.missing_kernel or self.missing_entry or self.invalid_kernel_bounds or self.invalid_entry_bounds or self.invalid_initrd_bounds or self.invalid_dtb_bounds or self.kernel_initrd_overlap or self.kernel_dtb_overlap or self.initrd_dtb_overlap or self.invalid_cmdline;
    }

    fn count(self: Blockers) usize {
        var n: usize = 0;
        if (self.missing_guest_memory) n += 1;
        if (self.missing_kernel) n += 1;
        if (self.missing_entry) n += 1;
        if (self.invalid_kernel_bounds) n += 1;
        if (self.invalid_entry_bounds) n += 1;
        if (self.invalid_initrd_bounds) n += 1;
        if (self.invalid_dtb_bounds) n += 1;
        if (self.kernel_initrd_overlap) n += 1;
        if (self.kernel_dtb_overlap) n += 1;
        if (self.initrd_dtb_overlap) n += 1;
        if (self.invalid_cmdline) n += 1;
        return n;
    }
};

pub const BootPackage = struct {
    owner_vm_id: vm_model.VmId,
    state: State,
    guest_base: usize,
    guest_size: usize,
    kernel: GpaRange,
    kernel_load_gpa: usize,
    entry_present: bool,
    entry_gpa: usize,
    initrd: GpaRange,
    dtb: GpaRange,
    cmdline: [max_cmdline_bytes]u8,
    cmdline_len: usize,
    cmdline_valid: bool,
    attach_kernel_count: usize,
    set_entry_count: usize,
    set_cmdline_count: usize,
    attach_initrd_count: usize,
    attach_dtb_count: usize,
    validate_count: usize,
    reset_count: usize,
    reject_count: usize,
    last_error: Error,
};

var boot_package: BootPackage = undefined;
var initialized = false;

pub fn init(owner_vm_id: vm_model.VmId) void {
    boot_package = empty(owner_vm_id, 0);
    initialized = true;
}

pub fn object() *const BootPackage { return mutable(); }

fn mutable() *BootPackage {
    if (!initialized) init(vm_model.object().id);
    return &boot_package;
}

fn empty(owner_vm_id: vm_model.VmId, reset_count: usize) BootPackage {
    return .{
        .owner_vm_id = owner_vm_id,
        .state = .empty,
        .guest_base = 0,
        .guest_size = 0,
        .kernel = .{ .present = false, .start = 0, .size = 0 },
        .kernel_load_gpa = 0,
        .entry_present = false,
        .entry_gpa = 0,
        .initrd = .{ .present = false, .start = 0, .size = 0 },
        .dtb = .{ .present = false, .start = 0, .size = 0 },
        .cmdline = [_]u8{0} ** max_cmdline_bytes,
        .cmdline_len = 0,
        .cmdline_valid = true,
        .attach_kernel_count = 0,
        .set_entry_count = 0,
        .set_cmdline_count = 0,
        .attach_initrd_count = 0,
        .attach_dtb_count = 0,
        .validate_count = 0,
        .reset_count = reset_count,
        .reject_count = 0,
        .last_error = .none,
    };
}

pub fn reset() void {
    const bp = mutable();
    boot_package = empty(bp.owner_vm_id, bp.reset_count + 1);
    initialized = true;
}

fn syncGuestBounds(bp: *BootPackage) void {
    const gm = guest_memory.object();
    if (gm.state == .configured) {
        bp.guest_base = 0;
        bp.guest_size = gm.size_bytes;
    } else {
        bp.guest_base = 0;
        bp.guest_size = 0;
    }
}

fn ensureMemory(bp: *BootPackage) Result {
    if (guest_memory.object().state != .configured) {
        if (guest_memory.configureDefault() != .ok) {
            bp.last_error = .guest_memory_missing;
            bp.reject_count += 1;
            return .rejected;
        }
    }
    syncGuestBounds(bp);
    return .ok;
}

pub fn attachKernelFromHv6Tiny() Result {
    const bp = mutable();
    bp.owner_vm_id = vm_model.object().id;
    if (guest_image.object().state != .loaded) {
        const load = guest_image.loadTiny();
        if (load.result != .ok) {
            bp.reject_count += 1;
            bp.last_error = .missing_kernel;
            return .rejected;
        }
    }
    if (ensureMemory(bp) != .ok) return .rejected;
    const img = guest_image.object();
    const range = GpaRange{ .present = true, .start = img.guest_load_base, .size = img.loaded_byte_count };
    if (validateRangeBounds(bp, range) != .ok) return reject(.range_out_of_bounds);
    bp.kernel = range;
    bp.kernel_load_gpa = img.guest_load_base;
    bp.attach_kernel_count += 1;
    bp.last_error = .none;
    updateState(bp);
    return .ok;
}

pub fn setEntry(gpa: usize) Result {
    const bp = mutable();
    if (ensureMemory(bp) != .ok) return .rejected;
    if (!pointInBounds(bp, gpa)) return reject(.range_out_of_bounds);
    bp.entry_present = true;
    bp.entry_gpa = gpa;
    bp.set_entry_count += 1;
    bp.last_error = .none;
    updateState(bp);
    return .ok;
}

pub fn setCmdline(line: []const u8) Result {
    const bp = mutable();
    if (line.len > max_cmdline_bytes) return reject(.cmdline_too_long);
    var i: usize = 0;
    while (i < max_cmdline_bytes) : (i += 1) bp.cmdline[i] = 0;
    i = 0;
    while (i < line.len) : (i += 1) bp.cmdline[i] = line[i];
    bp.cmdline_len = line.len;
    bp.cmdline_valid = true;
    bp.set_cmdline_count += 1;
    bp.last_error = .none;
    updateState(bp);
    return .ok;
}

pub fn attachInitrd(start: usize, size: usize) Result { return attachRange(.initrd, start, size); }
pub fn attachDtb(start: usize, size: usize) Result { return attachRange(.dtb, start, size); }

fn attachRange(kind: RangeKind, start: usize, size: usize) Result {
    const bp = mutable();
    if (ensureMemory(bp) != .ok) return .rejected;
    const range = GpaRange{ .present = true, .start = start, .size = size };
    if (validateRangeBounds(bp, range) != .ok) return reject(bp.last_error);
    if (kind != .kernel and bp.kernel.present and rangesOverlap(range, bp.kernel)) return reject(.range_overlap);
    if (kind == .initrd and bp.dtb.present and rangesOverlap(range, bp.dtb)) return reject(.range_overlap);
    if (kind == .dtb and bp.initrd.present and rangesOverlap(range, bp.initrd)) return reject(.range_overlap);
    switch (kind) {
        .kernel => bp.kernel = range,
        .initrd => { bp.initrd = range; bp.attach_initrd_count += 1; },
        .dtb => { bp.dtb = range; bp.attach_dtb_count += 1; },
    }
    bp.last_error = .none;
    updateState(bp);
    return .ok;
}

pub fn validate() Result {
    const bp = mutable();
    syncGuestBounds(bp);
    bp.validate_count += 1;
    const blockers = computeBlockers();
    if (blockers.any()) {
        bp.state = if (bp.kernel.present or bp.entry_present or bp.cmdline_len > 0 or bp.initrd.present or bp.dtb.present) .collecting else .empty;
        bp.reject_count += 1;
        bp.last_error = firstBlockerError(blockers);
        return .rejected;
    }
    bp.state = .ready;
    bp.last_error = .none;
    return .ok;
}

pub fn computeBlockers() Blockers {
    const bp = object();
    var b = Blockers{ .missing_guest_memory = false, .missing_kernel = false, .missing_entry = false, .invalid_kernel_bounds = false, .invalid_entry_bounds = false, .invalid_initrd_bounds = false, .invalid_dtb_bounds = false, .kernel_initrd_overlap = false, .kernel_dtb_overlap = false, .initrd_dtb_overlap = false, .invalid_cmdline = false };
    if (guest_memory.object().state != .configured or bp.guest_size == 0) b.missing_guest_memory = true;
    if (!bp.kernel.present) b.missing_kernel = true else if (validateRangeBoundsConst(bp, bp.kernel) != .ok) b.invalid_kernel_bounds = true;
    if (!bp.entry_present) b.missing_entry = true else if (!pointInBounds(bp, bp.entry_gpa)) b.invalid_entry_bounds = true;
    if (bp.initrd.present and validateRangeBoundsConst(bp, bp.initrd) != .ok) b.invalid_initrd_bounds = true;
    if (bp.dtb.present and validateRangeBoundsConst(bp, bp.dtb) != .ok) b.invalid_dtb_bounds = true;
    if (bp.kernel.present and bp.initrd.present and rangesOverlap(bp.kernel, bp.initrd)) b.kernel_initrd_overlap = true;
    if (bp.kernel.present and bp.dtb.present and rangesOverlap(bp.kernel, bp.dtb)) b.kernel_dtb_overlap = true;
    if (bp.initrd.present and bp.dtb.present and rangesOverlap(bp.initrd, bp.dtb)) b.initrd_dtb_overlap = true;
    if (!bp.cmdline_valid or bp.cmdline_len > max_cmdline_bytes) b.invalid_cmdline = true;
    return b;
}

fn updateState(bp: *BootPackage) void {
    const blockers = computeBlockers();
    bp.state = if (!blockers.any()) .ready else .collecting;
}

fn validateRangeBounds(bp: *BootPackage, r: GpaRange) Result {
    if (!r.present or r.size == 0) { bp.last_error = .range_zero; return .rejected; }
    const end = checkedAdd(r.start, r.size) orelse { bp.last_error = .range_overflow; return .rejected; };
    const guest_end = checkedAdd(bp.guest_base, bp.guest_size) orelse { bp.last_error = .range_overflow; return .rejected; };
    if (r.start < bp.guest_base or end > guest_end) { bp.last_error = .range_out_of_bounds; return .rejected; }
    return .ok;
}

fn validateRangeBoundsConst(bp: *const BootPackage, r: GpaRange) Result {
    if (!r.present or r.size == 0) return .rejected;
    const end = checkedAdd(r.start, r.size) orelse return .rejected;
    const guest_end = checkedAdd(bp.guest_base, bp.guest_size) orelse return .rejected;
    if (r.start < bp.guest_base or end > guest_end) return .rejected;
    return .ok;
}

fn pointInBounds(bp: *const BootPackage, gpa: usize) bool {
    const guest_end = checkedAdd(bp.guest_base, bp.guest_size) orelse return false;
    return bp.guest_size > 0 and gpa >= bp.guest_base and gpa < guest_end;
}

fn rangesOverlap(a: GpaRange, b: GpaRange) bool {
    if (!a.present or !b.present) return false;
    return a.start < b.endExclusive() and b.start < a.endExclusive();
}

fn reject(err: Error) Result {
    const bp = mutable();
    bp.reject_count += 1;
    bp.last_error = err;
    updateState(bp);
    return .rejected;
}

fn firstBlockerError(b: Blockers) Error {
    if (b.missing_guest_memory) return .guest_memory_missing;
    if (b.missing_kernel) return .missing_kernel;
    if (b.missing_entry) return .missing_entry;
    if (b.invalid_cmdline) return .invalid_cmdline;
    if (b.invalid_kernel_bounds or b.invalid_entry_bounds or b.invalid_initrd_bounds or b.invalid_dtb_bounds) return .range_out_of_bounds;
    if (b.kernel_initrd_overlap or b.kernel_dtb_overlap or b.initrd_dtb_overlap) return .range_overlap;
    return .none;
}

fn checkedAdd(a: usize, b: usize) ?usize { if (b > (~@as(usize, 0)) - a) return null; return a + b; }

pub fn printState() void { printImplementedMarker(); printFields(); printBlockersFields(); printNonClaims(); }
pub fn printAttachKernelCommand() void { const r = attachKernelFromHv6Tiny(); printResult("attach_kernel_result", r); printFields(); printBlockersFields(); printNonClaims(); }
pub fn printSetEntryCommand() void { const r = setEntry(guest_image.tiny_entry_point); printResult("set_entry_result", r); printFields(); printBlockersFields(); printNonClaims(); }
pub fn printSetCmdlineCommand(line: []const u8) void { const r = setCmdline(line); printResult("set_cmdline_result", r); printFields(); printBlockersFields(); printNonClaims(); }
pub fn printAttachInitrdCommand() void { const r = attachInitrd(default_initrd_gpa, default_initrd_size); printResult("attach_initrd_result", r); printFields(); printBlockersFields(); printNonClaims(); }
pub fn printAttachDtbCommand() void { const r = attachDtb(default_dtb_gpa, default_dtb_size); printResult("attach_dtb_result", r); printFields(); printBlockersFields(); printNonClaims(); }
pub fn printValidateCommand() void { const r = validate(); printResult("validate_result", r); printFields(); printBlockersFields(); printNonClaims(); }
pub fn printBlockersCommand() void { printBlockersFields(); printNonClaims(); }
pub fn printResetCommand() void { reset(); uart.write("hv: boot_package.reset_result=ok\r\n"); printFields(); printBlockersFields(); printNonClaims(); }

pub fn printOverlapTestCommand() void {
    reset();
    _ = attachKernelFromHv6Tiny();
    const r = attachInitrd(guest_image.tiny_load_base, 16);
    uart.write("hv: boot_package.overlap_test="); uart.write(if (r == .rejected) "rejected" else "failed-to-reject"); uart.write("\r\n");
    printFields(); printBlockersFields(); printNonClaims();
}

pub fn printBoundsTestCommand() void {
    reset();
    _ = ensureMemory(mutable());
    const bp = object();
    const r = attachDtb(bp.guest_size, 1);
    uart.write("hv: boot_package.bounds_test="); uart.write(if (r == .rejected) "rejected" else "failed-to-reject"); uart.write("\r\n");
    printFields(); printBlockersFields(); printNonClaims();
}

pub fn printImplementedMarker() void { uart.write("hv: boot_package=implemented\r\n"); }

fn printResult(name: []const u8, r: Result) void { uart.write("hv: boot_package."); uart.write(name); uart.write("="); uart.write(if (r == .ok) "ok" else "rejected"); uart.write("\r\n"); }

fn printFields() void {
    const bp = object();
    uart.write("hv: boot_package.owner_vm_id="); uart.writeDec(bp.owner_vm_id); uart.write("\r\n");
    uart.write("hv: boot_package.state="); uart.write(stateName(bp.state)); uart.write("\r\n");
    uart.write("hv: boot_package.ready="); uart.write(if (!computeBlockers().any()) "true" else "false"); uart.write("\r\n");
    uart.write("hv: boot_package.guest_base="); uart.writeHex(bp.guest_base); uart.write("\r\n");
    uart.write("hv: boot_package.guest_size_bytes="); uart.writeDec(bp.guest_size); uart.write("\r\n");
    printRange("kernel", bp.kernel); uart.write("hv: boot_package.kernel_load_gpa="); uart.writeHex(bp.kernel_load_gpa); uart.write("\r\n");
    uart.write("hv: boot_package.entry_present="); uart.write(if (bp.entry_present) "true" else "false"); uart.write("\r\n");
    uart.write("hv: boot_package.entry_gpa="); uart.writeHex(bp.entry_gpa); uart.write("\r\n");
    printRange("initrd", bp.initrd); printRange("dtb", bp.dtb);
    uart.write("hv: boot_package.cmdline_len="); uart.writeDec(bp.cmdline_len); uart.write("\r\n");
    uart.write("hv: boot_package.cmdline="); uart.write(bp.cmdline[0..bp.cmdline_len]); uart.write("\r\n");
    uart.write("hv: boot_package.cmdline_valid="); uart.write(if (bp.cmdline_valid) "true" else "false"); uart.write("\r\n");
    uart.write("hv: boot_package.attach_kernel_count="); uart.writeDec(bp.attach_kernel_count); uart.write("\r\n");
    uart.write("hv: boot_package.set_entry_count="); uart.writeDec(bp.set_entry_count); uart.write("\r\n");
    uart.write("hv: boot_package.set_cmdline_count="); uart.writeDec(bp.set_cmdline_count); uart.write("\r\n");
    uart.write("hv: boot_package.attach_initrd_count="); uart.writeDec(bp.attach_initrd_count); uart.write("\r\n");
    uart.write("hv: boot_package.attach_dtb_count="); uart.writeDec(bp.attach_dtb_count); uart.write("\r\n");
    uart.write("hv: boot_package.validate_count="); uart.writeDec(bp.validate_count); uart.write("\r\n");
    uart.write("hv: boot_package.reset_count="); uart.writeDec(bp.reset_count); uart.write("\r\n");
    uart.write("hv: boot_package.reject_count="); uart.writeDec(bp.reject_count); uart.write("\r\n");
    uart.write("hv: boot_package.last_error="); uart.write(errorName(bp.last_error)); uart.write("\r\n");
}

fn printRange(name: []const u8, r: GpaRange) void {
    uart.write("hv: boot_package."); uart.write(name); uart.write("_present="); uart.write(if (r.present) "true" else "false"); uart.write("\r\n");
    uart.write("hv: boot_package."); uart.write(name); uart.write("_start="); uart.writeHex(r.start); uart.write("\r\n");
    uart.write("hv: boot_package."); uart.write(name); uart.write("_size_bytes="); uart.writeDec(r.size); uart.write("\r\n");
    uart.write("hv: boot_package."); uart.write(name); uart.write("_end="); uart.writeHex(if (r.present) r.endExclusive() else 0); uart.write("\r\n");
}

fn printBlockersFields() void {
    const b = computeBlockers();
    uart.write("hv: boot_package.blocker_count="); uart.writeDec(b.count()); uart.write("\r\n");
    if (!b.any()) { uart.write("hv: boot_package.blocker=none\r\n"); return; }
    if (b.missing_guest_memory) uart.write("hv: boot_package.blocker=guest-memory-missing\r\n");
    if (b.missing_kernel) uart.write("hv: boot_package.blocker=kernel-image-missing\r\n");
    if (b.missing_entry) uart.write("hv: boot_package.blocker=entry-gpa-missing\r\n");
    if (b.invalid_kernel_bounds) uart.write("hv: boot_package.blocker=kernel-range-out-of-bounds\r\n");
    if (b.invalid_entry_bounds) uart.write("hv: boot_package.blocker=entry-gpa-out-of-bounds\r\n");
    if (b.invalid_initrd_bounds) uart.write("hv: boot_package.blocker=initrd-range-out-of-bounds\r\n");
    if (b.invalid_dtb_bounds) uart.write("hv: boot_package.blocker=dtb-range-out-of-bounds\r\n");
    if (b.kernel_initrd_overlap) uart.write("hv: boot_package.blocker=kernel-initrd-overlap\r\n");
    if (b.kernel_dtb_overlap) uart.write("hv: boot_package.blocker=kernel-dtb-overlap\r\n");
    if (b.initrd_dtb_overlap) uart.write("hv: boot_package.blocker=initrd-dtb-overlap\r\n");
    if (b.invalid_cmdline) uart.write("hv: boot_package.blocker=cmdline-invalid\r\n");
}

fn stateName(s: State) []const u8 { return switch (s) { .empty => "empty", .collecting => "collecting", .ready => "ready" }; }
fn errorName(e: Error) []const u8 { return switch (e) { .none => "none", .guest_memory_missing => "guest-memory-missing", .missing_kernel => "kernel-image-missing", .missing_entry => "entry-gpa-missing", .invalid_cmdline => "cmdline-invalid", .cmdline_too_long => "cmdline-too-long", .range_zero => "range-zero", .range_overflow => "range-overflow", .range_out_of_bounds => "range-out-of-bounds", .range_overlap => "range-overlap" }; }
fn printNonClaims() void { uart.write("hv: linux_guest=not-supported-yet\r\n"); uart.write("hv: guest_execution=not-supported-yet\r\n"); uart.write("hv: second_stage_translation=MISSING\r\n"); uart.write("hv: h_extension=unknown reason=no-safe-detection-yet\r\n"); }
