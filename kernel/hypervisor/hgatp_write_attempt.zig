const uart = @import("../console/uart.zig");
const vm = @import("vm.zig");
const vcpu = @import("vcpu.zig");
const hgatp_write_boundary = @import("hgatp_write_boundary.zig");

pub const HgatpWriteAttemptState = enum {
empty,
observed,
ready,
rejected,
};
pub const HgatpWriteAttemptBlocker = enum {
none,
empty_attempt,
missing_write_boundary,
invalid_write_boundary,
source_mutated,
request_missing,
request_value_mismatch,
attempt_allowed_to_reach_csr,
csr_write_function_called,
hgatp_write_attempted,
hgatp_write_performed,
active_stage2_forbidden,
};
pub const HgatpWriteAttemptNextAction = enum {
none,
build_write_boundary_externally,
validate_write_boundary_externally,
investigate_source_mutation,
inspect_boundary_request,
inspect_request_value,
keep_denied_before_csr,
stop_csr_call_observed,
stop_hgatp_write_attempt_observed,
stop_hgatp_write_performed_observed,
stop_active_stage2_observed,
};
pub const HgatpWriteAttemptFingerprint = struct {
boundary_checksum: usize,
boundary_request_checksum: usize,
boundary_request_value: usize,
boundary_ready: bool,
boundary_state: usize,
vm_id: vm.VmId,
vcpu_id: vcpu.VcpuId,
checksum: usize,
};
pub const HgatpWriteAttemptRequest = struct {
owner_vm_id: vm.VmId,
owner_vcpu_id: vcpu.VcpuId,
planned_hgatp_value: usize,
source_boundary_checksum: usize,
source_request_checksum: usize,
denied_before_csr: bool,
allowed_to_reach_csr: bool,
checksum: usize,
};
pub const HgatpWriteAttempt = struct {
owner_vm_id: vm.VmId,
owner_vcpu_id: vcpu.VcpuId,
write_boundary_present: bool,
write_boundary_valid: bool,
write_boundary_checksum: usize,
attempt_request_present: bool,
attempt_request_checksum: usize,
planned_hgatp_value: usize,
planned_vmid: usize,
planned_root_ppn: usize,
planned_mode: usize,
attempt_denied_before_csr: bool,
attempt_allowed_to_reach_csr: bool,
csr_write_function_present: bool,
csr_write_function_called: bool,
hgatp_write_attempted: bool,
hgatp_write_performed: bool,
active_stage2: bool,
guest_execution: bool,
source_fingerprint_before: HgatpWriteAttemptFingerprint,
source_fingerprint_after: HgatpWriteAttemptFingerprint,
source_fingerprint_unchanged: bool,
blocker: HgatpWriteAttemptBlocker,
blocker_count: usize,
next_action: HgatpWriteAttemptNextAction,
checksum: usize,
build_count: usize,
validate_count: usize,
reject_count: usize,
reset_count: usize,
state: HgatpWriteAttemptState,
ready: bool,
last_error: HgatpWriteAttemptBlocker,
};

