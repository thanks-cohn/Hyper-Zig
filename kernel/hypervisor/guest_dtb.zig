const uart = @import("../console/uart.zig");
const vm_model = @import("vm.zig");
const boot_package = @import("boot_package.zig");

pub const max_bootargs_bytes: usize = boot_package.max_cmdline_bytes;
pub const default_payload_size: usize = 384;
pub const default_dtb_gpa: usize = 0x1c00;

pub const State = enum { empty, built };
pub const Result = enum { ok, rejected };
pub const Error = enum { none, boot_package_not_ready, missing_guest_memory, missing_payload, missing_bootargs, missing_memory_node, missing_cpu_node, missing_chosen_node, missing_console_path, range_zero, range_overflow, range_out_of_bounds, kernel_overlap, initrd_overlap };

const Range = boot_package.GpaRange;

pub const Blockers = struct {
    boot_package_not_ready: bool,
    missing_guest_memory: bool,
    missing_payload: bool,
    invalid_payload_bounds: bool,
    kernel_overlap: bool,
    initrd_overlap: bool,
    missing_bootargs: bool,
    missing_memory_node: bool,
    missing_cpu_node: bool,
    missing_chosen_node: bool,
    missing_console_path: bool,

    fn any(self: Blockers) bool { return self.boot_package_not_ready or self.missing_guest_memory or self.missing_payload or self.invalid_payload_bounds or self.kernel_overlap or self.initrd_overlap or self.missing_bootargs or self.missing_memory_node or self.missing_cpu_node or self.missing_chosen_node or self.missing_console_path; }
    fn count(self: Blockers) usize {
        var n: usize = 0;
        if (self.boot_package_not_ready) n += 1;
        if (self.missing_guest_memory) n += 1;
        if (self.missing_payload) n += 1;
        if (self.invalid_payload_bounds) n += 1;
        if (self.kernel_overlap) n += 1;
        if (self.initrd_overlap) n += 1;
        if (self.missing_bootargs) n += 1;
        if (self.missing_memory_node) n += 1;
        if (self.missing_cpu_node) n += 1;
        if (self.missing_chosen_node) n += 1;
        if (self.missing_console_path) n += 1;
        return n;
    }
};

pub const DtbContract = struct {
    owner_vm_id: vm_model.VmId,
    state: State,
    payload_present: bool,
    payload_gpa: usize,
    payload_size: usize,
    guest_base: usize,
    guest_size: usize,
    bootargs: [max_bootargs_bytes]u8,
    bootargs_len: usize,
    memory_node_present: bool,
    memory_base: usize,
    memory_size: usize,
    cpu_node_present: bool,
    cpu_hart_id: usize,
    cpu_isa: []const u8,
    chosen_node_present: bool,
    initrd_present: bool,
    initrd_start: usize,
    initrd_end: usize,
    console_path_present: bool,
    console_path: []const u8,
    interrupt_controller_claim: []const u8,
    timer_claim: []const u8,
    build_count: usize,
    validate_count: usize,
    reset_count: usize,
    reject_count: usize,
    last_error: Error,
};

var contract: DtbContract = undefined;
var initialized = false;

pub fn init(owner_vm_id: vm_model.VmId) void { contract = empty(owner_vm_id, 0); initialized = true; }
pub fn object() *const DtbContract { return mutable(); }
fn mutable() *DtbContract { if (!initialized) init(vm_model.object().id); return &contract; }

fn empty(owner_vm_id: vm_model.VmId, reset_count: usize) DtbContract {
    return .{ .owner_vm_id = owner_vm_id, .state = .empty, .payload_present = false, .payload_gpa = 0, .payload_size = 0, .guest_base = 0, .guest_size = 0, .bootargs = [_]u8{0} ** max_bootargs_bytes, .bootargs_len = 0, .memory_node_present = false, .memory_base = 0, .memory_size = 0, .cpu_node_present = false, .cpu_hart_id = 0, .cpu_isa = "", .chosen_node_present = false, .initrd_present = false, .initrd_start = 0, .initrd_end = 0, .console_path_present = false, .console_path = "", .interrupt_controller_claim = "missing-not-claimed", .timer_claim = "missing-not-claimed", .build_count = 0, .validate_count = 0, .reset_count = reset_count, .reject_count = 0, .last_error = .none };
}

pub fn reset() void { const old = mutable(); contract = empty(old.owner_vm_id, old.reset_count + 1); initialized = true; }

