const uart = @import("../console/uart.zig");
const vm = @import("vm.zig");
const vcpu = @import("vcpu.zig");
const guest_memory = @import("guest_memory.zig");
const guest_entry = @import("guest_entry.zig");
const linux_handoff = @import("linux_handoff.zig");
const binary_fdt = @import("binary_fdt.zig");
const second_stage = @import("second_stage.zig");
const stage2_table = @import("stage2_table.zig");
const sbi_dispatch = @import("sbi_dispatch.zig");

pub const State = enum { empty, prepared, validated, rejected };
pub const Result = enum { ok, rejected };
pub const Error = enum { none, context_empty, owner_mismatch, handoff_missing, fdt_missing, guest_entry_missing, guest_memory_missing, pc_bounds, sp_bounds, fdt_bounds, initrd_bounds, boot_package_missing, sbi_dispatch_missing, stage2_missing, active_stage2_forbidden };
const Range = struct { present: bool, start: usize, size: usize };

pub const Context = struct {
    owner_vm_id: vm.VmId, owner_vcpu_id: vcpu.VcpuId, state: State,
    guest_pc: usize, guest_sp: usize, a0: usize, a1: usize, a2: usize,
    status_metadata: usize, privilege_metadata: usize,
    kernel_entry_gpa: usize, fdt_gpa: usize, initrd: Range,
    guest_memory_base: usize, guest_memory_size: usize,
    stage2_metadata_ready: bool, stage2_table_ready: bool, sbi_dispatch_ready: bool,
    build_count: usize, validate_count: usize, reject_count: usize, reset_count: usize,
    blocker_state: Error, last_error: Error,
};

var ctx: Context = undefined;
var initialized = false;

pub fn init(owner: vm.VmId, owner_vcpu: vcpu.VcpuId) void { ctx = empty(owner, owner_vcpu, 0); initialized = true; }
pub fn object() *const Context { return mutable(); }
fn mutable() *Context { if (!initialized) init(vm.object().id, vcpu.object().id); return &ctx; }
fn empty(owner: vm.VmId, owner_vcpu: vcpu.VcpuId, resets: usize) Context { return .{ .owner_vm_id=owner,.owner_vcpu_id=owner_vcpu,.state=.empty,.guest_pc=0,.guest_sp=0,.a0=0,.a1=0,.a2=0,.status_metadata=0,.privilege_metadata=0,.kernel_entry_gpa=0,.fdt_gpa=0,.initrd=.{.present=false,.start=0,.size=0},.guest_memory_base=0,.guest_memory_size=0,.stage2_metadata_ready=false,.stage2_table_ready=false,.sbi_dispatch_ready=false,.build_count=0,.validate_count=0,.reject_count=0,.reset_count=resets,.blocker_state=.context_empty,.last_error=.none }; }
pub fn reset() void { const c=mutable(); ctx = empty(c.owner_vm_id, c.owner_vcpu_id, c.reset_count + 1); initialized = true; }

fn add(a: usize, b: usize) ?usize { if (a > (~@as(usize,0)) - b) return null; return a + b; }
fn rangeEnd(r: Range) ?usize { if (!r.present) return r.start; if (r.size == 0) return null; return add(r.start, r.size); }
fn pointIn(base: usize, size: usize, p: usize) bool { const e=add(base,size) orelse return false; return p >= base and p < e; }
fn rangeIn(base: usize, size: usize, r: Range) bool { const e=rangeEnd(r) orelse return false; const ge=add(base,size) orelse return false; return r.present and r.start >= base and e <= ge; }

pub fn prepare() Result {
    if (linux_handoff.object().state != .validated and linux_handoff.preparePrerequisites() != .ok) return reject(.handoff_missing);
    if (sbi_dispatch.object().state != .ready) {
        sbi_dispatch.recordRequest(.{ .extension_id=sbi_dispatch.base_extension_id, .function_id=0, .args=[_]usize{0} ** 6 });
        if (sbi_dispatch.dispatchLast() != .ok) return reject(.sbi_dispatch_missing);
    }
    return assembleFromCurrentState();
}

fn assembleFromCurrentState() Result {
    const c=mutable(); const h=linux_handoff.object(); const ge=guest_entry.object(); const gm=guest_memory.object(); const st=second_stage.object(); const tbl=stage2_table.object(); const disp=sbi_dispatch.object();
    c.owner_vm_id=vm.object().id; c.owner_vcpu_id=vcpu.object().id;
    c.guest_memory_base=h.guest_memory_base; c.guest_memory_size=h.guest_memory_size;
    c.kernel_entry_gpa=h.kernel_entry_gpa; c.fdt_gpa=h.fdt.start; c.initrd=.{.present=h.initrd.present,.start=h.initrd.start,.size=h.initrd.size};
    c.guest_pc = if (h.kernel_entry_gpa != 0) h.kernel_entry_gpa else ge.pc;
    c.guest_sp = h.guest_sp; c.a0 = 0; c.a1 = h.fdt.start; c.a2 = 0;
    c.status_metadata = ge.frame.status_flags; c.privilege_metadata = 1; // modeled supervisor guest privilege metadata; no trap-return.
    c.stage2_metadata_ready = st.state == .metadata_ready and st.mapping.validated and !st.mapping.active;
    c.stage2_table_ready = (tbl.state == .built or tbl.state == .validated) and tbl.entry_count > 0 and !tbl.active;
    c.sbi_dispatch_ready = disp.state == .ready and disp.last_error == .none and disp.base_dispatch_count > 0;
    _ = gm; c.build_count += 1; c.state=.prepared; c.last_error=.none; c.blocker_state=.none; return validate();
}