var attempt: HgatpWriteAttempt = undefined;
var initialized = false;
fn tag(e: anytype) usize {
return @intFromEnum(e);
}
fn mix(a: usize,
b: usize) usize {
return (a ^ b) *% 0x9e37_79b9_7f4a_7c15;
}
fn boolInt(v: bool) usize {
return if (v) 1 else 0;
}
fn emptyFp() HgatpWriteAttemptFingerprint {
return .{
.boundary_checksum = 0,
.boundary_request_checksum = 0,
.boundary_request_value = 0,
.boundary_ready = false,
.boundary_state = 0,
.vm_id = 0,
.vcpu_id = 0,
.checksum = 0,
};
}
fn empty(owner: vm.VmId,
owner_vcpu: vcpu.VcpuId,
resets: usize) HgatpWriteAttempt {
return .{
.owner_vm_id = owner,
.owner_vcpu_id = owner_vcpu,
.write_boundary_present = false,
.write_boundary_valid = false,
.write_boundary_checksum = 0,
.attempt_request_present = false,
.attempt_request_checksum = 0,
.planned_hgatp_value = 0,
.planned_vmid = 0,
.planned_root_ppn = 0,
.planned_mode = 0,
.attempt_denied_before_csr = false,
.attempt_allowed_to_reach_csr = false,
.csr_write_function_present = false,
.csr_write_function_called = false,
.hgatp_write_attempted = false,
.hgatp_write_performed = false,
.active_stage2 = false,
.guest_execution = false,
.source_fingerprint_before = emptyFp(),
.source_fingerprint_after = emptyFp(),
.source_fingerprint_unchanged = false,
.blocker = .none,
.blocker_count = 0,
.next_action = .none,
.checksum = 0,
.build_count = 0,
.validate_count = 0,
.reject_count = 0,
.reset_count = resets,
.state = .empty,
.ready = false,
.last_error = .none,
};
}
pub fn init(owner: vm.VmId,
owner_vcpu: vcpu.VcpuId) void {
attempt = empty(owner,
owner_vcpu,
0);
initialized = true;
}
fn mutable() *HgatpWriteAttempt {
if (!initialized) init(vm.object().id,
vcpu.object().id);
return &attempt;
}
pub fn object() *const HgatpWriteAttempt {
return mutable();
}
pub fn reset() void {
const r = mutable().reset_count + 1;
attempt = empty(vm.object().id,
vcpu.object().id,
r);
initialized = true;
}
fn fpChecksum(f: HgatpWriteAttemptFingerprint) usize {
var x: usize = 0x3030;
x = mix(x,
f.boundary_checksum);
x = mix(x,
f.boundary_request_checksum);
x = mix(x,
f.boundary_request_value);
x = mix(x,
boolInt(f.boundary_ready));
x = mix(x,
f.boundary_state);
x = mix(x,
@intCast(f.vm_id));
x = mix(x,
@intCast(f.vcpu_id));
return if (x == 0) 1 else x;
}
pub fn readSourceFingerprint() HgatpWriteAttemptFingerprint {
const b = hgatp_write_boundary.object();
var f = HgatpWriteAttemptFingerprint{
.boundary_checksum = b.checksum,
.boundary_request_checksum = b.request_checksum,
.boundary_request_value = b.request_value,
.boundary_ready = b.ready,
.boundary_state = tag(b.state),
.vm_id = vm.object().id,
.vcpu_id = vcpu.object().id,
.checksum = 0,
};
f.checksum = fpChecksum(f);
return f;
}
fn sameFp(a: HgatpWriteAttemptFingerprint,
b: HgatpWriteAttemptFingerprint) bool {
return a.checksum == b.checksum and a.boundary_checksum == b.boundary_checksum and a.boundary_request_checksum == b.boundary_request_checksum and a.boundary_request_value == b.boundary_request_value and a.boundary_ready == b.boundary_ready and a.boundary_state == b.boundary_state and a.vm_id == b.vm_id and a.vcpu_id == b.vcpu_id;
}
fn requestChecksum(req: HgatpWriteAttemptRequest) usize {
var x: usize = 0x30;
x = mix(x,
@intCast(req.owner_vm_id));
x = mix(x,
@intCast(req.owner_vcpu_id));
x = mix(x,
req.planned_hgatp_value);
x = mix(x,
req.source_boundary_checksum);
x = mix(x,
req.source_request_checksum);
x = mix(x,
boolInt(req.denied_before_csr));
x = mix(x,
boolInt(req.allowed_to_reach_csr));
return if (x == 0) 1 else x;
}
fn attemptChecksum(r: HgatpWriteAttempt) usize {
var x: usize = 0x303030;
x = mix(x,
r.source_fingerprint_before.checksum);
x = mix(x,
r.source_fingerprint_after.checksum);
x = mix(x,
r.write_boundary_checksum);
x = mix(x,
r.attempt_request_checksum);
x = mix(x,
r.planned_hgatp_value);
x = mix(x,
tag(r.blocker));
x = mix(x,
tag(r.next_action));
x = mix(x,
boolInt(r.attempt_denied_before_csr));
x = mix(x,
boolInt(r.attempt_allowed_to_reach_csr));
return if (x == 0) 1 else x;
}
fn firstBlocker(r: HgatpWriteAttempt) HgatpWriteAttemptBlocker {
if (r.state == .empty) return .empty_attempt;
if (!r.write_boundary_present) return .missing_write_boundary;
if (!r.write_boundary_valid) return .invalid_write_boundary;
if (!r.source_fingerprint_unchanged) return .source_mutated;
if (!r.attempt_request_present) return .request_missing;
if (r.planned_hgatp_value != hgatp_write_boundary.object().request_value) return .request_value_mismatch;
if (r.attempt_allowed_to_reach_csr) return .attempt_allowed_to_reach_csr;
if (r.csr_write_function_called) return .csr_write_function_called;
if (r.hgatp_write_attempted) return .hgatp_write_attempted;
if (r.hgatp_write_performed) return .hgatp_write_performed;
if (r.active_stage2 or r.guest_execution) return .active_stage2_forbidden;
return .none;
}
fn actionFor(b: HgatpWriteAttemptBlocker) HgatpWriteAttemptNextAction {
return switch (b) {
.none => .keep_denied_before_csr,
.empty_attempt => .none,
.missing_write_boundary => .build_write_boundary_externally,
.invalid_write_boundary => .validate_write_boundary_externally,
.source_mutated => .investigate_source_mutation,
.request_missing => .inspect_boundary_request,
.request_value_mismatch => .inspect_request_value,
.attempt_allowed_to_reach_csr => .keep_denied_before_csr,
.csr_write_function_called => .stop_csr_call_observed,
.hgatp_write_attempted => .stop_hgatp_write_attempt_observed,
.hgatp_write_performed => .stop_hgatp_write_performed_observed,
.active_stage2_forbidden => .stop_active_stage2_observed,
};
}
fn finish(r: *HgatpWriteAttempt) HgatpWriteAttemptBlocker {
const b = firstBlocker(r.*);
r.blocker = b;
r.last_error = b;
r.blocker_count = if (b == .none) 0 else 1;
r.next_action = actionFor(b);
r.ready = b == .none;
r.state = if (r.ready) .ready else .rejected;
if (!r.ready) r.reject_count += 1;
r.checksum = attemptChecksum(r.*);
return b;
}
pub fn build() HgatpWriteAttemptBlocker {
const r = mutable();
r.build_count += 1;
r.owner_vm_id = vm.object().id;
r.owner_vcpu_id = vcpu.object().id;
r.source_fingerprint_before = readSourceFingerprint();
const b = hgatp_write_boundary.object();
r.write_boundary_present = b.state != .empty and b.checksum != 0;
r.write_boundary_valid = b.state == .ready and b.ready;
r.write_boundary_checksum = b.checksum;
r.planned_hgatp_value = b.request_value;
r.planned_vmid = b.planned_vmid;
r.planned_root_ppn = b.planned_root_ppn;
r.planned_mode = b.planned_mode;
const req = HgatpWriteAttemptRequest{
.owner_vm_id = r.owner_vm_id,
.owner_vcpu_id = r.owner_vcpu_id,
.planned_hgatp_value = b.request_value,
.source_boundary_checksum = b.checksum,
.source_request_checksum = b.request_checksum,
.denied_before_csr = true,
.allowed_to_reach_csr = false,
.checksum = 0,
};
var req2 = req;
req2.checksum = requestChecksum(req);
r.attempt_request_present = b.boundary_request_seen and b.boundary_request_denied and !b.boundary_request_allowed;
r.attempt_request_checksum = req2.checksum;
r.attempt_denied_before_csr = true;
r.attempt_allowed_to_reach_csr = false;
r.csr_write_function_present = false;
r.csr_write_function_called = false;
r.hgatp_write_attempted = false;
r.hgatp_write_performed = false;
r.active_stage2 = false;
r.guest_execution = false;
r.state = .observed;
r.source_fingerprint_after = readSourceFingerprint();
r.source_fingerprint_unchanged = sameFp(r.source_fingerprint_before,
r.source_fingerprint_after);
return finish(r);
}
pub fn validate() HgatpWriteAttemptBlocker {
const r = mutable();
r.validate_count += 1;
return finish(r);
}
fn corrupt(kind: HgatpWriteAttemptBlocker) HgatpWriteAttemptBlocker {
_ = build();
const r = mutable();
switch (kind) {
.missing_write_boundary => r.write_boundary_present = false,
.invalid_write_boundary => r.write_boundary_valid = false,
.source_mutated => r.source_fingerprint_unchanged = false,
.request_missing => r.attempt_request_present = false,
.request_value_mismatch => r.planned_hgatp_value +%= 1,
.attempt_allowed_to_reach_csr => r.attempt_allowed_to_reach_csr = true,
.csr_write_function_called => r.csr_write_function_called = true,
.hgatp_write_attempted => r.hgatp_write_attempted = true,
.hgatp_write_performed => r.hgatp_write_performed = true,
.active_stage2_forbidden => r.active_stage2 = true,
else => {}
} return validate();
}
pub fn invariantConsumption() bool {
reset();
_ = build();
const b = hgatp_write_boundary.object();
return object().write_boundary_checksum == b.checksum and object().planned_hgatp_value == b.request_value and object().source_fingerprint_before.boundary_ready == b.ready;
}
pub fn invariantCorruption() bool {
return corrupt(.missing_write_boundary) == .missing_write_boundary and corrupt(.source_mutated) == .source_mutated and corrupt(.request_value_mismatch) == .request_value_mismatch;
}
fn blockerName(b: HgatpWriteAttemptBlocker) []const u8 {
return switch (b) {
.none => "none",
.empty_attempt => "empty-attempt",
.missing_write_boundary => "missing-write-boundary",
.invalid_write_boundary => "invalid-write-boundary",
.source_mutated => "source-mutated",
.request_missing => "request-missing",
.request_value_mismatch => "request-value-mismatch",
.attempt_allowed_to_reach_csr => "attempt-allowed-to-reach-csr",
.csr_write_function_called => "csr-write-function-called",
.hgatp_write_attempted => "hgatp-write-attempted",
.hgatp_write_performed => "hgatp-write-performed",
.active_stage2_forbidden => "active-stage2-forbidden",
};
}
fn actionName(a: HgatpWriteAttemptNextAction) []const u8 {
return switch (a) {
.none => "none",
.build_write_boundary_externally => "build-write-boundary-externally",
.validate_write_boundary_externally => "validate-write-boundary-externally",
.investigate_source_mutation => "investigate-source-mutation",
.inspect_boundary_request => "inspect-boundary-request",
.inspect_request_value => "inspect-request-value",
.keep_denied_before_csr => "keep-denied-before-csr",
.stop_csr_call_observed => "stop-csr-call-observed",
.stop_hgatp_write_attempt_observed => "stop-hgatp-write-attempt-observed",
.stop_hgatp_write_performed_observed => "stop-hgatp-write-performed-observed",
.stop_active_stage2_observed => "stop-active-stage2-observed",
};
}
fn printBool(v: bool) void {
uart.write(if (v) "true" else "false");
}
fn printResult(name: []const u8,
b: HgatpWriteAttemptBlocker) void {
uart.write("hv: hgatp_write_attempt.");
uart.write(name);
uart.write("=");
uart.write(if (b == .none) "ok" else "rejected");
uart.write("\r\nhv: hgatp_write_attempt.result_blocker=");
uart.write(blockerName(b));
uart.write("\r\n");
}
fn printBlockers() void {
const r = object();
uart.write("hv: hgatp_write_attempt.blocker_count=");
uart.writeDec(r.blocker_count);
uart.write("\r\nhv: hgatp_write_attempt.blocker=");
uart.write(blockerName(r.blocker));
uart.write("\r\n");
}
fn printSummary() void {
const r = object();
uart.write("hv: hgatp_write_attempt=software-only-guarded-hgatp-write-attempt\r\nhv: hgatp_write_attempt.state=");
uart.write(@tagName(r.state));
uart.write("\r\nhv: hgatp_write_attempt.ready=");
printBool(r.ready);
uart.write("\r\nhv: hgatp_write_attempt.build_count=");
uart.writeDec(r.build_count);
uart.write("\r\nhv: hgatp_write_attempt.validate_count=");
uart.writeDec(r.validate_count);
uart.write("\r\nhv: hgatp_write_attempt.reject_count=");
uart.writeDec(r.reject_count);
uart.write("\r\nhv: hgatp_write_attempt.reset_count=");
uart.writeDec(r.reset_count);
uart.write("\r\n");
printBlockers();
}
fn printFields() void {
const r = object();
uart.write("hv: hgatp_write_attempt.write_boundary_present=");
printBool(r.write_boundary_present);
uart.write("\r\nhv: hgatp_write_attempt.write_boundary_valid=");
printBool(r.write_boundary_valid);
uart.write("\r\nhv: hgatp_write_attempt.write_boundary_checksum=");
uart.writeHex(r.write_boundary_checksum);
uart.write("\r\nhv: hgatp_write_attempt.planned_hgatp_value=");
uart.writeHex(r.planned_hgatp_value);
uart.write("\r\nhv: hgatp_write_attempt.planned_vmid=");
uart.writeDec(r.planned_vmid);
uart.write("\r\nhv: hgatp_write_attempt.planned_root_ppn=");
uart.writeHex(r.planned_root_ppn);
uart.write("\r\nhv: hgatp_write_attempt.planned_mode=");
uart.writeDec(r.planned_mode);
uart.write("\r\nhv: hgatp_write_attempt.source_fingerprint_before=");
uart.writeHex(r.source_fingerprint_before.checksum);
uart.write("\r\nhv: hgatp_write_attempt.source_fingerprint_after=");
uart.writeHex(r.source_fingerprint_after.checksum);
uart.write("\r\nhv: hgatp_write_attempt.source_fingerprint_unchanged=");
uart.write(if (r.source_fingerprint_unchanged) "yes" else "no");
uart.write("\r\n");
}
fn printRequest() void {
const r = object();
uart.write("hv: hgatp_write_attempt.attempt_request_present=");
printBool(r.attempt_request_present);
uart.write("\r\nhv: hgatp_write_attempt.attempt_request_checksum=");
uart.writeHex(r.attempt_request_checksum);
uart.write("\r\nhv: hgatp_write_attempt.attempt_denied_before_csr=");
printBool(r.attempt_denied_before_csr);
uart.write("\r\nhv: hgatp_write_attempt.attempt_allowed_to_reach_csr=");
printBool(r.attempt_allowed_to_reach_csr);
uart.write("\r\nhv: hgatp_write_attempt.csr_write_function_present=");
printBool(r.csr_write_function_present);
uart.write("\r\nhv: hgatp_write_attempt.csr_write_function_called=");
printBool(r.csr_write_function_called);
uart.write("\r\nhv: hgatp_write_attempt.hgatp_write_attempted=");
printBool(r.hgatp_write_attempted);
uart.write("\r\nhv: hgatp_write_attempt.hgatp_write_performed=");
printBool(r.hgatp_write_performed);
uart.write("\r\nhv: hgatp_write_attempt.active_stage2=");
printBool(r.active_stage2);
uart.write("\r\nhv: hgatp_write_attempt.guest_execution=");
printBool(r.guest_execution);
uart.write("\r\n");
}
pub fn printStatusCommand() void {
printSummary();
printFields();
printRequest();
}
pub fn printBuildCommand() void {
const b = build();
printResult("build_result",
b);
printSummary();
printFields();
printRequest();
}
pub fn printValidateCommand() void {
const b = validate();
printResult("validate_result",
b);
printSummary();
printFields();
printRequest();
}
pub fn printBlockersCommand() void {
_ = validate();
printBlockers();
}
pub fn printNextCommand() void {
uart.write("hv: hgatp_write_attempt.next_action=");
uart.write(actionName(object().next_action));
uart.write("\r\n");
}
pub fn printChecksumCommand() void {
uart.write("hv: hgatp_write_attempt.checksum=");
uart.writeHex(object().checksum);
uart.write("\r\n");
}
pub fn printResetCommand() void {
reset();
uart.write("hv: hgatp_write_attempt.reset_result=ok\r\n");
printSummary();
}
pub fn printFieldsCommand() void {
printFields();
printRequest();
}
pub fn printRequestCommand() void {
printRequest();
}
pub fn printDecisionCommand() void {
uart.write("hv: hgatp_write_attempt.decision=deny-before-csr\r\n");
}
pub fn printRequireBoundaryTestCommand() void {
printResult("require_boundary_test",
corrupt(.missing_write_boundary));
printBlockers();
}
pub fn printSourceIntegrityTestCommand() void {
printResult("source_integrity_test",
corrupt(.source_mutated));
printBlockers();
}
pub fn printRequestValueTestCommand() void {
printResult("request_value_test",
corrupt(.request_value_mismatch));
printBlockers();
}
pub fn printInvariantConsumptionCommand() void {
uart.write("hv: hgatp_write_attempt.invariant_consumption_result=");
uart.write(if (invariantConsumption()) "ok" else "rejected");
uart.write("\r\n");
}
pub fn printInvariantCorruptionCommand() void {
uart.write("hv: hgatp_write_attempt.invariant_corruption_result=");
uart.write(if (invariantCorruption()) "ok" else "rejected");
uart.write("\r\n");
}