pub fn buildFromBootPackage(payload_gpa: usize, payload_size: usize) Result {
    const c = mutable();
    c.owner_vm_id = vm_model.object().id;
    const bp = boot_package.object();
    if (boot_package.validate() != .ok) return reject(.boot_package_not_ready);
    if (bp.guest_size == 0) return reject(.missing_guest_memory);
    const payload = Range{ .present = true, .start = payload_gpa, .size = payload_size };
    if (validateBounds(bp.guest_base, bp.guest_size, payload) != .ok) return reject(last_bounds_error);
    if (bp.kernel.present and rangesOverlap(payload, bp.kernel)) return reject(.kernel_overlap);
    if (bp.initrd.present and rangesOverlap(payload, bp.initrd)) return reject(.initrd_overlap);
    c.payload_present = true; c.payload_gpa = payload_gpa; c.payload_size = payload_size;
    c.guest_base = bp.guest_base; c.guest_size = bp.guest_size;
    copyBootargs(c, bp.cmdline[0..bp.cmdline_len]);
    c.memory_node_present = true; c.memory_base = bp.guest_base; c.memory_size = bp.guest_size;
    c.cpu_node_present = true; c.cpu_hart_id = 0; c.cpu_isa = "rv64imac";
    c.chosen_node_present = true;
    c.initrd_present = bp.initrd.present; c.initrd_start = bp.initrd.start; c.initrd_end = if (bp.initrd.present) bp.initrd.start + bp.initrd.size else 0;
    c.console_path_present = true; c.console_path = "/soc/uart@10000000";
    c.interrupt_controller_claim = "missing-not-claimed"; c.timer_claim = "missing-not-claimed";
    c.build_count += 1; c.last_error = .none; c.state = if (computeBlockers().any()) .empty else .built;
    return if (c.state == .built) .ok else reject(firstBlockerError(computeBlockers()));
}

fn copyBootargs(c: *DtbContract, s: []const u8) void { var i: usize = 0; while (i < max_bootargs_bytes) : (i += 1) c.bootargs[i] = 0; i = 0; while (i < s.len and i < max_bootargs_bytes) : (i += 1) c.bootargs[i] = s[i]; c.bootargs_len = s.len; }

var last_bounds_error: Error = .none;
fn validateBounds(base: usize, size: usize, r: Range) Result {
    if (!r.present or r.size == 0) { last_bounds_error = .range_zero; return .rejected; }
    const end = checkedAdd(r.start, r.size) orelse { last_bounds_error = .range_overflow; return .rejected; };
    const guest_end = checkedAdd(base, size) orelse { last_bounds_error = .range_overflow; return .rejected; };
    if (r.start < base or end > guest_end) { last_bounds_error = .range_out_of_bounds; return .rejected; }
    last_bounds_error = .none; return .ok;
}
fn checkedAdd(a: usize, b: usize) ?usize { if (b > (~@as(usize, 0)) - a) return null; return a + b; }
fn rangesOverlap(a: Range, b: Range) bool { return a.present and b.present and a.start < b.start + b.size and b.start < a.start + a.size; }
fn reject(e: Error) Result { const c = mutable(); c.reject_count += 1; c.last_error = e; c.state = .empty; return .rejected; }

pub fn validate() Result { const c = mutable(); c.validate_count += 1; const b = computeBlockers(); if (b.any()) return reject(firstBlockerError(b)); c.state = .built; c.last_error = .none; return .ok; }

pub fn computeBlockers() Blockers {
    const c = object(); const bp = boot_package.object();
    var b = Blockers{ .boot_package_not_ready = false, .missing_guest_memory = false, .missing_payload = false, .invalid_payload_bounds = false, .kernel_overlap = false, .initrd_overlap = false, .missing_bootargs = false, .missing_memory_node = false, .missing_cpu_node = false, .missing_chosen_node = false, .missing_console_path = false };
    if (boot_package.computeBlockers().any()) b.boot_package_not_ready = true;
    if (c.guest_size == 0) b.missing_guest_memory = true;
    if (!c.payload_present) b.missing_payload = true else if (validateBounds(c.guest_base, c.guest_size, .{ .present = true, .start = c.payload_gpa, .size = c.payload_size }) != .ok) b.invalid_payload_bounds = true;
    if (c.payload_present and bp.kernel.present and rangesOverlap(.{ .present = true, .start = c.payload_gpa, .size = c.payload_size }, bp.kernel)) b.kernel_overlap = true;
    if (c.payload_present and bp.initrd.present and rangesOverlap(.{ .present = true, .start = c.payload_gpa, .size = c.payload_size }, bp.initrd)) b.initrd_overlap = true;
    if (c.bootargs_len == 0) b.missing_bootargs = true;
    if (!c.memory_node_present or c.memory_size == 0) b.missing_memory_node = true;
    if (!c.cpu_node_present or c.cpu_isa.len == 0) b.missing_cpu_node = true;
    if (!c.chosen_node_present) b.missing_chosen_node = true;
    if (!c.console_path_present or c.console_path.len == 0) b.missing_console_path = true;
    return b;
}
fn firstBlockerError(b: Blockers) Error { if (b.boot_package_not_ready) return .boot_package_not_ready; if (b.missing_guest_memory) return .missing_guest_memory; if (b.missing_payload) return .missing_payload; if (b.invalid_payload_bounds) return .range_out_of_bounds; if (b.kernel_overlap) return .kernel_overlap; if (b.initrd_overlap) return .initrd_overlap; if (b.missing_bootargs) return .missing_bootargs; if (b.missing_memory_node) return .missing_memory_node; if (b.missing_cpu_node) return .missing_cpu_node; if (b.missing_chosen_node) return .missing_chosen_node; if (b.missing_console_path) return .missing_console_path; return .none; }

