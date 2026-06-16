const uart = @import("../console/uart.zig");
const vm = @import("vm.zig");
const vcpu = @import("vcpu.zig");
const op = @import("hgatp_hardware_write_operation.zig");

pub const HgatpExecutionDryRunState = enum {
empty, built, executed, rejected
};
pub const HgatpExecutionDryRunBlocker = enum {
none, missing_operation, invalid_operation, source_mutated, request_value_mismatch, explicit_opt_in_enabled, policy_allows_hardware_write, operation_call_reachable, operation_call_called, raw_write_called, execution_reached_raw_write, execution_called_raw_write, fake_trap_observed, fake_readback_observed, hgatp_write_attempted, hgatp_write_performed, active_stage2_forbidden, guest_entered_forbidden, first_instruction_forbidden
};
pub const HgatpExecutionDryRunNextAction = enum {
none, build_operation_externally, validate_operation_externally, investigate_source_mutation, inspect_request_value, keep_explicit_opt_in_disabled, keep_policy_denied_before_csr, keep_operation_call_unreachable, keep_operation_call_uncalled, keep_raw_write_uncalled, keep_execution_before_raw_write, keep_trap_slot_empty, keep_readback_slot_empty, stop_write_attempt_claim, stop_write_performed_claim, stop_active_stage2_claim, stop_guest_entry_claim, stop_first_instruction_claim
};
pub const HgatpExecutionDryRunDecision = enum {
none, execution_denied_before_csr, blocked_before_raw_write, rejected
};
pub const HgatpExecutionDryRunResultCode = enum {
none, dry_run_complete_denied_before_csr, operation_missing, operation_invalid, source_mutated, request_value_mismatch, explicit_opt_in_enabled, policy_claimed_allowed, operation_call_claimed_reachable, operation_call_claimed_called, raw_write_claimed_called, execution_reached_raw_write, execution_called_raw_write, fake_trap_observed, fake_readback_observed, write_attempt_claimed, write_performed_claimed, active_stage2_claimed, guest_entry_claimed, first_instruction_claimed
};

pub const HgatpExecutionDryRunFingerprint = struct {
operation_checksum: usize, operation_state: usize, operation_decision: usize, operation_result_code: usize, operation_request_value: usize, operation_request_checksum: usize, operation_explicit_opt_in: bool, operation_policy_allows: bool, operation_policy_denies: bool, operation_denied_before_csr: bool, operation_blocked_before_raw_write: bool, operation_call_reachable: bool, operation_call_called: bool, raw_write_function_called: bool, trap_observed: bool, readback_attempted: bool, readback_valid: bool, hgatp_write_attempted: bool, hgatp_write_performed: bool, active_stage2: bool, guest_entered: bool, first_guest_instruction_executed: bool, vm_id: vm.VmId, vcpu_id: vcpu.VcpuId, checksum: usize
};
pub const HgatpExecutionDryRunRequest = struct {
present: bool, value: usize, checksum: usize
};
pub const HgatpExecutionDryRunSteps = struct {
source_loaded: bool, preflight_checked: bool, policy_checked: bool, opt_in_checked: bool, denied_before_csr: bool, blocked_before_raw_write: bool, raw_write_skipped: bool, result_recorded: bool, safe_return_recorded: bool, count: usize
};
pub const HgatpExecutionDryRunResult = struct {
present: bool, code: HgatpExecutionDryRunResultCode, checksum: usize
};
pub const HgatpExecutionDryRunTrapSlot = struct {
present: bool, capture_armed: bool, observed: bool, scause: usize, stval: usize, sepc: usize
};
pub const HgatpExecutionDryRunReadbackSlot = struct {
present: bool, allowed: bool, attempted: bool, value: usize, valid: bool
};