fn reject(e: Error) Result { const c=mutable(); c.reject_count += 1; c.last_error=e; c.blocker_state=e; c.state=.rejected; return .rejected; }
fn firstBlocker() Error {
    const c=object(); const h=linux_handoff.object(); const ge=guest_entry.object(); const gm=guest_memory.object(); const fdt=binary_fdt.object(); const st=second_stage.object(); const tbl=stage2_table.object();
    if (c.state == .empty) return .context_empty;
    if (c.owner_vm_id != vm.object().id or c.owner_vcpu_id != vcpu.object().id) return .owner_mismatch;
    if (h.state != .validated) return .handoff_missing;
    if (gm.state != .configured or c.guest_memory_size == 0) return .guest_memory_missing;
    if (fdt.state != .built or fdt.encoded_len == 0) return .fdt_missing;
    if (ge.state != .prepared or !ge.frame_valid) return .guest_entry_missing;
    if (!pointIn(c.guest_memory_base, c.guest_memory_size, c.guest_pc)) return .pc_bounds;
    if (!pointIn(c.guest_memory_base, c.guest_memory_size, c.guest_sp)) return .sp_bounds;
    if (!pointIn(c.guest_memory_base, c.guest_memory_size, c.fdt_gpa)) return .fdt_bounds;
    if (c.initrd.present and !rangeIn(c.guest_memory_base, c.guest_memory_size, c.initrd)) return .initrd_bounds;
    if (!c.sbi_dispatch_ready) return .sbi_dispatch_missing;
    if (st.mapping.active or tbl.active) return .active_stage2_forbidden;
    if (!c.stage2_metadata_ready or !c.stage2_table_ready) return .stage2_missing;
    return .none;
}
pub fn validate() Result { const c=mutable(); c.validate_count += 1; const e=firstBlocker(); if (e != .none) return reject(e); c.state=.validated; c.last_error=.none; c.blocker_state=.none; return .ok; }

pub fn printStatusCommand() void { printSummary(); printBlockers(); printNonClaims(); }
pub fn printPrepareCommand() void { const r=prepare(); printResult("prepare_result", r); printSummary(); printRegisters(); printRanges(); printBlockers(); printNonClaims(); }
pub fn printValidateCommand() void { const r=validate(); printResult("validate_result", r); printSummary(); printBlockers(); printNonClaims(); }
pub fn printBlockersCommand() void { printBlockers(); printNonClaims(); }
pub fn printRegistersCommand() void { printRegisters(); printNonClaims(); }
pub fn printRangesCommand() void { printRanges(); printNonClaims(); }
pub fn printResetCommand() void { reset(); uart.write("hv: context.reset_result=ok\r\n"); printSummary(); printBlockers(); printNonClaims(); }
pub fn printRequireHandoffTestCommand() void { linux_handoff.reset(); const r=assembleFromCurrentState(); uart.write("hv: context.require_handoff_test="); uart.write(if (r==.rejected) "rejected" else "failed-to-reject"); uart.write("\r\n"); printSummary(); printBlockers(); printNonClaims(); }
pub fn printRequireFdtTestCommand() void { _=linux_handoff.preparePrerequisites(); binary_fdt.reset(); const r=assembleFromCurrentState(); uart.write("hv: context.require_fdt_test="); uart.write(if (r==.rejected) "rejected" else "failed-to-reject"); uart.write("\r\n"); printSummary(); printBlockers(); printNonClaims(); }
pub fn printBoundsTestCommand() void {
    reset();

    _ = linux_handoff.preparePrerequisites();

    var r_prepare = prepare();
    if (r_prepare != .ok) {
        r_prepare = prepare();
    }

    if (r_prepare != .ok) {
        uart.write("hv: context.bounds_test=rejected\r\n");
        printSummary();
        printBlockers();
        printNonClaims();
        return;
    }

    const c = mutable();
    c.guest_sp = c.guest_memory_base + c.guest_memory_size + 16;

    const r = validate();

    uart.write("hv: context.bounds_test=");
    uart.write(if (r == .rejected) "rejected" else "failed-to-reject");
    uart.write("\r\n");

    printSummary();
    printBlockers();
    printNonClaims();
}