pub fn printState() void { printImplementedMarker(); printFields(); printBlockersFields(); printNonClaims(); }
pub fn printBuildCommand() void { const r = buildFromBootPackage(default_dtb_gpa, default_payload_size); printResult("build_result", r); printFields(); printBlockersFields(); printNonClaims(); }
pub fn printValidateCommand() void { const r = validate(); printResult("validate_result", r); printFields(); printBlockersFields(); printNonClaims(); }
pub fn printBlockersCommand() void { printBlockersFields(); printNonClaims(); }
pub fn printNodesCommand() void { printNodeFields(); printNonClaims(); }
pub fn printResetCommand() void { reset(); uart.write("hv: dtb.reset_result=ok\r\n"); printFields(); printBlockersFields(); printNonClaims(); }
pub fn printBoundsTestCommand() void { reset(); _ = buildHv13Ready(); const bp = boot_package.object(); const r = buildFromBootPackage(bp.guest_size, 64); uart.write("hv: dtb.bounds_test="); uart.write(if (r == .rejected) "rejected" else "failed-to-reject"); uart.write("\r\n"); printFields(); printBlockersFields(); printNonClaims(); }
pub fn printOverlapTestCommand() void { reset(); _ = buildHv13Ready(); const r = buildFromBootPackage(0, 64); uart.write("hv: dtb.overlap_test="); uart.write(if (r == .rejected) "rejected" else "failed-to-reject"); uart.write("\r\n"); printFields(); printBlockersFields(); printNonClaims(); }

fn buildHv13Ready() Result { boot_package.reset(); if (boot_package.attachKernelFromHv6Tiny() != .ok) return .rejected; if (boot_package.setCmdline("root=/dev/ram0 console=hvc0 earlycon") != .ok) return .rejected; if (boot_package.setEntry(0) != .ok) return .rejected; if (boot_package.attachInitrd(boot_package.default_initrd_gpa, boot_package.default_initrd_size) != .ok) return .rejected; if (boot_package.validate() != .ok) return .rejected; return .ok; }

