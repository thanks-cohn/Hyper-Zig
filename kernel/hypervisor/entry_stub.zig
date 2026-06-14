const uart = @import("../console/uart.zig");
const vm = @import("vm.zig");
const vcpu = @import("vcpu.zig");
const trap_plan = @import("trap_plan.zig");
const guest_execution = @import("guest_execution.zig");
const guest_run_attempt = @import("guest_run_attempt.zig");
const second_stage = @import("second_stage.zig");
const stage2_table = @import("stage2_table.zig");
const sbi_dispatch = @import("sbi_dispatch.zig");

pub const State = enum { empty, prepared, validated, rejected };
pub const Result = enum { ok, rejected };
pub const AttemptResult = enum { none, blocked_safe_denied };
pub const Error = enum { none, stub_empty, trap_plan_missing, trap_plan_malformed, owner_mismatch, pc_bounds, sp_bounds, fdt_bounds, sbi_dispatch_missing, execution_gate_missing, run_attempt_gate_missing, stage2_missing, active_stage2_forbidden, entry_stub_not_executable, guest_entry_not_enabled };

pub const EntryStub = struct {
    owner_vm_id: vm.VmId, owner_vcpu_id: vcpu.VcpuId, state: State, source_trap_plan_state: trap_plan.State,
    planned_pc: usize, planned_sp: usize, planned_a0: usize, planned_a1: usize, planned_a2: usize,
    status_metadata: usize, privilege_metadata: usize, trap_return_kind_metadata: usize, entry_mode_metadata: usize,
    stub_address: usize, stub_size: usize, stub_checksum: usize,
    guest_memory_base: usize, guest_memory_size: usize,
    stage2_metadata_ready: bool, stage2_table_ready: bool, active_stage2_forbidden: bool, hgatp_write_forbidden: bool,
    h_extension_claimed: bool, h_extension_unknown: bool, execution_gate_ready: bool, run_attempt_gate_ready: bool, sbi_dispatch_ready: bool,
    build_count: usize, validate_count: usize, reject_count: usize, reset_count: usize, attempt_count: usize,
    attempt_result: AttemptResult, deterministic_blocker: Error, last_error: Error,
};

var stub: EntryStub = undefined;
var initialized = false;

pub fn init(owner: vm.VmId, owner_vcpu: vcpu.VcpuId) void { stub = empty(owner, owner_vcpu, 0); initialized = true; }
pub fn object() *const EntryStub { return mutable(); }
fn mutable() *EntryStub { if (!initialized) init(vm.object().id, vcpu.object().id); return &stub; }
fn empty(owner: vm.VmId, owner_vcpu: vcpu.VcpuId, resets: usize) EntryStub { return .{ .owner_vm_id=owner,.owner_vcpu_id=owner_vcpu,.state=.empty,.source_trap_plan_state=.empty,.planned_pc=0,.planned_sp=0,.planned_a0=0,.planned_a1=0,.planned_a2=0,.status_metadata=0,.privilege_metadata=0,.trap_return_kind_metadata=0,.entry_mode_metadata=0,.stub_address=0,.stub_size=0,.stub_checksum=0,.guest_memory_base=0,.guest_memory_size=0,.stage2_metadata_ready=false,.stage2_table_ready=false,.active_stage2_forbidden=true,.hgatp_write_forbidden=true,.h_extension_claimed=false,.h_extension_unknown=true,.execution_gate_ready=false,.run_attempt_gate_ready=false,.sbi_dispatch_ready=false,.build_count=0,.validate_count=0,.reject_count=0,.reset_count=resets,.attempt_count=0,.attempt_result=.none,.deterministic_blocker=.stub_empty,.last_error=.none }; }
pub fn reset() void { const p=mutable(); stub = empty(p.owner_vm_id, p.owner_vcpu_id, p.reset_count + 1); initialized = true; }

