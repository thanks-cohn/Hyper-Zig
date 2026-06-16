const uart = @import("../console/uart.zig");
const vm = @import("vm.zig");
const vcpu = @import("vcpu.zig");
const prep = @import("hgatp_hardware_write_prep.zig");

pub const HgatpHardwareWriteOperationState = enum { empty, observed, denied, rejected };
pub const HgatpHardwareWriteOperationBlocker = enum { none, missing_prep, invalid_prep, source_mutated, request_value_mismatch, explicit_opt_in_forbidden, policy_allows_hardware_write, operation_call_reachable, operation_call_called, raw_write_called, fake_trap_observed, fake_readback_observed, hgatp_write_attempted, hgatp_write_performed, active_stage2_forbidden, guest_entered_forbidden, first_instruction_forbidden };
pub const HgatpHardwareWriteOperationNextAction = enum { none, build_prep_externally, validate_prep_externally, investigate_source_mutation, inspect_request_value, keep_explicit_opt_in_disabled, keep_operation_denied_before_csr, keep_operation_blocked_before_raw_write, stop_operation_call_reachable, stop_operation_call_observed, stop_raw_write_observed, clear_trap_slot, clear_readback_slot, stop_write_attempt_claim, stop_write_performed_claim, stop_active_stage2_claim, stop_guest_entry_claim, stop_first_instruction_claim };
pub const HgatpHardwareWriteOperationDecision = enum { none, operation_denied_before_csr, blocked_before_raw_write, rejected };
pub const HgatpHardwareWriteOperationResultCode = enum { none, operation_denied_before_csr, blocked_before_raw_write, explicit_opt_in_missing, prep_missing, prep_invalid, source_mutated, request_value_mismatch, policy_claimed_allowed, call_claimed_reachable, call_claimed_called, raw_write_claimed_called, fake_trap_observed, fake_readback_observed, write_attempt_claimed, write_performed_claimed, active_stage2_claimed, guest_entry_claimed, first_instruction_claimed };

pub const HgatpHardwareWriteOperationFingerprint = struct { prep_checksum: usize, prep_ready: bool, prep_state: usize, prep_decision: usize, prep_result_code: usize, prep_hardware_write_value: usize, prep_hardware_write_checksum: usize, prep_policy_allows: bool, prep_policy_denies: bool, prep_blocked_before_call: bool, prep_call_reachable: bool, prep_call_called: bool, prep_raw_write_called: bool, prep_trap_observed: bool, prep_readback_attempted: bool, prep_readback_valid: bool, prep_hgatp_write_attempted: bool, prep_hgatp_write_performed: bool, prep_active_stage2: bool, prep_guest_entered: bool, prep_first_guest_instruction_executed: bool, vm_id: vm.VmId, vcpu_id: vcpu.VcpuId, checksum: usize };
pub const HgatpHardwareWriteOperationRequest = struct { present: bool, value: usize, checksum: usize, explicit_opt_in: bool, opt_in_required: bool, opt_in_default_false: bool };
pub const HgatpHardwareWriteOperationPreflight = struct { present: bool, passed: bool, failed: bool, blocker: HgatpHardwareWriteOperationBlocker, checksum: usize };
pub const HgatpHardwareWriteOperationResult = struct { present: bool, code: HgatpHardwareWriteOperationResultCode, checksum: usize };
pub const HgatpHardwareWriteOperationTrapSlot = struct { present: bool, armed: bool, observed: bool, scause: usize, stval: usize, sepc: usize, checksum: usize };
pub const HgatpHardwareWriteOperationReadbackSlot = struct { present: bool, allowed: bool, attempted: bool, value: usize, valid: bool, checksum: usize };