pub fn printImplementedMarker() void { uart.write("hv: dtb_contract=implemented\r\n"); }
fn printResult(name: []const u8, r: Result) void { uart.write("hv: dtb."); uart.write(name); uart.write("="); uart.write(if (r == .ok) "ok" else "rejected"); uart.write("\r\n"); }
fn printFields() void { const c = object(); uart.write("hv: dtb.owner_vm_id="); uart.writeDec(c.owner_vm_id); uart.write("\r\n"); uart.write("hv: dtb.state="); uart.write(if (c.state == .built) "built" else "empty"); uart.write("\r\n"); uart.write("hv: dtb.ready="); uart.write(if (!computeBlockers().any()) "true" else "false"); uart.write("\r\n"); uart.write("hv: dtb.payload_present="); uart.write(if (c.payload_present) "true" else "false"); uart.write("\r\n"); uart.write("hv: dtb.gpa="); uart.writeHex(c.payload_gpa); uart.write("\r\n"); uart.write("hv: dtb.size_bytes="); uart.writeDec(c.payload_size); uart.write("\r\n"); uart.write("hv: dtb.guest_base="); uart.writeHex(c.guest_base); uart.write("\r\n"); uart.write("hv: dtb.guest_size_bytes="); uart.writeDec(c.guest_size); uart.write("\r\n"); uart.write("hv: dtb.bootargs="); uart.write(c.bootargs[0..c.bootargs_len]); uart.write("\r\n"); uart.write("hv: dtb.initrd_present="); uart.write(if (c.initrd_present) "true" else "false"); uart.write("\r\n"); uart.write("hv: dtb.initrd_start="); uart.writeHex(c.initrd_start); uart.write("\r\n"); uart.write("hv: dtb.initrd_end="); uart.writeHex(c.initrd_end); uart.write("\r\n"); uart.write("hv: dtb.build_count="); uart.writeDec(c.build_count); uart.write("\r\n"); uart.write("hv: dtb.validate_count="); uart.writeDec(c.validate_count); uart.write("\r\n"); uart.write("hv: dtb.reset_count="); uart.writeDec(c.reset_count); uart.write("\r\n"); uart.write("hv: dtb.reject_count="); uart.writeDec(c.reject_count); uart.write("\r\n"); uart.write("hv: dtb.last_error="); uart.write(errorName(c.last_error)); uart.write("\r\n"); printNodeFields(); }
fn printNodeFields() void { const c = object(); uart.write("hv: dtb.node=/memory present="); uart.write(if (c.memory_node_present) "true" else "false"); uart.write(" base="); uart.writeHex(c.memory_base); uart.write(" size="); uart.writeDec(c.memory_size); uart.write("\r\n"); uart.write("hv: dtb.node=/cpus/cpu@0 present="); uart.write(if (c.cpu_node_present) "true" else "false"); uart.write(" hartid="); uart.writeDec(c.cpu_hart_id); uart.write(" isa="); uart.write(c.cpu_isa); uart.write("\r\n"); uart.write("hv: dtb.node=/chosen present="); uart.write(if (c.chosen_node_present) "true" else "false"); uart.write(" bootargs="); uart.write(c.bootargs[0..c.bootargs_len]); uart.write(" console_path="); uart.write(c.console_path); uart.write("\r\n"); uart.write("hv: dtb.node=/chosen linux,initrd-start="); uart.writeHex(c.initrd_start); uart.write("\r\n"); uart.write("hv: dtb.node=/chosen linux,initrd-end="); uart.writeHex(c.initrd_end); uart.write("\r\n"); uart.write("hv: dtb.interrupt_controller="); uart.write(c.interrupt_controller_claim); uart.write("\r\n"); uart.write("hv: dtb.timer="); uart.write(c.timer_claim); uart.write("\r\n"); }
fn printBlockersFields() void { const b = computeBlockers(); uart.write("hv: dtb.blocker_count="); uart.writeDec(b.count()); uart.write("\r\n"); if (!b.any()) { uart.write("hv: dtb.blocker=none\r\n"); return; } if (b.boot_package_not_ready) uart.write("hv: dtb.blocker=boot-package-not-ready\r\n"); if (b.missing_guest_memory) uart.write("hv: dtb.blocker=guest-memory-missing\r\n"); if (b.missing_payload) uart.write("hv: dtb.blocker=payload-missing\r\n"); if (b.invalid_payload_bounds) uart.write("hv: dtb.blocker=payload-out-of-bounds\r\n"); if (b.kernel_overlap) uart.write("hv: dtb.blocker=kernel-overlap\r\n"); if (b.initrd_overlap) uart.write("hv: dtb.blocker=initrd-overlap\r\n"); if (b.missing_bootargs) uart.write("hv: dtb.blocker=bootargs-missing\r\n"); if (b.missing_memory_node) uart.write("hv: dtb.blocker=memory-node-missing\r\n"); if (b.missing_cpu_node) uart.write("hv: dtb.blocker=cpu-node-missing\r\n"); if (b.missing_chosen_node) uart.write("hv: dtb.blocker=chosen-node-missing\r\n"); if (b.missing_console_path) uart.write("hv: dtb.blocker=console-path-missing\r\n"); }
fn errorName(e: Error) []const u8 { return switch (e) { .none => "none", .boot_package_not_ready => "boot-package-not-ready", .missing_guest_memory => "guest-memory-missing", .missing_payload => "payload-missing", .missing_bootargs => "bootargs-missing", .missing_memory_node => "memory-node-missing", .missing_cpu_node => "cpu-node-missing", .missing_chosen_node => "chosen-node-missing", .missing_console_path => "console-path-missing", .range_zero => "range-zero", .range_overflow => "range-overflow", .range_out_of_bounds => "range-out-of-bounds", .kernel_overlap => "kernel-overlap", .initrd_overlap => "initrd-overlap" }; }
fn printNonClaims() void { uart.write("hv: linux_guest=not-supported-yet\r\n"); uart.write("hv: guest_execution=not-supported-yet\r\n"); uart.write("hv: second_stage_translation=MISSING\r\n"); uart.write("hv: sbi_layer=MISSING\r\n"); uart.write("hv: h_extension=unknown reason=no-safe-detection-yet\r\n"); }
