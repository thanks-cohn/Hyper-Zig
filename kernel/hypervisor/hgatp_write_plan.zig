const uart = @import("../console/uart.zig");
const vm = @import("vm.zig");
const vcpu = @import("vcpu.zig");
const hgatp_candidate = @import("hgatp_candidate.zig");
const hgatp_readiness = @import("hgatp_activation_readiness.zig");
const second_stage = @import("second_stage.zig");
const stage2_table = @import("stage2_table.zig");
const h_extension = @import("h_extension.zig");

pub const HgatpWritePlanState = enum {
    empty,
    observed,
    ready,
    rejected
};
pub const HgatpWritePlanBlocker = enum {
    none,
    empty_plan,
    missing_hgatp_candidate,
    invalid_hgatp_candidate,
    missing_readiness,
    invalid_readiness,
    readiness_not_ready,
    missing_stage2_metadata,
    missing_stage2_table,
    missing_h_extension_discovery,
    missing_csr_safety,
    source_mutated,
    write_allowed_now,
    write_attempted,
    active_stage2_forbidden
};
pub const HgatpWritePlanNextAction = enum {
    none,
    build_hgatp_candidate_externally,
    validate_hgatp_candidate_externally,
    build_hgatp_readiness_externally,
    validate_hgatp_readiness_externally,
    wait_for_readiness_future_guarded_write,
    build_stage2_metadata_externally,
    build_stage2_table_externally,
    discover_h_extension_externally,
    establish_csr_safety_externally,
    investigate_source_mutation,
    stop_write_allowed_policy_violation,
    stop_hgatp_write_observed,
    stop_active_stage2_observed,
    future_guarded_write_blocked_until_hv28
};
pub const HgatpWritePlanFingerprint = struct {
    hgatp_state: usize,
    hgatp_ready: bool,
    hgatp_value: usize,
    hgatp_checksum: usize,
    hgatp_build_count: usize,
    hgatp_validate_count: usize,
    hgatp_reject_count: usize,
    readiness_state: usize,
    readiness_ready: bool,
    readiness_checksum: usize,
    readiness_source_fingerprint_unchanged: bool,
    second_stage_state: usize,
    second_stage_mapping_validated: bool,
    second_stage_active: bool,
    stage2_table_state: usize,
    stage2_table_entry_count: usize,
    stage2_table_active: bool,
    h_extension_state: usize,
    h_extension_unsafe_forbidden: bool,
    h_extension_hgatp_write_status: usize,
    h_extension_blocked_count: usize,
    h_extension_readable_count: usize,
    vm_id: vm.VmId,
    vcpu_id: vcpu.VcpuId,
    checksum: usize
};
pub const HgatpWritePlanSourceSummary = struct {
    hgatp_candidate_present: bool,
    hgatp_candidate_valid: bool,
    hgatp_candidate_checksum: usize,
    hgatp_candidate_value: usize,
    readiness_present: bool,
    readiness_valid: bool,
    readiness_checksum: usize,
    readiness_ready_for_future_guarded_write: bool,
    stage2_metadata_present: bool,
    stage2_table_present: bool,
    h_extension_discovery_present: bool,
    csr_safety_present: bool,
    write_attempted: bool,
    active_stage2: bool
};
pub const HgatpWritePlan = struct {
    owner_vm_id: vm.VmId,
    owner_vcpu_id: vcpu.VcpuId,
    hgatp_candidate_present: bool,
    hgatp_candidate_valid: bool,
    hgatp_candidate_checksum: usize,
    hgatp_candidate_value: usize,
    readiness_present: bool,
    readiness_valid: bool,
    readiness_checksum: usize,
    readiness_ready_for_future_guarded_write: bool,
    stage2_metadata_present: bool,
    stage2_table_present: bool,
    h_extension_discovery_present: bool,
    csr_safety_present: bool,
    source_fingerprint_before: HgatpWritePlanFingerprint,
    source_fingerprint_after: HgatpWritePlanFingerprint,
    source_fingerprint_unchanged: bool,
    planned_hgatp_value: usize,
    planned_vmid: usize,
    planned_root_ppn: usize,
    planned_mode: usize,
    write_guard_required: bool,
    write_allowed_now: bool,
    write_attempted: bool,
    active_stage2: bool,
    plan_ready: bool,
    next_action: HgatpWritePlanNextAction,
    blocker: HgatpWritePlanBlocker,
    blocker_count: usize,
    checksum: usize,
    state: HgatpWritePlanState,
    ready: bool,
    last_error: HgatpWritePlanBlocker,
    build_count: usize,
    validate_count: usize,
    reject_count: usize,
    reset_count: usize
};

