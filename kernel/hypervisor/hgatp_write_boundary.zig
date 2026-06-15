const uart = @import("../console/uart.zig");
const vm = @import("vm.zig");
const vcpu = @import("vcpu.zig");
const hgatp_write_gate = @import("hgatp_write_gate.zig");
const h_extension = @import("h_extension.zig");
const second_stage = @import("second_stage.zig");
const stage2_table = @import("stage2_table.zig");

pub const HgatpWriteBoundaryState = enum { empty, observed, ready, rejected };
pub const HgatpWriteBoundaryBlocker = enum { none, empty_boundary, missing_write_gate, invalid_write_gate, gate_does_not_block_before_hardware, gate_allows_hardware_boundary, source_mutated, request_value_mismatch, boundary_request_allowed, hardware_boundary_reached, hgatp_write_attempted, hgatp_write_performed, active_stage2_forbidden };
pub const HgatpWriteBoundaryDecision = enum { none, deny_before_hardware, reject_source_state, reject_boundary_violation };
pub const HgatpWriteBoundaryNextAction = enum { none, build_write_gate_externally, validate_write_gate_externally, keep_gate_blocking_before_hardware, investigate_source_mutation, inspect_request_value, stop_boundary_request_allowed, stop_hardware_boundary_observed, stop_hgatp_write_attempt_observed, stop_hgatp_write_performed_observed, stop_active_stage2_observed };
pub const HgatpWriteBoundaryFingerprint = struct { write_gate_state: usize, write_gate_ready: bool, write_gate_checksum: usize, gate_decision: usize, planned_hgatp_value: usize, request_blocked_before_hardware: bool, request_allowed_to_reach_hardware_boundary: bool, hgatp_write_attempted: bool, hgatp_write_performed: bool, hardware_write_boundary_reached: bool, active_stage2: bool, h_extension_hgatp_write_status: usize, second_stage_active: bool, stage2_table_active: bool, vm_id: vm.VmId, vcpu_id: vcpu.VcpuId, checksum: usize };
pub const HgatpWriteBoundarySourceSummary = struct { write_gate_present: bool, write_gate_valid: bool, write_gate_checksum: usize, gate_decision: usize, gate_blocks_before_hardware: bool, gate_allows_hardware_boundary: bool, planned_hgatp_value: usize, planned_vmid: usize, planned_root_ppn: usize, planned_mode: usize, hgatp_write_attempted: bool, hgatp_write_performed: bool, hardware_boundary_reached: bool, active_stage2: bool };
pub const HgatpWriteBoundaryRequest = struct { owner_vm_id: vm.VmId, owner_vcpu_id: vcpu.VcpuId, request_value: usize, request_checksum: usize, denied: bool, allowed: bool };
pub const HgatpWriteBoundary = struct { owner_vm_id: vm.VmId, owner_vcpu_id: vcpu.VcpuId, write_gate_present: bool, write_gate_valid: bool, write_gate_checksum: usize, gate_decision: usize, gate_blocks_before_hardware: bool, gate_allows_hardware_boundary: bool, planned_hgatp_value: usize, planned_vmid: usize, planned_root_ppn: usize, planned_mode: usize, source_fingerprint_before: HgatpWriteBoundaryFingerprint, source_fingerprint_after: HgatpWriteBoundaryFingerprint, source_fingerprint_unchanged: bool, boundary_request_seen: bool, boundary_request_denied: bool, boundary_request_allowed: bool, hardware_boundary_reached: bool, hgatp_write_attempted: bool, hgatp_write_performed: bool, active_stage2: bool, request_value: usize, request_checksum: usize, denied_request_count: usize, allowed_request_count: usize, boundary_reach_count: usize, write_attempt_count: usize, write_performed_count: usize, decision: HgatpWriteBoundaryDecision, next_action: HgatpWriteBoundaryNextAction, blocker: HgatpWriteBoundaryBlocker, blocker_count: usize, checksum: usize, state: HgatpWriteBoundaryState, ready: bool, last_error: HgatpWriteBoundaryBlocker, build_count: usize, validate_count: usize, reject_count: usize, reset_count: usize };

var boundary: HgatpWriteBoundary = undefined;
var initialized = false;

