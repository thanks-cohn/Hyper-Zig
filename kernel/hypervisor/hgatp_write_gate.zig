const uart = @import("../console/uart.zig");
const vm = @import("vm.zig");
const vcpu = @import("vcpu.zig");
const hgatp_write_plan = @import("hgatp_write_plan.zig");
const h_extension = @import("h_extension.zig");
const second_stage = @import("second_stage.zig");
const stage2_table = @import("stage2_table.zig");

pub const HgatpWriteGateState = enum {
empty, observed, ready, rejected
};
pub const HgatpWriteGateBlocker = enum {
none, empty_gate, missing_write_plan, invalid_write_plan, missing_h_extension_discovery, missing_csr_safety, source_mutated, hardware_boundary_attempted, hgatp_write_attempted, hgatp_write_performed, active_stage2_forbidden
};
pub const HgatpWriteGateDecision = enum {
none, deny_before_hardware, future_policy_required
};
pub const HgatpWriteGateNextAction = enum {
none, build_write_plan_externally, validate_write_plan_externally, discover_h_extension_externally, establish_csr_safety_externally, investigate_source_mutation, stop_hardware_boundary_observed, stop_hgatp_write_attempt_observed, stop_hgatp_write_performed_observed, stop_active_stage2_observed, keep_blocking_until_future_policy
};
pub const HgatpWriteGateFingerprint = struct {
write_plan_state: usize, write_plan_ready: bool, write_plan_checksum: usize, planned_hgatp_value: usize, write_allowed_now: bool, write_attempted: bool, write_plan_active_stage2: bool, h_extension_state: usize, h_extension_unsafe_forbidden: bool, h_extension_hgatp_write_status: usize, h_extension_blocked_count: usize, h_extension_readable_count: usize, second_stage_active: bool, stage2_table_active: bool, vm_id: vm.VmId, vcpu_id: vcpu.VcpuId, checksum: usize
};
pub const HgatpWriteGateSourceSummary = struct {
write_plan_present: bool, write_plan_valid: bool, write_plan_checksum: usize, planned_hgatp_value: usize, planned_vmid: usize, planned_root_ppn: usize, planned_mode: usize, h_extension_discovery_present: bool, csr_safety_present: bool, hgatp_write_status: usize, unsafe_csr_read_forbidden: bool, hgatp_write_attempted: bool, hgatp_write_performed: bool, active_stage2: bool, hardware_write_boundary_reached: bool
};
pub const HgatpWriteGate = struct {
owner_vm_id: vm.VmId, owner_vcpu_id: vcpu.VcpuId, write_plan_present: bool, write_plan_valid: bool, write_plan_checksum: usize, planned_hgatp_value: usize, planned_vmid: usize, planned_root_ppn: usize, planned_mode: usize, h_extension_discovery_present: bool, csr_safety_present: bool, hgatp_write_status: usize, unsafe_csr_read_forbidden: bool, source_fingerprint_before: HgatpWriteGateFingerprint, source_fingerprint_after: HgatpWriteGateFingerprint, source_fingerprint_unchanged: bool, request_seen: bool, request_allowed_to_reach_hardware_boundary: bool, request_blocked_before_hardware: bool, hgatp_write_attempted: bool, hgatp_write_performed: bool, active_stage2: bool, hardware_write_boundary_reached: bool, decision: HgatpWriteGateDecision, next_action: HgatpWriteGateNextAction, blocker: HgatpWriteGateBlocker, blocker_count: usize, checksum: usize, state: HgatpWriteGateState, ready: bool, last_error: HgatpWriteGateBlocker, build_count: usize, validate_count: usize, reject_count: usize, request_count: usize, deny_count: usize, reset_count: usize
};

var gate: HgatpWriteGate = undefined;
var initialized = false;

