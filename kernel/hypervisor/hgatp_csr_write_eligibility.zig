const uart = @import("../console/uart.zig");
const vm = @import("vm.zig");
const vcpu = @import("vcpu.zig");
const boundary = @import("hgatp_csr_write_boundary.zig");

pub const HgatpCsrWriteEligibilityState = enum {
empty,
built,
evaluated,
rejected
};
pub const HgatpCsrWriteEligibilityBlocker = enum {
none,
boundary_missing,
boundary_invalid,
source_mutated,
request_value_mismatch,
policy_allows_hardware_write,
csr_write_eligible,
csr_write_reached,
csr_write_called,
raw_write_reached,
raw_write_called,
fake_trap_observed,
fake_fault_observed,
fake_readback_observed,
hgatp_write_attempted,
hgatp_write_performed,
active_stage2_forbidden,
guest_entered_forbidden,
first_instruction_forbidden
};
pub const HgatpCsrWriteEligibilityNextAction = enum {
none,
provide_valid_hv38_boundary,
investigate_source_mutation,
keep_denied_before_hardware,
clear_local_corruption
};
pub const HgatpCsrWriteEligibilityDecision = enum {
none,
csr_write_ineligible_denied_before_hardware,
boundary_missing,
boundary_invalid,
source_mutated,
request_value_mismatch,
policy_claimed_allowed,
csr_write_claimed_eligible,
csr_write_claimed_reached,
csr_write_claimed_called,
raw_write_claimed_reached,
raw_write_claimed_called,
fake_trap_observed,
fake_fault_observed,
fake_readback_observed,
write_attempt_claimed,
write_performed_claimed,
active_stage2_claimed,
guest_entry_claimed,
first_instruction_claimed
};

pub const HgatpCsrWriteEligibilityFingerprint = struct {
checksum: usize,
boundary_checksum: usize,
boundary_state: usize,
boundary_decision: usize,
boundary_result_code: usize,
boundary_request_value: usize,
boundary_request_checksum: usize,
boundary_denied_before_csr: bool,
boundary_blocked_before_raw_write: bool,
boundary_csr_write_called: bool,
boundary_raw_write_called: bool,
boundary_trap_observed: bool,
boundary_fault_observed: bool,
boundary_readback_attempted: bool,
boundary_readback_valid: bool,
boundary_hgatp_write_attempted: bool,
boundary_hgatp_write_performed: bool,
boundary_active_stage2: bool,
boundary_guest_entered: bool,
boundary_first_guest_instruction_executed: bool,
owner_vm_id: vm.VmId,
owner_vcpu_id: vcpu.VcpuId
};
pub const HgatpCsrWriteEligibilityRequest = struct {
present: bool,
value: usize,
checksum: usize,
source_decision: usize
};
pub const HgatpCsrWriteEligibilitySteps = struct {
source_loaded: bool,
boundary_checked: bool,
request_checked: bool,
policy_checked: bool,
csr_guard_checked: bool,
raw_guard_checked: bool,
denied_before_hardware: bool,
csr_write_skipped: bool,
raw_write_skipped: bool,
result_recorded: bool,
safe_return_recorded: bool,
count: usize
};
pub const HgatpCsrWriteEligibilityResult = struct {
code: HgatpCsrWriteEligibilityDecision,
denied_before_hardware: bool,
safe_to_return: bool,
csr_skipped: bool,
raw_skipped: bool
};
pub const HgatpCsrWriteEligibilityTrapSlot = struct {
present: bool,
armed: bool,
observed: bool,
scause: usize,
stval: usize,
sepc: usize
};
pub const HgatpCsrWriteEligibilityReadbackSlot = struct {
present: bool,
allowed: bool,
attempted: bool,
value: usize,
valid: bool
};

