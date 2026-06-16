const uart = @import("../console/uart.zig");
const vm = @import("vm.zig");
const vcpu = @import("vcpu.zig");
const dry = @import("hgatp_execution_dry_run.zig");

pub const HgatpHardwareExecutorState = enum { empty,
built,
executed,
rejected };
pub const HgatpHardwareExecutorBlocker = enum { none,
dry_run_missing,
dry_run_invalid,
source_mutated,
request_value_mismatch,
policy_allows_hardware_write,
boundary_bypassed,
csr_write_reached,
csr_write_called,
raw_write_reached,
raw_write_called,
fake_trap_observed,
fake_readback_observed,
hgatp_write_attempted,
hgatp_write_performed,
active_stage2_forbidden,
guest_entered_forbidden,
first_instruction_forbidden };
pub const HgatpHardwareExecutorNextAction = enum { none,
build_dry_run_externally,
validate_dry_run_externally,
investigate_source_mutation,
inspect_request_value,
keep_hardware_policy_denied,
keep_boundary_before_csr,
keep_csr_write_skipped,
keep_raw_write_skipped,
clear_trap_slot,
clear_readback_slot,
stop_hgatp_write_attempt_observed,
stop_hgatp_write_performed_observed,
stop_active_stage2_observed,
stop_guest_entry_observed,
stop_first_instruction_observed };
pub const HgatpHardwareExecutorDecision = enum { none,
hardware_executor_denied_before_csr,
rejected };
pub const HgatpHardwareExecutorResultCode = enum { none,
hardware_executor_denied_before_csr,
dry_run_missing,
dry_run_invalid,
source_mutated,
request_value_mismatch,
policy_claimed_allowed,
boundary_claimed_bypassed,
csr_write_claimed_reached,
csr_write_claimed_called,
raw_write_claimed_reached,
raw_write_claimed_called,
fake_trap_observed,
fake_readback_observed,
write_attempt_claimed,
write_performed_claimed,
active_stage2_claimed,
guest_entry_claimed,
first_instruction_claimed };

pub const HgatpHardwareExecutorFingerprint = struct { dry_run_checksum: usize,
dry_run_state: usize,
dry_run_decision: usize,
dry_run_result_code: usize,
dry_run_request_value: usize,
dry_run_request_checksum: usize,
dry_run_executor_entered: bool,
dry_run_executor_returned: bool,
dry_run_step_count: usize,
dry_run_denied_before_csr: bool,
dry_run_blocked_before_raw_write: bool,
dry_run_raw_write_skipped: bool,
dry_run_raw_write_called: bool,
dry_run_trap_observed: bool,
dry_run_readback_attempted: bool,
dry_run_readback_valid: bool,
dry_run_hgatp_write_attempted: bool,
dry_run_hgatp_write_performed: bool,
dry_run_active_stage2: bool,
dry_run_guest_entered: bool,
dry_run_first_guest_instruction_executed: bool,
vm_id: vm.VmId,
vcpu_id: vcpu.VcpuId,
checksum: usize };
pub const HgatpHardwareExecutorRequest = struct { present: bool,
value: usize,
checksum: usize };
pub const HgatpHardwareExecutorSteps = struct { source_loaded: bool,
boundary_checked: bool,
policy_checked: bool,
csr_guard_checked: bool,
raw_write_guard_checked: bool,
denied_before_csr: bool,
blocked_before_raw_write: bool,
csr_write_skipped: bool,
raw_write_skipped: bool,
result_recorded: bool,
safe_return_recorded: bool,
count: usize };
pub const HgatpHardwareExecutorResult = struct { present: bool,
code: HgatpHardwareExecutorResultCode,
checksum: usize };
pub const HgatpHardwareExecutorTrapSlot = struct { present: bool,
capture_armed: bool,
observed: bool,
scause: usize,
stval: usize,
sepc: usize };
pub const HgatpHardwareExecutorReadbackSlot = struct { present: bool,
allowed: bool,
attempted: bool,
value: usize,
valid: bool };

