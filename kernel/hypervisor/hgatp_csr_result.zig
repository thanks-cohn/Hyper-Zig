
const uart = @import("../console/uart.zig");
const vm = @import("vm.zig");
const vcpu = @import("vcpu.zig");
const hgatp_csr_interface = @import("hgatp_csr_interface.zig");

pub const HgatpCsrResultState = enum { empty, observed, ready, rejected };
pub const HgatpCsrResultBlocker = enum { none, missing_csr_interface, invalid_csr_interface, source_mutated, request_value_mismatch, csr_write_called, raw_asm_called, hgatp_write_attempted, hgatp_write_performed, fake_fault_observed, fake_readback_observed, active_stage2_forbidden, guest_entered_forbidden, first_instruction_forbidden };
pub const HgatpCsrResultNextAction = enum { none, build_csr_interface_externally, validate_csr_interface_externally, investigate_source_mutation, inspect_request_value, keep_csr_denied_not_called, stop_csr_call_observed, stop_raw_asm_observed, stop_hgatp_write_attempt_observed, stop_hgatp_write_performed_observed, clear_fault_observation, clear_readback_observation, stop_active_stage2_observed, stop_guest_entry_observed, stop_first_instruction_observed };
pub const HgatpCsrResultDecision = enum { none, denied_not_called_accounted, rejected };
pub const HgatpCsrResultCode = enum { none, denied_before_csr, blocked_before_asm, csr_not_called, raw_asm_not_called, unsafe_to_call, fault_slot_empty, readback_not_attempted, rejected_source_missing, rejected_source_invalid, rejected_source_mutated, rejected_write_claim, rejected_active_stage2, rejected_guest_execution };

pub const HgatpCsrResultFingerprint = struct { csr_interface_checksum: usize, csr_interface_request_checksum: usize, csr_interface_request_value: usize, csr_interface_ready: bool, csr_interface_state: usize, csr_interface_decision: usize, csr_write_function_called: bool, raw_asm_called: bool, hgatp_write_attempted: bool, hgatp_write_performed: bool, active_stage2: bool, guest_entered: bool, first_guest_instruction_executed: bool, vm_id: vm.VmId, vcpu_id: vcpu.VcpuId, checksum: usize };
pub const HgatpCsrResultObservation = struct { code: HgatpCsrResultCode, reason: HgatpCsrResultBlocker, checksum: usize };
pub const HgatpCsrResultTrapSlot = struct { present: bool, observed: bool, scause: usize, stval: usize, sepc: usize, checksum: usize };
pub const HgatpCsrResultReadbackSlot = struct { present: bool, attempted: bool, value: usize, valid: bool, checksum: usize };

pub const HgatpCsrResult = struct {
    owner_vm_id: vm.VmId, owner_vcpu_id: vcpu.VcpuId,
    csr_interface_present: bool, csr_interface_valid: bool, csr_interface_checksum: usize, csr_interface_request_checksum: usize, csr_interface_request_value: usize, csr_interface_decision: usize,
    csr_write_function_present: bool, csr_write_function_called: bool, csr_write_call_denied_by_policy: bool, csr_write_call_allowed_by_policy: bool, csr_write_call_blocked_before_asm: bool,
    raw_asm_present: bool, raw_asm_called: bool, raw_asm_returned: bool,
    result_observation_present: bool, result_code: HgatpCsrResultCode, result_reason: HgatpCsrResultBlocker,
    denied_before_csr: bool, blocked_before_asm: bool, not_called: bool, unsafe_to_call: bool,
    fault_slot_present: bool, fault_observed: bool, fault_scause: usize, fault_stval: usize, fault_sepc: usize,
    readback_slot_present: bool, readback_attempted: bool, readback_value: usize, readback_valid: bool,
    hgatp_write_attempted: bool, hgatp_write_performed: bool, active_stage2: bool, guest_entered: bool, first_guest_instruction_executed: bool,
    source_fingerprint_before: HgatpCsrResultFingerprint, source_fingerprint_after: HgatpCsrResultFingerprint, source_fingerprint_unchanged: bool,
    blocker: HgatpCsrResultBlocker, blocker_count: usize, next_action: HgatpCsrResultNextAction, decision: HgatpCsrResultDecision, checksum: usize, build_count: usize, validate_count: usize, reject_count: usize, reset_count: usize, state: HgatpCsrResultState, ready: bool,
};

