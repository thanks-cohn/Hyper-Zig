
const uart = @import("../console/uart.zig");
const vm = @import("vm.zig");
const vcpu = @import("vcpu.zig");
const hgatp_csr_result = @import("hgatp_csr_result.zig");

pub const HgatpHardwareWritePrepState = enum { empty, observed, ready, rejected };
pub const HgatpHardwareWritePrepBlocker = enum { none, missing_csr_result, invalid_csr_result, source_mutated, request_value_mismatch, policy_allows_hardware_write, hardware_call_reachable, hardware_call_called, raw_write_function_called, hgatp_write_attempted, hgatp_write_performed, fake_trap_capture_observed, fake_readback_observed, active_stage2_forbidden, guest_entered_forbidden, first_instruction_forbidden };
pub const HgatpHardwareWritePrepNextAction = enum { none, build_csr_result_externally, validate_csr_result_externally, investigate_source_mutation, inspect_request_value, keep_hardware_write_blocked, stop_policy_allows_hardware_write, stop_hardware_call_reachable, stop_csr_call_observed, stop_raw_write_function_observed, stop_hgatp_write_attempt_observed, stop_hgatp_write_performed_observed, clear_fault_observation, clear_readback_observation, stop_active_stage2_observed, stop_guest_entry_observed, stop_first_instruction_observed };
pub const HgatpHardwareWritePrepDecision = enum { none, hardware_write_blocked, rejected };
pub const HgatpHardwareWritePrepCode = enum { none, prior_denied_before_csr, prior_blocked_before_asm, csr_prior_not_called, raw_write_function_prior_not_called, prior_unsafe_to_call, trap_envelope_empty, readback_not_attempted, rejected_source_missing, rejected_source_invalid, rejected_source_mutated, rejected_write_claim, rejected_active_stage2, rejected_guest_execution };

pub const HgatpHardwareWritePrepFingerprint = struct { csr_result_checksum: usize, csr_result_code: usize, csr_result_request_checksum: usize, csr_result_request_value: usize, csr_result_ready: bool, csr_result_state: usize, csr_result_decision: usize, hardware_write_call_called: bool, raw_write_function_called: bool, hgatp_write_attempted: bool, hgatp_write_performed: bool, active_stage2: bool, guest_entered: bool, first_guest_instruction_executed: bool, vm_id: vm.VmId, vcpu_id: vcpu.VcpuId, checksum: usize };
pub const HgatpHardwareWriteEnvelope = struct { present: bool, value: usize, checksum: usize };
pub const HgatpHardwareWritePolicy = struct { allows: bool, denies: bool, blocked_before_call: bool, call_reachable: bool, checksum: usize };
pub const HgatpHardwareWritePrepObservation = struct { code: HgatpHardwareWritePrepCode, reason: HgatpHardwareWritePrepBlocker, checksum: usize };
pub const HgatpHardwareWriteTrapEnvelope = struct { present: bool, observed: bool, scause: usize, stval: usize, sepc: usize, checksum: usize };
pub const HgatpHardwareWriteReadbackEnvelope = struct { present: bool, attempted: bool, value: usize, valid: bool, checksum: usize };

pub const HgatpHardwareWritePrep = struct {
    owner_vm_id: vm.VmId, owner_vcpu_id: vcpu.VcpuId,
    csr_result_present: bool, csr_result_valid: bool, csr_result_checksum: usize, csr_result_code: usize, csr_result_request_checksum: usize, csr_result_request_value: usize, csr_result_decision: usize,
    hardware_write_envelope_present: bool, hardware_write_value: usize, hardware_write_checksum: usize, hardware_write_policy_allows: bool, hardware_write_policy_denies: bool, hardware_write_blocked_before_call: bool, hardware_write_call_reachable: bool, hardware_write_call_called: bool,
    raw_write_function_known: bool, raw_write_function_allowed: bool, raw_write_function_called: bool, hardware_write_call_returned: bool,
    result_observation_present: bool, result_code: HgatpHardwareWritePrepCode, result_reason: HgatpHardwareWritePrepBlocker,
    prior_denied_before_csr: bool, prior_blocked_before_asm: bool, prior_not_called: bool, prior_unsafe_to_call: bool, prior_fault_slot_present: bool, prior_fault_observed: bool, prior_readback_slot_present: bool, prior_readback_attempted: bool, prior_readback_valid: bool,
    trap_envelope_present: bool, trap_capture_armed: bool, trap_capture_observed: bool, trap_scause: usize, trap_stval: usize, trap_sepc: usize,
    readback_envelope_present: bool, readback_allowed: bool, readback_attempted: bool, readback_value: usize, readback_valid: bool,
    hgatp_write_attempted: bool, hgatp_write_performed: bool, active_stage2: bool, guest_entered: bool, first_guest_instruction_executed: bool,
    source_fingerprint_before: HgatpHardwareWritePrepFingerprint, source_fingerprint_after: HgatpHardwareWritePrepFingerprint, source_fingerprint_unchanged: bool,
    blocker: HgatpHardwareWritePrepBlocker, blocker_count: usize, next_action: HgatpHardwareWritePrepNextAction, decision: HgatpHardwareWritePrepDecision, checksum: usize, build_count: usize, validate_count: usize, reject_count: usize, reset_count: usize, state: HgatpHardwareWritePrepState, ready: bool,
};