pub fn init(owner: vm.VmId, owner_vcpu: vcpu.VcpuId) void {
gate = empty(owner, owner_vcpu, 0);
initialized = true;
}
pub fn object() *const HgatpWriteGate {
return mutable();
}
fn mutable() *HgatpWriteGate {
if (!initialized) init(vm.object().id, vcpu.object().id);
return &gate;
}
fn tag(e: anytype) usize {
return @intFromEnum(e);
}
fn mix(x: usize, y: usize) usize {
return (x ^ y) *% 0x9e37_79b9_7f4a_7c15;
}
fn emptyFp() HgatpWriteGateFingerprint {
return .{
.write_plan_state=0,
    .write_plan_ready=false,
    .write_plan_checksum=0,
    .planned_hgatp_value=0,
    .write_allowed_now=false,
    .write_attempted=false,
    .write_plan_active_stage2=false,
    .h_extension_state=0,
    .h_extension_unsafe_forbidden=false,
    .h_extension_hgatp_write_status=0,
    .h_extension_blocked_count=0,
    .h_extension_readable_count=0,
    .second_stage_active=false,
    .stage2_table_active=false,
    .vm_id=0,
    .vcpu_id=0,
    .checksum=0
};
}
fn empty(owner: vm.VmId, owner_vcpu: vcpu.VcpuId, resets: usize) HgatpWriteGate {
return .{
.owner_vm_id=owner,
    .owner_vcpu_id=owner_vcpu,
    .write_plan_present=false,
    .write_plan_valid=false,
    .write_plan_checksum=0,
    .planned_hgatp_value=0,
    .planned_vmid=0,
    .planned_root_ppn=0,
    .planned_mode=0,
    .h_extension_discovery_present=false,
    .csr_safety_present=false,
    .hgatp_write_status=0,
    .unsafe_csr_read_forbidden=true,
    .source_fingerprint_before=emptyFp(),
    .source_fingerprint_after=emptyFp(),
    .source_fingerprint_unchanged=false,
    .request_seen=false,
    .request_allowed_to_reach_hardware_boundary=false,
    .request_blocked_before_hardware=true,
    .hgatp_write_attempted=false,
    .hgatp_write_performed=false,
    .active_stage2=false,
    .hardware_write_boundary_reached=false,
    .decision=.none,
    .next_action=.none,
    .blocker=.none,
    .blocker_count=0,
    .checksum=0,
    .state=.empty,
    .ready=false,
    .last_error=.none,
    .build_count=0,
    .validate_count=0,
    .reject_count=0,
    .request_count=0,
    .deny_count=0,
    .reset_count=resets
};
}
pub fn reset() void {
const r=mutable().reset_count + 1;
gate = empty(vm.object().id, vcpu.object().id, r);
initialized = true;
}
fn fpChecksum(f: HgatpWriteGateFingerprint) usize {
var x: usize=0x28;
x=mix(x,f.write_plan_state);
x=mix(x,if(f.write_plan_ready)1 else 0);
x=mix(x,f.write_plan_checksum);
x=mix(x,f.planned_hgatp_value);
x=mix(x,if(f.write_allowed_now)1 else 0);
x=mix(x,if(f.write_attempted)1 else 0);
x=mix(x,if(f.write_plan_active_stage2)1 else 0);
x=mix(x,f.h_extension_state);
x=mix(x,if(f.h_extension_unsafe_forbidden)1 else 0);
x=mix(x,f.h_extension_hgatp_write_status);
x=mix(x,f.h_extension_blocked_count);
x=mix(x,f.h_extension_readable_count);
x=mix(x,if(f.second_stage_active)1 else 0);
x=mix(x,if(f.stage2_table_active)1 else 0);
x=mix(x,@intCast(f.vm_id));
x=mix(x,@intCast(f.vcpu_id));
return if (x==0) 1 else x;
}
pub fn readSourceFingerprint() HgatpWriteGateFingerprint {
const p=hgatp_write_plan.object();
const he=h_extension.object();
const ss=second_stage.object();
const tbl=stage2_table.object();
var f=HgatpWriteGateFingerprint{
.write_plan_state=tag(p.state),
    .write_plan_ready=p.ready,
    .write_plan_checksum=p.checksum,
    .planned_hgatp_value=p.planned_hgatp_value,
    .write_allowed_now=p.write_allowed_now,
    .write_attempted=p.write_attempted,
    .write_plan_active_stage2=p.active_stage2,
    .h_extension_state=tag(he.state),
    .h_extension_unsafe_forbidden=he.unsafe_csr_read_forbidden,
    .h_extension_hgatp_write_status=tag(he.hgatp_write_status),
    .h_extension_blocked_count=he.blocked_csr_count,
    .h_extension_readable_count=he.readable_csr_count,
    .second_stage_active=ss.mapping.active,
    .stage2_table_active=tbl.active,
    .vm_id=vm.object().id,
    .vcpu_id=vcpu.object().id,
    .checksum=0
};
f.checksum=fpChecksum(f);
return f;
}
fn sameFp(a: HgatpWriteGateFingerprint, b: HgatpWriteGateFingerprint) bool {
return a.checksum==b.checksum and a.write_plan_state==b.write_plan_state and a.write_plan_ready==b.write_plan_ready and a.write_plan_checksum==b.write_plan_checksum and a.planned_hgatp_value==b.planned_hgatp_value and a.write_allowed_now==b.write_allowed_now and a.write_attempted==b.write_attempted and a.write_plan_active_stage2==b.write_plan_active_stage2 and a.h_extension_state==b.h_extension_state and a.h_extension_unsafe_forbidden==b.h_extension_unsafe_forbidden and a.h_extension_hgatp_write_status==b.h_extension_hgatp_write_status and a.second_stage_active==b.second_stage_active and a.stage2_table_active==b.stage2_table_active and a.vm_id==b.vm_id and a.vcpu_id==b.vcpu_id;
}
fn summary() HgatpWriteGateSourceSummary {
const p=hgatp_write_plan.object();
const he=h_extension.object();
const ss=second_stage.object();
const tbl=stage2_table.object();
return .{
.write_plan_present=p.state != .empty and p.checksum != 0,
    .write_plan_valid=p.state == .ready and p.ready and p.plan_ready,
    .write_plan_checksum=p.checksum,
    .planned_hgatp_value=p.planned_hgatp_value,
    .planned_vmid=p.planned_vmid,
    .planned_root_ppn=p.planned_root_ppn,
    .planned_mode=p.planned_mode,
    .h_extension_discovery_present=he.state == .discovered or he.state == .validated,
    .csr_safety_present=he.unsafe_csr_read_forbidden and he.hgatp_write_status == .not_attempted,
    .hgatp_write_status=tag(he.hgatp_write_status),
    .unsafe_csr_read_forbidden=he.unsafe_csr_read_forbidden,
    .hgatp_write_attempted=p.write_attempted or he.hgatp_write_status != .not_attempted,
    .hgatp_write_performed=false,
    .active_stage2=p.active_stage2 or ss.mapping.active or tbl.active,
    .hardware_write_boundary_reached=false
};
}
fn firstBlocker(r: HgatpWriteGate) HgatpWriteGateBlocker {
if (r.state == .empty)
return .empty_gate;
if (!r.source_fingerprint_unchanged)
return .source_mutated;
if (!r.write_plan_present)
return .missing_write_plan;
if (!r.write_plan_valid)
return .invalid_write_plan;
if (!r.h_extension_discovery_present)
return .missing_h_extension_discovery;
if (!r.csr_safety_present)
return .missing_csr_safety;
if (r.request_allowed_to_reach_hardware_boundary or r.hardware_write_boundary_reached)
return .hardware_boundary_attempted;
if (r.hgatp_write_attempted)
return .hgatp_write_attempted;
if (r.hgatp_write_performed)
return .hgatp_write_performed;
if (r.active_stage2)
return .active_stage2_forbidden;
return .none;
}
fn actionFor(b: HgatpWriteGateBlocker) HgatpWriteGateNextAction {
return switch(b){
.none=>.keep_blocking_until_future_policy,
    .empty_gate=>.none,
    .missing_write_plan=>.build_write_plan_externally,
    .invalid_write_plan=>.validate_write_plan_externally,
    .missing_h_extension_discovery=>.discover_h_extension_externally,
    .missing_csr_safety=>.establish_csr_safety_externally,
    .source_mutated=>.investigate_source_mutation,
    .hardware_boundary_attempted=>.stop_hardware_boundary_observed,
    .hgatp_write_attempted=>.stop_hgatp_write_attempt_observed,
    .hgatp_write_performed=>.stop_hgatp_write_performed_observed,
    .active_stage2_forbidden=>.stop_active_stage2_observed
};
}
fn gateChecksum(r: HgatpWriteGate) usize {
var x: usize=0x2828;
x=mix(x,r.source_fingerprint_before.checksum);
x=mix(x,r.source_fingerprint_after.checksum);
x=mix(x,r.write_plan_checksum);
x=mix(x,r.planned_hgatp_value);
x=mix(x,r.planned_vmid);
x=mix(x,r.planned_root_ppn);
x=mix(x,r.planned_mode);
x=mix(x,tag(r.decision));
x=mix(x,tag(r.blocker));
x=mix(x,tag(r.next_action));
x=mix(x,if(r.request_blocked_before_hardware)1 else 0);
return if (x==0) 1 else x;
}
pub fn build() HgatpWriteGateBlocker {
const r=mutable();
r.build_count += 1;
r.request_count += 1;
r.owner_vm_id=vm.object().id;
r.owner_vcpu_id=vcpu.object().id;
r.source_fingerprint_before=readSourceFingerprint();
const s=summary();
r.write_plan_present=s.write_plan_present;
r.write_plan_valid=s.write_plan_valid;
r.write_plan_checksum=s.write_plan_checksum;
r.planned_hgatp_value=s.planned_hgatp_value;
r.planned_vmid=s.planned_vmid;
r.planned_root_ppn=s.planned_root_ppn;
r.planned_mode=s.planned_mode;
r.h_extension_discovery_present=s.h_extension_discovery_present;
r.csr_safety_present=s.csr_safety_present;
r.hgatp_write_status=s.hgatp_write_status;
r.unsafe_csr_read_forbidden=s.unsafe_csr_read_forbidden;
r.request_seen=true;
r.request_allowed_to_reach_hardware_boundary=false;
r.request_blocked_before_hardware=true;
r.hgatp_write_attempted=s.hgatp_write_attempted;
r.hgatp_write_performed=s.hgatp_write_performed;
r.active_stage2=s.active_stage2;
r.hardware_write_boundary_reached=s.hardware_write_boundary_reached;
r.state=.observed;
r.source_fingerprint_after=readSourceFingerprint();
r.source_fingerprint_unchanged=sameFp(r.source_fingerprint_before,r.source_fingerprint_after);
const b=firstBlocker(r.*);
r.blocker=b;
r.last_error=b;
r.blocker_count=if(b==.none)0 else 1;
r.next_action=actionFor(b);
r.decision=.deny_before_hardware;
r.ready=b == .none;
r.state=if(r.ready) .ready else .rejected;
if (!r.ready) r.reject_count += 1;
r.deny_count += 1;
r.checksum=gateChecksum(r.*);
return b;
}
pub fn validate() HgatpWriteGateBlocker {
const r=mutable();
r.validate_count += 1;
const b=firstBlocker(r.*);
r.blocker=b;
r.last_error=b;
r.blocker_count=if(b==.none)0 else 1;
r.next_action=actionFor(b);
r.decision=if (r.state == .empty) .none else .deny_before_hardware;
r.ready=b == .none;
r.state=if(r.ready) .ready else .rejected;
if(!r.ready) r.reject_count += 1;
r.checksum=gateChecksum(r.*);
return b;
}
fn corrupt(kind: HgatpWriteGateBlocker) HgatpWriteGateBlocker {
_=build();
const r=mutable();
switch(kind){
.missing_write_plan=>r.write_plan_present=false,
    .invalid_write_plan=>r.write_plan_valid=false,
    .missing_h_extension_discovery=>r.h_extension_discovery_present=false,
    .missing_csr_safety=>r.csr_safety_present=false,
    .source_mutated=>r.source_fingerprint_unchanged=false,
    .hardware_boundary_attempted=>r.hardware_write_boundary_reached=true,
    .hgatp_write_attempted=>r.hgatp_write_attempted=true,
    .hgatp_write_performed=>r.hgatp_write_performed=true,
    .active_stage2_forbidden=>r.active_stage2=true, else=>{}
}
return validate();
}
pub fn invariantLifecycle() bool {
reset();
const empty_bad=validate()==.empty_gate;
_=build();
const observed=object().build_count==1 and object().request_seen and object().request_blocked_before_hardware;
reset();
return empty_bad and observed and object().state == .empty;
}
pub fn invariantConsumption() bool {
reset();
_=build();
const before=object().write_plan_checksum;
return before == hgatp_write_plan.object().checksum;
}
pub fn invariantCorruption() bool {
return corrupt(.missing_write_plan)==.missing_write_plan and corrupt(.invalid_write_plan)==.invalid_write_plan and corrupt(.source_mutated)==.source_mutated;
}
fn blockerName(b: HgatpWriteGateBlocker) []const u8 {
return switch(b){
.none=>"none",
    .empty_gate=>"empty-gate",
    .missing_write_plan=>"missing-write-plan",
    .invalid_write_plan=>"invalid-write-plan",
    .missing_h_extension_discovery=>"missing-h-extension-discovery",
    .missing_csr_safety=>"missing-csr-safety",
    .source_mutated=>"source-mutated",
    .hardware_boundary_attempted=>"hardware-boundary-attempted",
    .hgatp_write_attempted=>"hgatp-write-attempted",
    .hgatp_write_performed=>"hgatp-write-performed",
    .active_stage2_forbidden=>"active-stage2-forbidden"
};
}
fn actionName(a: HgatpWriteGateNextAction) []const u8 {
return switch(a){
.none=>"none",
    .build_write_plan_externally=>"build-write-plan-externally",
    .validate_write_plan_externally=>"validate-write-plan-externally",
    .discover_h_extension_externally=>"discover-h-extension-externally",
    .establish_csr_safety_externally=>"establish-csr-safety-externally",
    .investigate_source_mutation=>"investigate-source-mutation",
    .stop_hardware_boundary_observed=>"stop-hardware-boundary-observed",
    .stop_hgatp_write_attempt_observed=>"stop-hgatp-write-attempt-observed",
    .stop_hgatp_write_performed_observed=>"stop-hgatp-write-performed-observed",
    .stop_active_stage2_observed=>"stop-active-stage2-observed",
    .keep_blocking_until_future_policy=>"keep-blocking-until-future-policy"
};
}
fn printResult(label: []const u8, b: HgatpWriteGateBlocker) void {
uart.write("hv: hgatp_write_gate.");
uart.write(label);
uart.write("=");
uart.write(if(b==.none)"ok" else "rejected");
uart.write("\r\n");
uart.write("hv: hgatp_write_gate.result_blocker=");
uart.write(blockerName(b));
uart.write("\r\n");
}
fn printSummary() void {
const r=object();
uart.write("hv: hgatp_write_gate=software-only-guarded-write-gate\r\n");
uart.write("hv: hgatp_write_gate.state=");
uart.write(@tagName(r.state));
uart.write("\r\n");
uart.write("hv: hgatp_write_gate.ready=");
uart.write(if(r.ready)"true" else "false");
uart.write("\r\n");
uart.write("hv: hgatp_write_gate.owner_vm_id=");
uart.writeDec(r.owner_vm_id);
uart.write("\r\n");
uart.write("hv: hgatp_write_gate.owner_vcpu_id=");
uart.writeDec(r.owner_vcpu_id);
uart.write("\r\n");
uart.write("hv: hgatp_write_gate.build_count=");
uart.writeDec(r.build_count);
uart.write("\r\n");
uart.write("hv: hgatp_write_gate.validate_count=");
uart.writeDec(r.validate_count);
uart.write("\r\n");
uart.write("hv: hgatp_write_gate.reject_count=");
uart.writeDec(r.reject_count);
uart.write("\r\n");
uart.write("hv: hgatp_write_gate.request_count=");
uart.writeDec(r.request_count);
uart.write("\r\n");
uart.write("hv: hgatp_write_gate.deny_count=");
uart.writeDec(r.deny_count);
uart.write("\r\n");
uart.write("hv: hgatp_write_gate.reset_count=");
uart.writeDec(r.reset_count);
uart.write("\r\n");
printBlockers();
}
fn printSources() void {
const r=object();
uart.write("hv: hgatp_write_gate.write_plan_present=");
uart.write(if(r.write_plan_present)"true" else "false");
uart.write("\r\n");
uart.write("hv: hgatp_write_gate.write_plan_valid=");
uart.write(if(r.write_plan_valid)"true" else "false");
uart.write("\r\n");
uart.write("hv: hgatp_write_gate.write_plan_checksum=");
uart.writeHex(r.write_plan_checksum);
uart.write("\r\n");
uart.write("hv: hgatp_write_gate.planned_hgatp_value=");
uart.writeHex(r.planned_hgatp_value);
uart.write("\r\n");
uart.write("hv: hgatp_write_gate.planned_vmid=");
uart.writeDec(r.planned_vmid);
uart.write("\r\n");
uart.write("hv: hgatp_write_gate.planned_root_ppn=");
uart.writeHex(r.planned_root_ppn);
uart.write("\r\n");
uart.write("hv: hgatp_write_gate.planned_mode=");
uart.writeDec(r.planned_mode);
uart.write("\r\n");
uart.write("hv: hgatp_write_gate.h_extension_discovery_present=");
uart.write(if(r.h_extension_discovery_present)"true" else "false");
uart.write("\r\n");
uart.write("hv: hgatp_write_gate.csr_safety_present=");
uart.write(if(r.csr_safety_present)"true" else "false");
uart.write("\r\n");
uart.write("hv: hgatp_write_gate.unsafe_csr_read_forbidden=");
uart.write(if(r.unsafe_csr_read_forbidden)"true" else "false");
uart.write("\r\n");
uart.write("hv: hgatp_write_gate.hgatp_write_status=");
uart.writeDec(r.hgatp_write_status);
uart.write("\r\n");
uart.write("hv: hgatp_write_gate.source_fingerprint_before=");
uart.writeHex(r.source_fingerprint_before.checksum);
uart.write("\r\n");
uart.write("hv: hgatp_write_gate.source_fingerprint_after=");
uart.writeHex(r.source_fingerprint_after.checksum);
uart.write("\r\n");
uart.write("hv: hgatp_write_gate.source_fingerprint_unchanged=");
uart.write(if(r.source_fingerprint_unchanged)"yes" else "no");
uart.write("\r\n");
}
fn printPolicy() void {
const r=object();
uart.write("hv: hgatp_write_gate.request_seen=");
uart.write(if(r.request_seen)"true" else "false");
uart.write("\r\n");
uart.write("hv: hgatp_write_gate.request_allowed_to_reach_hardware_boundary=");
uart.write(if(r.request_allowed_to_reach_hardware_boundary)"true" else "false");
uart.write("\r\n");
uart.write("hv: hgatp_write_gate.request_blocked_before_hardware=");
uart.write(if(r.request_blocked_before_hardware)"true" else "false");
uart.write("\r\n");
uart.write("hv: hgatp_write_gate.hgatp_write_attempted=");
uart.write(if(r.hgatp_write_attempted)"true" else "false");
uart.write("\r\n");
uart.write("hv: hgatp_write_gate.hgatp_write_performed=");
uart.write(if(r.hgatp_write_performed)"true" else "false");
uart.write("\r\n");
uart.write("hv: hgatp_write_gate.hardware_write_boundary_reached=");
uart.write(if(r.hardware_write_boundary_reached)"true" else "false");
uart.write("\r\n");
uart.write("hv: hgatp_write_gate.active_stage2=");
uart.write(if(r.active_stage2)"yes" else "false");
uart.write("\r\n");
uart.write("hv: hgatp_write_gate.decision=");
uart.write(@tagName(r.decision));
uart.write("\r\n");
uart.write("hv: hgatp_write_gate.next_action=");
uart.write(actionName(r.next_action));
uart.write("\r\n");
}
fn printBlockers() void {
const r=object();
uart.write("hv: hgatp_write_gate.blocker_count=");
uart.writeDec(r.blocker_count);
uart.write("\r\n");
uart.write("hv: hgatp_write_gate.blocker=");
uart.write(blockerName(r.blocker));
uart.write("\r\n");
}
pub fn printStatusCommand() void {
printSummary();
printSources();
printPolicy();
}
pub fn printBuildCommand() void {
const b=build();
printResult("build_result", b);
printSummary();
printSources();
printPolicy();
}
pub fn printValidateCommand() void {
const b=validate();
printResult("validate_result", b);
printSummary();
printSources();
printPolicy();
}
pub fn printBlockersCommand() void {
_=validate();
printBlockers();
}
pub fn printNextCommand() void {
uart.write("hv: hgatp_write_gate.next_action=");
uart.write(actionName(object().next_action));
uart.write("\r\n");
}
pub fn printChecksumCommand() void {
uart.write("hv: hgatp_write_gate.checksum=");
uart.writeHex(object().checksum);
uart.write("\r\n");
}
pub fn printFieldsCommand() void {
printSources();
printPolicy();
}
pub fn printDecisionCommand() void {
uart.write("hv: hgatp_write_gate.decision=");
uart.write(@tagName(object().decision));
uart.write("\r\n");
}
pub fn printResetCommand() void {
reset();
uart.write("hv: hgatp_write_gate.reset_result=ok\r\n");
printSummary();
}
pub fn printInvariantLifecycleCommand() void {
uart.write("hv: hgatp_write_gate.invariant_lifecycle_result=");
uart.write(if(invariantLifecycle())"ok" else "rejected");
uart.write("\r\n");
}
pub fn printInvariantConsumptionCommand() void {
uart.write("hv: hgatp_write_gate.invariant_consumption_result=");
uart.write(if(invariantConsumption())"ok" else "rejected");
uart.write("\r\n");
}
pub fn printInvariantCorruptionCommand() void {
uart.write("hv: hgatp_write_gate.invariant_corruption_result=");
uart.write(if(invariantCorruption())"ok" else "rejected");
uart.write("\r\n");
}
pub fn printRequirePlanTestCommand() void {
printResult("require_plan_test", corrupt(.missing_write_plan));
printBlockers();
}
pub fn printInvalidPlanTestCommand() void {
printResult("invalid_plan_test", corrupt(.invalid_write_plan));
printBlockers();
}
pub fn printRequireHextTestCommand() void {
printResult("require_hext_test", corrupt(.missing_h_extension_discovery));
printBlockers();
}
pub fn printRequireCsrSafetyTestCommand() void {
printResult("require_csr_safety_test", corrupt(.missing_csr_safety));
printBlockers();
}
pub fn printSourceIntegrityTestCommand() void {
printResult("source_integrity_test", corrupt(.source_mutated));
printBlockers();
}
pub fn printBoundaryAttemptTestCommand() void {
printResult("boundary_attempt_test", corrupt(.hardware_boundary_attempted));
printBlockers();
}
pub fn printWriteAttemptTestCommand() void {
printResult("write_attempt_test", corrupt(.hgatp_write_attempted));
printBlockers();
}
pub fn printWritePerformedTestCommand() void {
printResult("write_performed_test", corrupt(.hgatp_write_performed));
printBlockers();
}
pub fn printActiveStage2TestCommand() void {
printResult("active_stage2_test", corrupt(.active_stage2_forbidden));
printBlockers();
}