var obj: HgatpCsrResult = undefined; var initialized = false;
fn tag(e: anytype) usize { return @intFromEnum(e); } fn bint(v: bool) usize { return if (v) 1 else 0; } fn mix(a: usize, b: usize) usize { return (a ^ b) *% 0x9e37_79b9_7f4a_7c15; }
fn emptyFp() HgatpCsrResultFingerprint { return .{ .csr_interface_checksum=0, .csr_interface_request_checksum=0, .csr_interface_request_value=0, .csr_interface_ready=false, .csr_interface_state=0, .csr_interface_decision=0, .csr_write_function_called=false, .raw_asm_called=false, .hgatp_write_attempted=false, .hgatp_write_performed=false, .active_stage2=false, .guest_entered=false, .first_guest_instruction_executed=false, .vm_id=0, .vcpu_id=0, .checksum=0 }; }
fn empty(owner: vm.VmId, owner_vcpu: vcpu.VcpuId, resets: usize) HgatpCsrResult { return .{ .owner_vm_id=owner, .owner_vcpu_id=owner_vcpu, .csr_interface_present=false, .csr_interface_valid=false, .csr_interface_checksum=0, .csr_interface_request_checksum=0, .csr_interface_request_value=0, .csr_interface_decision=0, .csr_write_function_present=false, .csr_write_function_called=false, .csr_write_call_denied_by_policy=true, .csr_write_call_allowed_by_policy=false, .csr_write_call_blocked_before_asm=true, .raw_asm_present=true, .raw_asm_called=false, .raw_asm_returned=false, .result_observation_present=false, .result_code=.none, .result_reason=.none, .denied_before_csr=true, .blocked_before_asm=true, .not_called=true, .unsafe_to_call=true, .fault_slot_present=true, .fault_observed=false, .fault_scause=0, .fault_stval=0, .fault_sepc=0, .readback_slot_present=true, .readback_attempted=false, .readback_value=0, .readback_valid=false, .hgatp_write_attempted=false, .hgatp_write_performed=false, .active_stage2=false, .guest_entered=false, .first_guest_instruction_executed=false, .source_fingerprint_before=emptyFp(), .source_fingerprint_after=emptyFp(), .source_fingerprint_unchanged=false, .blocker=.none, .blocker_count=0, .next_action=.none, .decision=.none, .checksum=0, .build_count=0, .validate_count=0, .reject_count=0, .reset_count=resets, .state=.empty, .ready=false }; }
pub fn init(owner: vm.VmId, owner_vcpu: vcpu.VcpuId) void { obj = empty(owner, owner_vcpu, 0); initialized = true; } fn mutable() *HgatpCsrResult { if (!initialized) init(vm.object().id, vcpu.object().id); return &obj; } pub fn object() *const HgatpCsrResult { return mutable(); } pub fn reset() void { const r = mutable().reset_count + 1; obj = empty(vm.object().id, vcpu.object().id, r); initialized = true; }
fn fpChecksum(f: HgatpCsrResultFingerprint) usize { var x: usize = 0x3232; x=mix(x,f.csr_interface_checksum); x=mix(x,f.csr_interface_request_checksum); x=mix(x,f.csr_interface_request_value); x=mix(x,bint(f.csr_interface_ready)); x=mix(x,f.csr_interface_state); x=mix(x,f.csr_interface_decision); x=mix(x,bint(f.csr_write_function_called)); x=mix(x,bint(f.raw_asm_called)); x=mix(x,bint(f.hgatp_write_attempted)); x=mix(x,bint(f.hgatp_write_performed)); x=mix(x,bint(f.active_stage2)); x=mix(x,bint(f.guest_entered)); x=mix(x,bint(f.first_guest_instruction_executed)); x=mix(x,@intCast(f.vm_id)); x=mix(x,@intCast(f.vcpu_id)); return if (x==0) 1 else x; }
pub fn readSourceFingerprint() HgatpCsrResultFingerprint { const s = hgatp_csr_interface.object(); var f = HgatpCsrResultFingerprint{ .csr_interface_checksum=s.checksum, .csr_interface_request_checksum=s.request_checksum, .csr_interface_request_value=s.request_value, .csr_interface_ready=s.ready, .csr_interface_state=tag(s.state), .csr_interface_decision=tag(s.decision), .csr_write_function_called=s.csr_write_function_called, .raw_asm_called=s.raw_asm_called, .hgatp_write_attempted=s.hgatp_write_attempted, .hgatp_write_performed=s.hgatp_write_performed, .active_stage2=s.active_stage2, .guest_entered=s.guest_entered, .first_guest_instruction_executed=s.first_guest_instruction_executed, .vm_id=vm.object().id, .vcpu_id=vcpu.object().id, .checksum=0 }; f.checksum=fpChecksum(f); return f; }
fn sameFp(a: HgatpCsrResultFingerprint, b: HgatpCsrResultFingerprint) bool { return a.checksum==b.checksum and a.csr_interface_checksum==b.csr_interface_checksum and a.csr_interface_request_checksum==b.csr_interface_request_checksum and a.csr_interface_request_value==b.csr_interface_request_value and a.csr_interface_ready==b.csr_interface_ready and a.csr_interface_state==b.csr_interface_state and a.csr_interface_decision==b.csr_interface_decision and a.csr_write_function_called==b.csr_write_function_called and a.raw_asm_called==b.raw_asm_called and a.hgatp_write_attempted==b.hgatp_write_attempted and a.hgatp_write_performed==b.hgatp_write_performed and a.active_stage2==b.active_stage2 and a.guest_entered==b.guest_entered and a.first_guest_instruction_executed==b.first_guest_instruction_executed and a.vm_id==b.vm_id and a.vcpu_id==b.vcpu_id; }
fn slotChecksum(p: bool, a: bool, x: usize, y: usize, z: usize) usize { var c: usize=0x3201; c=mix(c,bint(p)); c=mix(c,bint(a)); c=mix(c,x); c=mix(c,y); c=mix(c,z); return if (c==0) 1 else c; }
fn resultChecksum(r: HgatpCsrResult) usize { var x: usize=0x323232; x=mix(x,r.source_fingerprint_before.checksum); x=mix(x,r.source_fingerprint_after.checksum); x=mix(x,r.csr_interface_checksum); x=mix(x,r.csr_interface_request_checksum); x=mix(x,r.csr_interface_request_value); x=mix(x,tag(r.result_code)); x=mix(x,tag(r.blocker)); x=mix(x,tag(r.next_action)); x=mix(x,bint(r.denied_before_csr)); x=mix(x,bint(r.not_called)); return if (x==0) 1 else x; }
fn codeFor(b: HgatpCsrResultBlocker) HgatpCsrResultCode { return switch (b) { .none=>.denied_before_csr, .missing_csr_interface=>.rejected_source_missing, .invalid_csr_interface=>.rejected_source_invalid, .source_mutated=>.rejected_source_mutated, .request_value_mismatch=>.rejected_source_invalid, .csr_write_called, .raw_asm_called, .hgatp_write_attempted, .hgatp_write_performed=>.rejected_write_claim, .fake_fault_observed=>.fault_slot_empty, .fake_readback_observed=>.readback_not_attempted, .active_stage2_forbidden=>.rejected_active_stage2, .guest_entered_forbidden, .first_instruction_forbidden=>.rejected_guest_execution }; }
fn firstBlocker(r: HgatpCsrResult) HgatpCsrResultBlocker { if (!r.csr_interface_present) return .missing_csr_interface; if (!r.csr_interface_valid) return .invalid_csr_interface; if (!r.source_fingerprint_unchanged) return .source_mutated; if (r.csr_interface_request_value != hgatp_csr_interface.object().request_value) return .request_value_mismatch; if (r.csr_write_function_called) return .csr_write_called; if (r.raw_asm_called or r.raw_asm_returned) return .raw_asm_called; if (r.hgatp_write_attempted) return .hgatp_write_attempted; if (r.hgatp_write_performed) return .hgatp_write_performed; if (r.fault_observed or r.fault_scause != 0 or r.fault_stval != 0 or r.fault_sepc != 0) return .fake_fault_observed; if (r.readback_attempted or r.readback_valid or r.readback_value != 0) return .fake_readback_observed; if (r.active_stage2) return .active_stage2_forbidden; if (r.guest_entered) return .guest_entered_forbidden; if (r.first_guest_instruction_executed) return .first_instruction_forbidden; return .none; }
fn actionFor(b: HgatpCsrResultBlocker) HgatpCsrResultNextAction { return switch (b) { .none=>.keep_csr_denied_not_called, .missing_csr_interface=>.build_csr_interface_externally, .invalid_csr_interface=>.validate_csr_interface_externally, .source_mutated=>.investigate_source_mutation, .request_value_mismatch=>.inspect_request_value, .csr_write_called=>.stop_csr_call_observed, .raw_asm_called=>.stop_raw_asm_observed, .hgatp_write_attempted=>.stop_hgatp_write_attempt_observed, .hgatp_write_performed=>.stop_hgatp_write_performed_observed, .fake_fault_observed=>.clear_fault_observation, .fake_readback_observed=>.clear_readback_observation, .active_stage2_forbidden=>.stop_active_stage2_observed, .guest_entered_forbidden=>.stop_guest_entry_observed, .first_instruction_forbidden=>.stop_first_instruction_observed }; }
fn finish(r: *HgatpCsrResult) HgatpCsrResultBlocker { const b=firstBlocker(r.*); r.blocker=b; r.blocker_count=if (b==.none) 0 else 1; r.next_action=actionFor(b); r.ready=b==.none; r.state=if (r.ready) .ready else .rejected; r.decision=if (r.ready) .denied_not_called_accounted else .rejected; r.result_code=codeFor(b); r.result_reason=b; r.result_observation_present=true; if (!r.ready) r.reject_count += 1; r.checksum=resultChecksum(r.*); return b; }
pub fn build() HgatpCsrResultBlocker { const r=mutable(); r.build_count += 1; r.owner_vm_id=vm.object().id; r.owner_vcpu_id=vcpu.object().id; r.source_fingerprint_before=readSourceFingerprint(); const s=hgatp_csr_interface.object(); r.csr_interface_present=s.state != .empty and s.checksum != 0; r.csr_interface_valid=s.ready and s.state == .ready; r.csr_interface_checksum=s.checksum; r.csr_interface_request_checksum=s.request_checksum; r.csr_interface_request_value=s.request_value; r.csr_interface_decision=tag(s.decision); r.csr_write_function_present=s.csr_write_function_present; r.csr_write_function_called=s.csr_write_function_called; r.csr_write_call_denied_by_policy=s.csr_write_call_denied_by_policy; r.csr_write_call_allowed_by_policy=s.csr_write_call_allowed_by_policy; r.csr_write_call_blocked_before_asm=s.csr_write_call_blocked_before_asm; r.raw_asm_present=s.raw_asm_present; r.raw_asm_called=s.raw_asm_called; r.raw_asm_returned=s.raw_asm_returned; r.denied_before_csr=true; r.blocked_before_asm=true; r.not_called=!r.csr_write_function_called and !r.raw_asm_called; r.unsafe_to_call=true; r.fault_slot_present=true; r.fault_observed=false; r.fault_scause=0; r.fault_stval=0; r.fault_sepc=0; r.readback_slot_present=true; r.readback_attempted=false; r.readback_value=0; r.readback_valid=false; r.hgatp_write_attempted=s.hgatp_write_attempted; r.hgatp_write_performed=s.hgatp_write_performed; r.active_stage2=s.active_stage2; r.guest_entered=s.guest_entered; r.first_guest_instruction_executed=s.first_guest_instruction_executed; r.state=.observed; r.source_fingerprint_after=readSourceFingerprint(); r.source_fingerprint_unchanged=sameFp(r.source_fingerprint_before,r.source_fingerprint_after); return finish(r); }
pub fn validate() HgatpCsrResultBlocker { const r=mutable(); r.validate_count += 1; return finish(r); }
fn corrupt(kind: HgatpCsrResultBlocker) HgatpCsrResultBlocker { _=build(); const r=mutable(); switch(kind){ .missing_csr_interface=>r.csr_interface_present=false, .invalid_csr_interface=>r.csr_interface_valid=false, .source_mutated=>r.source_fingerprint_unchanged=false, .request_value_mismatch=>r.csr_interface_request_value +%= 1, .csr_write_called=>r.csr_write_function_called=true, .raw_asm_called=>r.raw_asm_called=true, .hgatp_write_attempted=>r.hgatp_write_attempted=true, .hgatp_write_performed=>r.hgatp_write_performed=true, .fake_fault_observed=>r.fault_observed=true, .fake_readback_observed=>r.readback_valid=true, .active_stage2_forbidden=>r.active_stage2=true, .guest_entered_forbidden=>r.guest_entered=true, .first_instruction_forbidden=>r.first_guest_instruction_executed=true, else=>{} } return validate(); }
pub fn invariantConsumption() bool { reset(); _=build(); const s=hgatp_csr_interface.object(); return object().csr_interface_checksum==s.checksum and object().csr_interface_request_checksum==s.request_checksum and object().csr_interface_request_value==s.request_value and object().source_fingerprint_before.csr_interface_decision==tag(s.decision); }
pub fn invariantCorruption() bool { return corrupt(.missing_csr_interface)==.missing_csr_interface and corrupt(.source_mutated)==.source_mutated and corrupt(.fake_fault_observed)==.fake_fault_observed and corrupt(.first_instruction_forbidden)==.first_instruction_forbidden; }
fn blockerName(b: HgatpCsrResultBlocker) []const u8 { return switch(b){ .none=>"none", .missing_csr_interface=>"missing-csr-interface", .invalid_csr_interface=>"invalid-csr-interface", .source_mutated=>"source-mutated", .request_value_mismatch=>"request-value-mismatch", .csr_write_called=>"csr-write-called", .raw_asm_called=>"raw-asm-called", .hgatp_write_attempted=>"hgatp-write-attempted", .hgatp_write_performed=>"hgatp-write-performed", .fake_fault_observed=>"fake-fault-observed", .fake_readback_observed=>"fake-readback-observed", .active_stage2_forbidden=>"active-stage2-forbidden", .guest_entered_forbidden=>"guest-entered-forbidden", .first_instruction_forbidden=>"first-instruction-forbidden" }; }
fn actionName(a: HgatpCsrResultNextAction) []const u8 { return switch(a){ .none=>"none", .build_csr_interface_externally=>"build-csr-interface-externally", .validate_csr_interface_externally=>"validate-csr-interface-externally", .investigate_source_mutation=>"investigate-source-mutation", .inspect_request_value=>"inspect-request-value", .keep_csr_denied_not_called=>"keep-csr-denied-not-called", .stop_csr_call_observed=>"stop-csr-call-observed", .stop_raw_asm_observed=>"stop-raw-asm-observed", .stop_hgatp_write_attempt_observed=>"stop-hgatp-write-attempt-observed", .stop_hgatp_write_performed_observed=>"stop-hgatp-write-performed-observed", .clear_fault_observation=>"clear-fault-observation", .clear_readback_observation=>"clear-readback-observation", .stop_active_stage2_observed=>"stop-active-stage2-observed", .stop_guest_entry_observed=>"stop-guest-entry-observed", .stop_first_instruction_observed=>"stop-first-instruction-observed" }; }
fn printBool(v: bool) void { uart.write(if(v) "true" else "false"); } fn printResult(name: []const u8, b: HgatpCsrResultBlocker) void { uart.write("hv: hgatp_csr_result."); uart.write(name); uart.write("="); uart.write(if(b==.none) "ok" else "rejected"); uart.write("\r\nhv: hgatp_csr_result.result_blocker="); uart.write(blockerName(b)); uart.write("\r\n"); }
fn printBlockers() void { const r=object(); uart.write("hv: hgatp_csr_result.blocker_count="); uart.writeDec(r.blocker_count); uart.write("\r\nhv: hgatp_csr_result.blocker="); uart.write(blockerName(r.blocker)); uart.write("\r\n"); }
fn printSummary() void { const r=object(); uart.write("hv: hgatp_csr_result=guarded-hgatp-csr-result-fault-accounting\r\nhv: hgatp_csr_result.state="); uart.write(@tagName(r.state)); uart.write("\r\nhv: hgatp_csr_result.ready="); printBool(r.ready); uart.write("\r\nhv: hgatp_csr_result.build_count="); uart.writeDec(r.build_count); uart.write("\r\nhv: hgatp_csr_result.validate_count="); uart.writeDec(r.validate_count); uart.write("\r\nhv: hgatp_csr_result.reject_count="); uart.writeDec(r.reject_count); uart.write("\r\nhv: hgatp_csr_result.reset_count="); uart.writeDec(r.reset_count); uart.write("\r\n"); printBlockers(); }
fn printFields() void { const r=object(); uart.write("hv: hgatp_csr_result.owner_vm_id="); uart.writeDec(r.owner_vm_id); uart.write("\r\nhv: hgatp_csr_result.owner_vcpu_id="); uart.writeDec(r.owner_vcpu_id); uart.write("\r\nhv: hgatp_csr_result.csr_interface_present="); printBool(r.csr_interface_present); uart.write("\r\nhv: hgatp_csr_result.csr_interface_valid="); printBool(r.csr_interface_valid); uart.write("\r\nhv: hgatp_csr_result.csr_interface_checksum="); uart.writeHex(r.csr_interface_checksum); uart.write("\r\nhv: hgatp_csr_result.csr_interface_request_checksum="); uart.writeHex(r.csr_interface_request_checksum); uart.write("\r\nhv: hgatp_csr_result.csr_interface_request_value="); uart.writeHex(r.csr_interface_request_value); uart.write("\r\nhv: hgatp_csr_result.csr_interface_decision="); uart.writeDec(r.csr_interface_decision); uart.write("\r\nhv: hgatp_csr_result.csr_write_function_present="); printBool(r.csr_write_function_present); uart.write("\r\nhv: hgatp_csr_result.csr_write_function_called="); printBool(r.csr_write_function_called); uart.write("\r\nhv: hgatp_csr_result.csr_write_call_denied_by_policy="); printBool(r.csr_write_call_denied_by_policy); uart.write("\r\nhv: hgatp_csr_result.csr_write_call_allowed_by_policy="); printBool(r.csr_write_call_allowed_by_policy); uart.write("\r\nhv: hgatp_csr_result.csr_write_call_blocked_before_asm="); printBool(r.csr_write_call_blocked_before_asm); uart.write("\r\nhv: hgatp_csr_result.raw_asm_present="); printBool(r.raw_asm_present); uart.write("\r\nhv: hgatp_csr_result.raw_asm_called="); printBool(r.raw_asm_called); uart.write("\r\nhv: hgatp_csr_result.raw_asm_returned="); printBool(r.raw_asm_returned); uart.write("\r\nhv: hgatp_csr_result.denied_before_csr="); printBool(r.denied_before_csr); uart.write("\r\nhv: hgatp_csr_result.blocked_before_asm="); printBool(r.blocked_before_asm); uart.write("\r\nhv: hgatp_csr_result.not_called="); printBool(r.not_called); uart.write("\r\nhv: hgatp_csr_result.unsafe_to_call="); printBool(r.unsafe_to_call); uart.write("\r\nhv: hgatp_csr_result.hgatp_write_attempted="); printBool(r.hgatp_write_attempted); uart.write("\r\nhv: hgatp_csr_result.hgatp_write_performed="); printBool(r.hgatp_write_performed); uart.write("\r\nhv: hgatp_csr_result.active_stage2="); printBool(r.active_stage2); uart.write("\r\nhv: hgatp_csr_result.guest_entered="); printBool(r.guest_entered); uart.write("\r\nhv: hgatp_csr_result.first_guest_instruction_executed="); printBool(r.first_guest_instruction_executed); uart.write("\r\nhv: hgatp_csr_result.source_fingerprint_before="); uart.writeHex(r.source_fingerprint_before.checksum); uart.write("\r\nhv: hgatp_csr_result.source_fingerprint_after="); uart.writeHex(r.source_fingerprint_after.checksum); uart.write("\r\nhv: hgatp_csr_result.source_fingerprint_unchanged="); printBool(r.source_fingerprint_unchanged); uart.write("\r\n"); }
fn printObservation() void { const r=object(); uart.write("hv: hgatp_csr_result.result_observation_present="); printBool(r.result_observation_present); uart.write("\r\nhv: hgatp_csr_result.result_code="); uart.write(@tagName(r.result_code)); uart.write("\r\nhv: hgatp_csr_result.result_reason="); uart.write(blockerName(r.result_reason)); uart.write("\r\n"); }
fn printTrapSlot() void { const r=object(); uart.write("hv: hgatp_csr_result.fault_slot_present="); printBool(r.fault_slot_present); uart.write("\r\nhv: hgatp_csr_result.fault_observed="); printBool(r.fault_observed); uart.write("\r\nhv: hgatp_csr_result.fault_scause="); uart.writeDec(r.fault_scause); uart.write("\r\nhv: hgatp_csr_result.fault_stval="); uart.writeDec(r.fault_stval); uart.write("\r\nhv: hgatp_csr_result.fault_sepc="); uart.writeDec(r.fault_sepc); uart.write("\r\n"); }
fn printReadback() void { const r=object(); uart.write("hv: hgatp_csr_result.readback_slot_present="); printBool(r.readback_slot_present); uart.write("\r\nhv: hgatp_csr_result.readback_attempted="); printBool(r.readback_attempted); uart.write("\r\nhv: hgatp_csr_result.readback_value="); uart.writeHex(r.readback_value); uart.write("\r\nhv: hgatp_csr_result.readback_valid="); printBool(r.readback_valid); uart.write("\r\n"); }
pub fn printStatusCommand() void { printSummary(); printFields(); printObservation(); printTrapSlot(); printReadback(); }
pub fn printBuildCommand() void { printResult("build_result", build()); printSummary(); printFields(); printObservation(); printTrapSlot(); printReadback(); }
pub fn printValidateCommand() void { printResult("validate_result", validate()); printSummary(); printFields(); printObservation(); printTrapSlot(); printReadback(); }
pub fn printBlockersCommand() void { _=validate(); printBlockers(); } pub fn printNextCommand() void { uart.write("hv: hgatp_csr_result.next_action="); uart.write(actionName(object().next_action)); uart.write("\r\n"); } pub fn printChecksumCommand() void { uart.write("hv: hgatp_csr_result.checksum="); uart.writeHex(object().checksum); uart.write("\r\n"); } pub fn printResetCommand() void { reset(); uart.write("hv: hgatp_csr_result.reset_result=ok\r\n"); printSummary(); } pub fn printFieldsCommand() void { printFields(); } pub fn printObservationCommand() void { printObservation(); } pub fn printTrapSlotCommand() void { printTrapSlot(); } pub fn printReadbackCommand() void { printReadback(); } pub fn printDecisionCommand() void { uart.write("hv: hgatp_csr_result.decision="); uart.write(@tagName(object().decision)); uart.write("\r\n"); }
pub fn printRequireInterfaceTestCommand() void { printResult("require_interface_test", corrupt(.missing_csr_interface)); printBlockers(); } pub fn printInvalidInterfaceTestCommand() void { printResult("invalid_interface_test", corrupt(.invalid_csr_interface)); printBlockers(); } pub fn printSourceIntegrityTestCommand() void { printResult("source_integrity_test", corrupt(.source_mutated)); printBlockers(); } pub fn printRequestValueTestCommand() void { printResult("request_value_test", corrupt(.request_value_mismatch)); printBlockers(); } pub fn printCsrCalledTestCommand() void { printResult("csr_called_test", corrupt(.csr_write_called)); printBlockers(); } pub fn printRawAsmCalledTestCommand() void { printResult("raw_asm_called_test", corrupt(.raw_asm_called)); printBlockers(); } pub fn printWriteAttemptedTestCommand() void { printResult("write_attempted_test", corrupt(.hgatp_write_attempted)); printBlockers(); } pub fn printWritePerformedTestCommand() void { printResult("write_performed_test", corrupt(.hgatp_write_performed)); printBlockers(); } pub fn printFakeFaultTestCommand() void { printResult("fake_fault_test", corrupt(.fake_fault_observed)); printBlockers(); } pub fn printFakeReadbackTestCommand() void { printResult("fake_readback_test", corrupt(.fake_readback_observed)); printBlockers(); } pub fn printActiveStage2TestCommand() void { printResult("active_stage2_test", corrupt(.active_stage2_forbidden)); printBlockers(); } pub fn printGuestEnteredTestCommand() void { printResult("guest_entered_test", corrupt(.guest_entered_forbidden)); printBlockers(); } pub fn printFirstInstructionTestCommand() void { printResult("first_instruction_test", corrupt(.first_instruction_forbidden)); printBlockers(); } pub fn printInvariantConsumptionCommand() void { uart.write("hv: hgatp_csr_result.invariant_consumption_result="); uart.write(if(invariantConsumption()) "ok" else "rejected"); uart.write("\r\n"); } pub fn printInvariantCorruptionCommand() void { uart.write("hv: hgatp_csr_result.invariant_corruption_result="); uart.write(if(invariantCorruption()) "ok" else "rejected"); uart.write("\r\n"); }