pub const HgatpCsrWriteEligibility = struct {
    owner_vm_id: vm.VmId,
owner_vcpu_id: vcpu.VcpuId,
boundary_present: bool,
boundary_valid: bool,
boundary_checksum: usize,
boundary_decision: usize,
boundary_request_value: usize,
boundary_request_checksum: usize,
boundary_denied_before_csr: bool,
boundary_blocked_before_raw_write: bool,
boundary_csr_write_called: bool,
boundary_raw_write_called: bool,
boundary_trap_observed: bool,
boundary_fault_observed: bool,
boundary_readback_attempted: bool,
boundary_readback_valid: bool,
    eligibility_request_present: bool,
eligibility_request_checksum: usize,
eligibility_request_value: usize,
evaluator_built: bool,
evaluator_entered: bool,
evaluator_returned: bool,
evaluator_step_count: usize,
step_source_loaded: bool,
step_boundary_checked: bool,
step_request_checked: bool,
step_policy_checked: bool,
step_csr_guard_checked: bool,
step_raw_guard_checked: bool,
step_denied_before_hardware: bool,
step_csr_write_skipped: bool,
step_raw_write_skipped: bool,
step_result_recorded: bool,
step_safe_return_recorded: bool,
    eligibility_policy_allows: bool,
eligibility_policy_denies: bool,
csr_write_eligible: bool,
csr_write_ineligible: bool,
csr_write_denied_before_hardware: bool,
csr_write_reached: bool,
csr_write_called: bool,
csr_write_returned: bool,
raw_write_reached: bool,
raw_write_called: bool,
raw_write_returned: bool,
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
source_fingerprint_before: HgatpCsrWriteEligibilityFingerprint,
source_fingerprint_after: HgatpCsrWriteEligibilityFingerprint,
source_fingerprint_unchanged: bool,
blocker: HgatpCsrWriteEligibilityBlocker,
blocker_count: usize,
next_action: HgatpCsrWriteEligibilityNextAction,
decision: HgatpCsrWriteEligibilityDecision,
checksum: usize,
build_count: usize,
validate_count: usize,
evaluate_count: usize,
reject_count: usize,
reset_count: usize,
state: HgatpCsrWriteEligibilityState,
};