fn add(a: usize, b: usize) ?usize { if (a > (~@as(usize,0)) - b) return null; return a + b; }
fn pointIn(base: usize, size: usize, p: usize) bool { const e=add(base,size) orelse return false; return p >= base and p < e; }

pub fn prepare() Result {
    if (trap_plan.object().state != .validated and trap_plan.prepare() != .ok) return reject(.trap_plan_missing);
    return assembleFromTrapPlan();
}

fn assembleFromTrapPlan() Result {
    const p=mutable(); const c=trap_plan.object(); const st=second_stage.object(); const tbl=stage2_table.object(); const disp=sbi_dispatch.object();
    p.owner_vm_id = c.owner_vm_id; p.owner_vcpu_id = c.owner_vcpu_id; p.source_trap_plan_state = c.state;
    p.planned_pc = c.planned_pc; p.planned_sp = c.planned_sp; p.planned_a0 = c.planned_a0; p.planned_a1 = c.planned_a1; p.planned_a2 = c.planned_a2;
    p.status_metadata = c.status_metadata; p.privilege_metadata = c.privilege_metadata; p.trap_return_kind_metadata = c.trap_return_kind_metadata; p.entry_mode_metadata = c.entry_mode_metadata; p.stub_address = @intFromPtr(&guarded_entry_stub_bytes); p.stub_size = guarded_entry_stub_bytes.len;
    p.guest_memory_base = c.guest_memory_base; p.guest_memory_size = c.guest_memory_size;
    p.stage2_metadata_ready = c.stage2_metadata_ready and st.state == .metadata_ready and st.mapping.validated and !st.mapping.active;
    p.stage2_table_ready = c.stage2_table_ready and (tbl.state == .built or tbl.state == .validated) and tbl.entry_count > 0 and !tbl.active;
    p.active_stage2_forbidden = !st.mapping.active and !tbl.active; p.hgatp_write_forbidden = true; p.h_extension_claimed = false; p.h_extension_unknown = true;
    p.sbi_dispatch_ready = c.sbi_dispatch_ready and disp.state == .ready and disp.last_error == .none;
    _ = guest_run_attempt.armNoExecute();
    _ = guest_execution.arm();
    p.run_attempt_gate_ready = guest_run_attempt.object().state == .armed_no_execute or guest_run_attempt.object().state == .checked or guest_run_attempt.object().state == .blocked;
    p.execution_gate_ready = guest_execution.object().state == .armed_blocked or guest_execution.object().state == .blocked or guest_execution.object().state == .validated;
    p.stub_checksum = computeChecksum(p.*); p.build_count += 1; p.state=.prepared; p.last_error=.none; p.deterministic_blocker=.none;
    return validate();
}

fn firstBlocker() Error {
    const p=object(); const c=trap_plan.object(); const st=second_stage.object(); const tbl=stage2_table.object();
    if (p.state == .empty) return .stub_empty;
    if (c.state != .validated) return .trap_plan_missing;
    if (p.source_trap_plan_state != .validated or p.guest_memory_size == 0) return .trap_plan_malformed;
    if (p.owner_vm_id != vm.object().id or p.owner_vcpu_id != vcpu.object().id) return .owner_mismatch;
    if (!pointIn(p.guest_memory_base, p.guest_memory_size, p.planned_pc)) return .pc_bounds;
    if (!pointIn(p.guest_memory_base, p.guest_memory_size, p.planned_sp)) return .sp_bounds;
    if (!pointIn(p.guest_memory_base, p.guest_memory_size, p.planned_a1)) return .fdt_bounds;
    if (!p.sbi_dispatch_ready) return .sbi_dispatch_missing;
    if (st.mapping.active or tbl.active or !p.active_stage2_forbidden) return .active_stage2_forbidden;
    if (!p.stage2_metadata_ready or !p.stage2_table_ready) return .stage2_missing;
    if (!p.execution_gate_ready) return .execution_gate_missing;
    if (!p.run_attempt_gate_ready) return .run_attempt_gate_missing;
    return .none;
}