pub fn currentObservation() HgatpCsrResultObservation {
    const r = object();
    return .{
        .code = r.result_code,
        .reason = r.result_reason,
        .checksum = observationChecksum(r.result_code, r.result_reason),
    };
}

pub fn currentTrapSlot() HgatpCsrResultTrapSlot {
    const r = object();
    return .{
        .present = r.fault_slot_present,
        .observed = r.fault_observed,
        .scause = r.fault_scause,
        .stval = r.fault_stval,
        .sepc = r.fault_sepc,
        .checksum = slotChecksum(r.fault_slot_present, r.fault_observed, r.fault_scause, r.fault_stval, r.fault_sepc),
    };
}

pub fn currentReadbackSlot() HgatpCsrResultReadbackSlot {
    const r = object();
    return .{
        .present = r.readback_slot_present,
        .attempted = r.readback_attempted,
        .value = r.readback_value,
        .valid = r.readback_valid,
        .checksum = slotChecksum(r.readback_slot_present, r.readback_attempted, r.readback_value, bint(r.readback_valid), 0),
    };
}

fn observationChecksum(code: HgatpCsrResultCode, reason: HgatpCsrResultBlocker) usize {
    var x: usize = 0x3202;
    x = mix(x, tag(code));
    x = mix(x, tag(reason));
    return if (x == 0) 1 else x;
}