fn tag(e: anytype) usize { return @intFromEnum(e);
}
fn mix(a: usize, b: usize) usize { return (a ^ b) *% 0x9e37_79b9_7f4a_7c15;
}
fn boolInt(v: bool) usize { return if (v) 1 else 0;
}
fn emptyFp() HgatpWriteBoundaryFingerprint {
    return .{ .write_gate_state = 0,
        .write_gate_ready = false,
        .write_gate_checksum = 0,
        .gate_decision = 0,
        .planned_hgatp_value = 0,
        .request_blocked_before_hardware = false,
        .request_allowed_to_reach_hardware_boundary = false,
        .hgatp_write_attempted = false,
        .hgatp_write_performed = false,
        .hardware_write_boundary_reached = false,
        .active_stage2 = false,
        .h_extension_hgatp_write_status = 0,
        .second_stage_active = false,
        .stage2_table_active = false,
        .vm_id = 0,
        .vcpu_id = 0,
        .checksum = 0 };
}
fn empty(owner: vm.VmId, owner_vcpu: vcpu.VcpuId, resets: usize) HgatpWriteBoundary {
    return .{ .owner_vm_id = owner,
        .owner_vcpu_id = owner_vcpu,
        .write_gate_present = false,
        .write_gate_valid = false,
        .write_gate_checksum = 0,
        .gate_decision = 0,
        .gate_blocks_before_hardware = false,
        .gate_allows_hardware_boundary = false,
        .planned_hgatp_value = 0,
        .planned_vmid = 0,
        .planned_root_ppn = 0,
        .planned_mode = 0,
        .source_fingerprint_before = emptyFp(),
        .source_fingerprint_after = emptyFp(),
        .source_fingerprint_unchanged = false,
        .boundary_request_seen = false,
        .boundary_request_denied = false,
        .boundary_request_allowed = false,
        .hardware_boundary_reached = false,
        .hgatp_write_attempted = false,
        .hgatp_write_performed = false,
        .active_stage2 = false,
        .request_value = 0,
        .request_checksum = 0,
        .denied_request_count = 0,
        .allowed_request_count = 0,
        .boundary_reach_count = 0,
        .write_attempt_count = 0,
        .write_performed_count = 0,
        .decision = .none,
        .next_action = .none,
        .blocker = .none,
        .blocker_count = 0,
        .checksum = 0,
        .state = .empty,
        .ready = false,
        .last_error = .none,
        .build_count = 0,
        .validate_count = 0,
        .reject_count = 0,
        .reset_count = resets };
}
pub fn init(owner: vm.VmId, owner_vcpu: vcpu.VcpuId) void { boundary = empty(owner, owner_vcpu, 0);
initialized = true;
}
fn mutable() *HgatpWriteBoundary { if (!initialized) init(vm.object().id, vcpu.object().id);
return &boundary;
}
pub fn object() *const HgatpWriteBoundary { return mutable();
}
pub fn reset() void { const r = mutable().reset_count + 1;
boundary = empty(vm.object().id, vcpu.object().id, r);
initialized = true;
}