fn mix(x: usize, y: usize) usize { return (x ^% (y +% 0x9e37_79b9_7f4a_7c15)) *% 0xbf58_476d_1ce4_e5b9; }
fn computeChecksum(p: EntryStub) usize { var h: usize = 0x4856_3233_4553_5455; h = mix(h, p.owner_vm_id); h = mix(h, p.owner_vcpu_id); h = mix(h, p.planned_pc); h = mix(h, p.planned_sp); h = mix(h, p.planned_a0); h = mix(h, p.planned_a1); h = mix(h, p.planned_a2); h = mix(h, p.status_metadata); h = mix(h, p.privilege_metadata); h = mix(h, p.trap_return_kind_metadata); h = mix(h, p.entry_mode_metadata); h = mix(h, p.stub_address); h = mix(h, p.stub_size); h = mix(h, p.guest_memory_base); h = mix(h, p.guest_memory_size); return if (h == 0) 1 else h; }
const guarded_entry_stub_bytes = [_]u8{ 0x48, 0x56, 0x32, 0x33, 0x45, 0x4e, 0x54, 0x52, 0x59, 0x53, 0x54, 0x55, 0x42, 0x00, 0x00, 0x01 };

pub fn validate() Result { const p=mutable(); p.validate_count += 1; const e=firstBlocker(); if (e != .none) return reject(e); p.state=.validated; p.last_error=.none; p.deterministic_blocker=.none; return .ok; }
fn reject(e: Error) Result { const p=mutable(); p.reject_count += 1; p.last_error=e; p.deterministic_blocker=e; p.state=.rejected; return .rejected; }

pub fn guardedAttempt() Result { const p=mutable(); if (p.state != .validated and validate() != .ok) { p.attempt_count += 1; p.attempt_result=.blocked_safe_denied; return .rejected; } p.attempt_count += 1; p.attempt_result=.blocked_safe_denied; p.last_error=.guest_entry_not_enabled; p.deterministic_blocker=.guest_entry_not_enabled; return .rejected; }

pub fn printStatusCommand() void { printSummary(); printBlockers(); printNonClaims(); }
pub fn printPrepareCommand() void { const r=prepare(); printResult("prepare_result", r); printSummary(); printRegisters(); printGates(); printBlockers(); printNonClaims(); }
pub fn printValidateCommand() void { const r=validate(); printResult("validate_result", r); printSummary(); printBlockers(); printNonClaims(); }
pub fn printBlockersCommand() void { printBlockers(); printNonClaims(); }
pub fn printRegistersCommand() void { printRegisters(); printNonClaims(); }
pub fn printGatesCommand() void { printGates(); printNonClaims(); }
pub fn printDescriptorCommand() void { printDescriptor(); printNonClaims(); }
pub fn printChecksumCommand() void { const p=mutable(); p.stub_checksum = computeChecksum(p.*); uart.write("hv: entry_stub.checksum="); uart.writeHex(p.stub_checksum); uart.write("\r\n"); printNonClaims(); }
pub fn printAttemptCommand() void { const r=guardedAttempt(); uart.write("hv: guarded_entry_attempt="); uart.write(if (r==.rejected) "blocked" else "unexpected"); uart.write("\r\n"); printSummary(); printNonClaims(); }
pub fn printResetCommand() void { reset(); uart.write("hv: entry_stub.reset_result=ok\r\n"); printSummary(); printBlockers(); printNonClaims(); }
pub fn printRequirePlanTestCommand() void { trap_plan.reset(); const r=assembleFromTrapPlan(); uart.write("hv: entry_stub.require_plan_test="); uart.write(if (r==.rejected) "rejected" else "failed-to-reject"); uart.write("\r\n"); printSummary(); printBlockers(); printNonClaims(); }
pub fn printPcBoundsTestCommand() void { _=prepare(); mutable().planned_pc = mutable().guest_memory_base + mutable().guest_memory_size + 4; const r=validate(); testResult("pc_bounds_test", r); }
pub fn printSpBoundsTestCommand() void { _=prepare(); mutable().planned_sp = mutable().guest_memory_base + mutable().guest_memory_size + 8; const r=validate(); testResult("sp_bounds_test", r); }
pub fn printFdtBoundsTestCommand() void { _=prepare(); mutable().planned_a1 = mutable().guest_memory_base + mutable().guest_memory_size + 12; const r=validate(); testResult("fdt_bounds_test", r); }
pub fn printActiveStage2TestCommand() void { _=prepare(); mutable().active_stage2_forbidden = false; const r=validate(); testResult("active_stage2_test", r); }