pub const HgatpHardwareExecutor = struct {
    owner_vm_id: vm.VmId,
owner_vcpu_id: vcpu.VcpuId,
dry_run_present: bool,
dry_run_valid: bool,
dry_run_checksum: usize,
dry_run_decision: usize,
dry_run_request_value: usize,
dry_run_request_checksum: usize,
dry_run_executor_entered: bool,
dry_run_executor_returned: bool,
dry_run_step_count: usize,
dry_run_denied_before_csr: bool,
dry_run_blocked_before_raw_write: bool,
dry_run_raw_write_skipped: bool,
dry_run_raw_write_called: bool,
dry_run_trap_observed: bool,
dry_run_readback_attempted: bool,
dry_run_readback_valid: bool,
    hardware_request_present: bool,
hardware_request_checksum: usize,
hardware_request_value: usize,
executor_built: bool,
executor_entered: bool,
executor_returned: bool,
executor_step_count: usize,
    step_source_loaded: bool,
step_boundary_checked: bool,
step_policy_checked: bool,
step_csr_guard_checked: bool,
step_raw_write_guard_checked: bool,
step_denied_before_csr: bool,
step_blocked_before_raw_write: bool,
step_csr_write_skipped: bool,
step_raw_write_skipped: bool,
step_result_recorded: bool,
step_safe_return_recorded: bool,
    hardware_policy_allows: bool,
hardware_policy_denies: bool,
hardware_denied_before_csr: bool,
hardware_blocked_before_raw_write: bool,
hardware_reached_csr_write: bool,
hardware_called_csr_write: bool,
hardware_reached_raw_write: bool,
hardware_called_raw_write: bool,
hardware_returned_from_raw_write: bool,
    csr_write_function_known: bool,
csr_write_function_allowed: bool,
csr_write_function_called: bool,
raw_write_function_known: bool,
raw_write_function_allowed: bool,
raw_write_function_called: bool,
    result_present: bool,
result_code: HgatpHardwareExecutorResultCode,
result_checksum: usize,
trap_slot_present: bool,
trap_capture_armed: bool,
trap_observed: bool,
trap_scause: usize,
trap_stval: usize,
trap_sepc: usize,
readback_slot_present: bool,
readback_allowed: bool,
readback_attempted: bool,
readback_value: usize,
readback_valid: bool,
    hgatp_write_attempted: bool,
hgatp_write_performed: bool,
active_stage2: bool,
guest_entered: bool,
first_guest_instruction_executed: bool,
source_fingerprint_before: HgatpHardwareExecutorFingerprint,
source_fingerprint_after: HgatpHardwareExecutorFingerprint,
source_fingerprint_unchanged: bool,
blocker: HgatpHardwareExecutorBlocker,
blocker_count: usize,
next_action: HgatpHardwareExecutorNextAction,
decision: HgatpHardwareExecutorDecision,
checksum: usize,
build_count: usize,
validate_count: usize,
execute_count: usize,
reject_count: usize,
reset_count: usize,
state: HgatpHardwareExecutorState,
};
var obj: HgatpHardwareExecutor = undefined;
var initialized=false;
fn tag(e:anytype)usize{return @intFromEnum(e);}
fn b(v:bool)usize{return if(v)1 else 0;}
fn mix(a:usize,c:usize)usize{return (a^c)*%0x9e37_79b9_7f4a_7c15;}
fn emptyFp()HgatpHardwareExecutorFingerprint{return .{.dry_run_checksum=0,.dry_run_state=0,.dry_run_decision=0,.dry_run_result_code=0,.dry_run_request_value=0,.dry_run_request_checksum=0,.dry_run_executor_entered=false,.dry_run_executor_returned=false,.dry_run_step_count=0,.dry_run_denied_before_csr=false,.dry_run_blocked_before_raw_write=false,.dry_run_raw_write_skipped=false,.dry_run_raw_write_called=false,.dry_run_trap_observed=false,.dry_run_readback_attempted=false,.dry_run_readback_valid=false,.dry_run_hgatp_write_attempted=false,.dry_run_hgatp_write_performed=false,.dry_run_active_stage2=false,.dry_run_guest_entered=false,.dry_run_first_guest_instruction_executed=false,.vm_id=0,.vcpu_id=0,.checksum=0};}
fn empty(owner:vm.VmId,vc:vcpu.VcpuId,resets:usize)HgatpHardwareExecutor{return .{.owner_vm_id=owner,.owner_vcpu_id=vc,.dry_run_present=false,.dry_run_valid=false,.dry_run_checksum=0,.dry_run_decision=0,.dry_run_request_value=0,.dry_run_request_checksum=0,.dry_run_executor_entered=false,.dry_run_executor_returned=false,.dry_run_step_count=0,.dry_run_denied_before_csr=false,.dry_run_blocked_before_raw_write=false,.dry_run_raw_write_skipped=false,.dry_run_raw_write_called=false,.dry_run_trap_observed=false,.dry_run_readback_attempted=false,.dry_run_readback_valid=false,.hardware_request_present=false,.hardware_request_checksum=0,.hardware_request_value=0,.executor_built=false,.executor_entered=false,.executor_returned=false,.executor_step_count=0,.step_source_loaded=false,.step_boundary_checked=false,.step_policy_checked=false,.step_csr_guard_checked=false,.step_raw_write_guard_checked=false,.step_denied_before_csr=false,.step_blocked_before_raw_write=false,.step_csr_write_skipped=false,.step_raw_write_skipped=false,.step_result_recorded=false,.step_safe_return_recorded=false,.hardware_policy_allows=false,.hardware_policy_denies=true,.hardware_denied_before_csr=true,.hardware_blocked_before_raw_write=true,.hardware_reached_csr_write=false,.hardware_called_csr_write=false,.hardware_reached_raw_write=false,.hardware_called_raw_write=false,.hardware_returned_from_raw_write=false,.csr_write_function_known=true,.csr_write_function_allowed=false,.csr_write_function_called=false,.raw_write_function_known=true,.raw_write_function_allowed=false,.raw_write_function_called=false,.result_present=false,.result_code=.none,.result_checksum=0,.trap_slot_present=true,.trap_capture_armed=false,.trap_observed=false,.trap_scause=0,.trap_stval=0,.trap_sepc=0,.readback_slot_present=true,.readback_allowed=false,.readback_attempted=false,.readback_value=0,.readback_valid=false,.hgatp_write_attempted=false,.hgatp_write_performed=false,.active_stage2=false,.guest_entered=false,.first_guest_instruction_executed=false,.source_fingerprint_before=emptyFp(),.source_fingerprint_after=emptyFp(),.source_fingerprint_unchanged=false,.blocker=.none,.blocker_count=0,.next_action=.none,.decision=.none,.checksum=0,.build_count=0,.validate_count=0,.execute_count=0,.reject_count=0,.reset_count=resets,.state=.empty};}
pub fn init(owner:vm.VmId,vc:vcpu.VcpuId)void{obj=empty(owner,vc,0);initialized=true;}
fn mutable()*HgatpHardwareExecutor{if(!initialized)init(vm.object().id,vcpu.object().id);return &obj;}
pub fn object()*const HgatpHardwareExecutor{return mutable();}
pub fn reset()void{const r=mutable().reset_count+1;obj=empty(vm.object().id,vcpu.object().id,r);initialized=true;}
fn fpChecksum(f: HgatpHardwareExecutorFingerprint) usize {
    var x: usize = 0x3600;
    x = mix(x,
f.dry_run_checksum);
x = mix(x,
f.dry_run_state);
x = mix(x,
f.dry_run_decision);
x = mix(x,
f.dry_run_result_code);
    x = mix(x,
f.dry_run_request_value);
x = mix(x,
f.dry_run_request_checksum);
x = mix(x,
b(f.dry_run_executor_entered));
x = mix(x,
b(f.dry_run_executor_returned));
    x = mix(x,
f.dry_run_step_count);
x = mix(x,
b(f.dry_run_denied_before_csr));
x = mix(x,
b(f.dry_run_blocked_before_raw_write));
x = mix(x,
b(f.dry_run_raw_write_skipped));
    x = mix(x,
b(f.dry_run_raw_write_called));
x = mix(x,
b(f.dry_run_trap_observed));
x = mix(x,
b(f.dry_run_readback_attempted));
x = mix(x,
b(f.dry_run_readback_valid));
    x = mix(x,
b(f.dry_run_hgatp_write_attempted));
x = mix(x,
b(f.dry_run_hgatp_write_performed));
x = mix(x,
b(f.dry_run_active_stage2));
x = mix(x,
b(f.dry_run_guest_entered));
    x = mix(x,
b(f.dry_run_first_guest_instruction_executed));
x = mix(x,
@intCast(f.vm_id));
x = mix(x,
@intCast(f.vcpu_id));
    return if (x == 0) 1 else x;
}
pub fn readSourceFingerprint()HgatpHardwareExecutorFingerprint{const s=dry.object();var f=HgatpHardwareExecutorFingerprint{.dry_run_checksum=s.checksum,.dry_run_state=tag(s.state),.dry_run_decision=tag(s.decision),.dry_run_result_code=tag(s.result_code),.dry_run_request_value=s.dry_run_request_value,.dry_run_request_checksum=s.dry_run_request_checksum,.dry_run_executor_entered=s.executor_entered,.dry_run_executor_returned=s.executor_returned,.dry_run_step_count=s.executor_step_count,.dry_run_denied_before_csr=s.step_denied_before_csr,.dry_run_blocked_before_raw_write=s.step_blocked_before_raw_write,.dry_run_raw_write_skipped=s.step_raw_write_skipped,.dry_run_raw_write_called=s.raw_write_function_called,.dry_run_trap_observed=s.trap_observed,.dry_run_readback_attempted=s.readback_attempted,.dry_run_readback_valid=s.readback_valid,.dry_run_hgatp_write_attempted=s.hgatp_write_attempted,.dry_run_hgatp_write_performed=s.hgatp_write_performed,.dry_run_active_stage2=s.active_stage2,.dry_run_guest_entered=s.guest_entered,.dry_run_first_guest_instruction_executed=s.first_guest_instruction_executed,.vm_id=vm.object().id,.vcpu_id=vcpu.object().id,.checksum=0};f.checksum=fpChecksum(f);return f;}
fn sameFp(a:HgatpHardwareExecutorFingerprint,c:HgatpHardwareExecutorFingerprint)bool{return a.checksum==c.checksum and a.dry_run_checksum==c.dry_run_checksum and a.dry_run_request_value==c.dry_run_request_value and a.dry_run_request_checksum==c.dry_run_request_checksum and a.dry_run_executor_entered==c.dry_run_executor_entered and a.dry_run_executor_returned==c.dry_run_executor_returned and a.vm_id==c.vm_id and a.vcpu_id==c.vcpu_id;}
fn sourcePresent()bool{const s=dry.object();return s.state!=.empty and s.checksum!=0;}
fn sourceValid()bool{const s=dry.object();return s.state==.executed and s.result_present and s.result_code==.dry_run_complete_denied_before_csr and s.dry_run_request_present;}
fn loadSource(r:*HgatpHardwareExecutor)void{const s=dry.object();r.dry_run_present=sourcePresent();r.dry_run_valid=sourceValid();r.dry_run_checksum=s.checksum;r.dry_run_decision=tag(s.decision);r.dry_run_request_value=s.dry_run_request_value;r.dry_run_request_checksum=s.dry_run_request_checksum;r.dry_run_executor_entered=s.executor_entered;r.dry_run_executor_returned=s.executor_returned;r.dry_run_step_count=s.executor_step_count;r.dry_run_denied_before_csr=s.step_denied_before_csr;r.dry_run_blocked_before_raw_write=s.step_blocked_before_raw_write;r.dry_run_raw_write_skipped=s.step_raw_write_skipped;r.dry_run_raw_write_called=s.raw_write_function_called;r.dry_run_trap_observed=s.trap_observed;r.dry_run_readback_attempted=s.readback_attempted;r.dry_run_readback_valid=s.readback_valid;r.hardware_request_present=r.dry_run_present;r.hardware_request_value=s.dry_run_request_value;r.hardware_request_checksum=s.dry_run_request_checksum;r.hgatp_write_attempted=s.hgatp_write_attempted;r.hgatp_write_performed=s.hgatp_write_performed;r.active_stage2=s.active_stage2;r.guest_entered=s.guest_entered;r.first_guest_instruction_executed=s.first_guest_instruction_executed;}
fn code(k:HgatpHardwareExecutorBlocker)HgatpHardwareExecutorResultCode{return switch(k){.none=>.hardware_executor_denied_before_csr,.dry_run_missing=>.dry_run_missing,.dry_run_invalid=>.dry_run_invalid,.source_mutated=>.source_mutated,.request_value_mismatch=>.request_value_mismatch,.policy_allows_hardware_write=>.policy_claimed_allowed,.boundary_bypassed=>.boundary_claimed_bypassed,.csr_write_reached=>.csr_write_claimed_reached,.csr_write_called=>.csr_write_claimed_called,.raw_write_reached=>.raw_write_claimed_reached,.raw_write_called=>.raw_write_claimed_called,.fake_trap_observed=>.fake_trap_observed,.fake_readback_observed=>.fake_readback_observed,.hgatp_write_attempted=>.write_attempt_claimed,.hgatp_write_performed=>.write_performed_claimed,.active_stage2_forbidden=>.active_stage2_claimed,.guest_entered_forbidden=>.guest_entry_claimed,.first_instruction_forbidden=>.first_instruction_claimed};}
fn action(k:HgatpHardwareExecutorBlocker)HgatpHardwareExecutorNextAction{return switch(k){.none=>.keep_hardware_policy_denied,.dry_run_missing=>.build_dry_run_externally,.dry_run_invalid=>.validate_dry_run_externally,.source_mutated=>.investigate_source_mutation,.request_value_mismatch=>.inspect_request_value,.policy_allows_hardware_write=>.keep_hardware_policy_denied,.boundary_bypassed=>.keep_boundary_before_csr,.csr_write_reached=>.keep_csr_write_skipped,.csr_write_called=>.keep_csr_write_skipped,.raw_write_reached=>.keep_raw_write_skipped,.raw_write_called=>.keep_raw_write_skipped,.fake_trap_observed=>.clear_trap_slot,.fake_readback_observed=>.clear_readback_slot,.hgatp_write_attempted=>.stop_hgatp_write_attempt_observed,.hgatp_write_performed=>.stop_hgatp_write_performed_observed,.active_stage2_forbidden=>.stop_active_stage2_observed,.guest_entered_forbidden=>.stop_guest_entry_observed,.first_instruction_forbidden=>.stop_first_instruction_observed};}
fn first(r:HgatpHardwareExecutor)HgatpHardwareExecutorBlocker{if(!r.dry_run_present)return .dry_run_missing;if(!r.dry_run_valid)return .dry_run_invalid;if(!r.source_fingerprint_unchanged)return .source_mutated;if(r.hardware_request_value!=r.dry_run_request_value or r.hardware_request_checksum!=r.dry_run_request_checksum)return .request_value_mismatch;if(r.hardware_policy_allows or !r.hardware_policy_denies)return .policy_allows_hardware_write;if(!r.hardware_denied_before_csr or !r.hardware_blocked_before_raw_write)return .boundary_bypassed;if(r.hardware_reached_csr_write)return .csr_write_reached;if(r.hardware_called_csr_write or r.csr_write_function_called)return .csr_write_called;if(r.hardware_reached_raw_write)return .raw_write_reached;if(r.hardware_called_raw_write or r.hardware_returned_from_raw_write or r.raw_write_function_called)return .raw_write_called;if(r.trap_capture_armed or r.trap_observed or r.trap_scause!=0 or r.trap_stval!=0 or r.trap_sepc!=0)return .fake_trap_observed;if(r.readback_allowed or r.readback_attempted or r.readback_valid or r.readback_value!=0)return .fake_readback_observed;if(r.hgatp_write_attempted)return .hgatp_write_attempted;if(r.hgatp_write_performed)return .hgatp_write_performed;if(r.active_stage2)return .active_stage2_forbidden;if(r.guest_entered)return .guest_entered_forbidden;if(r.first_guest_instruction_executed)return .first_instruction_forbidden;return .none;}
fn checksum(r:HgatpHardwareExecutor)usize{var x:usize=0x3636;x=mix(x,r.source_fingerprint_before.checksum);x=mix(x,r.source_fingerprint_after.checksum);x=mix(x,r.dry_run_checksum);x=mix(x,r.dry_run_request_value);x=mix(x,r.hardware_request_value);x=mix(x,r.executor_step_count);x=mix(x,tag(r.result_code));return if(x==0)1 else x;}
fn finish(r:*HgatpHardwareExecutor)HgatpHardwareExecutorBlocker{const k=first(r.*);r.blocker=k;r.blocker_count=if(k==.none)0 else 1;r.next_action=action(k);r.result_present=true;r.result_code=code(k);r.decision=if(k==.none).hardware_executor_denied_before_csr else .rejected;r.state=if(k==.none and r.executor_returned).executed else if(k==.none).built else .rejected;if(k!=.none)r.reject_count+=1;r.checksum=checksum(r.*);r.result_checksum=r.checksum^0x3636;return k;}
pub fn build()HgatpHardwareExecutorBlocker{const r=mutable();r.build_count+=1;r.owner_vm_id=vm.object().id;r.owner_vcpu_id=vcpu.object().id;r.source_fingerprint_before=readSourceFingerprint();loadSource(r);r.executor_built=true;r.executor_entered=false;r.executor_returned=false;r.executor_step_count=0;r.step_source_loaded=false;r.step_boundary_checked=false;r.step_policy_checked=false;r.step_csr_guard_checked=false;r.step_raw_write_guard_checked=false;r.step_denied_before_csr=false;r.step_blocked_before_raw_write=false;r.step_csr_write_skipped=false;r.step_raw_write_skipped=false;r.step_result_recorded=false;r.step_safe_return_recorded=false;r.hardware_policy_allows=false;r.hardware_policy_denies=true;r.hardware_denied_before_csr=true;r.hardware_blocked_before_raw_write=true;r.hardware_reached_csr_write=false;r.hardware_called_csr_write=false;r.hardware_reached_raw_write=false;r.hardware_called_raw_write=false;r.hardware_returned_from_raw_write=false;r.csr_write_function_known=true;r.csr_write_function_allowed=false;r.csr_write_function_called=false;r.raw_write_function_known=true;r.raw_write_function_allowed=false;r.raw_write_function_called=false;r.trap_slot_present=true;r.trap_capture_armed=false;r.trap_observed=false;r.trap_scause=0;r.trap_stval=0;r.trap_sepc=0;r.readback_slot_present=true;r.readback_allowed=false;r.readback_attempted=false;r.readback_value=0;r.readback_valid=false;r.source_fingerprint_after=readSourceFingerprint();r.source_fingerprint_unchanged=sameFp(r.source_fingerprint_before,r.source_fingerprint_after);return finish(r);}
pub fn validate()HgatpHardwareExecutorBlocker{const r=mutable();r.validate_count+=1;return finish(r);} 
pub fn execute()HgatpHardwareExecutorBlocker{const r=mutable();r.execute_count+=1;r.source_fingerprint_before=readSourceFingerprint();loadSource(r);r.executor_entered=true;r.executor_returned=false;r.executor_step_count=0;r.step_source_loaded=true;r.executor_step_count+=1;r.step_boundary_checked=true;r.executor_step_count+=1;r.step_policy_checked=true;r.executor_step_count+=1;r.step_csr_guard_checked=true;r.executor_step_count+=1;r.step_raw_write_guard_checked=true;r.executor_step_count+=1;r.step_denied_before_csr=true;r.hardware_denied_before_csr=true;r.executor_step_count+=1;r.step_blocked_before_raw_write=true;r.hardware_blocked_before_raw_write=true;r.executor_step_count+=1;r.step_csr_write_skipped=true;r.hardware_reached_csr_write=false;r.hardware_called_csr_write=false;r.csr_write_function_called=false;r.executor_step_count+=1;r.step_raw_write_skipped=true;r.hardware_reached_raw_write=false;r.hardware_called_raw_write=false;r.raw_write_function_called=false;r.executor_step_count+=1;r.step_result_recorded=true;r.result_present=true;r.executor_step_count+=1;r.step_safe_return_recorded=true;r.executor_returned=true;r.executor_step_count+=1;r.source_fingerprint_after=readSourceFingerprint();r.source_fingerprint_unchanged=sameFp(r.source_fingerprint_before,r.source_fingerprint_after);return finish(r);}
fn corrupt(k:HgatpHardwareExecutorBlocker)HgatpHardwareExecutorBlocker{_=build();const r=mutable();switch(k){.dry_run_missing=>r.dry_run_present=false,.dry_run_invalid=>r.dry_run_valid=false,.source_mutated=>r.source_fingerprint_unchanged=false,.request_value_mismatch=>r.hardware_request_value+%=1,.policy_allows_hardware_write=>r.hardware_policy_allows=true,.boundary_bypassed=>r.hardware_denied_before_csr=false,.csr_write_reached=>r.hardware_reached_csr_write = true,.csr_write_called=>r.csr_write_function_called = true,.raw_write_reached=>r.hardware_reached_raw_write = true,.raw_write_called=>r.raw_write_function_called = true,.fake_trap_observed=>r.trap_observed = true,.fake_readback_observed=>r.readback_valid = true,.hgatp_write_attempted=>r.hgatp_write_attempted = true,.hgatp_write_performed=>r.hgatp_write_performed = true,.active_stage2_forbidden=>r.active_stage2 = true,.guest_entered_forbidden=>r.guest_entered = true,.first_instruction_forbidden=>r.first_guest_instruction_executed = true,.none=>{}}return validate();}
pub fn invariantConsumption()bool{_=build();const s=dry.object();return object().dry_run_checksum==s.checksum and object().dry_run_request_value==s.dry_run_request_value and object().dry_run_request_checksum==s.dry_run_request_checksum and object().dry_run_decision==tag(s.decision) and object().hardware_request_value==s.dry_run_request_value and object().hardware_request_checksum==s.dry_run_request_checksum;}
pub fn invariantCorruption()bool{_=corrupt(.request_value_mismatch);return object().blocker==.request_value_mismatch and object().result_code==.request_value_mismatch;}
fn pb(v:bool)void{uart.write(if(v)"true" else "false");}
fn lineB(n:[]const u8,v:bool)void{uart.write("hv: hgatp_hardware_executor.");uart.write(n);uart.write("=");pb(v);uart.write("\r\n");}
fn lineU(n:[]const u8,v:usize)void{uart.write("hv: hgatp_hardware_executor.");uart.write(n);uart.write("=");uart.writeDec(v);uart.write("\r\n");}
fn lineH(n:[]const u8,v:usize)void{uart.write("hv: hgatp_hardware_executor.");uart.write(n);uart.write("=");uart.writeHex(v);uart.write("\r\n");}
fn pr(label:[]const u8,k:HgatpHardwareExecutorBlocker)void{uart.write("hv: hgatp_hardware_executor.");uart.write(label);uart.write("=");uart.write(@tagName(code(k)));uart.write(" blocker=");uart.write(@tagName(k));uart.write("\r\n");}
pub fn printSummary()void{const r=object();uart.write("hv: hgatp_hardware_executor.state=");uart.write(@tagName(r.state));uart.write(" decision=");uart.write(@tagName(r.decision));uart.write(" result_code=");uart.write(@tagName(r.result_code));uart.write(" blocker=");uart.write(@tagName(r.blocker));uart.write(" checksum=");uart.writeHex(r.checksum);uart.write("\r\n");}
pub fn printAllFields()void{const r=object();lineB("dry_run_present",r.dry_run_present);lineB("dry_run_valid",r.dry_run_valid);lineH("dry_run_checksum",r.dry_run_checksum);lineU("dry_run_decision",r.dry_run_decision);lineH("dry_run_request_value",r.dry_run_request_value);lineH("dry_run_request_checksum",r.dry_run_request_checksum);lineB("hardware_request_present",r.hardware_request_present);lineH("hardware_request_value",r.hardware_request_value);lineH("hardware_request_checksum",r.hardware_request_checksum);lineB("executor_built",r.executor_built);lineB("executor_entered",r.executor_entered);lineB("executor_returned",r.executor_returned);lineU("executor_step_count",r.executor_step_count);lineU("build_count",r.build_count);lineU("validate_count",r.validate_count);lineU("execute_count",r.execute_count);lineB("source_fingerprint_unchanged",r.source_fingerprint_unchanged);lineB("hgatp_write_attempted",r.hgatp_write_attempted);lineB("hgatp_write_performed",r.hgatp_write_performed);lineB("active_stage2",r.active_stage2);lineB("guest_entered",r.guest_entered);lineB("first_guest_instruction_executed",r.first_guest_instruction_executed);}
pub fn printSteps()void{const r=object();lineB("step_source_loaded",r.step_source_loaded);lineB("step_boundary_checked",r.step_boundary_checked);lineB("step_policy_checked",r.step_policy_checked);lineB("step_csr_guard_checked",r.step_csr_guard_checked);lineB("step_raw_write_guard_checked",r.step_raw_write_guard_checked);lineB("step_denied_before_csr",r.step_denied_before_csr);lineB("step_blocked_before_raw_write",r.step_blocked_before_raw_write);lineB("step_csr_write_skipped",r.step_csr_write_skipped);lineB("step_raw_write_skipped",r.step_raw_write_skipped);lineB("step_result_recorded",r.step_result_recorded);lineB("step_safe_return_recorded",r.step_safe_return_recorded);lineU("executor_step_count",r.executor_step_count);}
pub fn printPolicy()void{const r=object();lineB("hardware_policy_allows",r.hardware_policy_allows);lineB("hardware_policy_denies",r.hardware_policy_denies);lineB("hardware_denied_before_csr",r.hardware_denied_before_csr);lineB("hardware_blocked_before_raw_write",r.hardware_blocked_before_raw_write);lineB("hardware_reached_csr_write",r.hardware_reached_csr_write);lineB("hardware_called_csr_write",r.hardware_called_csr_write);lineB("hardware_reached_raw_write",r.hardware_reached_raw_write);lineB("hardware_called_raw_write",r.hardware_called_raw_write);lineB("hardware_returned_from_raw_write",r.hardware_returned_from_raw_write);lineB("csr_write_function_known",r.csr_write_function_known);lineB("csr_write_function_allowed",r.csr_write_function_allowed);lineB("csr_write_function_called",r.csr_write_function_called);lineB("raw_write_function_known",r.raw_write_function_known);lineB("raw_write_function_allowed",r.raw_write_function_allowed);lineB("raw_write_function_called",r.raw_write_function_called);}
pub fn printRequest()void{const r=object();lineB("hardware_request_present",r.hardware_request_present);lineH("hardware_request_value",r.hardware_request_value);lineH("hardware_request_checksum",r.hardware_request_checksum);lineH("dry_run_request_value",r.dry_run_request_value);lineH("dry_run_request_checksum",r.dry_run_request_checksum);}
pub fn printResult()void{const r=object();lineB("result_present",r.result_present);uart.write("hv: hgatp_hardware_executor.result_code=");uart.write(@tagName(r.result_code));uart.write("\r\n");lineH("result_checksum",r.result_checksum);}
pub fn printTrapSlot()void{const r=object();lineB("trap_slot_present",r.trap_slot_present);lineB("trap_capture_armed",r.trap_capture_armed);lineB("trap_observed",r.trap_observed);lineU("trap_scause",r.trap_scause);lineU("trap_stval",r.trap_stval);lineU("trap_sepc",r.trap_sepc);}
pub fn printReadback()void{const r=object();lineB("readback_slot_present",r.readback_slot_present);lineB("readback_allowed",r.readback_allowed);lineB("readback_attempted",r.readback_attempted);lineH("readback_value",r.readback_value);lineB("readback_valid",r.readback_valid);}
pub fn printBlockers()void{const r=object();uart.write("hv: hgatp_hardware_executor.blocker=");uart.write(@tagName(r.blocker));uart.write("\r\n");lineU("blocker_count",r.blocker_count);}
pub fn printStatusCommand()void{printSummary();printAllFields();printSteps();printPolicy();printResult();printTrapSlot();printReadback();}
pub fn printBuildCommand()void{pr("build_result",build());printStatusCommand();}
pub fn printValidateCommand()void{pr("validate_result",validate());printStatusCommand();}
pub fn printExecuteCommand()void{pr("execute_result",execute());printStatusCommand();}
pub fn printBlockersCommand()void{_=validate();printBlockers();}
pub fn printNextCommand()void{uart.write("hv: hgatp_hardware_executor.next_action=");uart.write(@tagName(object().next_action));uart.write("\r\n");}
pub fn printChecksumCommand()void{lineH("checksum",object().checksum);}
pub fn printResetCommand()void{reset();uart.write("hv: hgatp_hardware_executor.reset_result=ok\r\n");printSummary();}
pub fn printFieldsCommand()void{printAllFields();printPolicy();}
pub fn printRequestCommand()void{printRequest();}
pub fn printStepsCommand()void{printSteps();}
pub fn printResultCommand()void{printResult();}
pub fn printTrapSlotCommand()void{printTrapSlot();}
pub fn printReadbackCommand()void{printReadback();}
pub fn printDecisionCommand()void{uart.write("hv: hgatp_hardware_executor.decision=");uart.write(@tagName(object().decision));uart.write("\r\n");}
pub fn printRequireDryRunTestCommand()void{pr("require_dry_run_test",corrupt(.dry_run_missing));printBlockers();}
pub fn printInvalidDryRunTestCommand()void{pr("invalid_dry_run_test",corrupt(.dry_run_invalid));printBlockers();}
pub fn printSourceIntegrityTestCommand()void{pr("source_integrity_test",corrupt(.source_mutated));printBlockers();}
pub fn printRequestValueTestCommand()void{pr("request_value_test",corrupt(.request_value_mismatch));printBlockers();}
pub fn printPolicyAllowsTestCommand()void{pr("policy_allows_test",corrupt(.policy_allows_hardware_write));printBlockers();}
pub fn printBoundaryBypassTestCommand()void{pr("boundary_bypass_test",corrupt(.boundary_bypassed));printBlockers();}
pub fn printCsrReachedTestCommand()void{pr("csr_reached_test",corrupt(.csr_write_reached));printBlockers();}
pub fn printCsrCalledTestCommand()void{pr("csr_called_test",corrupt(.csr_write_called));printBlockers();}
pub fn printRawReachedTestCommand()void{pr("raw_reached_test",corrupt(.raw_write_reached));printBlockers();}
pub fn printRawCalledTestCommand()void{pr("raw_called_test",corrupt(.raw_write_called));printBlockers();}
pub fn printFakeTrapTestCommand()void{pr("fake_trap_test",corrupt(.fake_trap_observed));printBlockers();}
pub fn printFakeReadbackTestCommand()void{pr("fake_readback_test",corrupt(.fake_readback_observed));printBlockers();}
pub fn printWriteAttemptedTestCommand()void{pr("write_attempted_test",corrupt(.hgatp_write_attempted));printBlockers();}
pub fn printWritePerformedTestCommand()void{pr("write_performed_test",corrupt(.hgatp_write_performed));printBlockers();}
pub fn printActiveStage2TestCommand()void{pr("active_stage2_test",corrupt(.active_stage2_forbidden));printBlockers();}
pub fn printGuestEnteredTestCommand()void{pr("guest_entered_test",corrupt(.guest_entered_forbidden));printBlockers();}
pub fn printFirstInstructionTestCommand()void{pr("first_instruction_test",corrupt(.first_instruction_forbidden));printBlockers();}
pub fn printInvariantConsumptionCommand()void{uart.write("hv: hgatp_hardware_executor.invariant_consumption_result=");uart.write(if(invariantConsumption())"ok" else "rejected");uart.write("\r\n");}
pub fn printInvariantCorruptionCommand()void{uart.write("hv: hgatp_hardware_executor.invariant_corruption_result=");uart.write(if(invariantCorruption())"ok" else "rejected");uart.write("\r\n");}