var obj: HgatpHardwareWritePrep = undefined; var initialized = false;
fn tag(e: anytype) usize { return @intFromEnum(e); } fn bint(v: bool) usize { return if (v) 1 else 0; } fn mix(a: usize, b: usize) usize { return (a ^ b) *% 0x9e37_79b9_7f4a_7c15; }
fn emptyFp() HgatpHardwareWritePrepFingerprint { return .{ .csr_result_checksum=0, .csr_result_code=0, .csr_result_request_checksum=0, .csr_result_request_value=0, .csr_result_ready=false, .csr_result_state=0, .csr_result_decision=0, .hardware_write_call_called=false, .raw_write_function_called=false, .hgatp_write_attempted=false, .hgatp_write_performed=false, .active_stage2=false, .guest_entered=false, .first_guest_instruction_executed=false, .vm_id=0, .vcpu_id=0, .checksum=0 }; }
fn empty(owner: vm.VmId, owner_vcpu: vcpu.VcpuId, resets: usize) HgatpHardwareWritePrep { return .{ .owner_vm_id=owner, .owner_vcpu_id=owner_vcpu, .csr_result_present=false, .csr_result_valid=false, .csr_result_checksum=0, .csr_result_code=0, .csr_result_request_checksum=0, .csr_result_request_value=0, .csr_result_decision=0, .hardware_write_envelope_present=false, .hardware_write_value=0, .hardware_write_checksum=0, .hardware_write_policy_allows=false, .hardware_write_policy_denies=true, .hardware_write_blocked_before_call=true, .hardware_write_call_reachable=false, .hardware_write_call_called=false, .raw_write_function_known=true, .raw_write_function_allowed=false, .raw_write_function_called=false, .hardware_write_call_returned=false, .result_observation_present=false, .result_code=.none, .result_reason=.none, .prior_denied_before_csr=true, .prior_blocked_before_asm=true, .prior_not_called=true, .prior_unsafe_to_call=true, .prior_fault_slot_present=false, .prior_fault_observed=false, .prior_readback_slot_present=false, .prior_readback_attempted=false, .prior_readback_valid=false, .trap_envelope_present=true, .trap_capture_armed=false, .trap_capture_observed=false, .trap_scause=0, .trap_stval=0, .trap_sepc=0, .readback_envelope_present=true, .readback_allowed=false, .readback_attempted=false, .readback_value=0, .readback_valid=false, .hgatp_write_attempted=false, .hgatp_write_performed=false, .active_stage2=false, .guest_entered=false, .first_guest_instruction_executed=false, .source_fingerprint_before=emptyFp(), .source_fingerprint_after=emptyFp(), .source_fingerprint_unchanged=false, .blocker=.none, .blocker_count=0, .next_action=.none, .decision=.none, .checksum=0, .build_count=0, .validate_count=0, .reject_count=0, .reset_count=resets, .state=.empty, .ready=false }; }
pub fn init(owner: vm.VmId, owner_vcpu: vcpu.VcpuId) void { obj = empty(owner, owner_vcpu, 0); initialized = true; } fn mutable() *HgatpHardwareWritePrep { if (!initialized) init(vm.object().id, vcpu.object().id); return &obj; } pub fn object() *const HgatpHardwareWritePrep { return mutable(); } pub fn reset() void { const r = mutable().reset_count + 1; obj = empty(vm.object().id, vcpu.object().id, r); initialized = true; }
fn fpChecksum(f: HgatpHardwareWritePrepFingerprint) usize { var x: usize = 0x3232; x=mix(x,f.csr_result_checksum); x=mix(x,f.csr_result_code); x=mix(x,f.csr_result_request_checksum); x=mix(x,f.csr_result_request_value); x=mix(x,bint(f.csr_result_ready)); x=mix(x,f.csr_result_state); x=mix(x,f.csr_result_decision); x=mix(x,bint(f.hardware_write_call_called)); x=mix(x,bint(f.raw_write_function_called)); x=mix(x,bint(f.hgatp_write_attempted)); x=mix(x,bint(f.hgatp_write_performed)); x=mix(x,bint(f.active_stage2)); x=mix(x,bint(f.guest_entered)); x=mix(x,bint(f.first_guest_instruction_executed)); x=mix(x,@intCast(f.vm_id)); x=mix(x,@intCast(f.vcpu_id)); return if (x==0) 1 else x; }
pub fn readSourceFingerprint() HgatpHardwareWritePrepFingerprint { const s = hgatp_csr_result.object(); var f = HgatpHardwareWritePrepFingerprint{ .csr_result_checksum=s.checksum, .csr_result_code=tag(s.result_code), .csr_result_request_checksum=s.csr_interface_request_checksum, .csr_result_request_value=s.csr_interface_request_value, .csr_result_ready=s.ready, .csr_result_state=tag(s.state), .csr_result_decision=tag(s.decision), .hardware_write_call_called=false, .raw_write_function_called=false, .hgatp_write_attempted=s.hgatp_write_attempted, .hgatp_write_performed=s.hgatp_write_performed, .active_stage2=s.active_stage2, .guest_entered=s.guest_entered, .first_guest_instruction_executed=s.first_guest_instruction_executed, .vm_id=vm.object().id, .vcpu_id=vcpu.object().id, .checksum=0 }; f.checksum=fpChecksum(f); return f; }
fn sameFp(a: HgatpHardwareWritePrepFingerprint, b: HgatpHardwareWritePrepFingerprint) bool { return a.checksum==b.checksum and a.csr_result_checksum==b.csr_result_checksum and a.csr_result_code==b.csr_result_code and a.csr_result_request_checksum==b.csr_result_request_checksum and a.csr_result_request_value==b.csr_result_request_value and a.csr_result_ready==b.csr_result_ready and a.csr_result_state==b.csr_result_state and a.csr_result_decision==b.csr_result_decision and a.hardware_write_call_called==b.hardware_write_call_called and a.raw_write_function_called==b.raw_write_function_called and a.hgatp_write_attempted==b.hgatp_write_attempted and a.hgatp_write_performed==b.hgatp_write_performed and a.active_stage2==b.active_stage2 and a.guest_entered==b.guest_entered and a.first_guest_instruction_executed==b.first_guest_instruction_executed and a.vm_id==b.vm_id and a.vcpu_id==b.vcpu_id; }
fn slotChecksum(p: bool, a: bool, x: usize, y: usize, z: usize) usize { var c: usize=0x3201; c=mix(c,bint(p)); c=mix(c,bint(a)); c=mix(c,x); c=mix(c,y); c=mix(c,z); return if (c==0) 1 else c; }
fn resultChecksum(r: HgatpHardwareWritePrep) usize { var x: usize=0x323232; x=mix(x,r.source_fingerprint_before.checksum); x=mix(x,r.source_fingerprint_after.checksum); x=mix(x,r.csr_result_checksum); x=mix(x,r.csr_result_request_checksum); x=mix(x,r.csr_result_request_value); x=mix(x,tag(r.result_code)); x=mix(x,tag(r.blocker)); x=mix(x,tag(r.next_action)); x=mix(x,bint(r.prior_denied_before_csr)); x=mix(x,bint(r.prior_not_called)); return if (x==0) 1 else x; }
fn codeFor(b: HgatpHardwareWritePrepBlocker) HgatpHardwareWritePrepCode { return switch (b) { .none=>.prior_denied_before_csr, .missing_csr_result=>.rejected_source_missing, .invalid_csr_result=>.rejected_source_invalid, .source_mutated=>.rejected_source_mutated, .request_value_mismatch=>.rejected_source_invalid, .policy_allows_hardware_write, .hardware_call_reachable, .hardware_call_called, .raw_write_function_called, .hgatp_write_attempted, .hgatp_write_performed=>.rejected_write_claim, .fake_trap_capture_observed=>.trap_envelope_empty, .fake_readback_observed=>.readback_not_attempted, .active_stage2_forbidden=>.rejected_active_stage2, .guest_entered_forbidden, .first_instruction_forbidden=>.rejected_guest_execution }; }
fn firstBlocker(r: HgatpHardwareWritePrep) HgatpHardwareWritePrepBlocker { if (!r.csr_result_present) return .missing_csr_result; if (!r.csr_result_valid) return .invalid_csr_result; if (!r.source_fingerprint_unchanged) return .source_mutated; if (r.csr_result_request_value != hgatp_csr_result.object().csr_interface_request_value) return .request_value_mismatch; if (r.hardware_write_policy_allows or !r.hardware_write_policy_denies or !r.hardware_write_blocked_before_call) return .policy_allows_hardware_write; if (r.hardware_write_call_reachable) return .hardware_call_reachable; if (r.hardware_write_call_called) return .hardware_call_called; if (r.raw_write_function_allowed or r.raw_write_function_called or r.hardware_write_call_returned) return .raw_write_function_called; if (r.hgatp_write_attempted) return .hgatp_write_attempted; if (r.hgatp_write_performed) return .hgatp_write_performed; if (r.trap_capture_observed or r.trap_scause != 0 or r.trap_stval != 0 or r.trap_sepc != 0) return .fake_trap_capture_observed; if (r.readback_allowed or r.readback_attempted or r.readback_valid or r.readback_value != 0) return .fake_readback_observed; if (r.active_stage2) return .active_stage2_forbidden; if (r.guest_entered) return .guest_entered_forbidden; if (r.first_guest_instruction_executed) return .first_instruction_forbidden; return .none; }
fn actionFor(b: HgatpHardwareWritePrepBlocker) HgatpHardwareWritePrepNextAction { return switch (b) { .none=>.keep_hardware_write_blocked, .missing_csr_result=>.build_csr_result_externally, .invalid_csr_result=>.validate_csr_result_externally, .source_mutated=>.investigate_source_mutation, .request_value_mismatch=>.inspect_request_value, .policy_allows_hardware_write=>.stop_policy_allows_hardware_write, .hardware_call_reachable=>.stop_hardware_call_reachable, .hardware_call_called=>.stop_csr_call_observed, .raw_write_function_called=>.stop_raw_write_function_observed, .hgatp_write_attempted=>.stop_hgatp_write_attempt_observed, .hgatp_write_performed=>.stop_hgatp_write_performed_observed, .fake_trap_capture_observed=>.clear_fault_observation, .fake_readback_observed=>.clear_readback_observation, .active_stage2_forbidden=>.stop_active_stage2_observed, .guest_entered_forbidden=>.stop_guest_entry_observed, .first_instruction_forbidden=>.stop_first_instruction_observed }; }
fn finish(r: *HgatpHardwareWritePrep) HgatpHardwareWritePrepBlocker { const b=firstBlocker(r.*); r.blocker=b; r.blocker_count=if (b==.none) 0 else 1; r.next_action=actionFor(b); r.ready=b==.none; r.state=if (r.ready) .ready else .rejected; r.decision=if (r.ready) .hardware_write_blocked else .rejected; r.result_code=codeFor(b); r.result_reason=b; r.result_observation_present=true; if (!r.ready) r.reject_count += 1; r.checksum=resultChecksum(r.*); return b; }
pub fn build() HgatpHardwareWritePrepBlocker { const r=mutable(); r.build_count += 1; r.owner_vm_id=vm.object().id; r.owner_vcpu_id=vcpu.object().id; r.source_fingerprint_before=readSourceFingerprint(); const s=hgatp_csr_result.object(); r.csr_result_present=s.state != .empty and s.checksum != 0; r.csr_result_valid=s.ready and s.state == .ready; r.csr_result_checksum=s.checksum; r.csr_result_code=tag(s.result_code); r.csr_result_request_checksum=s.csr_interface_request_checksum; r.csr_result_request_value=s.csr_interface_request_value; r.csr_result_decision=tag(s.decision); r.hardware_write_envelope_present=true; r.hardware_write_value=s.csr_interface_request_value; r.hardware_write_checksum=s.csr_interface_request_checksum; r.hardware_write_policy_allows=false; r.hardware_write_policy_denies=true; r.hardware_write_blocked_before_call=true; r.hardware_write_call_reachable=false; r.hardware_write_call_called=false; r.raw_write_function_known=true; r.raw_write_function_allowed=false; r.raw_write_function_called=false; r.hardware_write_call_returned=false; r.prior_denied_before_csr=s.denied_before_csr; r.prior_blocked_before_asm=s.blocked_before_asm; r.prior_not_called=s.not_called; r.prior_unsafe_to_call=s.unsafe_to_call; r.prior_fault_slot_present=s.fault_slot_present; r.prior_fault_observed=s.fault_observed; r.prior_readback_slot_present=s.readback_slot_present; r.prior_readback_attempted=s.readback_attempted; r.prior_readback_valid=s.readback_valid; r.trap_envelope_present=true; r.trap_capture_armed=false; r.trap_capture_observed=false; r.trap_scause=0; r.trap_stval=0; r.trap_sepc=0; r.readback_envelope_present=true; r.readback_allowed=false; r.readback_attempted=false; r.readback_value=0; r.readback_valid=false; r.hgatp_write_attempted=s.hgatp_write_attempted; r.hgatp_write_performed=s.hgatp_write_performed; r.active_stage2=s.active_stage2; r.guest_entered=s.guest_entered; r.first_guest_instruction_executed=s.first_guest_instruction_executed; r.state=.observed; r.source_fingerprint_after=readSourceFingerprint(); r.source_fingerprint_unchanged=sameFp(r.source_fingerprint_before,r.source_fingerprint_after); return finish(r); }
pub fn validate() HgatpHardwareWritePrepBlocker { const r=mutable(); r.validate_count += 1; return finish(r); }
fn corrupt(kind: HgatpHardwareWritePrepBlocker) HgatpHardwareWritePrepBlocker { _=build(); const r=mutable(); switch(kind){ .missing_csr_result=>r.csr_result_present=false, .invalid_csr_result=>r.csr_result_valid=false, .source_mutated=>r.source_fingerprint_unchanged=false, .request_value_mismatch=>r.csr_result_request_value +%= 1, .policy_allows_hardware_write=>r.hardware_write_policy_allows=true, .hardware_call_reachable=>r.hardware_write_call_reachable=true, .hardware_call_called=>r.hardware_write_call_called=true, .raw_write_function_called=>r.raw_write_function_called=true, .hgatp_write_attempted=>r.hgatp_write_attempted=true, .hgatp_write_performed=>r.hgatp_write_performed=true, .fake_trap_capture_observed=>r.trap_capture_observed=true, .fake_readback_observed=>r.readback_valid=true, .active_stage2_forbidden=>r.active_stage2=true, .guest_entered_forbidden=>r.guest_entered=true, .first_instruction_forbidden=>r.first_guest_instruction_executed=true, else=>{} } return validate(); }
pub fn invariantConsumption() bool { reset(); _=build(); const s=hgatp_csr_result.object(); return object().csr_result_checksum==s.checksum and object().csr_result_request_checksum==s.csr_interface_request_checksum and object().csr_result_request_value==s.csr_interface_request_value and object().source_fingerprint_before.csr_result_decision==tag(s.decision); }
pub fn invariantCorruption() bool { return corrupt(.missing_csr_result)==.missing_csr_result and corrupt(.source_mutated)==.source_mutated and corrupt(.fake_trap_capture_observed)==.fake_trap_capture_observed and corrupt(.first_instruction_forbidden)==.first_instruction_forbidden; }
fn blockerName(b: HgatpHardwareWritePrepBlocker) []const u8 { return switch(b){ .none=>"none", .missing_csr_result=>"missing-csr-result", .invalid_csr_result=>"invalid-csr-result", .source_mutated=>"source-mutated", .request_value_mismatch=>"request-value-mismatch", .policy_allows_hardware_write=>"policy-allows-hardware-write", .hardware_call_reachable=>"hardware-call-reachable", .hardware_call_called=>"hardware-call-called", .raw_write_function_called=>"raw-write-called", .hgatp_write_attempted=>"hgatp-write-attempted", .hgatp_write_performed=>"hgatp-write-performed", .fake_trap_capture_observed=>"fake-trap-observed", .fake_readback_observed=>"fake-readback-observed", .active_stage2_forbidden=>"active-stage2-forbidden", .guest_entered_forbidden=>"guest-entered-forbidden", .first_instruction_forbidden=>"first-instruction-forbidden" }; }
fn actionName(a: HgatpHardwareWritePrepNextAction) []const u8 { return switch(a){ .none=>"none", .build_csr_result_externally=>"build-csr-result-externally", .validate_csr_result_externally=>"validate-csr-result-externally", .investigate_source_mutation=>"investigate-source-mutation", .inspect_request_value=>"inspect-request-value", .keep_hardware_write_blocked=>"keep-hardware-write-blocked", .stop_policy_allows_hardware_write=>"stop-policy-allows-hardware-write", .stop_hardware_call_reachable=>"stop-hardware-call-reachable", .stop_csr_call_observed=>"stop-csr-call-observed", .stop_raw_write_function_observed=>"stop-raw-asm-observed", .stop_hgatp_write_attempt_observed=>"stop-hgatp-write-attempt-observed", .stop_hgatp_write_performed_observed=>"stop-hgatp-write-performed-observed", .clear_fault_observation=>"clear-fault-observation", .clear_readback_observation=>"clear-readback-observation", .stop_active_stage2_observed=>"stop-active-stage2-observed", .stop_guest_entry_observed=>"stop-guest-entry-observed", .stop_first_instruction_observed=>"stop-first-instruction-observed" }; }
fn printBool(v: bool) void { uart.write(if(v) "true" else "false"); } fn printResult(name: []const u8, b: HgatpHardwareWritePrepBlocker) void { uart.write("hv: hgatp_hardware_write_prep."); uart.write(name); uart.write("="); uart.write(if(b==.none) "ok" else "rejected"); uart.write("\r\nhv: hgatp_hardware_write_prep.result_blocker="); uart.write(blockerName(b)); uart.write("\r\n"); }
fn printBlockers() void { const r=object(); uart.write("hv: hgatp_hardware_write_prep.blocker_count="); uart.writeDec(r.blocker_count); uart.write("\r\nhv: hgatp_hardware_write_prep.blocker="); uart.write(blockerName(r.blocker)); uart.write("\r\n"); }
fn printSummary() void { const r=object(); uart.write("hv: hgatp_hardware_write_prep=guarded-hgatp-hardware-write-prep\r\nhv: hgatp_hardware_write_prep.state="); uart.write(@tagName(r.state)); uart.write("\r\nhv: hgatp_hardware_write_prep.ready="); printBool(r.ready); uart.write("\r\nhv: hgatp_hardware_write_prep.build_count="); uart.writeDec(r.build_count); uart.write("\r\nhv: hgatp_hardware_write_prep.validate_count="); uart.writeDec(r.validate_count); uart.write("\r\nhv: hgatp_hardware_write_prep.reject_count="); uart.writeDec(r.reject_count); uart.write("\r\nhv: hgatp_hardware_write_prep.reset_count="); uart.writeDec(r.reset_count); uart.write("\r\n"); printBlockers(); }
fn printFields() void { const r=object(); uart.write("hv: hgatp_hardware_write_prep.owner_vm_id="); uart.writeDec(r.owner_vm_id); uart.write("\r\nhv: hgatp_hardware_write_prep.owner_vcpu_id="); uart.writeDec(r.owner_vcpu_id); uart.write("\r\nhv: hgatp_hardware_write_prep.csr_result_present="); printBool(r.csr_result_present); uart.write("\r\nhv: hgatp_hardware_write_prep.csr_result_valid="); printBool(r.csr_result_valid); uart.write("\r\nhv: hgatp_hardware_write_prep.csr_result_checksum="); uart.writeHex(r.csr_result_checksum); uart.write("\r\nhv: hgatp_hardware_write_prep.csr_result_request_checksum="); uart.writeHex(r.csr_result_request_checksum); uart.write("\r\nhv: hgatp_hardware_write_prep.csr_result_request_value="); uart.writeHex(r.csr_result_request_value); uart.write("\r\nhv: hgatp_hardware_write_prep.csr_result_decision="); uart.writeDec(r.csr_result_decision); uart.write("\r\nhv: hgatp_hardware_write_prep.hardware_write_envelope_present="); printBool(r.hardware_write_envelope_present); uart.write("\r\nhv: hgatp_hardware_write_prep.hardware_write_call_called="); printBool(r.hardware_write_call_called); uart.write("\r\nhv: hgatp_hardware_write_prep.hardware_write_policy_denies="); printBool(r.hardware_write_policy_denies); uart.write("\r\nhv: hgatp_hardware_write_prep.hardware_write_policy_allows="); printBool(r.hardware_write_policy_allows); uart.write("\r\nhv: hgatp_hardware_write_prep.hardware_write_blocked_before_call="); printBool(r.hardware_write_blocked_before_call); uart.write("\r\nhv: hgatp_hardware_write_prep.hardware_write_call_reachable="); printBool(r.hardware_write_call_reachable); uart.write("\r\nhv: hgatp_hardware_write_prep.raw_write_function_known="); printBool(r.raw_write_function_known); uart.write("\r\nhv: hgatp_hardware_write_prep.raw_write_function_allowed="); printBool(r.raw_write_function_allowed); uart.write("\r\nhv: hgatp_hardware_write_prep.raw_write_function_called="); printBool(r.raw_write_function_called); uart.write("\r\nhv: hgatp_hardware_write_prep.hardware_write_call_returned="); printBool(r.hardware_write_call_returned); uart.write("\r\nhv: hgatp_hardware_write_prep.prior_denied_before_csr="); printBool(r.prior_denied_before_csr); uart.write("\r\nhv: hgatp_hardware_write_prep.prior_blocked_before_asm="); printBool(r.prior_blocked_before_asm); uart.write("\r\nhv: hgatp_hardware_write_prep.prior_not_called="); printBool(r.prior_not_called); uart.write("\r\nhv: hgatp_hardware_write_prep.prior_unsafe_to_call="); printBool(r.prior_unsafe_to_call); uart.write("\r\nhv: hgatp_hardware_write_prep.hgatp_write_attempted="); printBool(r.hgatp_write_attempted); uart.write("\r\nhv: hgatp_hardware_write_prep.hgatp_write_performed="); printBool(r.hgatp_write_performed); uart.write("\r\nhv: hgatp_hardware_write_prep.active_stage2="); printBool(r.active_stage2); uart.write("\r\nhv: hgatp_hardware_write_prep.guest_entered="); printBool(r.guest_entered); uart.write("\r\nhv: hgatp_hardware_write_prep.first_guest_instruction_executed="); printBool(r.first_guest_instruction_executed); uart.write("\r\nhv: hgatp_hardware_write_prep.source_fingerprint_before="); uart.writeHex(r.source_fingerprint_before.checksum); uart.write("\r\nhv: hgatp_hardware_write_prep.source_fingerprint_after="); uart.writeHex(r.source_fingerprint_after.checksum); uart.write("\r\nhv: hgatp_hardware_write_prep.source_fingerprint_unchanged="); printBool(r.source_fingerprint_unchanged); uart.write("\r\n"); }
fn printObservation() void { const r=object(); uart.write("hv: hgatp_hardware_write_prep.result_observation_present="); printBool(r.result_observation_present); uart.write("\r\nhv: hgatp_hardware_write_prep.result_code="); uart.write(@tagName(r.result_code)); uart.write("\r\nhv: hgatp_hardware_write_prep.result_reason="); uart.write(blockerName(r.result_reason)); uart.write("\r\n"); }
fn printTrapSlot() void { const r=object(); uart.write("hv: hgatp_hardware_write_prep.trap_envelope_present="); printBool(r.trap_envelope_present); uart.write("\r\nhv: hgatp_hardware_write_prep.trap_capture_armed="); printBool(r.trap_capture_armed); uart.write("\r\nhv: hgatp_hardware_write_prep.trap_capture_observed="); printBool(r.trap_capture_observed); uart.write("\r\nhv: hgatp_hardware_write_prep.trap_scause="); uart.writeDec(r.trap_scause); uart.write("\r\nhv: hgatp_hardware_write_prep.trap_stval="); uart.writeDec(r.trap_stval); uart.write("\r\nhv: hgatp_hardware_write_prep.trap_sepc="); uart.writeDec(r.trap_sepc); uart.write("\r\n"); }
fn printReadback() void { const r=object(); uart.write("hv: hgatp_hardware_write_prep.readback_envelope_present="); printBool(r.readback_envelope_present); uart.write("\r\nhv: hgatp_hardware_write_prep.readback_allowed="); printBool(r.readback_allowed); uart.write("\r\nhv: hgatp_hardware_write_prep.readback_attempted="); printBool(r.readback_attempted); uart.write("\r\nhv: hgatp_hardware_write_prep.readback_value="); uart.writeHex(r.readback_value); uart.write("\r\nhv: hgatp_hardware_write_prep.readback_valid="); printBool(r.readback_valid); uart.write("\r\n"); }
pub fn printStatusCommand() void { printSummary(); printFields(); printObservation(); printTrapSlot(); printReadback(); }
pub fn printBuildCommand() void { printResult("build_result", build()); printSummary(); printFields(); printObservation(); printTrapSlot(); printReadback(); }
pub fn printValidateCommand() void { printResult("validate_result", validate()); printSummary(); printFields(); printObservation(); printTrapSlot(); printReadback(); }
pub fn printBlockersCommand() void { _=validate(); printBlockers(); } pub fn printNextCommand() void { uart.write("hv: hgatp_hardware_write_prep.next_action="); uart.write(actionName(object().next_action)); uart.write("\r\n"); } pub fn printChecksumCommand() void { uart.write("hv: hgatp_hardware_write_prep.checksum="); uart.writeHex(object().checksum); uart.write("\r\n"); } pub fn printResetCommand() void { reset(); uart.write("hv: hgatp_hardware_write_prep.reset_result=ok\r\n"); printSummary(); } pub fn printFieldsCommand() void { printFields(); } pub fn printObservationCommand() void { printObservation(); } pub fn printTrapSlotCommand() void { printTrapSlot(); } pub fn printReadbackCommand() void { printReadback(); } pub fn printDecisionCommand() void { uart.write("hv: hgatp_hardware_write_prep.decision="); uart.write(@tagName(object().decision)); uart.write("\r\n"); }
pub fn printRequireInterfaceTestCommand() void { printResult("require_interface_test", corrupt(.missing_csr_result)); printBlockers(); } pub fn printInvalidInterfaceTestCommand() void { printResult("invalid_interface_test", corrupt(.invalid_csr_result)); printBlockers(); } pub fn printSourceIntegrityTestCommand() void { printResult("source_integrity_test", corrupt(.source_mutated)); printBlockers(); } pub fn printRequestValueTestCommand() void { printResult("request_value_test", corrupt(.request_value_mismatch)); printBlockers(); } pub fn printPolicyAllowsTestCommand() void { printResult("policy_allows_test", corrupt(.policy_allows_hardware_write)); printBlockers(); } pub fn printCallReachableTestCommand() void { printResult("call_reachable_test", corrupt(.hardware_call_reachable)); printBlockers(); }
pub fn printCsrCalledTestCommand() void { printResult("csr_called_test", corrupt(.hardware_call_called)); printBlockers(); } pub fn printRawAsmCalledTestCommand() void { printResult("raw_write_function_called_test", corrupt(.raw_write_function_called)); printBlockers(); } pub fn printWriteAttemptedTestCommand() void { printResult("write_attempted_test", corrupt(.hgatp_write_attempted)); printBlockers(); } pub fn printWritePerformedTestCommand() void { printResult("write_performed_test", corrupt(.hgatp_write_performed)); printBlockers(); } pub fn printFakeFaultTestCommand() void { printResult("fake_fault_test", corrupt(.fake_trap_capture_observed)); printBlockers(); } pub fn printFakeReadbackTestCommand() void { printResult("fake_readback_test", corrupt(.fake_readback_observed)); printBlockers(); } pub fn printActiveStage2TestCommand() void { printResult("active_stage2_test", corrupt(.active_stage2_forbidden)); printBlockers(); } pub fn printGuestEnteredTestCommand() void { printResult("guest_entered_test", corrupt(.guest_entered_forbidden)); printBlockers(); } pub fn printFirstInstructionTestCommand() void { printResult("first_instruction_test", corrupt(.first_instruction_forbidden)); printBlockers(); } pub fn printInvariantConsumptionCommand() void { uart.write("hv: hgatp_hardware_write_prep.invariant_consumption_result="); uart.write(if(invariantConsumption()) "ok" else "rejected"); uart.write("\r\n"); } pub fn printInvariantCorruptionCommand() void { uart.write("hv: hgatp_hardware_write_prep.invariant_corruption_result="); uart.write(if(invariantCorruption()) "ok" else "rejected"); uart.write("\r\n"); }