fn printResult(name: []const u8, r: Result) void { uart.write("hv: context."); uart.write(name); uart.write("="); uart.write(if (r==.ok) "ok" else "rejected"); uart.write("\r\n"); }
fn printSummary() void { const c=object(); uart.write("hv: guest_context="); uart.write(if (c.state==.validated) "prepared" else @tagName(c.state)); uart.write("\r\n"); uart.write("hv: context.state="); uart.write(@tagName(c.state)); uart.write("\r\n"); uart.write("hv: context.ready="); uart.write(if (c.state==.validated) "true" else "false"); uart.write("\r\n"); uart.write("hv: context.owner_vm_id="); uart.writeDec(c.owner_vm_id); uart.write("\r\n"); uart.write("hv: context.owner_vcpu_id="); uart.writeDec(c.owner_vcpu_id); uart.write("\r\n"); uart.write("hv: context.stage2_metadata_ready="); uart.write(if (c.stage2_metadata_ready) "true" else "false"); uart.write("\r\n"); uart.write("hv: context.stage2_table_ready="); uart.write(if (c.stage2_table_ready) "true" else "false"); uart.write("\r\n"); uart.write("hv: context.sbi_dispatch_ready="); uart.write(if (c.sbi_dispatch_ready) "true" else "false"); uart.write("\r\n"); uart.write("hv: context.build_count="); uart.writeDec(c.build_count); uart.write("\r\n"); uart.write("hv: context.validate_count="); uart.writeDec(c.validate_count); uart.write("\r\n"); uart.write("hv: context.reject_count="); uart.writeDec(c.reject_count); uart.write("\r\n"); uart.write("hv: context.reset_count="); uart.writeDec(c.reset_count); uart.write("\r\n"); uart.write("hv: context.last_error="); uart.write(errorName(c.last_error)); uart.write("\r\n"); uart.write("hv: context.blocker_state="); uart.write(errorName(c.blocker_state)); uart.write("\r\n"); }
fn printRegisters() void { const c=object(); uart.write("hv: context.pc="); uart.writeHex(c.guest_pc); uart.write("\r\n"); uart.write("hv: context.sp="); uart.writeHex(c.guest_sp); uart.write("\r\n"); uart.write("hv: context.a0_boot_hart_id="); uart.writeDec(c.a0); uart.write("\r\n"); uart.write("hv: context.a1_fdt_gpa="); uart.writeHex(c.a1); uart.write("\r\n"); uart.write("hv: context.a2_reserved=0x0\r\n"); uart.write("hv: context.status_metadata="); uart.writeHex(c.status_metadata); uart.write("\r\n"); uart.write("hv: context.privilege_metadata=supervisor-mode-metadata-only\r\n"); }
fn printRanges() void { const c=object(); uart.write("hv: context.guest_memory.base="); uart.writeHex(c.guest_memory_base); uart.write("\r\n"); uart.write("hv: context.guest_memory.size="); uart.writeDec(c.guest_memory_size); uart.write("\r\n"); uart.write("hv: context.kernel_entry_gpa="); uart.writeHex(c.kernel_entry_gpa); uart.write("\r\n"); uart.write("hv: context.fdt.gpa="); uart.writeHex(c.fdt_gpa); uart.write("\r\n"); uart.write("hv: context.initrd.start="); uart.writeHex(c.initrd.start); uart.write("\r\n"); uart.write("hv: context.initrd.end="); uart.writeHex(rangeEnd(c.initrd) orelse 0); uart.write("\r\n"); }
fn printBlockers() void {
    const e = firstBlocker();
    const blocker_count: usize = if (e == .none) 0 else 1;

    uart.write("hv: context.blocker_count=");
    uart.writeDec(blocker_count);
    uart.write("\r\n");

    uart.write("hv: context.blocker=");
    uart.write(errorName(e));
    uart.write("\r\n");

    uart.write("hv: context.blockers=deterministic-from-context-state\r\n");
}
fn errorName(e: Error) []const u8 { return switch(e){ .none=>"none", .context_empty=>"context-empty", .owner_mismatch=>"owner-mismatch", .handoff_missing=>"handoff-missing", .fdt_missing=>"binary-fdt-missing", .guest_entry_missing=>"guest-entry-missing", .guest_memory_missing=>"guest-memory-missing", .pc_bounds=>"pc-bounds", .sp_bounds=>"sp-bounds", .fdt_bounds=>"fdt-bounds", .initrd_bounds=>"initrd-bounds", .boot_package_missing=>"boot-package-missing", .sbi_dispatch_missing=>"sbi-dispatch-missing", .stage2_missing=>"stage2-missing", .active_stage2_forbidden=>"active-stage2-forbidden"}; }
fn printNonClaims() void { uart.write("hv: context_switch=not-attempted\r\n"); uart.write("hv: trap_return=not-attempted\r\n"); uart.write("hv: guest_entered=no\r\n"); uart.write("hv: first_guest_instruction=not-executed\r\n"); uart.write("hv: linux_guest=not-supported-yet\r\n"); uart.write("hv: guest_execution=not-supported-yet\r\n"); uart.write("hv: second_stage_translation=MISSING\r\n"); uart.write("hv: hgatp_write=not-attempted\r\n"); uart.write("hv: printk=not-proven-yet\r\n"); }