pub fn noWriteInvariantHeld() bool {
    const r = object();
    return !r.csr_write_function_called and
        !r.raw_asm_called and
        !r.raw_asm_returned and
        !r.hgatp_write_attempted and
        !r.hgatp_write_performed;
}

pub fn noFaultOrReadbackInvariantHeld() bool {
    const r = object();
    return r.fault_slot_present and
        !r.fault_observed and
        r.fault_scause == 0 and
        r.fault_stval == 0 and
        r.fault_sepc == 0 and
        r.readback_slot_present and
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
    const s = hgatp_csr_interface.object();
    return r.csr_interface_checksum == s.checksum and
        r.csr_interface_request_checksum == s.request_checksum and
        r.csr_interface_request_value == s.request_value and
        r.csr_interface_decision == tag(s.decision);
}

pub fn currentBlockerCount() usize {
    return object().blocker_count;
}

pub fn currentChecksum() usize {
    return object().checksum;
}

pub fn currentDecision() HgatpCsrResultDecision {
    return object().decision;
}

pub fn currentNextAction() HgatpCsrResultNextAction {
    return object().next_action;
}

pub fn currentResultCode() HgatpCsrResultCode {
    return object().result_code;
}

pub fn currentSourceStable() bool {
    return object().source_fingerprint_unchanged;
}