pub const HgatpHardwareWriteOperation = struct {
    owner_vm_id: vm.VmId, owner_vcpu_id: vcpu.VcpuId, prep_present: bool, prep_valid: bool, prep_checksum: usize, prep_decision: usize, prep_hardware_write_value: usize, prep_hardware_write_checksum: usize, prep_policy_allows: bool, prep_policy_denies: bool, prep_blocked_before_call: bool, prep_call_reachable: bool, prep_call_called: bool, prep_raw_write_called: bool, prep_trap_observed: bool, prep_readback_attempted: bool, prep_readback_valid: bool,
    operation_request_present: bool, operation_request_checksum: usize, operation_request_value: usize, operation_explicit_opt_in: bool, operation_opt_in_required: bool, operation_opt_in_default_false: bool, operation_policy_allows: bool, operation_policy_denies: bool, operation_denied_before_csr: bool, operation_blocked_before_raw_write: bool, operation_call_reachable: bool, operation_call_called: bool, operation_call_returned: bool, raw_write_function_known: bool, raw_write_function_allowed: bool, raw_write_function_called: bool,
    preflight_present: bool, preflight_passed: bool, preflight_failed: bool, preflight_blocker: HgatpHardwareWriteOperationBlocker, result_present: bool, result_code: HgatpHardwareWriteOperationResultCode, result_checksum: usize, trap_slot_present: bool, trap_capture_armed: bool, trap_observed: bool, trap_scause: usize, trap_stval: usize, trap_sepc: usize, readback_slot_present: bool, readback_allowed: bool, readback_attempted: bool, readback_value: usize, readback_valid: bool, hgatp_write_attempted: bool, hgatp_write_performed: bool, active_stage2: bool, guest_entered: bool, first_guest_instruction_executed: bool,
    source_fingerprint_before: HgatpHardwareWriteOperationFingerprint, source_fingerprint_after: HgatpHardwareWriteOperationFingerprint, source_fingerprint_unchanged: bool, blocker: HgatpHardwareWriteOperationBlocker, blocker_count: usize, next_action: HgatpHardwareWriteOperationNextAction, decision: HgatpHardwareWriteOperationDecision, checksum: usize, build_count: usize, validate_count: usize, reject_count: usize, reset_count: usize, state: HgatpHardwareWriteOperationState,
};