var obj: HgatpCsrWriteEligibility = undefined;
var initialized = false;
fn yes() bool { return 1 == 1; }
fn tag(e:anytype)usize{return @intFromEnum(e);} fn bit(v:bool)usize{return if(v)1 else 0;} fn mix(a:usize,c:usize)usize{return (a^c)*%0x9e37_79b9_7f4a_7c15;}
fn emptyFp()HgatpCsrWriteEligibilityFingerprint{return .{.checksum=0,.boundary_checksum=0,.boundary_state=0,.boundary_decision=0,.boundary_result_code=0,.boundary_request_value=0,.boundary_request_checksum=0,.boundary_denied_before_csr=false,.boundary_blocked_before_raw_write=false,.boundary_csr_write_called=false,.boundary_raw_write_called=false,.boundary_trap_observed=false,.boundary_fault_observed=false,.boundary_readback_attempted=false,.boundary_readback_valid=false,.boundary_hgatp_write_attempted=false,.boundary_hgatp_write_performed=false,.boundary_active_stage2=false,.boundary_guest_entered=false,.boundary_first_guest_instruction_executed=false,.owner_vm_id=0,.owner_vcpu_id=0};}
fn fpSum(f:HgatpCsrWriteEligibilityFingerprint)usize{var x:usize=0x3901;
x=mix(x,f.boundary_checksum);
x=mix(x,f.boundary_state);
x=mix(x,f.boundary_decision);
x=mix(x,f.boundary_result_code);
x=mix(x,f.boundary_request_value);
x=mix(x,f.boundary_request_checksum);
x=mix(x,bit(f.boundary_denied_before_csr));
x=mix(x,bit(f.boundary_blocked_before_raw_write));
x=mix(x,bit(f.boundary_csr_write_called));
x=mix(x,bit(f.boundary_raw_write_called));
x=mix(x,bit(f.boundary_trap_observed));
x=mix(x,bit(f.boundary_fault_observed));
x=mix(x,bit(f.boundary_readback_attempted));
x=mix(x,bit(f.boundary_readback_valid));
x=mix(x,bit(f.boundary_hgatp_write_attempted));
x=mix(x,bit(f.boundary_hgatp_write_performed));
x=mix(x,bit(f.boundary_active_stage2));
x=mix(x,bit(f.boundary_guest_entered));
x=mix(x,bit(f.boundary_first_guest_instruction_executed));
x=mix(x,@intCast(f.owner_vm_id));
x=mix(x,@intCast(f.owner_vcpu_id));
return if(x==0)1 else x;}
fn readFp()HgatpCsrWriteEligibilityFingerprint{const s=boundary.object();
var f=HgatpCsrWriteEligibilityFingerprint{.checksum=0,.boundary_checksum=s.boundary_checksum,.boundary_state=tag(s.state),.boundary_decision=tag(s.decision),.boundary_result_code=tag(s.result),.boundary_request_value=s.request_value,.boundary_request_checksum=s.request_checksum,.boundary_denied_before_csr=s.denied_before_csr,.boundary_blocked_before_raw_write=!s.raw_write_function_called,.boundary_csr_write_called=s.csr_write_function_called,.boundary_raw_write_called=s.raw_write_function_called,.boundary_trap_observed=s.trap_observed,.boundary_fault_observed=s.fault_observed,.boundary_readback_attempted=s.readback_attempted,.boundary_readback_valid=false,.boundary_hgatp_write_attempted=s.hgatp_write_attempted,.boundary_hgatp_write_performed=s.hgatp_write_performed,.boundary_active_stage2=s.active_stage2,.boundary_guest_entered=s.guest_entered,.boundary_first_guest_instruction_executed=s.first_guest_instruction_executed,.owner_vm_id=vm.object().id,.owner_vcpu_id=vcpu.object().id};
f.checksum=fpSum(f);
return f;}
fn same(a:HgatpCsrWriteEligibilityFingerprint,b:HgatpCsrWriteEligibilityFingerprint)bool{return a.checksum==b.checksum and a.boundary_checksum==b.boundary_checksum and a.boundary_request_value==b.boundary_request_value and a.boundary_request_checksum==b.boundary_request_checksum and a.boundary_decision==b.boundary_decision and a.owner_vm_id==b.owner_vm_id and a.owner_vcpu_id==b.owner_vcpu_id;}
fn empty(owner:vm.VmId,
vc:vcpu.VcpuId,
resets:usize)HgatpCsrWriteEligibility{return .{.owner_vm_id=owner,.owner_vcpu_id=vc,.boundary_present=false,.boundary_valid=false,.boundary_checksum=0,.boundary_decision=0,.boundary_request_value=0,.boundary_request_checksum=0,.boundary_denied_before_csr=false,.boundary_blocked_before_raw_write=false,.boundary_csr_write_called=false,.boundary_raw_write_called=false,.boundary_trap_observed=false,.boundary_fault_observed=false,.boundary_readback_attempted=false,.boundary_readback_valid=false,.eligibility_request_present=false,.eligibility_request_checksum=0,.eligibility_request_value=0,.evaluator_built=false,.evaluator_entered=false,.evaluator_returned=false,.evaluator_step_count=0,.step_source_loaded=false,.step_boundary_checked=false,.step_request_checked=false,.step_policy_checked=false,.step_csr_guard_checked=false,.step_raw_guard_checked=false,.step_denied_before_hardware=false,.step_csr_write_skipped=false,.step_raw_write_skipped=false,.step_result_recorded=false,.step_safe_return_recorded=false,.eligibility_policy_allows=false,.eligibility_policy_denies=yes(),.csr_write_eligible=false,.csr_write_ineligible=yes(),.csr_write_denied_before_hardware=yes(),.csr_write_reached=false,.csr_write_called=false,.csr_write_returned=false,.raw_write_reached=false,.raw_write_called=false,.raw_write_returned=false,.trap_slot_present=yes(),.trap_capture_armed=false,.trap_observed=false,.trap_scause=0,.trap_stval=0,.trap_sepc=0,.readback_slot_present=yes(),.readback_allowed=false,.readback_attempted=false,.readback_value=0,.readback_valid=false,.hgatp_write_attempted=false,.hgatp_write_performed=false,.active_stage2=false,.guest_entered=false,.first_guest_instruction_executed=false,.source_fingerprint_before=emptyFp(),.source_fingerprint_after=emptyFp(),.source_fingerprint_unchanged=false,.blocker=.none,.blocker_count=0,.next_action=.none,.decision=.none,.checksum=0,.build_count=0,.validate_count=0,.evaluate_count=0,.reject_count=0,.reset_count=resets,.state=.empty};}
pub fn init(owner:vm.VmId,
vc:vcpu.VcpuId)void{obj=empty(owner,vc,0);initialized=yes();} fn mut()*HgatpCsrWriteEligibility{if(!initialized)init(vm.object().id,vcpu.object().id);return &obj;} pub fn object()*const HgatpCsrWriteEligibility{return mut();} pub fn reset()void{const r=mut().reset_count+1;
obj=empty(vm.object().id,vcpu.object().id,r);
initialized=yes();}
fn pull(r:*HgatpCsrWriteEligibility)void{const s=boundary.object();
r.boundary_present=s.state!=.empty and s.boundary_checksum!=0;
r.boundary_valid=s.state==.ready and s.result==.execution_ready_without_write and s.decision==.ready_no_write and s.denied_before_csr and !s.csr_write_function_called and !s.raw_write_function_called;
r.boundary_checksum=s.boundary_checksum;
r.boundary_decision=tag(s.decision);
r.boundary_request_value=s.request_value;
r.boundary_request_checksum=s.request_checksum;
r.boundary_denied_before_csr=s.denied_before_csr;
r.boundary_blocked_before_raw_write=!s.raw_write_function_called;
r.boundary_csr_write_called=s.csr_write_function_called;
r.boundary_raw_write_called=s.raw_write_function_called;
r.boundary_trap_observed=s.trap_observed;
r.boundary_fault_observed=s.fault_observed;
r.boundary_readback_attempted=s.readback_attempted;
r.boundary_readback_valid=false;
r.eligibility_request_present=r.boundary_present;
r.eligibility_request_value=s.request_value;
r.eligibility_request_checksum=s.request_checksum ^ s.boundary_checksum ^ 0x39;
r.hgatp_write_attempted=s.hgatp_write_attempted;
r.hgatp_write_performed=s.hgatp_write_performed;
r.active_stage2=s.active_stage2;
r.guest_entered=s.guest_entered;
r.first_guest_instruction_executed=s.first_guest_instruction_executed;}
fn decide(r:HgatpCsrWriteEligibility)HgatpCsrWriteEligibilityBlocker{if(!r.boundary_present)return .boundary_missing;
if(!r.boundary_valid)return .boundary_invalid;
if(!r.source_fingerprint_unchanged)return .source_mutated;
if(r.eligibility_request_value!=r.boundary_request_value)return .request_value_mismatch;
if(r.eligibility_policy_allows)return .policy_allows_hardware_write;
if(r.csr_write_eligible)return .csr_write_eligible;
if(r.csr_write_reached)return .csr_write_reached;
if(r.csr_write_called)return .csr_write_called;
if(r.raw_write_reached)return .raw_write_reached;
if(r.raw_write_called)return .raw_write_called;
if(r.trap_observed)return .fake_trap_observed;
if(r.boundary_fault_observed)return .fake_fault_observed;
if(r.readback_attempted or r.readback_valid)return .fake_readback_observed;
if(r.hgatp_write_attempted)return .hgatp_write_attempted;
if(r.hgatp_write_performed)return .hgatp_write_performed;
if(r.active_stage2)return .active_stage2_forbidden;
if(r.guest_entered)return .guest_entered_forbidden;
if(r.first_guest_instruction_executed)return .first_instruction_forbidden;
return .none;}
fn decisionFor(k:HgatpCsrWriteEligibilityBlocker)HgatpCsrWriteEligibilityDecision{return switch(k){.none=>.csr_write_ineligible_denied_before_hardware,.boundary_missing=>.boundary_missing,.boundary_invalid=>.boundary_invalid,.source_mutated=>.source_mutated,.request_value_mismatch=>.request_value_mismatch,.policy_allows_hardware_write=>.policy_claimed_allowed,.csr_write_eligible=>.csr_write_claimed_eligible,.csr_write_reached=>.csr_write_claimed_reached,.csr_write_called=>.csr_write_claimed_called,.raw_write_reached=>.raw_write_claimed_reached,.raw_write_called=>.raw_write_claimed_called,.fake_trap_observed=>.fake_trap_observed,.fake_fault_observed=>.fake_fault_observed,.fake_readback_observed=>.fake_readback_observed,.hgatp_write_attempted=>.write_attempt_claimed,.hgatp_write_performed=>.write_performed_claimed,.active_stage2_forbidden=>.active_stage2_claimed,.guest_entered_forbidden=>.guest_entry_claimed,.first_instruction_forbidden=>.first_instruction_claimed};}
fn nextFor(k:HgatpCsrWriteEligibilityBlocker)HgatpCsrWriteEligibilityNextAction{return switch(k){.none=>.keep_denied_before_hardware,.boundary_missing,.boundary_invalid=>.provide_valid_hv38_boundary,.source_mutated=>.investigate_source_mutation,else=>.clear_local_corruption};}
fn sum(r:HgatpCsrWriteEligibility)usize{var x:usize=0x39;
x=mix(x,r.source_fingerprint_before.checksum);
x=mix(x,r.source_fingerprint_after.checksum);
x=mix(x,r.boundary_checksum);
x=mix(x,r.boundary_decision);
x=mix(x,r.boundary_request_value);
x=mix(x,r.boundary_request_checksum);
x=mix(x,r.eligibility_request_checksum);
x=mix(x,r.evaluate_count);
x=mix(x,r.evaluator_step_count);
x=mix(x,tag(r.decision));
x=mix(x,tag(r.blocker));
return if(x==0)1 else x;}
fn record(r:*HgatpCsrWriteEligibility)void{const k=decide(r.*);
r.blocker=k;
r.blocker_count=if(k==.none)0 else 1;
r.next_action=nextFor(k);
r.decision=decisionFor(k);
if(k!=.none)r.reject_count+=1;
r.state=if(k==.none and r.evaluator_entered).evaluated else if(k==.none).built else .rejected;
r.checksum=sum(r.*);}
pub fn build()HgatpCsrWriteEligibilityBlocker{const r=mut();
r.build_count+=1;
r.source_fingerprint_before=readFp();
pull(r);
r.evaluator_built=yes();
r.evaluator_entered=false;
r.evaluator_returned=false;
r.source_fingerprint_after=readFp();
r.source_fingerprint_unchanged=same(r.source_fingerprint_before,r.source_fingerprint_after);
record(r);
return r.blocker;}
pub fn validate()HgatpCsrWriteEligibilityBlocker{const r=mut();
r.validate_count+=1;
record(r);
return r.blocker;}
pub fn evaluate()HgatpCsrWriteEligibilityBlocker{const r=mut();
r.evaluate_count+=1;
r.source_fingerprint_before=readFp();
pull(r);
r.evaluator_entered=yes();
r.step_source_loaded=yes();
r.step_boundary_checked=yes();
r.step_request_checked=yes();
r.step_policy_checked=yes();
r.eligibility_policy_allows=false;
r.eligibility_policy_denies=yes();
r.step_csr_guard_checked=yes();
r.csr_write_eligible=false;
r.csr_write_ineligible=yes();
r.csr_write_denied_before_hardware=yes();
r.csr_write_reached=false;
r.csr_write_called=false;
r.csr_write_returned=false;
r.step_raw_guard_checked=yes();
r.raw_write_reached=false;
r.raw_write_called=false;
r.raw_write_returned=false;
r.step_denied_before_hardware=yes();
r.step_csr_write_skipped=yes();
r.step_raw_write_skipped=yes();
r.trap_slot_present=yes();
r.trap_capture_armed=false;
r.trap_observed=false;
r.trap_scause=0;
r.trap_stval=0;
r.trap_sepc=0;
r.readback_slot_present=yes();
r.readback_allowed=false;
r.readback_attempted=false;
r.readback_value=0;
r.readback_valid=false;
r.hgatp_write_attempted=false;
r.hgatp_write_performed=false;
r.active_stage2=false;
r.guest_entered=false;
r.first_guest_instruction_executed=false;
r.step_result_recorded=yes();
r.source_fingerprint_after=readFp();
r.source_fingerprint_unchanged=same(r.source_fingerprint_before,r.source_fingerprint_after);
r.step_safe_return_recorded=yes();
r.evaluator_returned=yes();
r.evaluator_step_count=11;
record(r);
return r.blocker;}
fn corrupt(k:HgatpCsrWriteEligibilityBlocker)HgatpCsrWriteEligibilityBlocker{_=build();
const r=mut();
r.boundary_present=yes();
r.boundary_valid=yes();
r.source_fingerprint_unchanged=yes();
switch(k){.boundary_missing=>r.boundary_present=false,.boundary_invalid=>r.boundary_valid=false,.source_mutated=>r.source_fingerprint_unchanged=false,.request_value_mismatch=>r.eligibility_request_value +%= 1,.policy_allows_hardware_write=>r.eligibility_policy_allows=yes(),.csr_write_eligible=>r.csr_write_eligible=yes(),.csr_write_reached=>r.csr_write_reached=yes(),.csr_write_called=>r.csr_write_called=yes(),.raw_write_reached=>r.raw_write_reached=yes(),.raw_write_called=>r.raw_write_called=yes(),.fake_trap_observed=>r.trap_observed=yes(),.fake_fault_observed=>r.boundary_fault_observed=yes(),.fake_readback_observed=>r.readback_valid=yes(),.hgatp_write_attempted=>r.hgatp_write_attempted=yes(),.hgatp_write_performed=>r.hgatp_write_performed=yes(),.active_stage2_forbidden=>r.active_stage2=yes(),.guest_entered_forbidden=>r.guest_entered=yes(),.first_instruction_forbidden=>r.first_guest_instruction_executed=yes(),.none=>{}} record(r);
return r.blocker;}
fn pb(v:bool)void{uart.write(if(v)"true" else "false");} fn lineB(n:[]const u8,v:bool)void{uart.write("hv: hgatp_csr_write_eligibility.");uart.write(n);uart.write("=");pb(v);uart.write("\r\n");} fn lineU(n:[]const u8,v:usize)void{uart.write("hv: hgatp_csr_write_eligibility.");uart.write(n);uart.write("=");uart.writeDec(v);uart.write("\r\n");} fn lineH(n:[]const u8,v:usize)void{uart.write("hv: hgatp_csr_write_eligibility.");uart.write(n);uart.write("=");uart.writeHex(v);uart.write("\r\n");}
fn pr(n:[]const u8,k:HgatpCsrWriteEligibilityBlocker)void{uart.write("hv: hgatp_csr_write_eligibility.");uart.write(n);uart.write("=");uart.write(@tagName(decisionFor(k)));uart.write(" blocker=");uart.write(@tagName(k));uart.write("\r\n");}
pub fn printSummaryCommand()void{const r=object();
uart.write("hv: hgatp_csr_write_eligibility.state=");uart.write(@tagName(r.state));uart.write(" decision=");uart.write(@tagName(r.decision));uart.write(" blocker=");uart.write(@tagName(r.blocker));uart.write(" next=");uart.write(@tagName(r.next_action));uart.write(" checksum=");uart.writeHex(r.checksum);uart.write("\r\n");}
pub fn printFieldsCommand()void{const r=object();
lineU("owner_vm_id",@intCast(r.owner_vm_id));lineU("owner_vcpu_id",@intCast(r.owner_vcpu_id));lineB("boundary_present",r.boundary_present);lineB("boundary_valid",r.boundary_valid);lineH("boundary_checksum",r.boundary_checksum);lineU("boundary_decision",r.boundary_decision);lineH("boundary_request_value",r.boundary_request_value);lineH("boundary_request_checksum",r.boundary_request_checksum);lineB("boundary_denied_before_csr",r.boundary_denied_before_csr);lineB("boundary_blocked_before_raw_write",r.boundary_blocked_before_raw_write);lineB("boundary_csr_write_called",r.boundary_csr_write_called);lineB("boundary_raw_write_called",r.boundary_raw_write_called);lineB("boundary_trap_observed",r.boundary_trap_observed);lineB("boundary_fault_observed",r.boundary_fault_observed);lineB("boundary_readback_attempted",r.boundary_readback_attempted);lineB("boundary_readback_valid",r.boundary_readback_valid);lineB("eligibility_request_present",r.eligibility_request_present);lineH("eligibility_request_checksum",r.eligibility_request_checksum);lineH("eligibility_request_value",r.eligibility_request_value);lineB("evaluator_built",r.evaluator_built);lineB("evaluator_entered",r.evaluator_entered);lineB("evaluator_returned",r.evaluator_returned);lineU("evaluator_step_count",r.evaluator_step_count);lineB("eligibility_policy_allows",r.eligibility_policy_allows);lineB("eligibility_policy_denies",r.eligibility_policy_denies);lineB("csr_write_eligible",r.csr_write_eligible);lineB("csr_write_ineligible",r.csr_write_ineligible);lineB("csr_write_denied_before_hardware",r.csr_write_denied_before_hardware);lineB("csr_write_reached",r.csr_write_reached);lineB("csr_write_called",r.csr_write_called);lineB("csr_write_returned",r.csr_write_returned);lineB("raw_write_reached",r.raw_write_reached);lineB("raw_write_called",r.raw_write_called);lineB("raw_write_returned",r.raw_write_returned);lineB("hgatp_write_attempted",r.hgatp_write_attempted);lineB("hgatp_write_performed",r.hgatp_write_performed);lineB("active_stage2",r.active_stage2);lineB("guest_entered",r.guest_entered);lineB("first_guest_instruction_executed",r.first_guest_instruction_executed);lineB("source_fingerprint_unchanged",r.source_fingerprint_unchanged);lineU("blocker_count",r.blocker_count);lineH("checksum",r.checksum);lineU("build_count",r.build_count);lineU("validate_count",r.validate_count);lineU("evaluate_count",r.evaluate_count);lineU("reject_count",r.reject_count);lineU("reset_count",r.reset_count);}
pub fn printStepsCommand()void{const r=object();
lineB("step_source_loaded",r.step_source_loaded);lineB("step_boundary_checked",r.step_boundary_checked);lineB("step_request_checked",r.step_request_checked);lineB("step_policy_checked",r.step_policy_checked);lineB("step_csr_guard_checked",r.step_csr_guard_checked);lineB("step_raw_guard_checked",r.step_raw_guard_checked);lineB("step_denied_before_hardware",r.step_denied_before_hardware);lineB("step_csr_write_skipped",r.step_csr_write_skipped);lineB("step_raw_write_skipped",r.step_raw_write_skipped);lineB("step_result_recorded",r.step_result_recorded);lineB("step_safe_return_recorded",r.step_safe_return_recorded);lineU("evaluator_step_count",r.evaluator_step_count);}
pub fn printRequestCommand()void{const r=object();
lineB("eligibility_request_present",r.eligibility_request_present);lineH("eligibility_request_value",r.eligibility_request_value);lineH("eligibility_request_checksum",r.eligibility_request_checksum);lineH("boundary_request_value",r.boundary_request_value);lineH("boundary_request_checksum",r.boundary_request_checksum);}
pub fn printTrapSlotCommand()void{const r=object();
lineB("trap_slot_present",r.trap_slot_present);lineB("trap_capture_armed",r.trap_capture_armed);lineB("trap_observed",r.trap_observed);lineU("trap_scause",r.trap_scause);lineU("trap_stval",r.trap_stval);lineU("trap_sepc",r.trap_sepc);}
pub fn printReadbackCommand()void{const r=object();
lineB("readback_slot_present",r.readback_slot_present);lineB("readback_allowed",r.readback_allowed);lineB("readback_attempted",r.readback_attempted);lineH("readback_value",r.readback_value);lineB("readback_valid",r.readback_valid);}
pub fn printResultCommand()void{const r=object();
uart.write("hv: hgatp_csr_write_eligibility.result=");uart.write(@tagName(r.decision));uart.write("\r\n");lineB("result_denied_before_hardware",r.csr_write_denied_before_hardware);lineB("result_csr_skipped",!r.csr_write_called and !r.csr_write_reached);lineB("result_raw_skipped",!r.raw_write_called and !r.raw_write_reached);} pub fn printDecisionCommand()void{const r=object();
uart.write("hv: hgatp_csr_write_eligibility.decision=");uart.write(@tagName(r.decision));uart.write("\r\n");uart.write("hv: hgatp_csr_write_eligibility.blocker=");uart.write(@tagName(r.blocker));uart.write("\r\n");} pub fn printBlockersCommand()void{const r=object();
uart.write("hv: hgatp_csr_write_eligibility.blocker=");uart.write(@tagName(r.blocker));uart.write("\r\n");lineU("blocker_count",r.blocker_count);} pub fn printNextCommand()void{const r=object();
uart.write("hv: hgatp_csr_write_eligibility.next_action=");uart.write(@tagName(r.next_action));uart.write("\r\n");} pub fn printChecksumCommand()void{lineH("checksum",object().checksum);} 
pub fn printStatusCommand()void{printSummaryCommand();printFieldsCommand();} pub fn printBuildCommand()void{pr("build_result",build());printStatusCommand();} pub fn printValidateCommand()void{pr("validate_result",validate());printStatusCommand();} pub fn printEvaluateCommand()void{pr("evaluate_result",evaluate());printStatusCommand();printStepsCommand();} pub fn printResetCommand()void{reset();uart.write("hv: hgatp_csr_write_eligibility.reset_result=ok\r\n");printStatusCommand();}
pub fn printRequireBoundaryTestCommand()void{pr("require_boundary_test",corrupt(.boundary_missing));printStatusCommand();} pub fn printInvalidBoundaryTestCommand()void{pr("invalid_boundary_test",corrupt(.boundary_invalid));printStatusCommand();} pub fn printSourceIntegrityTestCommand()void{pr("source_integrity_test",corrupt(.source_mutated));printStatusCommand();} pub fn printRequestValueTestCommand()void{pr("request_value_test",corrupt(.request_value_mismatch));printStatusCommand();} pub fn printPolicyAllowsTestCommand()void{pr("policy_allows_test",corrupt(.policy_allows_hardware_write));printStatusCommand();} pub fn printCsrEligibleTestCommand()void{pr("csr_eligible_test",corrupt(.csr_write_eligible));printStatusCommand();} pub fn printCsrReachedTestCommand()void{pr("csr_reached_test",corrupt(.csr_write_reached));printStatusCommand();} pub fn printCsrCalledTestCommand()void{pr("csr_called_test",corrupt(.csr_write_called));printStatusCommand();} pub fn printRawReachedTestCommand()void{pr("raw_reached_test",corrupt(.raw_write_reached));printStatusCommand();} pub fn printRawCalledTestCommand()void{pr("raw_called_test",corrupt(.raw_write_called));printStatusCommand();} pub fn printFakeTrapTestCommand()void{pr("fake_trap_test",corrupt(.fake_trap_observed));printStatusCommand();} pub fn printFakeFaultTestCommand()void{pr("fake_fault_test",corrupt(.fake_fault_observed));printStatusCommand();} pub fn printFakeReadbackTestCommand()void{pr("fake_readback_test",corrupt(.fake_readback_observed));printStatusCommand();} pub fn printWriteAttemptedTestCommand()void{pr("write_attempted_test",corrupt(.hgatp_write_attempted));printStatusCommand();} pub fn printWritePerformedTestCommand()void{pr("write_performed_test",corrupt(.hgatp_write_performed));printStatusCommand();} pub fn printActiveStage2TestCommand()void{pr("active_stage2_test",corrupt(.active_stage2_forbidden));printStatusCommand();} pub fn printGuestEnteredTestCommand()void{pr("guest_entered_test",corrupt(.guest_entered_forbidden));printStatusCommand();} pub fn printFirstInstructionTestCommand()void{pr("first_instruction_test",corrupt(.first_instruction_forbidden));printStatusCommand();} pub fn printInvariantConsumptionCommand()void{_=build();
const a=object().checksum;
const b=object().boundary_checksum;
_=evaluate();
const c=object().checksum;
uart.write("hv: hgatp_csr_write_eligibility.invariant_consumption_test=");
uart.write(if(a!=0 and c!=a and b==object().boundary_checksum)"ok" else "rejected");
uart.write("\r\n");
printStatusCommand();} pub fn printInvariantCorruptionCommand()void{pr("invariant_corruption_test",corrupt(.source_mutated));printStatusCommand();}