fn testResult(name: []const u8, r: Result) void { uart.write("hv: entry_stub."); uart.write(name); uart.write("="); uart.write(if (r==.rejected) "rejected" else "failed-to-reject"); uart.write("\r\n"); printSummary(); printBlockers(); printNonClaims(); }
fn printResult(name: []const u8, r: Result) void { uart.write("hv: entry_stub."); uart.write(name); uart.write("="); uart.write(if (r==.ok) "ok" else "rejected"); uart.write("\r\n"); }
fn printSummary() void { const p=object(); uart.write("hv: entry_stub="); uart.write(if (p.state==.validated) "prepared" else @tagName(p.state)); uart.write("\r\n"); uart.write("hv: entry_stub.state="); uart.write(@tagName(p.state)); uart.write("\r\n"); uart.write("hv: entry_stub.ready="); uart.write(if (p.state==.validated) "true" else "false"); uart.write("\r\n"); uart.write("hv: entry_stub.owner_vm_id="); uart.writeDec(p.owner_vm_id); uart.write("\r\n"); uart.write("hv: entry_stub.owner_vcpu_id="); uart.writeDec(p.owner_vcpu_id); uart.write("\r\n"); uart.write("hv: entry_stub.source_trap_plan_state="); uart.write(@tagName(p.source_trap_plan_state)); uart.write("\r\n"); uart.write("hv: entry_stub.guest_memory.base="); uart.writeHex(p.guest_memory_base); uart.write("\r\n"); uart.write("hv: entry_stub.guest_memory.size="); uart.writeDec(p.guest_memory_size); uart.write("\r\n"); printGates(); uart.write("hv: entry_stub.build_count="); uart.writeDec(p.build_count); uart.write("\r\n"); uart.write("hv: entry_stub.validate_count="); uart.writeDec(p.validate_count); uart.write("\r\n"); uart.write("hv: entry_stub.reject_count="); uart.writeDec(p.reject_count); uart.write("\r\n"); uart.write("hv: entry_stub.reset_count="); uart.writeDec(p.reset_count); uart.write("\r\n"); uart.write("hv: entry_stub.attempt_count="); uart.writeDec(p.attempt_count); uart.write("\r\n"); uart.write("hv: guarded_entry_attempt_result="); uart.write(if (p.attempt_result==.blocked_safe_denied) "safe-denied" else "none"); uart.write("\r\n"); uart.write("hv: entry_stub.last_error="); uart.write(errorName(p.last_error)); uart.write("\r\n"); }
fn printDescriptor() void { const p=object(); uart.write("hv: entry_stub.descriptor.address="); uart.writeHex(p.stub_address); uart.write("\r\n"); uart.write("hv: entry_stub.descriptor.size="); uart.writeDec(p.stub_size); uart.write("\r\n"); uart.write("hv: entry_stub.descriptor.kind=software-only-not-executable\r\n"); uart.write("hv: entry_stub.descriptor.checksum="); uart.writeHex(p.stub_checksum); uart.write("\r\n"); }
fn printRegisters() void { const p=object(); uart.write("hv: entry_stub.pc="); uart.writeHex(p.planned_pc); uart.write("\r\n"); uart.write("hv: entry_stub.sp="); uart.writeHex(p.planned_sp); uart.write("\r\n"); uart.write("hv: entry_stub.a0_boot_hart_id="); uart.writeDec(p.planned_a0); uart.write("\r\n"); uart.write("hv: entry_stub.a1_fdt_gpa="); uart.writeHex(p.planned_a1); uart.write("\r\n"); uart.write("hv: entry_stub.a2_reserved=0x0\r\n"); uart.write("hv: entry_stub.status_metadata="); uart.writeHex(p.status_metadata); uart.write("\r\n"); uart.write("hv: entry_stub.privilege_metadata=supervisor-mode-metadata-only\r\n"); uart.write("hv: entry_stub.trap_return_kind=software-entry-stub-only\r\n"); uart.write("hv: entry_stub.entry_mode=entry-stub-prepared-not-entered\r\n"); }
fn printGates() void { const p=object(); uart.write("hv: entry_stub.stage2_metadata_ready="); uart.write(if (p.stage2_metadata_ready) "true" else "false"); uart.write("\r\n"); uart.write("hv: entry_stub.stage2_table_ready="); uart.write(if (p.stage2_table_ready) "true" else "false"); uart.write("\r\n"); uart.write("hv: entry_stub.active_stage2=false\r\n"); uart.write("hv: entry_stub.active_stage2_forbidden="); uart.write(if (p.active_stage2_forbidden) "true" else "false"); uart.write("\r\n"); uart.write("hv: entry_stub.hgatp_write_forbidden=true\r\n"); uart.write("hv: entry_stub.h_extension=unknown reason=no-safe-detection-yet\r\n"); uart.write("hv: entry_stub.execution_gate_ready="); uart.write(if (p.execution_gate_ready) "true" else "false"); uart.write("\r\n"); uart.write("hv: entry_stub.run_attempt_gate_ready="); uart.write(if (p.run_attempt_gate_ready) "true" else "false"); uart.write("\r\n"); uart.write("hv: entry_stub.sbi_dispatch_ready="); uart.write(if (p.sbi_dispatch_ready) "true" else "false"); uart.write("\r\n"); }
fn printBlockers() void {
    const e = firstBlocker();
    const blocker_count: usize = if (e == .none) 0 else 1;

    uart.write("hv: entry_stub.blocker_count=");
    uart.writeDec(blocker_count);
    uart.write("\r\n");

    uart.write("hv: entry_stub.blocker=");
    uart.write(errorName(e));
    uart.write("\r\n");

    uart.write("hv: entry_stub.blockers=deterministic-from-entry-stub-state\r\n");
}
fn errorName(e: Error) []const u8 { return switch(e){ .none=>"none",.stub_empty=>"stub-empty",.trap_plan_missing=>"trap-plan-missing",.trap_plan_malformed=>"trap-plan-malformed",.owner_mismatch=>"owner-mismatch",.pc_bounds=>"pc-bounds",.sp_bounds=>"sp-bounds",.fdt_bounds=>"fdt-bounds",.sbi_dispatch_missing=>"sbi-dispatch-missing",.execution_gate_missing=>"execution-gate-missing",.run_attempt_gate_missing=>"run-attempt-gate-missing",.stage2_missing=>"stage2-missing",.active_stage2_forbidden=>"active-stage2-forbidden",.entry_stub_not_executable=>"entry-stub-not-executable",.guest_entry_not_enabled=>"guest-entry-not-enabled" }; }
fn printNonClaims() void { uart.write("hv: trap_return=not-executed\r\n"); uart.write("hv: guest_entered=no\r\n"); uart.write("hv: first_guest_instruction=not-executed\r\n"); uart.write("hv: entry_stub_execution=not-attempted\r\n"); uart.write("hv: hgatp_write=not-attempted\r\n"); uart.write("hv: h_extension=unknown reason=no-safe-detection-yet\r\n"); uart.write("hv: linux_guest=not-supported-yet\r\n"); uart.write("hv: guest_execution=not-supported-yet\r\n"); uart.write("hv: second_stage_translation=MISSING\r\n"); uart.write("hv: printk=not-proven-yet\r\n"); }