pub fn currentObservation() HgatpHardwareWritePrepObservation {
    const r = object();
    return .{
        .code = r.result_code,
        .reason = r.result_reason,
        .checksum = observationChecksum(r.result_code, r.result_reason),
    };
}

pub fn currentTrapSlot() HgatpHardwareWriteTrapEnvelope {
    const r = object();
    return .{
        .present = r.trap_envelope_present,
        .observed = r.trap_capture_observed,
        .scause = r.trap_scause,
        .stval = r.trap_stval,
        .sepc = r.trap_sepc,
        .checksum = slotChecksum(r.trap_envelope_present, r.trap_capture_observed, r.trap_scause, r.trap_stval, r.trap_sepc),
    };
}

pub fn currentReadbackSlot() HgatpHardwareWriteReadbackEnvelope {
    const r = object();
    return .{
        .present = r.readback_envelope_present,
        .attempted = r.readback_attempted,
        .value = r.readback_value,
        .valid = r.readback_valid,
        .checksum = slotChecksum(r.readback_envelope_present, r.readback_attempted, r.readback_value, bint(r.readback_valid), 0),
    };
}

fn observationChecksum(code: HgatpHardwareWritePrepCode, reason: HgatpHardwareWritePrepBlocker) usize {
    var x: usize = 0x3202;
    x = mix(x, tag(code));
    x = mix(x, tag(reason));
    return if (x == 0) 1 else x;
}