var obj: HgatpWritePlan = undefined;
var initialized = false;

pub fn init(owner: vm.VmId,
    owner_vcpu: vcpu.VcpuId) void {
    obj = empty(owner,
    owner_vcpu,
    0);
initialized = true;
}
pub fn object() *const HgatpWritePlan {
    return mutable();
}
fn mutable() *HgatpWritePlan {
    if (!initialized) init(vm.object().id,
    vcpu.object().id);
return &obj;
}
fn emptyFp() HgatpWritePlanFingerprint {
    return .{

    .hgatp_state=0,.hgatp_ready=false,.hgatp_value=0,.hgatp_checksum=0,.hgatp_build_count=0,.hgatp_validate_count=0,.hgatp_reject_count=0,.readiness_state=0,.readiness_ready=false,.readiness_checksum=0,.readiness_source_fingerprint_unchanged=false,.second_stage_state=0,.second_stage_mapping_validated=false,.second_stage_active=false,.stage2_table_state=0,.stage2_table_entry_count=0,.stage2_table_active=false,.h_extension_state=0,.h_extension_unsafe_forbidden=false,.h_extension_hgatp_write_status=0,.h_extension_blocked_count=0,.h_extension_readable_count=0,.vm_id=0,.vcpu_id=0,.checksum=0
};
}
fn empty(owner: vm.VmId,
    owner_vcpu: vcpu.VcpuId,
    resets: usize) HgatpWritePlan {
    return .{

    .owner_vm_id=owner,.owner_vcpu_id=owner_vcpu,.hgatp_candidate_present=false,.hgatp_candidate_valid=false,.hgatp_candidate_checksum=0,.hgatp_candidate_value=0,.readiness_present=false,.readiness_valid=false,.readiness_checksum=0,.readiness_ready_for_future_guarded_write=false,.stage2_metadata_present=false,.stage2_table_present=false,.h_extension_discovery_present=false,.csr_safety_present=false,.source_fingerprint_before=emptyFp(),.source_fingerprint_after=emptyFp(),.source_fingerprint_unchanged=false,.planned_hgatp_value=0,.planned_vmid=0,.planned_root_ppn=0,.planned_mode=0,.write_guard_required=true,.write_allowed_now=false,.write_attempted=false,.active_stage2=false,.plan_ready=false,.next_action=.none,.blocker=.none,.blocker_count=0,.checksum=0,.state=.empty,.ready=false,.last_error=.none,.build_count=0,.validate_count=0,.reject_count=0,.reset_count=resets
};
}
pub fn reset() void {
    const r = mutable().reset_count + 1;
obj = empty(vm.object().id,
    vcpu.object().id,
    r);
initialized = true;
}
fn tag(e: anytype) usize {
    return @intFromEnum(e);
}
fn mix(x: usize,
    y: usize) usize {
    return (x ^ y) *% 0x9e37_79b9_7f4a_7c15;
}
fn fpChecksum(f: HgatpWritePlanFingerprint) usize {
    var x: usize = 0x26;
x=mix(x,f.hgatp_state);
x=mix(x,if (f.hgatp_ready)1 else 0);
x=mix(x,f.hgatp_value);
x=mix(x,f.hgatp_checksum);
x=mix(x,f.hgatp_build_count);
x=mix(x,f.hgatp_validate_count);
x=mix(x,f.hgatp_reject_count);
x=mix(x,f.readiness_state);
x=mix(x,if (f.readiness_ready)1 else 0);
x=mix(x,f.readiness_checksum);
x=mix(x,if (f.readiness_source_fingerprint_unchanged)1 else 0);
x=mix(x,f.second_stage_state);
x=mix(x,if (f.second_stage_mapping_validated)1 else 0);
x=mix(x,if (f.second_stage_active)1 else 0);
x=mix(x,f.stage2_table_state);
x=mix(x,f.stage2_table_entry_count);
x=mix(x,if (f.stage2_table_active)1 else 0);
x=mix(x,f.h_extension_state);
x=mix(x,if (f.h_extension_unsafe_forbidden)1 else 0);
x=mix(x,f.h_extension_hgatp_write_status);
x=mix(x,f.h_extension_blocked_count);
x=mix(x,f.h_extension_readable_count);
x=mix(x,@intCast(f.vm_id));
x=mix(x,@intCast(f.vcpu_id));
return if (x == 0) 1 else x;
}
pub fn readSourceFingerprint() HgatpWritePlanFingerprint {
    const c=hgatp_candidate.object();
const rd=hgatp_readiness.object();
const ss=second_stage.object();
const tbl=stage2_table.object();
const he=h_extension.object();
var f=HgatpWritePlanFingerprint{
    .hgatp_state=tag(c.state),.hgatp_ready=c.ready,.hgatp_value=c.candidate_value,.hgatp_checksum=c.checksum,.hgatp_build_count=c.build_count,.hgatp_validate_count=c.validate_count,.hgatp_reject_count=c.reject_count,.readiness_state=tag(rd.state),.readiness_ready=rd.ready,.readiness_checksum=rd.checksum,.readiness_source_fingerprint_unchanged=rd.source_fingerprint_unchanged,.second_stage_state=tag(ss.state),.second_stage_mapping_validated=ss.mapping.validated,.second_stage_active=ss.mapping.active,.stage2_table_state=tag(tbl.state),.stage2_table_entry_count=tbl.entry_count,.stage2_table_active=tbl.active,.h_extension_state=tag(he.state),.h_extension_unsafe_forbidden=he.unsafe_csr_read_forbidden,.h_extension_hgatp_write_status=tag(he.hgatp_write_status),.h_extension_blocked_count=he.blocked_csr_count,.h_extension_readable_count=he.readable_csr_count,.vm_id=vm.object().id,.vcpu_id=vcpu.object().id,.checksum=0
};
f.checksum=fpChecksum(f);
return f;
}
fn sameFp(a: HgatpWritePlanFingerprint,
    b: HgatpWritePlanFingerprint) bool {
    return a.checksum == b.checksum and a.hgatp_state == b.hgatp_state and a.hgatp_value == b.hgatp_value and a.hgatp_checksum == b.hgatp_checksum and a.hgatp_build_count == b.hgatp_build_count and a.hgatp_validate_count == b.hgatp_validate_count and a.hgatp_reject_count == b.hgatp_reject_count and a.readiness_state == b.readiness_state and a.readiness_ready == b.readiness_ready and a.readiness_checksum == b.readiness_checksum and a.readiness_source_fingerprint_unchanged == b.readiness_source_fingerprint_unchanged and a.second_stage_state == b.second_stage_state and a.stage2_table_state == b.stage2_table_state and a.h_extension_state == b.h_extension_state and a.vm_id == b.vm_id and a.vcpu_id == b.vcpu_id;
}
fn summary() HgatpWritePlanSourceSummary {
    const c=hgatp_candidate.object();
const rd=hgatp_readiness.object();
const ss=second_stage.object();
const tbl=stage2_table.object();
const he=h_extension.object();
return .{

    .hgatp_candidate_present=c.state != .empty and c.candidate_value != 0 and c.checksum != 0,
    .hgatp_candidate_valid=c.state == .validated and c.ready,
    .hgatp_candidate_checksum=c.checksum,
    .hgatp_candidate_value=c.candidate_value,
    .readiness_present=rd.state != .empty and rd.checksum != 0,
    .readiness_valid=(rd.state == .ready and rd.ready),
    .readiness_checksum=rd.checksum,
    .readiness_ready_for_future_guarded_write=rd.ready_for_future_guarded_write,
    .stage2_metadata_present=ss.state == .metadata_ready and ss.mapping.validated and !ss.mapping.active,
    .stage2_table_present=(tbl.state == .built or tbl.state == .validated) and tbl.entry_count > 0 and !tbl.active,
    .h_extension_discovery_present=he.state == .discovered or he.state == .validated,
    .csr_safety_present=he.unsafe_csr_read_forbidden and he.hgatp_write_status == .not_attempted,
    .write_attempted=c.hgatp_write_attempted or he.hgatp_write_status != .not_attempted,
    .active_stage2=c.active_stage2 or ss.mapping.active or tbl.active
};
}
fn firstBlocker(r: HgatpWritePlan) HgatpWritePlanBlocker {
    if (r.state == .empty) return .empty_plan;
if (!r.source_fingerprint_unchanged) return .source_mutated;
if (!r.hgatp_candidate_present) return .missing_hgatp_candidate;
if (!r.hgatp_candidate_valid) return .invalid_hgatp_candidate;
if (!r.readiness_present) return .missing_readiness;
if (!r.readiness_valid) return .invalid_readiness;
if (!r.readiness_ready_for_future_guarded_write) return .readiness_not_ready;
if (!r.stage2_metadata_present) return .missing_stage2_metadata;
if (!r.stage2_table_present) return .missing_stage2_table;
if (!r.h_extension_discovery_present) return .missing_h_extension_discovery;
if (!r.csr_safety_present) return .missing_csr_safety;
if (r.write_allowed_now) return .write_allowed_now;
if (r.write_attempted) return .write_attempted;
if (r.active_stage2) return .active_stage2_forbidden;
return .none;
}
fn actionFor(b: HgatpWritePlanBlocker) HgatpWritePlanNextAction {
    return switch(b){
    .none=>.future_guarded_write_blocked_until_hv28,.empty_plan=>.none,.missing_hgatp_candidate=>.build_hgatp_candidate_externally,.invalid_hgatp_candidate=>.validate_hgatp_candidate_externally,.missing_readiness=>.build_hgatp_readiness_externally,.invalid_readiness=>.validate_hgatp_readiness_externally,.readiness_not_ready=>.wait_for_readiness_future_guarded_write,.missing_stage2_metadata=>.build_stage2_metadata_externally,.missing_stage2_table=>.build_stage2_table_externally,.missing_h_extension_discovery=>.discover_h_extension_externally,.missing_csr_safety=>.establish_csr_safety_externally,.source_mutated=>.investigate_source_mutation,.write_allowed_now=>.stop_write_allowed_policy_violation,.write_attempted=>.stop_hgatp_write_observed,.active_stage2_forbidden=>.stop_active_stage2_observed
};
}
fn readinessChecksum(r: HgatpWritePlan) usize {
    var x: usize=0x2626;
x=mix(x,r.source_fingerprint_before.checksum);
x=mix(x,r.source_fingerprint_after.checksum);
x=mix(x,r.hgatp_candidate_checksum);
x=mix(x,r.hgatp_candidate_value);
x=mix(x,r.readiness_checksum);
x=mix(x,r.planned_hgatp_value);
x=mix(x,r.planned_vmid);
x=mix(x,r.planned_root_ppn);
x=mix(x,r.planned_mode);
x=mix(x,tag(r.blocker));
x=mix(x,tag(r.next_action));
return if (x == 0) 1 else x;
}
pub fn build() HgatpWritePlanBlocker {
    const r=mutable();
r.build_count += 1;
r.owner_vm_id=vm.object().id;
r.owner_vcpu_id=vcpu.object().id;
r.source_fingerprint_before=readSourceFingerprint();
const s=summary();
r.hgatp_candidate_present=s.hgatp_candidate_present;
r.hgatp_candidate_valid=s.hgatp_candidate_valid;
r.hgatp_candidate_checksum=s.hgatp_candidate_checksum;
r.hgatp_candidate_value=s.hgatp_candidate_value;
r.readiness_present=s.readiness_present;
r.readiness_valid=s.readiness_valid;
r.readiness_checksum=s.readiness_checksum;
r.readiness_ready_for_future_guarded_write=s.readiness_ready_for_future_guarded_write;
r.planned_hgatp_value=s.hgatp_candidate_value;
r.planned_vmid=hgatp_candidate.object().vmid;
r.planned_root_ppn=hgatp_candidate.object().root_ppn;
r.planned_mode=hgatp_candidate.object().mode_value;
r.write_guard_required=true;
r.stage2_metadata_present=s.stage2_metadata_present;
r.stage2_table_present=s.stage2_table_present;
r.h_extension_discovery_present=s.h_extension_discovery_present;
r.csr_safety_present=s.csr_safety_present;
r.write_allowed_now=false;
r.write_attempted=s.write_attempted;
r.active_stage2=s.active_stage2;
r.state=.observed;
r.source_fingerprint_after=readSourceFingerprint();
r.source_fingerprint_unchanged=sameFp(r.source_fingerprint_before,
    r.source_fingerprint_after);
const b=firstBlocker(r.*);
r.blocker=b;
r.last_error=b;
r.blocker_count=if (b == .none) 0 else 1;
r.next_action=actionFor(b);
r.ready=b == .none;
r.plan_ready=r.ready;
r.state=if (r.ready) .ready else .rejected;
if (!r.ready) r.reject_count += 1;
r.checksum=readinessChecksum(r.*);
return b;
}
pub fn validate() HgatpWritePlanBlocker {
    const r=mutable();
r.validate_count += 1;
const b=firstBlocker(r.*);
r.blocker=b;
r.last_error=b;
r.blocker_count=if (b == .none)0 else 1;
r.next_action=actionFor(b);
r.ready=b == .none;
r.plan_ready=r.ready;
r.state=if (r.ready) .ready else .rejected;
if (!r.ready) r.reject_count += 1;
r.checksum=readinessChecksum(r.*);
return b;
}
fn corrupt(kind: HgatpWritePlanBlocker) HgatpWritePlanBlocker {
    _=build();
const r=mutable();
switch(kind){
    .missing_hgatp_candidate=>r.hgatp_candidate_present=false,.invalid_hgatp_candidate=>r.hgatp_candidate_valid=false,.missing_readiness=>r.readiness_present=false,.invalid_readiness=>r.readiness_valid=false,.readiness_not_ready=>r.readiness_ready_for_future_guarded_write=false,.missing_stage2_metadata=>r.stage2_metadata_present=false,.missing_stage2_table=>r.stage2_table_present=false,.missing_h_extension_discovery=>r.h_extension_discovery_present=false,.missing_csr_safety=>r.csr_safety_present=false,.write_allowed_now=>r.write_allowed_now=true,.write_attempted=>r.write_attempted=true,.active_stage2_forbidden=>r.active_stage2 = (kind == .active_stage2_forbidden),.source_mutated=>r.source_fingerprint_unchanged=false,
    else=>{}
} return validate();
}
pub fn invariantLifecycle() bool {
    reset();
const empty_bad=validate()==.empty_plan;
_=build();
const observed=object().build_count==1 and object().checksum != 0;
reset();
return empty_bad and observed and object().state == .empty;
}
pub fn invariantConsumption() bool {
    reset();
_=build();
const before=object().hgatp_candidate_checksum;
return before == hgatp_candidate.object().checksum;
}
pub fn invariantCorruption() bool {
    return corrupt(.missing_hgatp_candidate)==.missing_hgatp_candidate and corrupt(.invalid_hgatp_candidate)==.invalid_hgatp_candidate and corrupt(.source_mutated)==.source_mutated;
}
pub fn printStatusCommand() void {
    printSummary();
printSources();
printPolicy();
}
pub fn printBuildCommand() void {
    const b=build();
printResult("build_result",
    b);
printSummary();
printSources();
printPolicy();
}
pub fn printValidateCommand() void {
    const b=validate();
printResult("validate_result",
    b);
printSummary();
printSources();
printPolicy();
}
pub fn printBlockersCommand() void {
    _=validate();
printBlockers();
}
pub fn printNextCommand() void {
    uart.write("hv: hgatp_write_plan.next_action=");
uart.write(actionName(object().next_action));
uart.write("\r\n");
}
pub fn printChecksumCommand() void {
    uart.write("hv: hgatp_write_plan.checksum=");
uart.writeHex(object().checksum);
uart.write("\r\n");
}
pub fn printFieldsCommand() void {
    printSources();
printPlanFields();
printPolicy();
}
pub fn printResetCommand() void {
    reset();
uart.write("hv: hgatp_write_plan.reset_result=ok\r\n");
printSummary();
}
pub fn printInvariantLifecycleCommand() void {
    uart.write("hv: hgatp_write_plan.invariant_lifecycle_result=");
uart.write(if (invariantLifecycle())"ok" else "rejected");
uart.write("\r\n");
}
pub fn printInvariantConsumptionCommand() void {
    uart.write("hv: hgatp_write_plan.invariant_consumption_result=");
uart.write(if (invariantConsumption())"ok" else "rejected");
uart.write("\r\n");
}
pub fn printInvariantCorruptionCommand() void {
    uart.write("hv: hgatp_write_plan.invariant_corruption_result=");
uart.write(if (invariantCorruption())"ok" else "rejected");
uart.write("\r\n");
}
pub fn printRequireCandidateTestCommand() void {
    printResult("require_candidate_test",
    corrupt(.missing_hgatp_candidate));
printBlockers();
}
pub fn printRequireReadinessTestCommand() void {
    printResult("require_readiness_test",
    corrupt(.missing_readiness));
printBlockers();
}
pub fn printInvalidReadinessTestCommand() void {
    printResult("invalid_readiness_test",
    corrupt(.invalid_readiness));
printBlockers();
}
pub fn printReadinessNotReadyTestCommand() void {
    printResult("readiness_not_ready_test",
    corrupt(.readiness_not_ready));
printBlockers();
}
pub fn printRequireStage2MetadataTestCommand() void {
    printResult("require_stage2_metadata_test",
    corrupt(.missing_stage2_metadata));
printBlockers();
}
pub fn printRequireStage2TableTestCommand() void {
    printResult("require_stage2_table_test",
    corrupt(.missing_stage2_table));
printBlockers();
}
pub fn printInvalidCandidateTestCommand() void {
    printResult("invalid_candidate_test",
    corrupt(.invalid_hgatp_candidate));
printBlockers();
}
pub fn printRequireHextTestCommand() void {
    printResult("require_hext_test",
    corrupt(.missing_h_extension_discovery));
printBlockers();
}
pub fn printRequireCsrSafetyTestCommand() void {
    printResult("require_csr_safety_test",
    corrupt(.missing_csr_safety));
printBlockers();
}
pub fn printWriteAllowedTestCommand() void {
    printResult("write_allowed_test",
    corrupt(.write_allowed_now));
printBlockers();
}
pub fn printWriteAttemptTestCommand() void {
    printResult("write_attempt_test",
    corrupt(.write_attempted));
printBlockers();
}
pub fn printActiveStage2TestCommand() void {
    printResult("active_stage2_test",
    corrupt(.active_stage2_forbidden));
printBlockers();
}
pub fn printSourceIntegrityTestCommand() void {
    printResult("source_integrity_test",
    corrupt(.source_mutated));
printBlockers();
}
fn printResult(label: []const u8,
    b: HgatpWritePlanBlocker) void {
    uart.write("hv: hgatp_write_plan.");
uart.write(label);
uart.write("=");
uart.write(if (b == .none)"ok" else "rejected");
uart.write("\r\n");
uart.write("hv: hgatp_write_plan.result_blocker=");
uart.write(blockerName(b));
uart.write("\r\n");
}
fn printSummary() void {
    const r=object();
uart.write("hv: hgatp_write_plan=software-only-guarded-write-plan\r\n");
uart.write("hv: hgatp_write_plan.state=");
uart.write(@tagName(r.state));
uart.write("\r\n");
uart.write("hv: hgatp_write_plan.ready=");
uart.write(if (r.ready)"true" else "false");
uart.write("\r\n");
uart.write("hv: hgatp_write_plan.owner_vm_id=");
uart.writeDec(r.owner_vm_id);
uart.write("\r\n");
uart.write("hv: hgatp_write_plan.owner_vcpu_id=");
uart.writeDec(r.owner_vcpu_id);
uart.write("\r\n");
uart.write("hv: hgatp_write_plan.build_count=");
uart.writeDec(r.build_count);
uart.write("\r\n");
uart.write("hv: hgatp_write_plan.validate_count=");
uart.writeDec(r.validate_count);
uart.write("\r\n");
uart.write("hv: hgatp_write_plan.reject_count=");
uart.writeDec(r.reject_count);
uart.write("\r\n");
uart.write("hv: hgatp_write_plan.reset_count=");
uart.writeDec(r.reset_count);
uart.write("\r\n");
printBlockers();
uart.write("hv: hgatp_write_plan.next_action=");
uart.write(actionName(r.next_action));
uart.write("\r\n");
uart.write("hv: hgatp_write_plan.checksum=");
uart.writeHex(r.checksum);
uart.write("\r\n");
}
fn printSources() void {
    const r=object();
uart.write("hv: hgatp_write_plan.hgatp_candidate_present=");
uart.write(if (r.hgatp_candidate_present)"yes" else "no");
uart.write("\r\n");
uart.write("hv: hgatp_write_plan.hgatp_candidate_valid=");
uart.write(if (r.hgatp_candidate_valid)"yes" else "no");
uart.write("\r\n");
uart.write("hv: hgatp_write_plan.hgatp_candidate_checksum=");
uart.writeHex(r.hgatp_candidate_checksum);
uart.write("\r\n");
uart.write("hv: hgatp_write_plan.hgatp_candidate_value=");
uart.writeHex(r.hgatp_candidate_value);
uart.write("\r\n");
uart.write("hv: hgatp_write_plan.readiness_present=");
uart.write(if (r.readiness_present)"yes" else "no");
uart.write("\r\n");
uart.write("hv: hgatp_write_plan.readiness_valid=");
uart.write(if (r.readiness_valid)"yes" else "no");
uart.write("\r\n");
uart.write("hv: hgatp_write_plan.readiness_checksum=");
uart.writeHex(r.readiness_checksum);
uart.write("\r\n");
uart.write("hv: hgatp_write_plan.readiness_ready_for_future_guarded_write=");
uart.write(if (r.readiness_ready_for_future_guarded_write)"yes" else "no");
uart.write("\r\n");
uart.write("hv: hgatp_write_plan.stage2_metadata_present=");
uart.write(if (r.stage2_metadata_present)"yes" else "no");
uart.write("\r\n");
uart.write("hv: hgatp_write_plan.stage2_table_present=");
uart.write(if (r.stage2_table_present)"yes" else "no");
uart.write("\r\n");
uart.write("hv: hgatp_write_plan.h_extension_discovery_present=");
uart.write(if (r.h_extension_discovery_present)"yes" else "no");
uart.write("\r\n");
uart.write("hv: hgatp_write_plan.csr_safety_present=");
uart.write(if (r.csr_safety_present)"yes" else "no");
uart.write("\r\n");
uart.write("hv: hgatp_write_plan.source_fingerprint_before=");
uart.writeHex(r.source_fingerprint_before.checksum);
uart.write("\r\n");
uart.write("hv: hgatp_write_plan.source_fingerprint_after=");
uart.writeHex(r.source_fingerprint_after.checksum);
uart.write("\r\n");
uart.write("hv: hgatp_write_plan.source_fingerprint_unchanged=");
uart.write(if (r.source_fingerprint_unchanged)"yes" else "no");
uart.write("\r\n");
}
fn printPlanFields() void {
    const r=object();
uart.write("hv: hgatp_write_plan.planned_hgatp_value=");
uart.writeHex(r.planned_hgatp_value);
uart.write("\r\n");
uart.write("hv: hgatp_write_plan.planned_vmid=");
uart.writeDec(r.planned_vmid);
uart.write("\r\n");
uart.write("hv: hgatp_write_plan.planned_root_ppn=");
uart.writeHex(r.planned_root_ppn);
uart.write("\r\n");
uart.write("hv: hgatp_write_plan.planned_mode=");
uart.writeDec(r.planned_mode);
uart.write("\r\n");
uart.write("hv: hgatp_write_plan.write_guard_required=");
uart.write(if (r.write_guard_required)"true" else "false");
uart.write("\r\n");
uart.write("hv: hgatp_write_plan.plan_ready=");
uart.write(if (r.plan_ready)"true" else "false");
uart.write("\r\n");
}
fn printPolicy() void {
    const r=object();
uart.write("hv: hgatp_write_plan.write_allowed_now=false\r\n");
uart.write("hv: hgatp_write_plan.write_attempted=");
uart.write(if (r.write_attempted)"true" else "false");
uart.write("\r\n");
uart.write("hv: hgatp_write_plan.active_stage2=");
uart.write(if (r.active_stage2)"true" else "false");
uart.write("\r\n");
uart.write("hv: hgatp_write_plan.readiness_ready_for_future_guarded_write=");
uart.write(if (r.readiness_ready_for_future_guarded_write)"yes" else "no");
uart.write("\r\n");
uart.write("hv: second_stage_translation=MISSING\r\n");
uart.write("hv: guest_execution=not-supported-yet\r\n");
uart.write("hv: linux_guest=not-supported-yet\r\n");
}
fn printBlockers() void {
    const r=object();
uart.write("hv: hgatp_write_plan.blocker_count=");
uart.writeDec(r.blocker_count);
uart.write("\r\n");
uart.write("hv: hgatp_write_plan.blocker=");
uart.write(blockerName(r.blocker));
uart.write("\r\n");
}
fn blockerName(b: HgatpWritePlanBlocker) []const u8 {
    return switch(b){
    .none=>"none",.empty_plan=>"empty-plan",.missing_hgatp_candidate=>"missing-hgatp-candidate",.invalid_hgatp_candidate=>"invalid-hgatp-candidate",.missing_readiness=>"missing-readiness",.invalid_readiness=>"invalid-readiness",.readiness_not_ready=>"readiness-not-ready",.missing_stage2_metadata=>"missing-stage2-metadata",.missing_stage2_table=>"missing-stage2-table",.missing_h_extension_discovery=>"missing-h-extension-discovery",.missing_csr_safety=>"missing-csr-safety",.source_mutated=>"source-mutated",.write_allowed_now=>"write-allowed-now",.write_attempted=>"hgatp-write-attempted",.active_stage2_forbidden=>"active-stage2-forbidden"
};
}
fn actionName(a: HgatpWritePlanNextAction) []const u8 {
    return switch(a){
    .none=>"none",.build_hgatp_candidate_externally=>"build-hgatp-candidate-externally",.validate_hgatp_candidate_externally=>"validate-hgatp-candidate-externally",.build_hgatp_readiness_externally=>"build-hgatp-readiness-externally",.validate_hgatp_readiness_externally=>"validate-hgatp-readiness-externally",.wait_for_readiness_future_guarded_write=>"wait-for-readiness-future-guarded-write",.build_stage2_metadata_externally=>"build-stage2-metadata-externally",.build_stage2_table_externally=>"build-stage2-table-externally",.discover_h_extension_externally=>"discover-h-extension-externally",.establish_csr_safety_externally=>"establish-csr-safety-externally",.investigate_source_mutation=>"investigate-source-mutation",.stop_write_allowed_policy_violation=>"stop-write-allowed-policy-violation",.stop_hgatp_write_observed=>"stop-hgatp-write-observed",.stop_active_stage2_observed=>"stop-active-stage2-observed",.future_guarded_write_blocked_until_hv28=>"future-guarded-write-blocked-until-hv28"
};
}