fn fpChecksum(f: HgatpWriteBoundaryFingerprint) usize { var x: usize = 0x2929;
x = mix(x, f.write_gate_state);
x = mix(x, boolInt(f.write_gate_ready));
x = mix(x, f.write_gate_checksum);
x = mix(x, f.gate_decision);
x = mix(x, f.planned_hgatp_value);
x = mix(x, boolInt(f.request_blocked_before_hardware));
x = mix(x, boolInt(f.request_allowed_to_reach_hardware_boundary));
x = mix(x, boolInt(f.hgatp_write_attempted));
x = mix(x, boolInt(f.hgatp_write_performed));
x = mix(x, boolInt(f.hardware_write_boundary_reached));
x = mix(x, boolInt(f.active_stage2));
x = mix(x, f.h_extension_hgatp_write_status);
x = mix(x, boolInt(f.second_stage_active));
x = mix(x, boolInt(f.stage2_table_active));
x = mix(x, @intCast(f.vm_id));
x = mix(x, @intCast(f.vcpu_id));
return if (x == 0) 1 else x;
}
pub fn readSourceFingerprint() HgatpWriteBoundaryFingerprint { const g = hgatp_write_gate.object();
const he = h_extension.object();
const ss = second_stage.object();
const tbl = stage2_table.object();
var f = HgatpWriteBoundaryFingerprint{ .write_gate_state = tag(g.state),
        .write_gate_ready = g.ready,
        .write_gate_checksum = g.checksum,
        .gate_decision = tag(g.decision),
        .planned_hgatp_value = g.planned_hgatp_value,
        .request_blocked_before_hardware = g.request_blocked_before_hardware,
        .request_allowed_to_reach_hardware_boundary = g.request_allowed_to_reach_hardware_boundary,
        .hgatp_write_attempted = g.hgatp_write_attempted,
        .hgatp_write_performed = g.hgatp_write_performed,
        .hardware_write_boundary_reached = g.hardware_write_boundary_reached,
        .active_stage2 = g.active_stage2,
        .h_extension_hgatp_write_status = tag(he.hgatp_write_status),
        .second_stage_active = ss.mapping.active,
        .stage2_table_active = tbl.active,
        .vm_id = vm.object().id,
        .vcpu_id = vcpu.object().id,
        .checksum = 0 };
f.checksum = fpChecksum(f);
return f;
}
fn sameFp(a: HgatpWriteBoundaryFingerprint, b: HgatpWriteBoundaryFingerprint) bool { return a.checksum == b.checksum and a.write_gate_state == b.write_gate_state and a.write_gate_ready == b.write_gate_ready and a.write_gate_checksum == b.write_gate_checksum and a.gate_decision == b.gate_decision and a.planned_hgatp_value == b.planned_hgatp_value and a.request_blocked_before_hardware == b.request_blocked_before_hardware and a.request_allowed_to_reach_hardware_boundary == b.request_allowed_to_reach_hardware_boundary and a.hgatp_write_attempted == b.hgatp_write_attempted and a.hgatp_write_performed == b.hgatp_write_performed and a.hardware_write_boundary_reached == b.hardware_write_boundary_reached and a.active_stage2 == b.active_stage2 and a.h_extension_hgatp_write_status == b.h_extension_hgatp_write_status and a.second_stage_active == b.second_stage_active and a.stage2_table_active == b.stage2_table_active and a.vm_id == b.vm_id and a.vcpu_id == b.vcpu_id;
}
fn sourceSummary() HgatpWriteBoundarySourceSummary { const g = hgatp_write_gate.object();
const ss = second_stage.object();
const tbl = stage2_table.object();
return .{ .write_gate_present = g.state != .empty and g.checksum != 0,
        .write_gate_valid = g.state == .ready and g.ready,
        .write_gate_checksum = g.checksum,
        .gate_decision = tag(g.decision),
        .gate_blocks_before_hardware = g.request_blocked_before_hardware,
        .gate_allows_hardware_boundary = g.request_allowed_to_reach_hardware_boundary,
        .planned_hgatp_value = g.planned_hgatp_value,
        .planned_vmid = g.planned_vmid,
        .planned_root_ppn = g.planned_root_ppn,
        .planned_mode = g.planned_mode,
        .hgatp_write_attempted = g.hgatp_write_attempted,
        .hgatp_write_performed = g.hgatp_write_performed,
        .hardware_boundary_reached = g.hardware_write_boundary_reached,
        .active_stage2 = g.active_stage2 or ss.mapping.active or tbl.active };
}
fn requestChecksum(req: HgatpWriteBoundaryRequest) usize { var x: usize = 0x29;
x = mix(x, @intCast(req.owner_vm_id));
x = mix(x, @intCast(req.owner_vcpu_id));
x = mix(x, req.request_value);
x = mix(x, boolInt(req.denied));
x = mix(x, boolInt(req.allowed));
return if (x == 0) 1 else x;
}
fn boundaryChecksum(r: HgatpWriteBoundary) usize { var x: usize = 0x292929;
x = mix(x, r.source_fingerprint_before.checksum);
x = mix(x, r.source_fingerprint_after.checksum);
x = mix(x, r.write_gate_checksum);
x = mix(x, r.planned_hgatp_value);
x = mix(x, r.request_value);
x = mix(x, r.request_checksum);
x = mix(x, tag(r.decision));
x = mix(x, tag(r.next_action));
x = mix(x, tag(r.blocker));
x = mix(x, boolInt(r.boundary_request_denied));
return if (x == 0) 1 else x;
}
fn firstBlocker(r: HgatpWriteBoundary) HgatpWriteBoundaryBlocker { if (r.state == .empty) return .empty_boundary;
if (!r.write_gate_present) return .missing_write_gate;
if (!r.write_gate_valid) return .invalid_write_gate;
if (!r.gate_blocks_before_hardware) return .gate_does_not_block_before_hardware;
if (r.gate_allows_hardware_boundary) return .gate_allows_hardware_boundary;
if (!r.source_fingerprint_unchanged) return .source_mutated;
if (r.request_value != r.planned_hgatp_value) return .request_value_mismatch;
if (r.boundary_request_allowed) return .boundary_request_allowed;
if (r.hardware_boundary_reached) return .hardware_boundary_reached;
if (r.hgatp_write_attempted) return .hgatp_write_attempted;
if (r.hgatp_write_performed) return .hgatp_write_performed;
if (r.active_stage2) return .active_stage2_forbidden;
return .none;
}
fn actionFor(b: HgatpWriteBoundaryBlocker) HgatpWriteBoundaryNextAction { return switch (b) { .none => .keep_gate_blocking_before_hardware,
        .empty_boundary => .none,
        .missing_write_gate => .build_write_gate_externally,
        .invalid_write_gate => .validate_write_gate_externally,
        .gate_does_not_block_before_hardware,
        .gate_allows_hardware_boundary => .keep_gate_blocking_before_hardware,
        .source_mutated => .investigate_source_mutation,
        .request_value_mismatch => .inspect_request_value,
        .boundary_request_allowed => .stop_boundary_request_allowed,
        .hardware_boundary_reached => .stop_hardware_boundary_observed,
        .hgatp_write_attempted => .stop_hgatp_write_attempt_observed,
        .hgatp_write_performed => .stop_hgatp_write_performed_observed,
        .active_stage2_forbidden => .stop_active_stage2_observed };
}
fn decisionFor(b: HgatpWriteBoundaryBlocker) HgatpWriteBoundaryDecision { return switch (b) { .none => .deny_before_hardware,
        .source_mutated => .reject_source_state, else => .reject_boundary_violation };
}
fn finish(r: *HgatpWriteBoundary) HgatpWriteBoundaryBlocker { const b = firstBlocker(r.*);
r.blocker = b;
r.last_error = b;
r.blocker_count = if (b == .none) 0 else 1;
r.next_action = actionFor(b);
r.decision = decisionFor(b);
r.ready = b == .none;
r.state = if (r.ready) .ready else .rejected;
if (!r.ready) r.reject_count += 1;
r.checksum = boundaryChecksum(r.*);
return b;
}
pub fn build() HgatpWriteBoundaryBlocker { const r = mutable();
r.build_count += 1;
r.owner_vm_id = vm.object().id;
r.owner_vcpu_id = vcpu.object().id;
r.source_fingerprint_before = readSourceFingerprint();
const s = sourceSummary();
r.write_gate_present = s.write_gate_present;
r.write_gate_valid = s.write_gate_valid;
r.write_gate_checksum = s.write_gate_checksum;
r.gate_decision = s.gate_decision;
r.gate_blocks_before_hardware = s.gate_blocks_before_hardware;
r.gate_allows_hardware_boundary = s.gate_allows_hardware_boundary;
r.planned_hgatp_value = s.planned_hgatp_value;
r.planned_vmid = s.planned_vmid;
r.planned_root_ppn = s.planned_root_ppn;
r.planned_mode = s.planned_mode;
const req = HgatpWriteBoundaryRequest{ .owner_vm_id = r.owner_vm_id,
        .owner_vcpu_id = r.owner_vcpu_id,
        .request_value = s.planned_hgatp_value,
        .request_checksum = 0,
        .denied = true,
        .allowed = false };
r.boundary_request_seen = true;
r.boundary_request_denied = true;
r.boundary_request_allowed = false;
r.hardware_boundary_reached = false;
r.hgatp_write_attempted = s.hgatp_write_attempted;
r.hgatp_write_performed = s.hgatp_write_performed;
r.active_stage2 = s.active_stage2;
r.request_value = req.request_value;
r.request_checksum = requestChecksum(req);
r.denied_request_count += 1;
r.allowed_request_count = 0;
r.boundary_reach_count = 0;
r.write_attempt_count = if (r.hgatp_write_attempted) r.write_attempt_count + 1 else 0;
r.write_performed_count = if (r.hgatp_write_performed) r.write_performed_count + 1 else 0;
r.state = .observed;
r.source_fingerprint_after = readSourceFingerprint();
r.source_fingerprint_unchanged = sameFp(r.source_fingerprint_before, r.source_fingerprint_after);
return finish(r);
}
pub fn validate() HgatpWriteBoundaryBlocker { const r = mutable();
r.validate_count += 1;
return finish(r);
}
fn corrupt(kind: HgatpWriteBoundaryBlocker) HgatpWriteBoundaryBlocker { _ = build();
const r = mutable();
switch (kind) { .missing_write_gate => r.write_gate_present = false,
        .invalid_write_gate => r.write_gate_valid = false,
        .gate_allows_hardware_boundary => r.gate_allows_hardware_boundary = true,
        .source_mutated => r.source_fingerprint_unchanged = false,
        .request_value_mismatch => r.request_value +%= 1,
        .boundary_request_allowed => r.boundary_request_allowed = true,
        .hardware_boundary_reached => r.hardware_boundary_reached = true,
        .hgatp_write_attempted => r.hgatp_write_attempted = true,
        .hgatp_write_performed => r.hgatp_write_performed = true,
        .active_stage2_forbidden => r.active_stage2 = true, else => {} } return validate();
}
pub fn invariantLifecycle() bool { reset();
const empty_bad = validate() == .empty_boundary;
_ = build();
const seen = object().build_count == 1 and object().boundary_request_seen and object().boundary_request_denied;
reset();
return empty_bad and seen and object().state == .empty;
}
pub fn invariantConsumption() bool { reset();
_ = build();
return object().write_gate_checksum == hgatp_write_gate.object().checksum and object().planned_hgatp_value == hgatp_write_gate.object().planned_hgatp_value;
}
pub fn invariantCorruption() bool { return corrupt(.missing_write_gate) == .missing_write_gate and corrupt(.invalid_write_gate) == .invalid_write_gate and corrupt(.source_mutated) == .source_mutated;
}
fn blockerName(b: HgatpWriteBoundaryBlocker) []const u8 { return switch (b) { .none => "none",
        .empty_boundary => "empty-boundary",
        .missing_write_gate => "missing-write-gate",
        .invalid_write_gate => "invalid-write-gate",
        .gate_does_not_block_before_hardware => "gate-does-not-block-before-hardware",
        .gate_allows_hardware_boundary => "gate-allows-hardware-boundary",
        .source_mutated => "source-mutated",
        .request_value_mismatch => "request-value-mismatch",
        .boundary_request_allowed => "boundary-request-allowed",
        .hardware_boundary_reached => "hardware-boundary-reached",
        .hgatp_write_attempted => "hgatp-write-attempted",
        .hgatp_write_performed => "hgatp-write-performed",
        .active_stage2_forbidden => "active-stage2-forbidden" };
}
fn actionName(a: HgatpWriteBoundaryNextAction) []const u8 { return switch (a) { .none => "none",
        .build_write_gate_externally => "build-write-gate-externally",
        .validate_write_gate_externally => "validate-write-gate-externally",
        .keep_gate_blocking_before_hardware => "keep-gate-blocking-before-hardware",
        .investigate_source_mutation => "investigate-source-mutation",
        .inspect_request_value => "inspect-request-value",
        .stop_boundary_request_allowed => "stop-boundary-request-allowed",
        .stop_hardware_boundary_observed => "stop-hardware-boundary-observed",
        .stop_hgatp_write_attempt_observed => "stop-hgatp-write-attempt-observed",
        .stop_hgatp_write_performed_observed => "stop-hgatp-write-performed-observed",
        .stop_active_stage2_observed => "stop-active-stage2-observed" };
}
fn printBool(v: bool) void { uart.write(if (v) "true" else "false");
}
fn printResult(name: []const u8, b: HgatpWriteBoundaryBlocker) void { uart.write("hv: hgatp_write_boundary.");
uart.write(name);
uart.write("=");
uart.write(if (b == .none) "ok" else "rejected");
uart.write("\r\nhv: hgatp_write_boundary.result_blocker=");
uart.write(blockerName(b));
uart.write("\r\n");
}
fn printBlockers() void { const r = object();
uart.write("hv: hgatp_write_boundary.blocker_count=");
uart.writeDec(r.blocker_count);
uart.write("\r\nhv: hgatp_write_boundary.blocker=");
uart.write(blockerName(r.blocker));
uart.write("\r\n");
}
fn printSummary() void { const r = object();
uart.write("hv: hgatp_write_boundary=software-only-hgatp-hardware-boundary\r\nhv: hgatp_write_boundary.state=");
uart.write(@tagName(r.state));
uart.write("\r\nhv: hgatp_write_boundary.ready=");
printBool(r.ready);
uart.write("\r\nhv: hgatp_write_boundary.owner_vm_id=");
uart.writeDec(r.owner_vm_id);
uart.write("\r\nhv: hgatp_write_boundary.owner_vcpu_id=");
uart.writeDec(r.owner_vcpu_id);
uart.write("\r\nhv: hgatp_write_boundary.build_count=");
uart.writeDec(r.build_count);
uart.write("\r\nhv: hgatp_write_boundary.validate_count=");
uart.writeDec(r.validate_count);
uart.write("\r\nhv: hgatp_write_boundary.reject_count=");
uart.writeDec(r.reject_count);
uart.write("\r\nhv: hgatp_write_boundary.reset_count=");
uart.writeDec(r.reset_count);
uart.write("\r\n");
printBlockers();
}
fn printFields() void { const r = object();
uart.write("hv: hgatp_write_boundary.write_gate_present=");
printBool(r.write_gate_present);
uart.write("\r\nhv: hgatp_write_boundary.write_gate_valid=");
printBool(r.write_gate_valid);
uart.write("\r\nhv: hgatp_write_boundary.write_gate_checksum=");
uart.writeHex(r.write_gate_checksum);
uart.write("\r\nhv: hgatp_write_boundary.gate_decision=");
uart.writeDec(r.gate_decision);
uart.write("\r\nhv: hgatp_write_boundary.gate_blocks_before_hardware=");
printBool(r.gate_blocks_before_hardware);
uart.write("\r\nhv: hgatp_write_boundary.gate_allows_hardware_boundary=");
printBool(r.gate_allows_hardware_boundary);
uart.write("\r\nhv: hgatp_write_boundary.planned_hgatp_value=");
uart.writeHex(r.planned_hgatp_value);
uart.write("\r\nhv: hgatp_write_boundary.planned_vmid=");
uart.writeDec(r.planned_vmid);
uart.write("\r\nhv: hgatp_write_boundary.planned_root_ppn=");
uart.writeHex(r.planned_root_ppn);
uart.write("\r\nhv: hgatp_write_boundary.planned_mode=");
uart.writeDec(r.planned_mode);
uart.write("\r\nhv: hgatp_write_boundary.source_fingerprint_before=");
uart.writeHex(r.source_fingerprint_before.checksum);
uart.write("\r\nhv: hgatp_write_boundary.source_fingerprint_after=");
uart.writeHex(r.source_fingerprint_after.checksum);
uart.write("\r\nhv: hgatp_write_boundary.source_fingerprint_unchanged=");
uart.write(if (r.source_fingerprint_unchanged) "yes" else "no");
uart.write("\r\n");
}
fn printRequest() void { const r = object();
uart.write("hv: hgatp_write_boundary.boundary_request_seen=");
printBool(r.boundary_request_seen);
uart.write("\r\nhv: hgatp_write_boundary.boundary_request_denied=");
printBool(r.boundary_request_denied);
uart.write("\r\nhv: hgatp_write_boundary.boundary_request_allowed=");
printBool(r.boundary_request_allowed);
uart.write("\r\nhv: hgatp_write_boundary.hardware_boundary_reached=");
printBool(r.hardware_boundary_reached);
uart.write("\r\nhv: hgatp_write_boundary.hgatp_write_attempted=");
printBool(r.hgatp_write_attempted);
uart.write("\r\nhv: hgatp_write_boundary.hgatp_write_performed=");
printBool(r.hgatp_write_performed);
uart.write("\r\nhv: hgatp_write_boundary.active_stage2=");
printBool(r.active_stage2);
uart.write("\r\nhv: hgatp_write_boundary.request_value=");
uart.writeHex(r.request_value);
uart.write("\r\nhv: hgatp_write_boundary.request_checksum=");
uart.writeHex(r.request_checksum);
uart.write("\r\nhv: hgatp_write_boundary.denied_request_count=");
uart.writeDec(r.denied_request_count);
uart.write("\r\nhv: hgatp_write_boundary.allowed_request_count=");
uart.writeDec(r.allowed_request_count);
uart.write("\r\nhv: hgatp_write_boundary.boundary_reach_count=");
uart.writeDec(r.boundary_reach_count);
uart.write("\r\nhv: hgatp_write_boundary.write_attempt_count=");
uart.writeDec(r.write_attempt_count);
uart.write("\r\nhv: hgatp_write_boundary.write_performed_count=");
uart.writeDec(r.write_performed_count);
uart.write("\r\n");
}
pub fn printStatusCommand() void { printSummary();
printFields();
printRequest();
}
pub fn printBuildCommand() void { const b = build();
printResult("build_result", b);
printSummary();
printFields();
printRequest();
}
pub fn printValidateCommand() void { const b = validate();
printResult("validate_result", b);
printSummary();
printFields();
printRequest();
}
pub fn printBlockersCommand() void { _ = validate();
printBlockers();
}
pub fn printNextCommand() void { uart.write("hv: hgatp_write_boundary.next_action=");
uart.write(actionName(object().next_action));
uart.write("\r\n");
}
pub fn printChecksumCommand() void { uart.write("hv: hgatp_write_boundary.checksum=");
uart.writeHex(object().checksum);
uart.write("\r\n");
}
pub fn printResetCommand() void { reset();
uart.write("hv: hgatp_write_boundary.reset_result=ok\r\n");
printSummary();
}
pub fn printFieldsCommand() void { printFields();
printRequest();
}
pub fn printRequestCommand() void { printRequest();
}
pub fn printDecisionCommand() void { uart.write("hv: hgatp_write_boundary.decision=");
uart.write(@tagName(object().decision));
uart.write("\r\n");
}
pub fn printInvariantLifecycleCommand() void { uart.write("hv: hgatp_write_boundary.invariant_lifecycle_result=");
uart.write(if (invariantLifecycle()) "ok" else "rejected");
uart.write("\r\n");
}
pub fn printInvariantConsumptionCommand() void { uart.write("hv: hgatp_write_boundary.invariant_consumption_result=");
uart.write(if (invariantConsumption()) "ok" else "rejected");
uart.write("\r\n");
}
pub fn printInvariantCorruptionCommand() void { uart.write("hv: hgatp_write_boundary.invariant_corruption_result=");
uart.write(if (invariantCorruption()) "ok" else "rejected");
uart.write("\r\n");
}
pub fn printRequireGateTestCommand() void { printResult("require_gate_test", corrupt(.missing_write_gate));
printBlockers();
}
pub fn printInvalidGateTestCommand() void { printResult("invalid_gate_test", corrupt(.invalid_write_gate));
printBlockers();
}
pub fn printGateAllowsBoundaryTestCommand() void { printResult("gate_allows_boundary_test", corrupt(.gate_allows_hardware_boundary));
printBlockers();
}
pub fn printSourceIntegrityTestCommand() void { printResult("source_integrity_test", corrupt(.source_mutated));
printBlockers();
}
pub fn printRequestValueTestCommand() void { printResult("request_value_test", corrupt(.request_value_mismatch));
printBlockers();
}
pub fn printBoundaryAllowedTestCommand() void { printResult("boundary_allowed_test", corrupt(.boundary_request_allowed));
printBlockers();
}
pub fn printBoundaryReachedTestCommand() void { printResult("boundary_reached_test", corrupt(.hardware_boundary_reached));
printBlockers();
}
pub fn printWriteAttemptTestCommand() void { printResult("write_attempt_test", corrupt(.hgatp_write_attempted));
printBlockers();
}
pub fn printWritePerformedTestCommand() void { printResult("write_performed_test", corrupt(.hgatp_write_performed));
printBlockers();
}
pub fn printActiveStage2TestCommand() void { printResult("active_stage2_test", corrupt(.active_stage2_forbidden));
printBlockers();
}