pub const HgatpExecutionDryRun = struct {
    owner_vm_id: vm.VmId, owner_vcpu_id: vcpu.VcpuId,
    operation_present: bool, operation_valid: bool, operation_checksum: usize, operation_decision: usize, operation_request_value: usize, operation_request_checksum: usize, operation_explicit_opt_in: bool, operation_policy_allows: bool, operation_policy_denies: bool, operation_denied_before_csr: bool, operation_blocked_before_raw_write: bool, operation_call_reachable: bool, operation_call_called: bool, operation_raw_write_called: bool, operation_trap_observed: bool, operation_readback_attempted: bool, operation_readback_valid: bool,
    dry_run_request_present: bool, dry_run_request_checksum: usize, dry_run_request_value: usize,
    executor_entered: bool, executor_returned: bool, executor_step_count: usize,
    step_source_loaded: bool, step_preflight_checked: bool, step_policy_checked: bool, step_opt_in_checked: bool, step_denied_before_csr: bool, step_blocked_before_raw_write: bool, step_raw_write_skipped: bool, step_result_recorded: bool, step_safe_return_recorded: bool,
    preflight_passed: bool, preflight_failed: bool, preflight_blocker: HgatpExecutionDryRunBlocker,
    execution_policy_allows: bool, execution_policy_denies: bool, execution_denied_before_csr: bool, execution_blocked_before_raw_write: bool, execution_reached_raw_write: bool, execution_called_raw_write: bool, execution_returned_from_raw_write: bool,
    raw_write_function_known: bool, raw_write_function_allowed: bool, raw_write_function_called: bool,
    result_present: bool, result_code: HgatpExecutionDryRunResultCode, result_checksum: usize,
    trap_slot_present: bool, trap_capture_armed: bool, trap_observed: bool, trap_scause: usize, trap_stval: usize, trap_sepc: usize,
    readback_slot_present: bool, readback_allowed: bool, readback_attempted: bool, readback_value: usize, readback_valid: bool,
    hgatp_write_attempted: bool, hgatp_write_performed: bool, active_stage2: bool, guest_entered: bool, first_guest_instruction_executed: bool,
    source_fingerprint_before: HgatpExecutionDryRunFingerprint, source_fingerprint_after: HgatpExecutionDryRunFingerprint, source_fingerprint_unchanged: bool,
    blocker: HgatpExecutionDryRunBlocker, blocker_count: usize, next_action: HgatpExecutionDryRunNextAction, decision: HgatpExecutionDryRunDecision, checksum: usize, build_count: usize, validate_count: usize, execute_count: usize, reject_count: usize, reset_count: usize, state: HgatpExecutionDryRunState,
};

