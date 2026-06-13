const uart = @import("../console/uart.zig");
const vm_model = @import("vm.zig");
const vcpu_model = @import("vcpu.zig");
const sbi = @import("sbi.zig");

pub const TimerState = enum { empty, armed, expired };
pub const ValidationResult = enum { ok, missing_owner, not_armed, missing_compare, pending_not_computed };
pub const RequestResult = enum { ok, rejected };

pub const VirtualTimer = struct {
    owner_vm_id: vm_model.VmId,
    owner_vcpu_id: vcpu_model.VcpuId,
    state: TimerState,
    host_tick_snapshot: usize,
    guest_compare_value: usize,
    pending_interrupt: bool,
    armed: bool,
    set_request_count: usize,
    query_request_count: usize,
    expiration_count: usize,
    rejected_request_count: usize,
    reset_count: usize,
    last_sbi_extension_id: usize,
    last_sbi_function_id: usize,
    last_requested_timer_value: usize,
    last_validation_result: ValidationResult,
    last_request_result: RequestResult,
};

const timer_extension_id: usize = 0x54494d45;
const timer_set_function_id: usize = 0;
const default_compare: usize = 100;
const default_now_before: usize = 40;
const pending_compare: usize = 80;
const pending_now_after: usize = 81;

var state: VirtualTimer = undefined;
var initialized = false;

pub fn init(owner_vm_id: vm_model.VmId, owner_vcpu_id: vcpu_model.VcpuId) void {
    state = empty(owner_vm_id, owner_vcpu_id, 0);
    initialized = true;
}

pub fn object() *const VirtualTimer { return mutable(); }
fn mutable() *VirtualTimer { if (!initialized) init(vm_model.object().id, vcpu_model.object().id); return &state; }

fn empty(owner_vm_id: vm_model.VmId, owner_vcpu_id: vcpu_model.VcpuId, reset_count: usize) VirtualTimer {
    return .{
        .owner_vm_id = owner_vm_id,
        .owner_vcpu_id = owner_vcpu_id,
        .state = .empty,
        .host_tick_snapshot = 0,
        .guest_compare_value = 0,
        .pending_interrupt = false,
        .armed = false,
        .set_request_count = 0,
        .query_request_count = 0,
        .expiration_count = 0,
        .rejected_request_count = 0,
        .reset_count = reset_count,
        .last_sbi_extension_id = 0,
        .last_sbi_function_id = 0,
        .last_requested_timer_value = 0,
        .last_validation_result = .not_armed,
        .last_request_result = .ok,
    };
}

pub fn reset() void { const t = mutable(); state = empty(t.owner_vm_id, t.owner_vcpu_id, t.reset_count + 1); initialized = true; }

pub fn applySbiTimerSet(compare_value: usize, now_ticks: usize) RequestResult {
    const args = [_]usize{ compare_value, 0, 0, 0, 0, 0 };
    const rec = sbi.recordRequest(timer_extension_id, timer_set_function_id, args);
    const t = mutable();
    t.last_sbi_extension_id = timer_extension_id;
    t.last_sbi_function_id = timer_set_function_id;
    t.last_requested_timer_value = compare_value;
    if (rec != .ok or compare_value == 0) {
        t.rejected_request_count += 1;
        t.last_request_result = .rejected;
        t.last_validation_result = .missing_compare;
        return .rejected;
    }
    t.set_request_count += 1;
    t.host_tick_snapshot = now_ticks;
    t.guest_compare_value = compare_value;
    t.armed = true;
    t.last_request_result = .ok;
    recomputePending(t, nowTicksForCompare(now_ticks, compare_value));
    _ = validate();
    return .ok;
}

fn nowTicksForCompare(now_ticks: usize, compare_value: usize) usize { _ = compare_value; return now_ticks; }

pub fn queryPending(now_ticks: usize) bool {
    const t = mutable();
    t.query_request_count += 1;
    recomputePending(t, now_ticks);
    _ = validate();
    return t.pending_interrupt;
}

fn recomputePending(t: *VirtualTimer, now_ticks: usize) void {
    t.host_tick_snapshot = now_ticks;
    if (!t.armed or t.guest_compare_value == 0) {
        t.pending_interrupt = false;
        if (!t.armed) t.state = .empty;
        return;
    }
    const was_pending = t.pending_interrupt;
    t.pending_interrupt = now_ticks >= t.guest_compare_value;
    if (t.pending_interrupt) {
        t.state = .expired;
        if (!was_pending) t.expiration_count += 1;
    } else {
        t.state = .armed;
    }
}

pub fn validate() ValidationResult {
    const t = mutable();
    if (t.owner_vm_id != vm_model.object().id or t.owner_vcpu_id != vcpu_model.object().id) return finishValidation(.missing_owner);
    if (!t.armed) return finishValidation(.not_armed);
    if (t.guest_compare_value == 0) return finishValidation(.missing_compare);
    return finishValidation(.ok);
}
fn finishValidation(r: ValidationResult) ValidationResult { mutable().last_validation_result = r; return r; }