var obj: HgatpHardwareWriteOperation = undefined;
var initialized=false;
fn tag(e:anytype) usize { return @intFromEnum(e);
}
fn bint(v:bool) usize { return if(v) 1 else 0;
}
fn mix(a:usize,b:usize) usize { return (a ^ b) *% 0x9e37_79b9_7f4a_7c15;
}
fn emptyFp() HgatpHardwareWriteOperationFingerprint { return .{ .prep_checksum=0,.prep_ready=false,.prep_state=0,.prep_decision=0,.prep_result_code=0,.prep_hardware_write_value=0,.prep_hardware_write_checksum=0,.prep_policy_allows=false,.prep_policy_denies=false,.prep_blocked_before_call=false,.prep_call_reachable=false,.prep_call_called=false,.prep_raw_write_called=false,.prep_trap_observed=false,.prep_readback_attempted=false,.prep_readback_valid=false,.prep_hgatp_write_attempted=false,.prep_hgatp_write_performed=false,.prep_active_stage2=false,.prep_guest_entered=false,.prep_first_guest_instruction_executed=false,.vm_id=0,.vcpu_id=0,.checksum=0 };
}
fn empty(owner:vm.VmId, owner_vcpu:vcpu.VcpuId, resets:usize) HgatpHardwareWriteOperation { return .{ .owner_vm_id=owner,.owner_vcpu_id=owner_vcpu,.prep_present=false,.prep_valid=false,.prep_checksum=0,.prep_decision=0,.prep_hardware_write_value=0,.prep_hardware_write_checksum=0,.prep_policy_allows=false,.prep_policy_denies=false,.prep_blocked_before_call=false,.prep_call_reachable=false,.prep_call_called=false,.prep_raw_write_called=false,.prep_trap_observed=false,.prep_readback_attempted=false,.prep_readback_valid=false,.operation_request_present=false,.operation_request_checksum=0,.operation_request_value=0,.operation_explicit_opt_in=false,.operation_opt_in_required=true,.operation_opt_in_default_false=true,.operation_policy_allows=false,.operation_policy_denies=true,.operation_denied_before_csr=true,.operation_blocked_before_raw_write=true,.operation_call_reachable=false,.operation_call_called=false,.operation_call_returned=false,.raw_write_function_known=true,.raw_write_function_allowed=false,.raw_write_function_called=false,.preflight_present=false,.preflight_passed=false,.preflight_failed=true,.preflight_blocker=.none,.result_present=false,.result_code=.none,.result_checksum=0,.trap_slot_present=true,.trap_capture_armed=false,.trap_observed=false,.trap_scause=0,.trap_stval=0,.trap_sepc=0,.readback_slot_present=true,.readback_allowed=false,.readback_attempted=false,.readback_value=0,.readback_valid=false,.hgatp_write_attempted=false,.hgatp_write_performed=false,.active_stage2=false,.guest_entered=false,.first_guest_instruction_executed=false,.source_fingerprint_before=emptyFp(),.source_fingerprint_after=emptyFp(),.source_fingerprint_unchanged=false,.blocker=.none,.blocker_count=0,.next_action=.none,.decision=.none,.checksum=0,.build_count=0,.validate_count=0,.reject_count=0,.reset_count=resets,.state=.empty };
}
pub fn init(owner:vm.VmId, owner_vcpu:vcpu.VcpuId) void { obj=empty(owner,owner_vcpu,0);
initialized=true;
}
fn mutable()*HgatpHardwareWriteOperation{ if(!initialized) init(vm.object().id,vcpu.object().id);
return &obj;
}
pub fn object()*const HgatpHardwareWriteOperation{ return mutable();
}
pub fn reset() void { const r=mutable().reset_count+1;
obj=empty(vm.object().id,vcpu.object().id,r);
initialized=true;
}
fn fpChecksum(f:HgatpHardwareWriteOperationFingerprint) usize { var x:usize=0x3434;
x=mix(x,f.prep_checksum);
x=mix(x,bint(f.prep_ready));
x=mix(x,f.prep_state);
x=mix(x,f.prep_decision);
x=mix(x,f.prep_result_code);
x=mix(x,f.prep_hardware_write_value);
x=mix(x,f.prep_hardware_write_checksum);
x=mix(x,bint(f.prep_policy_allows));
x=mix(x,bint(f.prep_policy_denies));
x=mix(x,bint(f.prep_blocked_before_call));
x=mix(x,bint(f.prep_call_reachable));
x=mix(x,bint(f.prep_call_called));
x=mix(x,bint(f.prep_raw_write_called));
x=mix(x,bint(f.prep_trap_observed));
x=mix(x,bint(f.prep_readback_attempted));
x=mix(x,bint(f.prep_readback_valid));
x=mix(x,bint(f.prep_hgatp_write_attempted));
x=mix(x,bint(f.prep_hgatp_write_performed));
x=mix(x,bint(f.prep_active_stage2));
x=mix(x,bint(f.prep_guest_entered));
x=mix(x,bint(f.prep_first_guest_instruction_executed));
x=mix(x,@intCast(f.vm_id));
x=mix(x,@intCast(f.vcpu_id));
return if(x==0) 1 else x;
}
pub fn readSourceFingerprint() HgatpHardwareWriteOperationFingerprint { const s=prep.object();
var f=HgatpHardwareWriteOperationFingerprint{ .prep_checksum=s.checksum,.prep_ready=s.ready,.prep_state=tag(s.state),.prep_decision=tag(s.decision),.prep_result_code=tag(s.result_code),.prep_hardware_write_value=s.hardware_write_value,.prep_hardware_write_checksum=s.hardware_write_checksum,.prep_policy_allows=s.hardware_write_policy_allows,.prep_policy_denies=s.hardware_write_policy_denies,.prep_blocked_before_call=s.hardware_write_blocked_before_call,.prep_call_reachable=s.hardware_write_call_reachable,.prep_call_called=s.hardware_write_call_called,.prep_raw_write_called=s.raw_write_function_called,.prep_trap_observed=s.trap_capture_observed,.prep_readback_attempted=s.readback_attempted,.prep_readback_valid=s.readback_valid,.prep_hgatp_write_attempted=s.hgatp_write_attempted,.prep_hgatp_write_performed=s.hgatp_write_performed,.prep_active_stage2=s.active_stage2,.prep_guest_entered=s.guest_entered,.prep_first_guest_instruction_executed=s.first_guest_instruction_executed,.vm_id=vm.object().id,.vcpu_id=vcpu.object().id,.checksum=0 };
f.checksum=fpChecksum(f);
return f;
}
fn sameFp(a:HgatpHardwareWriteOperationFingerprint,b:HgatpHardwareWriteOperationFingerprint) bool { return a.checksum==b.checksum and a.prep_checksum==b.prep_checksum and a.prep_ready==b.prep_ready and a.prep_state==b.prep_state and a.prep_decision==b.prep_decision and a.prep_result_code==b.prep_result_code and a.prep_hardware_write_value==b.prep_hardware_write_value and a.prep_hardware_write_checksum==b.prep_hardware_write_checksum and a.prep_policy_allows==b.prep_policy_allows and a.prep_policy_denies==b.prep_policy_denies and a.prep_blocked_before_call==b.prep_blocked_before_call and a.prep_call_reachable==b.prep_call_reachable and a.prep_call_called==b.prep_call_called and a.prep_raw_write_called==b.prep_raw_write_called and a.prep_trap_observed==b.prep_trap_observed and a.prep_readback_attempted==b.prep_readback_attempted and a.prep_readback_valid==b.prep_readback_valid and a.prep_hgatp_write_attempted==b.prep_hgatp_write_attempted and a.prep_hgatp_write_performed==b.prep_hgatp_write_performed and a.prep_active_stage2==b.prep_active_stage2 and a.prep_guest_entered==b.prep_guest_entered and a.prep_first_guest_instruction_executed==b.prep_first_guest_instruction_executed and a.vm_id==b.vm_id and a.vcpu_id==b.vcpu_id;
}
fn checksumOp(r:HgatpHardwareWriteOperation) usize { var x:usize=0x3400;
x=mix(x,r.source_fingerprint_before.checksum);
x=mix(x,r.source_fingerprint_after.checksum);
x=mix(x,r.prep_checksum);
x=mix(x,r.prep_hardware_write_value);
x=mix(x,r.prep_hardware_write_checksum);
x=mix(x,r.operation_request_value);
x=mix(x,r.operation_request_checksum);
x=mix(x,tag(r.blocker));
x=mix(x,tag(r.result_code));
return if(x==0) 1 else x;
}
fn firstBlocker(r:HgatpHardwareWriteOperation) HgatpHardwareWriteOperationBlocker { if(!r.prep_present) return .missing_prep;
if(!r.prep_valid) return .invalid_prep;
if(!r.source_fingerprint_unchanged) return .source_mutated;
if(r.operation_request_value != r.prep_hardware_write_value or r.operation_request_checksum != r.prep_hardware_write_checksum) return .request_value_mismatch;
if(r.operation_explicit_opt_in) return .explicit_opt_in_forbidden;
if(r.operation_policy_allows or !r.operation_policy_denies or !r.operation_denied_before_csr or !r.operation_blocked_before_raw_write) return .policy_allows_hardware_write;
if(r.operation_call_reachable) return .operation_call_reachable;
if(r.operation_call_called) return .operation_call_called;
if(r.raw_write_function_allowed or r.raw_write_function_called or r.operation_call_returned) return .raw_write_called;
if(r.trap_capture_armed or r.trap_observed or r.trap_scause!=0 or r.trap_stval!=0 or r.trap_sepc!=0) return .fake_trap_observed;
if(r.readback_allowed or r.readback_attempted or r.readback_valid or r.readback_value!=0) return .fake_readback_observed;
if(r.hgatp_write_attempted) return .hgatp_write_attempted;
if(r.hgatp_write_performed) return .hgatp_write_performed;
if(r.active_stage2) return .active_stage2_forbidden;
if(r.guest_entered) return .guest_entered_forbidden;
if(r.first_guest_instruction_executed) return .first_instruction_forbidden;
return .none;
}
fn actionFor(b:HgatpHardwareWriteOperationBlocker) HgatpHardwareWriteOperationNextAction { return switch(b){ .none=>.keep_operation_denied_before_csr,.missing_prep=>.build_prep_externally,.invalid_prep=>.validate_prep_externally,.source_mutated=>.investigate_source_mutation,.request_value_mismatch=>.inspect_request_value,.explicit_opt_in_forbidden=>.keep_explicit_opt_in_disabled,.policy_allows_hardware_write=>.keep_operation_denied_before_csr,.operation_call_reachable=>.stop_operation_call_reachable,.operation_call_called=>.stop_operation_call_observed,.raw_write_called=>.stop_raw_write_observed,.fake_trap_observed=>.clear_trap_slot,.fake_readback_observed=>.clear_readback_slot,.hgatp_write_attempted=>.stop_write_attempt_claim,.hgatp_write_performed=>.stop_write_performed_claim,.active_stage2_forbidden=>.stop_active_stage2_claim,.guest_entered_forbidden=>.stop_guest_entry_claim,.first_instruction_forbidden=>.stop_first_instruction_claim };
}
fn resultFor(b:HgatpHardwareWriteOperationBlocker) HgatpHardwareWriteOperationResultCode { return switch(b){ .none=>.operation_denied_before_csr,.missing_prep=>.prep_missing,.invalid_prep=>.prep_invalid,.source_mutated=>.source_mutated,.request_value_mismatch=>.request_value_mismatch,.explicit_opt_in_forbidden=>.explicit_opt_in_missing,.policy_allows_hardware_write=>.policy_claimed_allowed,.operation_call_reachable=>.call_claimed_reachable,.operation_call_called=>.call_claimed_called,.raw_write_called=>.raw_write_claimed_called,.fake_trap_observed=>.fake_trap_observed,.fake_readback_observed=>.fake_readback_observed,.hgatp_write_attempted=>.write_attempt_claimed,.hgatp_write_performed=>.write_performed_claimed,.active_stage2_forbidden=>.active_stage2_claimed,.guest_entered_forbidden=>.guest_entry_claimed,.first_instruction_forbidden=>.first_instruction_claimed };
}
fn finish(r:*HgatpHardwareWriteOperation) HgatpHardwareWriteOperationBlocker { const b=firstBlocker(r.*);
r.blocker=b;
r.blocker_count=if(b==.none) 0 else 1;
r.next_action=actionFor(b);
r.preflight_present=true;
r.preflight_passed=false;
r.preflight_failed=true;
r.preflight_blocker=b;
r.result_present=true;
r.result_code=resultFor(b);
r.decision=if(b==.none) .operation_denied_before_csr else if(b==.raw_write_called) .blocked_before_raw_write else .rejected;
r.state=if(b==.none) .denied else .rejected;
if(b!=.none) r.reject_count+=1;
r.checksum=checksumOp(r.*);
r.result_checksum=r.checksum ^ 0x3434;
return b;
}
pub fn build() HgatpHardwareWriteOperationBlocker { const r=mutable();
r.build_count+=1;
r.owner_vm_id=vm.object().id;
r.owner_vcpu_id=vcpu.object().id;
r.source_fingerprint_before=readSourceFingerprint();
const s=prep.object();
r.prep_present=s.state!=.empty and s.checksum!=0;
r.prep_valid=s.ready and s.state==.ready;
r.prep_checksum=s.checksum;
r.prep_decision=tag(s.decision);
r.prep_hardware_write_value=s.hardware_write_value;
r.prep_hardware_write_checksum=s.hardware_write_checksum;
r.prep_policy_allows=s.hardware_write_policy_allows;
r.prep_policy_denies=s.hardware_write_policy_denies;
r.prep_blocked_before_call=s.hardware_write_blocked_before_call;
r.prep_call_reachable=s.hardware_write_call_reachable;
r.prep_call_called=s.hardware_write_call_called;
r.prep_raw_write_called=s.raw_write_function_called;
r.prep_trap_observed=s.trap_capture_observed;
r.prep_readback_attempted=s.readback_attempted;
r.prep_readback_valid=s.readback_valid;
r.operation_request_present=r.prep_present;
r.operation_request_value=s.hardware_write_value;
r.operation_request_checksum=s.hardware_write_checksum;
r.operation_explicit_opt_in=false;
r.operation_opt_in_required=true;
r.operation_opt_in_default_false=true;
r.operation_policy_allows=false;
r.operation_policy_denies=true;
r.operation_denied_before_csr=true;
r.operation_blocked_before_raw_write=true;
r.operation_call_reachable=false;
r.operation_call_called=false;
r.operation_call_returned=false;
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
r.hgatp_write_attempted=s.hgatp_write_attempted;
r.hgatp_write_performed=s.hgatp_write_performed;
r.active_stage2=s.active_stage2;
r.guest_entered=s.guest_entered;
r.first_guest_instruction_executed=s.first_guest_instruction_executed;
r.state=.observed;
r.source_fingerprint_after=readSourceFingerprint();
r.source_fingerprint_unchanged=sameFp(r.source_fingerprint_before,r.source_fingerprint_after);
return finish(r);
}
pub fn validate() HgatpHardwareWriteOperationBlocker { const r=mutable();
r.validate_count+=1;
return finish(r);
}
fn corrupt(kind:HgatpHardwareWriteOperationBlocker) HgatpHardwareWriteOperationBlocker { _=build();
const r=mutable();
switch(kind){ .missing_prep=>r.prep_present=false,.invalid_prep=>r.prep_valid=false,.source_mutated=>r.source_fingerprint_unchanged=false,.request_value_mismatch=>r.operation_request_value +%= 1,.explicit_opt_in_forbidden=>r.operation_explicit_opt_in=true,.policy_allows_hardware_write=>r.operation_policy_allows=true,.operation_call_reachable=>r.operation_call_reachable=true,.operation_call_called=>r.operation_call_called=true,.raw_write_called=>r.raw_write_function_called=true,.fake_trap_observed=>r.trap_observed=true,.fake_readback_observed=>r.readback_valid=true,.hgatp_write_attempted=>r.hgatp_write_attempted=true,.hgatp_write_performed=>r.hgatp_write_performed=true,.active_stage2_forbidden=>r.active_stage2=true,.guest_entered_forbidden=>r.guest_entered=true,.first_instruction_forbidden=>r.first_guest_instruction_executed=true,.none=>{} } return validate();
}
pub fn invariantConsumption() bool { _=build();
const s=prep.object();
return object().prep_checksum==s.checksum and object().prep_hardware_write_value==s.hardware_write_value and object().prep_hardware_write_checksum==s.hardware_write_checksum and object().prep_decision==tag(s.decision) and object().operation_request_present and !object().operation_explicit_opt_in;
}
pub fn invariantCorruption() bool { return corrupt(.missing_prep)==.missing_prep and corrupt(.source_mutated)==.source_mutated and corrupt(.fake_trap_observed)==.fake_trap_observed and corrupt(.first_instruction_forbidden)==.first_instruction_forbidden;
}
fn blockerName(b:HgatpHardwareWriteOperationBlocker) []const u8 { return switch(b){ .none=>"none",.missing_prep=>"missing-prep",.invalid_prep=>"invalid-prep",.source_mutated=>"source-mutated",.request_value_mismatch=>"request-value-mismatch",.explicit_opt_in_forbidden=>"explicit-opt-in-forbidden",.policy_allows_hardware_write=>"policy-allows-hardware-write",.operation_call_reachable=>"operation-call-reachable",.operation_call_called=>"operation-call-called",.raw_write_called=>"raw-write-called",.fake_trap_observed=>"fake-trap-observed",.fake_readback_observed=>"fake-readback-observed",.hgatp_write_attempted=>"hgatp-write-attempted",.hgatp_write_performed=>"hgatp-write-performed",.active_stage2_forbidden=>"active-stage2-forbidden",.guest_entered_forbidden=>"guest-entered-forbidden",.first_instruction_forbidden=>"first-instruction-forbidden" };
}
fn actionName(a:HgatpHardwareWriteOperationNextAction) []const u8 { return @tagName(a);
}
fn printBool(v:bool) void { uart.write(if(v) "true" else "false");
}
fn printResult(name:[]const u8,b:HgatpHardwareWriteOperationBlocker) void { uart.write("hv: hgatp_hardware_write_operation.");
uart.write(name);
uart.write("=");
uart.write(if(b==.none) "denied-before-csr" else "rejected");
uart.write("\r\nhv: hgatp_hardware_write_operation.result_blocker=");
uart.write(blockerName(b));
uart.write("\r\n");
}
fn printBlockers() void { const r=object();
uart.write("hv: hgatp_hardware_write_operation.blocker_count=");
uart.writeDec(r.blocker_count);
uart.write("\r\nhv: hgatp_hardware_write_operation.blocker=");
uart.write(blockerName(r.blocker));
uart.write("\r\n");
}
fn printSummary() void { const r=object();
uart.write("hv: hgatp_hardware_write_operation=opt-in-guarded-hgatp-hardware-write-operation\r\nhv: hgatp_hardware_write_operation.state=");
uart.write(@tagName(r.state));
uart.write("\r\nhv: hgatp_hardware_write_operation.build_count=");
uart.writeDec(r.build_count);
uart.write("\r\nhv: hgatp_hardware_write_operation.validate_count=");
uart.writeDec(r.validate_count);
uart.write("\r\nhv: hgatp_hardware_write_operation.reject_count=");
uart.writeDec(r.reject_count);
uart.write("\r\nhv: hgatp_hardware_write_operation.reset_count=");
uart.writeDec(r.reset_count);
uart.write("\r\n");
printBlockers();
}
fn fieldBool(name: []const u8, v: bool) void { uart.write("hv: hgatp_hardware_write_operation.");
uart.write(name);
uart.write("=");
printBool(v);
uart.write("\r\n");
}
fn fieldHex(name: []const u8, v: usize) void { uart.write("hv: hgatp_hardware_write_operation.");
uart.write(name);
uart.write("=");
uart.writeHex(v);
uart.write("\r\n");
}
fn fieldDec(name: []const u8, v: usize) void { uart.write("hv: hgatp_hardware_write_operation.");
uart.write(name);
uart.write("=");
uart.writeDec(v);
uart.write("\r\n");
}
fn printFields() void { const r=object();
fieldDec("owner_vm_id", r.owner_vm_id);
fieldDec("owner_vcpu_id", r.owner_vcpu_id);
fieldBool("prep_present", r.prep_present);
fieldBool("prep_valid", r.prep_valid);
fieldHex("prep_checksum", r.prep_checksum);
fieldDec("prep_decision", r.prep_decision);
fieldHex("prep_hardware_write_value", r.prep_hardware_write_value);
fieldHex("prep_hardware_write_checksum", r.prep_hardware_write_checksum);
fieldBool("prep_policy_allows", r.prep_policy_allows);
fieldBool("prep_policy_denies", r.prep_policy_denies);
fieldBool("prep_blocked_before_call", r.prep_blocked_before_call);
fieldBool("prep_call_reachable", r.prep_call_reachable);
fieldBool("prep_call_called", r.prep_call_called);
fieldBool("prep_raw_write_called", r.prep_raw_write_called);
fieldBool("prep_trap_observed", r.prep_trap_observed);
fieldBool("prep_readback_attempted", r.prep_readback_attempted);
fieldBool("prep_readback_valid", r.prep_readback_valid);
fieldBool("operation_request_present", r.operation_request_present);
fieldHex("operation_request_checksum", r.operation_request_checksum);
fieldHex("operation_request_value", r.operation_request_value);
fieldBool("operation_explicit_opt_in", r.operation_explicit_opt_in);
fieldBool("operation_opt_in_required", r.operation_opt_in_required);
fieldBool("operation_opt_in_default_false", r.operation_opt_in_default_false);
fieldBool("operation_policy_allows", r.operation_policy_allows);
fieldBool("operation_policy_denies", r.operation_policy_denies);
fieldBool("operation_denied_before_csr", r.operation_denied_before_csr);
fieldBool("operation_blocked_before_raw_write", r.operation_blocked_before_raw_write);
fieldBool("operation_call_reachable", r.operation_call_reachable);
fieldBool("operation_call_called", r.operation_call_called);
fieldBool("operation_call_returned", r.operation_call_returned);
fieldBool("raw_write_function_known", r.raw_write_function_known);
fieldBool("raw_write_function_allowed", r.raw_write_function_allowed);
fieldBool("raw_write_function_called", r.raw_write_function_called);
fieldBool("preflight_present", r.preflight_present);
fieldBool("preflight_passed", r.preflight_passed);
fieldBool("preflight_failed", r.preflight_failed);
fieldBool("trap_slot_present", r.trap_slot_present);
fieldBool("trap_capture_armed", r.trap_capture_armed);
fieldBool("trap_observed", r.trap_observed);
fieldDec("trap_scause", r.trap_scause);
fieldDec("trap_stval", r.trap_stval);
fieldDec("trap_sepc", r.trap_sepc);
fieldBool("readback_slot_present", r.readback_slot_present);
fieldBool("readback_allowed", r.readback_allowed);
fieldBool("readback_attempted", r.readback_attempted);
fieldHex("readback_value", r.readback_value);
fieldBool("readback_valid", r.readback_valid);
fieldBool("hgatp_write_attempted", r.hgatp_write_attempted);
fieldBool("hgatp_write_performed", r.hgatp_write_performed);
fieldBool("active_stage2", r.active_stage2);
fieldBool("guest_entered", r.guest_entered);
fieldBool("first_guest_instruction_executed", r.first_guest_instruction_executed);
fieldHex("source_fingerprint_before", r.source_fingerprint_before.checksum);
fieldHex("source_fingerprint_after", r.source_fingerprint_after.checksum);
fieldBool("source_fingerprint_unchanged", r.source_fingerprint_unchanged);
fieldDec("blocker_count", r.blocker_count);
fieldHex("checksum", r.checksum);
fieldDec("build_count", r.build_count);
fieldDec("validate_count", r.validate_count);
fieldDec("reject_count", r.reject_count);
fieldDec("reset_count", r.reset_count);
}
fn printRequest() void { const r=object();
uart.write("hv: hgatp_hardware_write_operation.operation_request_present=");
printBool(r.operation_request_present);
uart.write("\r\nhv: hgatp_hardware_write_operation.operation_request_value=");
uart.writeHex(r.operation_request_value);
uart.write("\r\nhv: hgatp_hardware_write_operation.operation_request_checksum=");
uart.writeHex(r.operation_request_checksum);
uart.write("\r\nhv: hgatp_hardware_write_operation.operation_explicit_opt_in=");
printBool(r.operation_explicit_opt_in);
uart.write("\r\nhv: hgatp_hardware_write_operation.operation_opt_in_required=");
printBool(r.operation_opt_in_required);
uart.write("\r\nhv: hgatp_hardware_write_operation.operation_opt_in_default_false=");
printBool(r.operation_opt_in_default_false);
uart.write("\r\n");
}
fn printPreflight() void { const r=object();
uart.write("hv: hgatp_hardware_write_operation.preflight_present=");
printBool(r.preflight_present);
uart.write("\r\nhv: hgatp_hardware_write_operation.preflight_passed=");
printBool(r.preflight_passed);
uart.write("\r\nhv: hgatp_hardware_write_operation.preflight_failed=");
printBool(r.preflight_failed);
uart.write("\r\nhv: hgatp_hardware_write_operation.preflight_blocker=");
uart.write(blockerName(r.preflight_blocker));
uart.write("\r\n");
}
fn printOperationResult() void { const r=object();
uart.write("hv: hgatp_hardware_write_operation.result_present=");
printBool(r.result_present);
uart.write("\r\nhv: hgatp_hardware_write_operation.result_code=");
uart.write(@tagName(r.result_code));
uart.write("\r\nhv: hgatp_hardware_write_operation.result_checksum=");
uart.writeHex(r.result_checksum);
uart.write("\r\n");
}
fn printTrapSlot() void { const r=object();
uart.write("hv: hgatp_hardware_write_operation.trap_slot_present=");
printBool(r.trap_slot_present);
uart.write("\r\nhv: hgatp_hardware_write_operation.trap_capture_armed=");
printBool(r.trap_capture_armed);
uart.write("\r\nhv: hgatp_hardware_write_operation.trap_observed=");
printBool(r.trap_observed);
uart.write("\r\nhv: hgatp_hardware_write_operation.trap_scause=");
uart.writeDec(r.trap_scause);
uart.write("\r\nhv: hgatp_hardware_write_operation.trap_stval=");
uart.writeDec(r.trap_stval);
uart.write("\r\nhv: hgatp_hardware_write_operation.trap_sepc=");
uart.writeDec(r.trap_sepc);
uart.write("\r\n");
}
fn printReadback() void { const r=object();
uart.write("hv: hgatp_hardware_write_operation.readback_slot_present=");
printBool(r.readback_slot_present);
uart.write("\r\nhv: hgatp_hardware_write_operation.readback_allowed=");
printBool(r.readback_allowed);
uart.write("\r\nhv: hgatp_hardware_write_operation.readback_attempted=");
printBool(r.readback_attempted);
uart.write("\r\nhv: hgatp_hardware_write_operation.readback_value=");
uart.writeHex(r.readback_value);
uart.write("\r\nhv: hgatp_hardware_write_operation.readback_valid=");
printBool(r.readback_valid);
uart.write("\r\n");
}
pub fn printStatusCommand() void { printSummary();
printFields();
printRequest();
printPreflight();
printOperationResult();
printTrapSlot();
printReadback();
}
pub fn printBuildCommand() void { printResult("build_result", build());
printSummary();
printFields();
printRequest();
printPreflight();
printOperationResult();
printTrapSlot();
printReadback();
}
pub fn printValidateCommand() void { printResult("validate_result", validate());
printSummary();
printFields();
printRequest();
printPreflight();
printOperationResult();
printTrapSlot();
printReadback();
}
pub fn printBlockersCommand() void { _=validate();
printBlockers();
}
pub fn printNextCommand() void { uart.write("hv: hgatp_hardware_write_operation.next_action=");
uart.write(actionName(object().next_action));
uart.write("\r\n");
}
pub fn printChecksumCommand() void { uart.write("hv: hgatp_hardware_write_operation.checksum=");
uart.writeHex(object().checksum);
uart.write("\r\n");
}
pub fn printResetCommand() void { reset();
uart.write("hv: hgatp_hardware_write_operation.reset_result=ok\r\n");
printSummary();
}
pub fn printFieldsCommand() void { printFields();
}
pub fn printRequestCommand() void { printRequest();
}
pub fn printPreflightCommand() void { printPreflight();
}
pub fn printOperationResultCommand() void { printOperationResult();
}
pub fn printTrapSlotCommand() void { printTrapSlot();
}
pub fn printReadbackCommand() void { printReadback();
}
pub fn printDecisionCommand() void { uart.write("hv: hgatp_hardware_write_operation.decision=");
uart.write(@tagName(object().decision));
uart.write("\r\n");
}
pub fn printRequirePrepTestCommand() void { printResult("require_prep_test", corrupt(.missing_prep));
printBlockers();
}
pub fn printInvalidPrepTestCommand() void { printResult("invalid_prep_test", corrupt(.invalid_prep));
printBlockers();
}
pub fn printSourceIntegrityTestCommand() void { printResult("source_integrity_test", corrupt(.source_mutated));
printBlockers();
}
pub fn printRequestValueTestCommand() void { printResult("request_value_test", corrupt(.request_value_mismatch));
printBlockers();
}
pub fn printOptInTestCommand() void { printResult("opt_in_test", corrupt(.explicit_opt_in_forbidden));
printBlockers();
}
pub fn printPolicyAllowsTestCommand() void { printResult("policy_allows_test", corrupt(.policy_allows_hardware_write));
printBlockers();
}
pub fn printCallReachableTestCommand() void { printResult("call_reachable_test", corrupt(.operation_call_reachable));
printBlockers();
}
pub fn printCallCalledTestCommand() void { printResult("call_called_test", corrupt(.operation_call_called));
printBlockers();
}
pub fn printRawWriteCalledTestCommand() void { printResult("raw_write_called_test", corrupt(.raw_write_called));
printBlockers();
}
pub fn printFakeTrapTestCommand() void { printResult("fake_trap_test", corrupt(.fake_trap_observed));
printBlockers();
}
pub fn printFakeReadbackTestCommand() void { printResult("fake_readback_test", corrupt(.fake_readback_observed));
printBlockers();
}
pub fn printWriteAttemptedTestCommand() void { printResult("write_attempted_test", corrupt(.hgatp_write_attempted));
printBlockers();
}
pub fn printWritePerformedTestCommand() void { printResult("write_performed_test", corrupt(.hgatp_write_performed));
printBlockers();
}
pub fn printActiveStage2TestCommand() void { printResult("active_stage2_test", corrupt(.active_stage2_forbidden));
printBlockers();
}
pub fn printGuestEnteredTestCommand() void { printResult("guest_entered_test", corrupt(.guest_entered_forbidden));
printBlockers();
}
pub fn printFirstInstructionTestCommand() void { printResult("first_instruction_test", corrupt(.first_instruction_forbidden));
printBlockers();
}
pub fn printInvariantConsumptionCommand() void { uart.write("hv: hgatp_hardware_write_operation.invariant_consumption_result=");
uart.write(if(invariantConsumption()) "ok" else "rejected");
uart.write("\r\n");
}
pub fn printInvariantCorruptionCommand() void { uart.write("hv: hgatp_hardware_write_operation.invariant_corruption_result=");
uart.write(if(invariantCorruption()) "ok" else "rejected");
uart.write("\r\n");
}