var obj: HgatpExecutionDryRun = undefined;
var initialized = false;
fn tag(e: anytype) usize {
return @intFromEnum(e);
}
fn b(v: bool) usize {
return if (v) 1 else 0;
}
fn mix(a: usize, c: usize) usize {
return (a ^ c) *% 0x9e37_79b9_7f4a_7c15;
}
fn emptyFp() HgatpExecutionDryRunFingerprint {
return .{
.operation_checksum=0,.operation_state=0,.operation_decision=0,.operation_result_code=0,.operation_request_value=0,.operation_request_checksum=0,.operation_explicit_opt_in=false,.operation_policy_allows=false,.operation_policy_denies=false,.operation_denied_before_csr=false,.operation_blocked_before_raw_write=false,.operation_call_reachable=false,.operation_call_called=false,.raw_write_function_called=false,.trap_observed=false,.readback_attempted=false,.readback_valid=false,.hgatp_write_attempted=false,.hgatp_write_performed=false,.active_stage2=false,.guest_entered=false,.first_guest_instruction_executed=false,.vm_id=0,.vcpu_id=0,.checksum=0
};
}
fn empty(owner: vm.VmId, owner_vcpu: vcpu.VcpuId, resets: usize) HgatpExecutionDryRun {
return .{
.owner_vm_id=owner,.owner_vcpu_id=owner_vcpu,.operation_present=false,.operation_valid=false,.operation_checksum=0,.operation_decision=0,.operation_request_value=0,.operation_request_checksum=0,.operation_explicit_opt_in=false,.operation_policy_allows=false,.operation_policy_denies=true,.operation_denied_before_csr=true,.operation_blocked_before_raw_write=true,.operation_call_reachable=false,.operation_call_called=false,.operation_raw_write_called=false,.operation_trap_observed=false,.operation_readback_attempted=false,.operation_readback_valid=false,.dry_run_request_present=false,.dry_run_request_checksum=0,.dry_run_request_value=0,.executor_entered=false,.executor_returned=false,.executor_step_count=0,.step_source_loaded=false,.step_preflight_checked=false,.step_policy_checked=false,.step_opt_in_checked=false,.step_denied_before_csr=false,.step_blocked_before_raw_write=false,.step_raw_write_skipped=false,.step_result_recorded=false,.step_safe_return_recorded=false,.preflight_passed=false,.preflight_failed=true,.preflight_blocker=.none,.execution_policy_allows=false,.execution_policy_denies=true,.execution_denied_before_csr=true,.execution_blocked_before_raw_write=true,.execution_reached_raw_write=false,.execution_called_raw_write=false,.execution_returned_from_raw_write=false,.raw_write_function_known=true,.raw_write_function_allowed=false,.raw_write_function_called=false,.result_present=false,.result_code=.none,.result_checksum=0,.trap_slot_present=true,.trap_capture_armed=false,.trap_observed=false,.trap_scause=0,.trap_stval=0,.trap_sepc=0,.readback_slot_present=true,.readback_allowed=false,.readback_attempted=false,.readback_value=0,.readback_valid=false,.hgatp_write_attempted=false,.hgatp_write_performed=false,.active_stage2=false,.guest_entered=false,.first_guest_instruction_executed=false,.source_fingerprint_before=emptyFp(),.source_fingerprint_after=emptyFp(),.source_fingerprint_unchanged=false,.blocker=.none,.blocker_count=0,.next_action=.none,.decision=.none,.checksum=0,.build_count=0,.validate_count=0,.execute_count=0,.reject_count=0,.reset_count=resets,.state=.empty
};
}
pub fn init(owner: vm.VmId, owner_vcpu: vcpu.VcpuId) void {
obj = empty(owner, owner_vcpu, 0);
initialized = true;
}
fn mutable() *HgatpExecutionDryRun {
if (!initialized) init(vm.object().id, vcpu.object().id);
return &obj;
}
pub fn object() *const HgatpExecutionDryRun {
return mutable();
}
pub fn reset() void {
const r = mutable().reset_count + 1;
obj = empty(vm.object().id, vcpu.object().id, r);
initialized = true;
}
fn fpChecksum(f: HgatpExecutionDryRunFingerprint) usize {
var x: usize = 0x3500;
x=mix(x,f.operation_checksum);
x=mix(x,f.operation_state);
x=mix(x,f.operation_decision);
x=mix(x,f.operation_result_code);
x=mix(x,f.operation_request_value);
x=mix(x,f.operation_request_checksum);
x=mix(x,b(f.operation_explicit_opt_in));
x=mix(x,b(f.operation_policy_allows));
x=mix(x,b(f.operation_policy_denies));
x=mix(x,b(f.operation_denied_before_csr));
x=mix(x,b(f.operation_blocked_before_raw_write));
x=mix(x,b(f.operation_call_reachable));
x=mix(x,b(f.operation_call_called));
x=mix(x,b(f.raw_write_function_called));
x=mix(x,b(f.trap_observed));
x=mix(x,b(f.readback_attempted));
x=mix(x,b(f.readback_valid));
x=mix(x,b(f.hgatp_write_attempted));
x=mix(x,b(f.hgatp_write_performed));
x=mix(x,b(f.active_stage2));
x=mix(x,b(f.guest_entered));
x=mix(x,b(f.first_guest_instruction_executed));
x=mix(x,@intCast(f.vm_id));
x=mix(x,@intCast(f.vcpu_id));
return if (x == 0) 1 else x;
}
pub fn readSourceFingerprint() HgatpExecutionDryRunFingerprint {
const s=op.object();
var f=HgatpExecutionDryRunFingerprint{
.operation_checksum=s.checksum,.operation_state=tag(s.state),.operation_decision=tag(s.decision),.operation_result_code=tag(s.result_code),.operation_request_value=s.operation_request_value,.operation_request_checksum=s.operation_request_checksum,.operation_explicit_opt_in=s.operation_explicit_opt_in,.operation_policy_allows=s.operation_policy_allows,.operation_policy_denies=s.operation_policy_denies,.operation_denied_before_csr=s.operation_denied_before_csr,.operation_blocked_before_raw_write=s.operation_blocked_before_raw_write,.operation_call_reachable=s.operation_call_reachable,.operation_call_called=s.operation_call_called,.raw_write_function_called=s.raw_write_function_called,.trap_observed=s.trap_observed,.readback_attempted=s.readback_attempted,.readback_valid=s.readback_valid,.hgatp_write_attempted=s.hgatp_write_attempted,.hgatp_write_performed=s.hgatp_write_performed,.active_stage2=s.active_stage2,.guest_entered=s.guest_entered,.first_guest_instruction_executed=s.first_guest_instruction_executed,.vm_id=vm.object().id,.vcpu_id=vcpu.object().id,.checksum=0
};
f.checksum=fpChecksum(f);
return f;
}
fn sameFp(a:HgatpExecutionDryRunFingerprint, c:HgatpExecutionDryRunFingerprint) bool {
return a.checksum==c.checksum and a.operation_checksum==c.operation_checksum and a.operation_state==c.operation_state and a.operation_decision==c.operation_decision and a.operation_result_code==c.operation_result_code and a.operation_request_value==c.operation_request_value and a.operation_request_checksum==c.operation_request_checksum and a.operation_explicit_opt_in==c.operation_explicit_opt_in and a.operation_policy_allows==c.operation_policy_allows and a.operation_policy_denies==c.operation_policy_denies and a.operation_denied_before_csr==c.operation_denied_before_csr and a.operation_blocked_before_raw_write==c.operation_blocked_before_raw_write and a.operation_call_reachable==c.operation_call_reachable and a.operation_call_called==c.operation_call_called and a.raw_write_function_called==c.raw_write_function_called and a.trap_observed==c.trap_observed and a.readback_attempted==c.readback_attempted and a.readback_valid==c.readback_valid and a.hgatp_write_attempted==c.hgatp_write_attempted and a.hgatp_write_performed==c.hgatp_write_performed and a.active_stage2==c.active_stage2 and a.guest_entered==c.guest_entered and a.first_guest_instruction_executed==c.first_guest_instruction_executed and a.vm_id==c.vm_id and a.vcpu_id==c.vcpu_id;
}
fn checksumDry(r:HgatpExecutionDryRun) usize {
var x:usize=0x3535;
x=mix(x,r.source_fingerprint_before.checksum);
x=mix(x,r.source_fingerprint_after.checksum);
x=mix(x,r.operation_checksum);
x=mix(x,r.operation_request_value);
x=mix(x,r.operation_request_checksum);
x=mix(x,r.dry_run_request_value);
x=mix(x,r.dry_run_request_checksum);
x=mix(x,r.executor_step_count);
x=mix(x,tag(r.blocker));
x=mix(x,tag(r.result_code));
return if (x==0) 1 else x;
}
fn sourcePresent() bool {
const s=op.object();
return s.state != .empty and s.checksum != 0;
}
fn sourceValid() bool {
const s=op.object();
return s.state == .denied and s.result_present and s.result_code == .operation_denied_before_csr and s.operation_request_present;
}
fn firstBlocker(r:HgatpExecutionDryRun) HgatpExecutionDryRunBlocker {
if(!r.operation_present) return .missing_operation;
if(!r.operation_valid) return .invalid_operation;
if(!r.source_fingerprint_unchanged) return .source_mutated;
if(r.dry_run_request_value != r.operation_request_value or r.dry_run_request_checksum != r.operation_request_checksum) return .request_value_mismatch;
if(r.operation_explicit_opt_in) return .explicit_opt_in_enabled;
if(r.operation_policy_allows or !r.operation_policy_denies or !r.operation_denied_before_csr or !r.operation_blocked_before_raw_write) return .policy_allows_hardware_write;
if(r.operation_call_reachable) return .operation_call_reachable;
if(r.operation_call_called) return .operation_call_called;
if(r.operation_raw_write_called or r.raw_write_function_called) return .raw_write_called;
if(r.execution_reached_raw_write) return .execution_reached_raw_write;
if(r.execution_called_raw_write or r.execution_returned_from_raw_write) return .execution_called_raw_write;
if(r.trap_capture_armed or r.trap_observed or r.trap_scause!=0 or r.trap_stval!=0 or r.trap_sepc!=0) return .fake_trap_observed;
if(r.readback_allowed or r.readback_attempted or r.readback_valid or r.readback_value!=0) return .fake_readback_observed;
if(r.hgatp_write_attempted) return .hgatp_write_attempted;
if(r.hgatp_write_performed) return .hgatp_write_performed;
if(r.active_stage2) return .active_stage2_forbidden;
if(r.guest_entered) return .guest_entered_forbidden;
if(r.first_guest_instruction_executed) return .first_instruction_forbidden;
return .none;
}
fn actionFor(k:HgatpExecutionDryRunBlocker) HgatpExecutionDryRunNextAction {
return switch(k){
.none=>.keep_policy_denied_before_csr,.missing_operation=>.build_operation_externally,.invalid_operation=>.validate_operation_externally,.source_mutated=>.investigate_source_mutation,.request_value_mismatch=>.inspect_request_value,.explicit_opt_in_enabled=>.keep_explicit_opt_in_disabled,.policy_allows_hardware_write=>.keep_policy_denied_before_csr,.operation_call_reachable=>.keep_operation_call_unreachable,.operation_call_called=>.keep_operation_call_uncalled,.raw_write_called=>.keep_raw_write_uncalled,.execution_reached_raw_write=>.keep_execution_before_raw_write,.execution_called_raw_write=>.keep_raw_write_uncalled,.fake_trap_observed=>.keep_trap_slot_empty,.fake_readback_observed=>.keep_readback_slot_empty,.hgatp_write_attempted=>.stop_write_attempt_claim,.hgatp_write_performed=>.stop_write_performed_claim,.active_stage2_forbidden=>.stop_active_stage2_claim,.guest_entered_forbidden=>.stop_guest_entry_claim,.first_instruction_forbidden=>.stop_first_instruction_claim
};
}
fn resultFor(k:HgatpExecutionDryRunBlocker) HgatpExecutionDryRunResultCode {
return switch(k){
.none=>.dry_run_complete_denied_before_csr,.missing_operation=>.operation_missing,.invalid_operation=>.operation_invalid,.source_mutated=>.source_mutated,.request_value_mismatch=>.request_value_mismatch,.explicit_opt_in_enabled=>.explicit_opt_in_enabled,.policy_allows_hardware_write=>.policy_claimed_allowed,.operation_call_reachable=>.operation_call_claimed_reachable,.operation_call_called=>.operation_call_claimed_called,.raw_write_called=>.raw_write_claimed_called,.execution_reached_raw_write=>.execution_reached_raw_write,.execution_called_raw_write=>.execution_called_raw_write,.fake_trap_observed=>.fake_trap_observed,.fake_readback_observed=>.fake_readback_observed,.hgatp_write_attempted=>.write_attempt_claimed,.hgatp_write_performed=>.write_performed_claimed,.active_stage2_forbidden=>.active_stage2_claimed,.guest_entered_forbidden=>.guest_entry_claimed,.first_instruction_forbidden=>.first_instruction_claimed
};
}
fn finish(r:*HgatpExecutionDryRun) HgatpExecutionDryRunBlocker {
const k=firstBlocker(r.*);
r.blocker=k;
r.blocker_count=if(k==.none) 0 else 1;
r.next_action=actionFor(k);
r.preflight_passed=false;
r.preflight_failed=true;
r.preflight_blocker=k;
r.result_present=true;
r.result_code=resultFor(k);
r.decision=if(k==.none) .execution_denied_before_csr else if(k==.execution_reached_raw_write or k==.execution_called_raw_write or k==.raw_write_called) .blocked_before_raw_write else .rejected;
r.state=if(k==.none and r.executor_returned) .executed else if(k==.none) .built else .rejected;
if(k!=.none) r.reject_count+=1;
r.checksum=checksumDry(r.*);
r.result_checksum=r.checksum ^ 0x3535;
return k;
}
fn loadSource(r:*HgatpExecutionDryRun) void {
const s=op.object();
r.operation_present=sourcePresent();
r.operation_valid=sourceValid();
r.operation_checksum=s.checksum;
r.operation_decision=tag(s.decision);
r.operation_request_value=s.operation_request_value;
r.operation_request_checksum=s.operation_request_checksum;
r.operation_explicit_opt_in=s.operation_explicit_opt_in;
r.operation_policy_allows=s.operation_policy_allows;
r.operation_policy_denies=s.operation_policy_denies;
r.operation_denied_before_csr=s.operation_denied_before_csr;
r.operation_blocked_before_raw_write=s.operation_blocked_before_raw_write;
r.operation_call_reachable=s.operation_call_reachable;
r.operation_call_called=s.operation_call_called;
r.operation_raw_write_called=s.raw_write_function_called;
r.operation_trap_observed=s.trap_observed;
r.operation_readback_attempted=s.readback_attempted;
r.operation_readback_valid=s.readback_valid;
r.dry_run_request_present=r.operation_present;
r.dry_run_request_value=s.operation_request_value;
r.dry_run_request_checksum=s.operation_request_checksum;
r.hgatp_write_attempted=s.hgatp_write_attempted;
r.hgatp_write_performed=s.hgatp_write_performed;
r.active_stage2=s.active_stage2;
r.guest_entered=s.guest_entered;
r.first_guest_instruction_executed=s.first_guest_instruction_executed;
}
pub fn build() HgatpExecutionDryRunBlocker {
const r=mutable();
r.build_count+=1;
r.owner_vm_id=vm.object().id;
r.owner_vcpu_id=vcpu.object().id;
r.source_fingerprint_before=readSourceFingerprint();
loadSource(r);
r.executor_entered=false;
r.executor_returned=false;
r.executor_step_count=0;
r.step_source_loaded=false;
r.step_preflight_checked=false;
r.step_policy_checked=false;
r.step_opt_in_checked=false;
r.step_denied_before_csr=false;
r.step_blocked_before_raw_write=false;
r.step_raw_write_skipped=false;
r.step_result_recorded=false;
r.step_safe_return_recorded=false;
r.execution_policy_allows=false;
r.execution_policy_denies=true;
r.execution_denied_before_csr=true;
r.execution_blocked_before_raw_write=true;
r.execution_reached_raw_write=false;
r.execution_called_raw_write=false;
r.execution_returned_from_raw_write=false;
r.raw_write_function_known=true;
r.raw_write_function_allowed=false;
r.raw_write_function_called=false;
r.trap_slot_present=true;
r.trap_capture_armed=false;
r.trap_observed=false;
r.trap_scause=0;
r.trap_stval=0;
r.trap_sepc=0;
r.readback_slot_present=true;
r.readback_allowed=false;
r.readback_attempted=false;
r.readback_value=0;
r.readback_valid=false;
r.source_fingerprint_after=readSourceFingerprint();
r.source_fingerprint_unchanged=sameFp(r.source_fingerprint_before,r.source_fingerprint_after);
return finish(r);
}
pub fn validate() HgatpExecutionDryRunBlocker {
const r=mutable();
r.validate_count+=1;
return finish(r);
}
pub fn execute() HgatpExecutionDryRunBlocker {
const r=mutable();
r.execute_count+=1;
r.executor_entered=true;
r.executor_returned=false;
r.executor_step_count=0;
r.source_fingerprint_before=readSourceFingerprint();
loadSource(r);
r.step_source_loaded=true;
r.executor_step_count+=1;
r.step_preflight_checked=true;
r.executor_step_count+=1;
r.preflight_passed=false;
r.preflight_failed=true;
r.step_policy_checked=true;
r.executor_step_count+=1;
r.execution_policy_allows=false;
r.execution_policy_denies=true;
r.step_opt_in_checked=true;
r.executor_step_count+=1;
r.operation_explicit_opt_in=false;
r.step_denied_before_csr=true;
r.executor_step_count+=1;
r.execution_denied_before_csr=true;
r.step_blocked_before_raw_write=true;
r.executor_step_count+=1;
r.execution_blocked_before_raw_write=true;
r.step_raw_write_skipped=true;
r.executor_step_count+=1;
r.execution_reached_raw_write=false;
r.execution_called_raw_write=false;
r.execution_returned_from_raw_write=false;
r.raw_write_function_known=true;
r.raw_write_function_allowed=false;
r.raw_write_function_called=false;
r.trap_slot_present=true;
r.trap_capture_armed=false;
r.trap_observed=false;
r.trap_scause=0;
r.trap_stval=0;
r.trap_sepc=0;
r.readback_slot_present=true;
r.readback_allowed=false;
r.readback_attempted=false;
r.readback_value=0;
r.readback_valid=false;
r.step_result_recorded=true;
r.executor_step_count+=1;
r.result_present=true;
r.step_safe_return_recorded=true;
r.executor_step_count+=1;
r.executor_returned=true;
r.source_fingerprint_after=readSourceFingerprint();
r.source_fingerprint_unchanged=sameFp(r.source_fingerprint_before,r.source_fingerprint_after);
return finish(r);
}
fn corrupt(kind:HgatpExecutionDryRunBlocker) HgatpExecutionDryRunBlocker {
_=build();
const r=mutable();
switch(kind){
.missing_operation=>r.operation_present=false,.invalid_operation=>r.operation_valid=false,.source_mutated=>r.source_fingerprint_unchanged=false,.request_value_mismatch=>r.dry_run_request_value +%= 1,.explicit_opt_in_enabled=>r.operation_explicit_opt_in=true,.policy_allows_hardware_write=>r.operation_policy_allows=true,.operation_call_reachable=>r.operation_call_reachable=true,.operation_call_called=>r.operation_call_called=true,.raw_write_called=>r.raw_write_function_called=true,.execution_reached_raw_write=>r.execution_reached_raw_write=true,.execution_called_raw_write=>r.execution_called_raw_write=true,.fake_trap_observed=>r.trap_observed=true,.fake_readback_observed=>r.readback_valid=true,.hgatp_write_attempted=>r.hgatp_write_attempted=true,.hgatp_write_performed=>r.hgatp_write_performed=true,.active_stage2_forbidden=>r.active_stage2=true,.guest_entered_forbidden=>r.guest_entered=true,.first_instruction_forbidden=>r.first_guest_instruction_executed=true,.none=>{}
} return validate();
}
pub fn invariantConsumption() bool {
_=build();
const s=op.object();
return object().operation_checksum==s.checksum and object().operation_request_value==s.operation_request_value and object().operation_request_checksum==s.operation_request_checksum and object().operation_decision==tag(s.decision) and object().dry_run_request_present and object().dry_run_request_value==s.operation_request_value and object().dry_run_request_checksum==s.operation_request_checksum;
}
pub fn invariantCorruption() bool {
_=corrupt(.request_value_mismatch);
return object().blocker==.request_value_mismatch and object().result_code==.request_value_mismatch;
}
fn printBool(v:bool) void {
uart.write(if(v) "true" else "false");
}
fn printResult(label:[]const u8, k:HgatpExecutionDryRunBlocker) void {
uart.write("hv: hgatp_execution_dry_run.");
uart.write(label);
uart.write("=");
uart.write(@tagName(resultFor(k)));
uart.write(" blocker=");
uart.write(@tagName(k));
uart.write("\r\n");
}
pub fn printSummary() void {
const r=object();
uart.write("hv: hgatp_execution_dry_run.state=");
uart.write(@tagName(r.state));
uart.write(" decision=");
uart.write(@tagName(r.decision));
uart.write(" result_code=");
uart.write(@tagName(r.result_code));
uart.write(" blocker=");
uart.write(@tagName(r.blocker));
uart.write(" checksum=");
uart.writeHex(r.checksum);
uart.write("\r\n");
}
fn lineBool(name:[]const u8,v:bool) void {
uart.write("hv: hgatp_execution_dry_run.");
uart.write(name);
uart.write("=");
printBool(v);
uart.write("\r\n");
}
fn lineU(name:[]const u8,v:usize) void {
uart.write("hv: hgatp_execution_dry_run.");
uart.write(name);
uart.write("=");
uart.writeDec(v);
uart.write("\r\n");
}
fn lineHex(name:[]const u8,v:usize) void {
uart.write("hv: hgatp_execution_dry_run.");
uart.write(name);
uart.write("=");
uart.writeHex(v);
uart.write("\r\n");
}
pub fn printAllFields() void {
const r=object();
lineBool("operation_present",r.operation_present);
lineBool("operation_valid",r.operation_valid);
lineHex("operation_checksum",r.operation_checksum);
lineU("operation_decision",r.operation_decision);
lineHex("operation_request_value",r.operation_request_value);
lineHex("operation_request_checksum",r.operation_request_checksum);
lineBool("operation_explicit_opt_in",r.operation_explicit_opt_in);
lineBool("operation_policy_allows",r.operation_policy_allows);
lineBool("operation_policy_denies",r.operation_policy_denies);
lineBool("operation_denied_before_csr",r.operation_denied_before_csr);
lineBool("operation_blocked_before_raw_write",r.operation_blocked_before_raw_write);
lineBool("operation_call_reachable",r.operation_call_reachable);
lineBool("operation_call_called",r.operation_call_called);
lineBool("operation_raw_write_called",r.operation_raw_write_called);
lineBool("dry_run_request_present",r.dry_run_request_present);
lineHex("dry_run_request_value",r.dry_run_request_value);
lineHex("dry_run_request_checksum",r.dry_run_request_checksum);
lineBool("executor_entered",r.executor_entered);
lineBool("executor_returned",r.executor_returned);
lineU("executor_step_count",r.executor_step_count);
lineU("build_count",r.build_count);
lineU("validate_count",r.validate_count);
lineU("execute_count",r.execute_count);
lineBool("source_fingerprint_unchanged",r.source_fingerprint_unchanged);
lineBool("hgatp_write_attempted",r.hgatp_write_attempted);
lineBool("hgatp_write_performed",r.hgatp_write_performed);
lineBool("active_stage2",r.active_stage2);
lineBool("guest_entered",r.guest_entered);
lineBool("first_guest_instruction_executed",r.first_guest_instruction_executed);
}
pub fn printSteps() void {
const r=object();
lineBool("step_source_loaded",r.step_source_loaded);
lineBool("step_preflight_checked",r.step_preflight_checked);
lineBool("step_policy_checked",r.step_policy_checked);
lineBool("step_opt_in_checked",r.step_opt_in_checked);
lineBool("step_denied_before_csr",r.step_denied_before_csr);
lineBool("step_blocked_before_raw_write",r.step_blocked_before_raw_write);
lineBool("step_raw_write_skipped",r.step_raw_write_skipped);
lineBool("step_result_recorded",r.step_result_recorded);
lineBool("step_safe_return_recorded",r.step_safe_return_recorded);
lineU("executor_step_count",r.executor_step_count);
}
pub fn printRequest() void {
const r=object();
lineBool("dry_run_request_present",r.dry_run_request_present);
lineHex("dry_run_request_value",r.dry_run_request_value);
lineHex("dry_run_request_checksum",r.dry_run_request_checksum);
lineHex("operation_request_value",r.operation_request_value);
lineHex("operation_request_checksum",r.operation_request_checksum);
}
pub fn printOperationResult() void {
const r=object();
lineBool("result_present",r.result_present);
uart.write("hv: hgatp_execution_dry_run.result_code=");
uart.write(@tagName(r.result_code));
uart.write("\r\n");
lineHex("result_checksum",r.result_checksum);
}
pub fn printTrapSlot() void {
const r=object();
lineBool("trap_slot_present",r.trap_slot_present);
lineBool("trap_capture_armed",r.trap_capture_armed);
lineBool("trap_observed",r.trap_observed);
lineU("trap_scause",r.trap_scause);
lineU("trap_stval",r.trap_stval);
lineU("trap_sepc",r.trap_sepc);
}
pub fn printReadback() void {
const r=object();
lineBool("readback_slot_present",r.readback_slot_present);
lineBool("readback_allowed",r.readback_allowed);
lineBool("readback_attempted",r.readback_attempted);
lineHex("readback_value",r.readback_value);
lineBool("readback_valid",r.readback_valid);
}
pub fn printPolicy() void {
const r=object();
lineBool("execution_policy_allows",r.execution_policy_allows);
lineBool("execution_policy_denies",r.execution_policy_denies);
lineBool("execution_denied_before_csr",r.execution_denied_before_csr);
lineBool("execution_blocked_before_raw_write",r.execution_blocked_before_raw_write);
lineBool("execution_reached_raw_write",r.execution_reached_raw_write);
lineBool("execution_called_raw_write",r.execution_called_raw_write);
lineBool("execution_returned_from_raw_write",r.execution_returned_from_raw_write);
lineBool("raw_write_function_known",r.raw_write_function_known);
lineBool("raw_write_function_allowed",r.raw_write_function_allowed);
lineBool("raw_write_function_called",r.raw_write_function_called);
}
pub fn printBlockers() void {
const r=object();
uart.write("hv: hgatp_execution_dry_run.blocker=");
uart.write(@tagName(r.blocker));
uart.write("\r\n");
lineU("blocker_count",r.blocker_count);
}
pub fn printStatusCommand() void {
printSummary();
printAllFields();
printSteps();
printPolicy();
printOperationResult();
printTrapSlot();
printReadback();
}
pub fn printBuildCommand() void {
printResult("build_result", build());
printStatusCommand();
}
pub fn printValidateCommand() void {
printResult("validate_result", validate());
printStatusCommand();
}
pub fn printExecuteCommand() void {
printResult("execute_result", execute());
printStatusCommand();
}
pub fn printBlockersCommand() void {
_=validate();
printBlockers();
}
pub fn printNextCommand() void {
uart.write("hv: hgatp_execution_dry_run.next_action=");
uart.write(@tagName(object().next_action));
uart.write("\r\n");
}
pub fn printChecksumCommand() void {
lineHex("checksum",object().checksum);
}
pub fn printResetCommand() void {
reset();
uart.write("hv: hgatp_execution_dry_run.reset_result=ok\r\n");
printSummary();
}
pub fn printFieldsCommand() void {
printAllFields();
printPolicy();
}
pub fn printRequestCommand() void {
printRequest();
}
pub fn printStepsCommand() void {
printSteps();
}
pub fn printResultCommand() void {
printOperationResult();
}
pub fn printTrapSlotCommand() void {
printTrapSlot();
}
pub fn printReadbackCommand() void {
printReadback();
}
pub fn printDecisionCommand() void {
uart.write("hv: hgatp_execution_dry_run.decision=");
uart.write(@tagName(object().decision));
uart.write("\r\n");
}
pub fn printRequireOperationTestCommand() void {
printResult("require_operation_test", corrupt(.missing_operation));
printBlockers();
}
pub fn printInvalidOperationTestCommand() void {
printResult("invalid_operation_test", corrupt(.invalid_operation));
printBlockers();
}
pub fn printSourceIntegrityTestCommand() void {
printResult("source_integrity_test", corrupt(.source_mutated));
printBlockers();
}
pub fn printRequestValueTestCommand() void {
printResult("request_value_test", corrupt(.request_value_mismatch));
printBlockers();
}
pub fn printOptInTestCommand() void {
printResult("opt_in_test", corrupt(.explicit_opt_in_enabled));
printBlockers();
}
pub fn printPolicyAllowsTestCommand() void {
printResult("policy_allows_test", corrupt(.policy_allows_hardware_write));
printBlockers();
}
pub fn printOperationCallReachableTestCommand() void {
printResult("operation_call_reachable_test", corrupt(.operation_call_reachable));
printBlockers();
}
pub fn printOperationCallCalledTestCommand() void {
printResult("operation_call_called_test", corrupt(.operation_call_called));
printBlockers();
}
pub fn printRawWriteCalledTestCommand() void {
printResult("raw_write_called_test", corrupt(.raw_write_called));
printBlockers();
}
pub fn printExecutionReachedRawWriteTestCommand() void {
printResult("execution_reached_raw_write_test", corrupt(.execution_reached_raw_write));
printBlockers();
}
pub fn printExecutionCalledRawWriteTestCommand() void {
printResult("execution_called_raw_write_test", corrupt(.execution_called_raw_write));
printBlockers();
}
pub fn printFakeTrapTestCommand() void {
printResult("fake_trap_test", corrupt(.fake_trap_observed));
printBlockers();
}
pub fn printFakeReadbackTestCommand() void {
printResult("fake_readback_test", corrupt(.fake_readback_observed));
printBlockers();
}
pub fn printWriteAttemptedTestCommand() void {
printResult("write_attempted_test", corrupt(.hgatp_write_attempted));
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
pub fn printGuestEnteredTestCommand() void {
printResult("guest_entered_test", corrupt(.guest_entered_forbidden));
printBlockers();
}
pub fn printFirstInstructionTestCommand() void {
printResult("first_instruction_test", corrupt(.first_instruction_forbidden));
printBlockers();
}
pub fn printInvariantConsumptionCommand() void {
uart.write("hv: hgatp_execution_dry_run.invariant_consumption_result=");
uart.write(if(invariantConsumption()) "ok" else "rejected");
uart.write("\r\n");
}
pub fn printInvariantCorruptionCommand() void {
uart.write("hv: hgatp_execution_dry_run.invariant_corruption_result=");
uart.write(if(invariantCorruption()) "ok" else "rejected");
uart.write("\r\n");
}