pub fn noWriteInvariantHeld() bool {
    const r = object();
    return !r.hardware_write_call_called and
        !r.raw_write_function_called and
        !r.hardware_write_call_returned and
        !r.hgatp_write_attempted and
        !r.hgatp_write_performed;
}

pub fn noFaultOrReadbackInvariantHeld() bool {
    const r = object();
    return r.trap_envelope_present and
        !r.trap_capture_observed and
        r.trap_scause == 0 and
        r.trap_stval == 0 and
        r.trap_sepc == 0 and
        r.readback_envelope_present and
        !r.readback_attempted and
        r.readback_value == 0 and
        !r.readback_valid;
}

pub fn noGuestInvariantHeld() bool {
    const r = object();
    return !r.active_stage2 and
        !r.guest_entered and
        !r.first_guest_instruction_executed;
}

pub fn sourceConsumptionHeld() bool {
    const r = object();
    const s = hgatp_csr_result.object();
    return r.csr_result_checksum == s.checksum and
        r.csr_result_request_checksum == s.csr_interface_request_checksum and
        r.csr_result_request_value == s.csr_interface_request_value and
        r.csr_result_decision == tag(s.decision);
}

pub fn currentBlockerCount() usize {
    return object().blocker_count;
}

pub fn currentChecksum() usize {
    return object().checksum;
}

pub fn currentDecision() HgatpHardwareWritePrepDecision {
    return object().decision;
}

pub fn currentNextAction() HgatpHardwareWritePrepNextAction {
    return object().next_action;
}

pub fn currentResultCode() HgatpHardwareWritePrepCode {
    return object().result_code;
}

pub fn currentSourceStable() bool {
    return object().source_fingerprint_unchanged;
}