pub fn printState() void { printImplementedMarker(); printFields(); printBlockers(false); printNonClaims(); }
pub fn printStatusCommand() void { printState(); }
pub fn printArmCommand() void { const r = applySbiTimerSet(default_compare, default_now_before); printRequestResult("arm_result", r); printFields(); printNonClaims(); }
pub fn printSbiSetTestCommand() void { const r = applySbiTimerSet(default_compare, default_now_before); printRequestResult("sbi_set_test", r); printFields(); sbi.printStatusCommand(); printNonClaims(); }
pub fn printInvalidTestCommand() void { const r = applySbiTimerSet(0, default_now_before); printRequestResult("invalid_test", r); printFields(); sbi.printStatusCommand(); printNonClaims(); }
pub fn printPendingTestCommand() void { _ = applySbiTimerSet(pending_compare, default_now_before); const before = queryPending(default_now_before); const after = queryPending(pending_now_after); uart.write("hv: virtual_timer.pending_before_compare="); uart.write(if (before) "true" else "false"); uart.write("\r\n"); uart.write("hv: virtual_timer.pending_after_compare="); uart.write(if (after) "true" else "false"); uart.write("\r\n"); printFields(); printNonClaims(); }
pub fn printValidateCommand() void { const r = validate(); uart.write("hv: virtual_timer.validate_result="); uart.write(validationName(r)); uart.write("\r\n"); printFields(); printBlockers(false); printNonClaims(); }
pub fn printBlockersCommand() void { _ = validate(); printBlockers(true); printFields(); printNonClaims(); }
pub fn printResetCommand() void { reset(); uart.write("hv: virtual_timer.reset_result=ok\r\n"); printFields(); printBlockers(false); printNonClaims(); }

pub fn printImplementedMarker() void { uart.write("hv: virtual_timer=foundation-metadata-only\r\n"); }
fn printRequestResult(name: []const u8, r: RequestResult) void { uart.write("hv: virtual_timer."); uart.write(name); uart.write("="); uart.write(if (r == .ok) "ok" else "rejected"); uart.write("\r\n"); }
fn printFields() void {
    const t = object();
    uart.write("hv: virtual_timer.owner_vm_id="); uart.writeDec(t.owner_vm_id); uart.write("\r\n");
    uart.write("hv: virtual_timer.owner_vcpu_id="); uart.writeDec(t.owner_vcpu_id); uart.write("\r\n");
    uart.write("hv: virtual_timer.state="); uart.write(stateName(t.state)); uart.write("\r\n");
    uart.write("hv: virtual_timer.armed="); uart.write(if (t.armed) "true" else "false"); uart.write("\r\n");
    uart.write("hv: virtual_timer.host_tick_snapshot="); uart.writeDec(t.host_tick_snapshot); uart.write("\r\n");
    uart.write("hv: virtual_timer.guest_compare_value="); uart.writeDec(t.guest_compare_value); uart.write("\r\n");
    uart.write("hv: virtual_timer.pending_interrupt="); uart.write(if (t.pending_interrupt) "true" else "false"); uart.write("\r\n");
    uart.write("hv: virtual_timer.set_request_count="); uart.writeDec(t.set_request_count); uart.write("\r\n");
    uart.write("hv: virtual_timer.query_request_count="); uart.writeDec(t.query_request_count); uart.write("\r\n");
    uart.write("hv: virtual_timer.expiration_count="); uart.writeDec(t.expiration_count); uart.write("\r\n");
    uart.write("hv: virtual_timer.rejected_request_count="); uart.writeDec(t.rejected_request_count); uart.write("\r\n");
    uart.write("hv: virtual_timer.reset_count="); uart.writeDec(t.reset_count); uart.write("\r\n");
    uart.write("hv: virtual_timer.last_sbi_extension_id="); uart.writeHex(t.last_sbi_extension_id); uart.write("\r\n");
    uart.write("hv: virtual_timer.last_sbi_function_id="); uart.writeDec(t.last_sbi_function_id); uart.write("\r\n");
    uart.write("hv: virtual_timer.last_requested_timer_value="); uart.writeDec(t.last_requested_timer_value); uart.write("\r\n");
    uart.write("hv: virtual_timer.last_validation_result="); uart.write(validationName(t.last_validation_result)); uart.write("\r\n");
    uart.write("hv: virtual_timer.last_request_result="); uart.write(if (t.last_request_result == .ok) "ok" else "rejected"); uart.write("\r\n");
}
fn printBlockers(verbose: bool) void {
    const t = object();
    var count: usize = 0;
    if (t.owner_vm_id != vm_model.object().id or t.owner_vcpu_id != vcpu_model.object().id) count += 1;
    if (!t.armed) count += 1;
    if (t.guest_compare_value == 0) count += 1;
    uart.write("hv: virtual_timer.blocker_count="); uart.writeDec(count); uart.write("\r\n");
    if (count == 0) { uart.write("hv: virtual_timer.blocker=none\r\n"); return; }
    if (t.owner_vm_id != vm_model.object().id or t.owner_vcpu_id != vcpu_model.object().id) uart.write("hv: virtual_timer.blocker=owner-mismatch\r\n");
    if (!t.armed) uart.write("hv: virtual_timer.blocker=not-armed\r\n");
    if (t.guest_compare_value == 0) uart.write("hv: virtual_timer.blocker=missing-compare\r\n");
    if (verbose) uart.write("hv: virtual_timer.blockers=deterministic-from-object-fields\r\n");
}
fn stateName(s: TimerState) []const u8 { return switch (s) { .empty => "empty", .armed => "armed", .expired => "expired" }; }
fn validationName(r: ValidationResult) []const u8 { return switch (r) { .ok => "ok", .missing_owner => "missing-owner", .not_armed => "not-armed", .missing_compare => "missing-compare", .pending_not_computed => "pending-not-computed" }; }
fn printNonClaims() void { uart.write("hv: timer_interrupt_delivery=not-implemented\r\n"); uart.write("hv: sbi_timer_service=metadata-only\r\n"); uart.write("hv: linux_guest=not-supported-yet\r\n"); uart.write("hv: guest_execution=not-supported-yet\r\n"); uart.write("hv: second_stage_translation=MISSING\r\n"); }
