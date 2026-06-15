const uart = @import("../console/uart.zig");
const vm = @import("vm.zig");
const vcpu = @import("vcpu.zig");
const hgatp_write_attempt = @import("hgatp_write_attempt.zig");

pub const HgatpCsrInterfaceState = enum {
    empty,
     observed,
     ready,
     rejected };
pub const HgatpCsrInterfaceBlocker = enum {
    none,
     empty_interface,
     missing_write_attempt,
     invalid_write_attempt,
     source_mutated,
     request_value_mismatch,
     csr_write_called,
     raw_asm_called,
     hgatp_write_attempted,
     hgatp_write_performed,
     active_stage2_forbidden };
pub const HgatpCsrInterfaceNextAction = enum {
    none,
     build_write_attempt_externally,
     validate_write_attempt_externally,
     investigate_source_mutation,
     inspect_request_value,
     keep_csr_denied_by_policy,
     stop_csr_call_observed,
     stop_raw_asm_observed,
     stop_hgatp_write_attempt_observed,
     stop_hgatp_write_performed_observed,
     stop_active_stage2_observed };
pub const HgatpCsrInterfaceDecision = enum {
    none,
     deny_before_csr,
     rejected };

pub const HgatpCsrInterfaceFingerprint = struct {
    write_attempt_checksum: usize,
    
    write_attempt_request_checksum: usize,
    
    write_attempt_value: usize,
    
    write_attempt_ready: bool,
    
    write_attempt_state: usize,
    
    write_attempt_denied_before_csr: bool,
    
    write_attempt_allowed_to_reach_csr: bool,
    
    write_attempt_csr_write_function_called: bool,
    
    write_attempt_hgatp_write_attempted: bool,
    
    write_attempt_hgatp_write_performed: bool,
    
    write_attempt_active_stage2: bool,
    
    vm_id: vm.VmId,
    
    vcpu_id: vcpu.VcpuId,
    
    checksum: usize,
    
};

pub const HgatpCsrInterfaceRequest = struct {
    owner_vm_id: vm.VmId,
     owner_vcpu_id: vcpu.VcpuId,
     request_value: usize,
     source_attempt_checksum: usize,
     source_attempt_request_checksum: usize,
     denied_by_policy: bool,
     allowed_by_policy: bool,
     checksum: usize };
pub const HgatpCsrInterfaceResult = struct {
    code: HgatpCsrInterfaceBlocker,
     denied_before_asm: bool,
     csr_called: bool,
     raw_called: bool,
     write_attempted: bool,
     write_performed: bool,
     checksum: usize };

pub const HgatpCsrInterface = struct {
    owner_vm_id: vm.VmId,
     owner_vcpu_id: vcpu.VcpuId,
    
    write_attempt_present: bool,
     write_attempt_valid: bool,
     write_attempt_checksum: usize,
     write_attempt_request_checksum: usize,
     write_attempt_value: usize,
     write_attempt_denied_before_csr: bool,
     write_attempt_allowed_to_reach_csr: bool,
    
    csr_interface_present: bool,
     csr_write_function_present: bool,
     csr_write_function_called: bool,
     csr_write_call_denied_by_policy: bool,
     csr_write_call_allowed_by_policy: bool,
     csr_write_call_blocked_before_asm: bool,
    
    raw_asm_present: bool,
     raw_asm_called: bool,
     raw_asm_returned: bool,
    
    hgatp_write_attempted: bool,
     hgatp_write_performed: bool,
     hgatp_readback_attempted: bool,
     hgatp_readback_value: usize,
     hgatp_readback_valid: bool,
     active_stage2: bool,
     guest_entered: bool,
     first_guest_instruction_executed: bool,
    
    source_fingerprint_before: HgatpCsrInterfaceFingerprint,
     source_fingerprint_after: HgatpCsrInterfaceFingerprint,
     source_fingerprint_unchanged: bool,
    
    request_present: bool,
     request_value: usize,
     request_checksum: usize,
     result_present: bool,
     result_code: HgatpCsrInterfaceBlocker,
     result_checksum: usize,
    
    blocker: HgatpCsrInterfaceBlocker,
     blocker_count: usize,
     next_action: HgatpCsrInterfaceNextAction,
     decision: HgatpCsrInterfaceDecision,
     checksum: usize,
     build_count: usize,
     validate_count: usize,
     reject_count: usize,
     reset_count: usize,
     state: HgatpCsrInterfaceState,
     ready: bool,
    
};

var obj: HgatpCsrInterface = undefined;
var initialized = false;
fn tag(e: anytype) usize {
    return @intFromEnum(e);
}
fn bint(v: bool) usize {
    return if (v) 1 else 0;
}
fn mix(a: usize,
     b: usize) usize {
    return (a ^ b) *% 0x9e37_79b9_7f4a_7c15;
}
fn emptyFp() HgatpCsrInterfaceFingerprint {
    return .{
    .write_attempt_checksum=0,
    
    .write_attempt_request_checksum=0,
    
    .write_attempt_value=0,
    
    .write_attempt_ready=false,
    
    .write_attempt_state=0,
    
    .write_attempt_denied_before_csr=false,
    
    .write_attempt_allowed_to_reach_csr=false,
    
    .write_attempt_csr_write_function_called=false,
    
    .write_attempt_hgatp_write_attempted=false,
    
    .write_attempt_hgatp_write_performed=false,
    
    .write_attempt_active_stage2=false,
    
    .vm_id=0,
    
    .vcpu_id=0,
    
    .checksum=0 };
}
fn empty(owner: vm.VmId,
     owner_vcpu: vcpu.VcpuId,
     resets: usize) HgatpCsrInterface {
    return .{
    .owner_vm_id=owner,
    
    .owner_vcpu_id=owner_vcpu,
    
    .write_attempt_present=false,
    
    .write_attempt_valid=false,
    
    .write_attempt_checksum=0,
    
    .write_attempt_request_checksum=0,
    
    .write_attempt_value=0,
    
    .write_attempt_denied_before_csr=false,
    
    .write_attempt_allowed_to_reach_csr=false,
    
    .csr_interface_present=false,
    
    .csr_write_function_present=false,
    
    .csr_write_function_called=false,
    
    .csr_write_call_denied_by_policy=true,
    
    .csr_write_call_allowed_by_policy=false,
    
    .csr_write_call_blocked_before_asm=true,
    
    .raw_asm_present=true,
    
    .raw_asm_called=false,
    
    .raw_asm_returned=false,
    
    .hgatp_write_attempted=false,
    
    .hgatp_write_performed=false,
    
    .hgatp_readback_attempted=false,
    
    .hgatp_readback_value=0,
    
    .hgatp_readback_valid=false,
    
    .active_stage2=false,
    
    .guest_entered=false,
    
    .first_guest_instruction_executed=false,
    
    .source_fingerprint_before=emptyFp(),
    
    .source_fingerprint_after=emptyFp(),
    
    .source_fingerprint_unchanged=false,
    
    .request_present=false,
    
    .request_value=0,
    
    .request_checksum=0,
    
    .result_present=false,
    
    .result_code=.none,
    
    .result_checksum=0,
    
    .blocker=.none,
    
    .blocker_count=0,
    
    .next_action=.none,
    
    .decision=.none,
    
    .checksum=0,
    
    .build_count=0,
    
    .validate_count=0,
    
    .reject_count=0,
    
    .reset_count=resets,
    
    .state=.empty,
    
    .ready=false };
}
pub fn init(owner: vm.VmId,
     owner_vcpu: vcpu.VcpuId) void {
    obj = empty(owner,
     owner_vcpu,
     0);
initialized = true;
}
fn mutable() *HgatpCsrInterface {
    if (!initialized) init(vm.object().id,
     vcpu.object().id);
return &obj;
}
pub fn object() *const HgatpCsrInterface {
    return mutable();
}
pub fn reset() void {
    const r = mutable().reset_count + 1;
obj = empty(vm.object().id,
     vcpu.object().id,
     r);
initialized = true;
}
fn fpChecksum(f: HgatpCsrInterfaceFingerprint) usize {
    var x: usize = 0x3131;
x=mix(x,
    f.write_attempt_checksum);
x=mix(x,
    f.write_attempt_request_checksum);
x=mix(x,
    f.write_attempt_value);
x=mix(x,
    bint(f.write_attempt_ready));
x=mix(x,
    f.write_attempt_state);
x=mix(x,
    bint(f.write_attempt_denied_before_csr));
x=mix(x,
    bint(f.write_attempt_allowed_to_reach_csr));
x=mix(x,
    bint(f.write_attempt_csr_write_function_called));
x=mix(x,
    bint(f.write_attempt_hgatp_write_attempted));
x=mix(x,
    bint(f.write_attempt_hgatp_write_performed));
x=mix(x,
    bint(f.write_attempt_active_stage2));
x=mix(x,
    @intCast(f.vm_id));
x=mix(x,
    @intCast(f.vcpu_id));
return if (x==0) 1 else x;
}
pub fn readSourceFingerprint() HgatpCsrInterfaceFingerprint {
    const a = hgatp_write_attempt.object();
var f = HgatpCsrInterfaceFingerprint{
    .write_attempt_checksum=a.checksum,
    
    .write_attempt_request_checksum=a.attempt_request_checksum,
    
    .write_attempt_value=a.planned_hgatp_value,
    
    .write_attempt_ready=a.ready,
    
    .write_attempt_state=tag(a.state),
    
    .write_attempt_denied_before_csr=a.attempt_denied_before_csr,
    
    .write_attempt_allowed_to_reach_csr=a.attempt_allowed_to_reach_csr,
    
    .write_attempt_csr_write_function_called=a.csr_write_function_called,
    
    .write_attempt_hgatp_write_attempted=a.hgatp_write_attempted,
    
    .write_attempt_hgatp_write_performed=a.hgatp_write_performed,
    
    .write_attempt_active_stage2=a.active_stage2,
    
    .vm_id=vm.object().id,
    
    .vcpu_id=vcpu.object().id,
    
    .checksum=0 };
f.checksum = fpChecksum(f);
return f;
}
fn sameFp(a: HgatpCsrInterfaceFingerprint,
     b: HgatpCsrInterfaceFingerprint) bool {
    return a.checksum==b.checksum and a.write_attempt_checksum==b.write_attempt_checksum and a.write_attempt_request_checksum==b.write_attempt_request_checksum and a.write_attempt_value==b.write_attempt_value and a.write_attempt_ready==b.write_attempt_ready and a.write_attempt_state==b.write_attempt_state and a.write_attempt_denied_before_csr==b.write_attempt_denied_before_csr and a.write_attempt_allowed_to_reach_csr==b.write_attempt_allowed_to_reach_csr and a.write_attempt_csr_write_function_called==b.write_attempt_csr_write_function_called and a.write_attempt_hgatp_write_attempted==b.write_attempt_hgatp_write_attempted and a.write_attempt_hgatp_write_performed==b.write_attempt_hgatp_write_performed and a.write_attempt_active_stage2==b.write_attempt_active_stage2 and a.vm_id==b.vm_id and a.vcpu_id==b.vcpu_id;
}
fn requestChecksum(r: HgatpCsrInterfaceRequest) usize {
    var x: usize=0x31;
x=mix(x,
    @intCast(r.owner_vm_id));
x=mix(x,
    @intCast(r.owner_vcpu_id));
x=mix(x,
    r.request_value);
x=mix(x,
    r.source_attempt_checksum);
x=mix(x,
    r.source_attempt_request_checksum);
x=mix(x,
    bint(r.denied_by_policy));
x=mix(x,
    bint(r.allowed_by_policy));
return if (x==0) 1 else x;
}
fn resultChecksum(r: HgatpCsrInterfaceResult) usize {
    var x: usize=0x3132;
x=mix(x,
    tag(r.code));
x=mix(x,
    bint(r.denied_before_asm));
x=mix(x,
    bint(r.csr_called));
x=mix(x,
    bint(r.raw_called));
x=mix(x,
    bint(r.write_attempted));
x=mix(x,
    bint(r.write_performed));
return if (x==0) 1 else x;
}
fn interfaceChecksum(r: HgatpCsrInterface) usize {
    var x: usize=0x313131;
x=mix(x,
    r.source_fingerprint_before.checksum);
x=mix(x,
    r.source_fingerprint_after.checksum);
x=mix(x,
    r.write_attempt_checksum);
x=mix(x,
    r.write_attempt_request_checksum);
x=mix(x,
    r.request_value);
x=mix(x,
    r.request_checksum);
x=mix(x,
    r.result_checksum);
x=mix(x,
    tag(r.blocker));
x=mix(x,
    tag(r.next_action));
return if (x==0) 1 else x;
}
pub fn unsafeHgatpWriteNotCalled(value: usize) void {
    asm volatile ("csrw 0x680, %[v]" :: [v] "r" (value));
}
fn firstBlocker(r: HgatpCsrInterface) HgatpCsrInterfaceBlocker {
    if (r.state == .empty) return .empty_interface;
if (!r.write_attempt_present) return .missing_write_attempt;
if (!r.write_attempt_valid) return .invalid_write_attempt;
if (!r.source_fingerprint_unchanged) return .source_mutated;
if (r.request_value != r.write_attempt_value) return .request_value_mismatch;
if (r.csr_write_function_called) return .csr_write_called;
if (r.raw_asm_called or r.raw_asm_returned) return .raw_asm_called;
if (r.hgatp_write_attempted) return .hgatp_write_attempted;
if (r.hgatp_write_performed) return .hgatp_write_performed;
if (r.active_stage2 or r.guest_entered or r.first_guest_instruction_executed) return .active_stage2_forbidden;
return .none;
}
fn actionFor(b: HgatpCsrInterfaceBlocker) HgatpCsrInterfaceNextAction {
    return switch (b) {
    .none=>.keep_csr_denied_by_policy,
    
    .empty_interface=>.none,
    
    .missing_write_attempt=>.build_write_attempt_externally,
    
    .invalid_write_attempt=>.validate_write_attempt_externally,
    
    .source_mutated=>.investigate_source_mutation,
    
    .request_value_mismatch=>.inspect_request_value,
    
    .csr_write_called=>.stop_csr_call_observed,
    
    .raw_asm_called=>.stop_raw_asm_observed,
    
    .hgatp_write_attempted=>.stop_hgatp_write_attempt_observed,
    
    .hgatp_write_performed=>.stop_hgatp_write_performed_observed,
    
    .active_stage2_forbidden=>.stop_active_stage2_observed };
}
fn finish(r: *HgatpCsrInterface) HgatpCsrInterfaceBlocker {
    const b = firstBlocker(r.*);
r.blocker=b;
r.blocker_count=if (b==.none) 0 else 1;
r.next_action=actionFor(b);
r.ready=b==.none;
r.state=if (r.ready) .ready else .rejected;
r.decision=if (r.ready) .deny_before_csr else .rejected;
if (!r.ready) r.reject_count += 1;
var res = HgatpCsrInterfaceResult{
    .code=b,
    
    .denied_before_asm=r.csr_write_call_blocked_before_asm,
    
    .csr_called=r.csr_write_function_called,
    
    .raw_called=r.raw_asm_called,
    
    .write_attempted=r.hgatp_write_attempted,
    
    .write_performed=r.hgatp_write_performed,
    
    .checksum=0 };
res.checksum=resultChecksum(res);
r.result_present=true;
r.result_code=b;
r.result_checksum=res.checksum;
r.checksum=interfaceChecksum(r.*);
return b;
}
pub fn build() HgatpCsrInterfaceBlocker {
    const r=mutable();
r.build_count += 1;
r.owner_vm_id=vm.object().id;
r.owner_vcpu_id=vcpu.object().id;
r.source_fingerprint_before=readSourceFingerprint();
const a=hgatp_write_attempt.object();
r.write_attempt_present=a.state != .empty and a.checksum != 0;
r.write_attempt_valid=a.state == .ready and a.ready;
r.write_attempt_checksum=a.checksum;
r.write_attempt_request_checksum=a.attempt_request_checksum;
r.write_attempt_value=a.planned_hgatp_value;
r.write_attempt_denied_before_csr=a.attempt_denied_before_csr;
r.write_attempt_allowed_to_reach_csr=a.attempt_allowed_to_reach_csr;
r.csr_interface_present=true;
r.csr_write_function_present=true;
r.csr_write_function_called=false;
r.csr_write_call_denied_by_policy=true;
r.csr_write_call_allowed_by_policy=false;
r.csr_write_call_blocked_before_asm=true;
r.raw_asm_present=true;
r.raw_asm_called=false;
r.raw_asm_returned=false;
r.hgatp_write_attempted=false;
r.hgatp_write_performed=false;
r.hgatp_readback_attempted=false;
r.hgatp_readback_value=0;
r.hgatp_readback_valid=false;
r.active_stage2=false;
r.guest_entered=false;
r.first_guest_instruction_executed=false;
var req=HgatpCsrInterfaceRequest{
    .owner_vm_id=r.owner_vm_id,
    
    .owner_vcpu_id=r.owner_vcpu_id,
    
    .request_value=a.planned_hgatp_value,
    
    .source_attempt_checksum=a.checksum,
    
    .source_attempt_request_checksum=a.attempt_request_checksum,
    
    .denied_by_policy=true,
    
    .allowed_by_policy=false,
    
    .checksum=0 };
req.checksum=requestChecksum(req);
r.request_present=r.write_attempt_present and a.attempt_request_present and a.attempt_denied_before_csr and !a.attempt_allowed_to_reach_csr;
r.request_value=req.request_value;
r.request_checksum=req.checksum;
r.state=.observed;
r.source_fingerprint_after=readSourceFingerprint();
r.source_fingerprint_unchanged=sameFp(r.source_fingerprint_before,
    r.source_fingerprint_after);
return finish(r);
}
pub fn validate() HgatpCsrInterfaceBlocker {
    const r=mutable();
r.validate_count += 1;
return finish(r);
}
fn corrupt(kind: HgatpCsrInterfaceBlocker) HgatpCsrInterfaceBlocker {
    _=build();
const r=mutable();
switch(kind){
    .missing_write_attempt=>r.write_attempt_present=false,
    
    .invalid_write_attempt=>r.write_attempt_valid=false,
    
    .source_mutated=>r.source_fingerprint_unchanged=false,
    
    .request_value_mismatch=>r.request_value +%= 1,
    
    .csr_write_called=>r.csr_write_function_called = true,
    
    .raw_asm_called=>r.raw_asm_called = true,
    
    .hgatp_write_attempted=>r.hgatp_write_attempted=true,
    
    .hgatp_write_performed=>r.hgatp_write_performed = true,
    
    .active_stage2_forbidden=>r.active_stage2 = true,
    else=>{} }
return validate();
}
pub fn invariantConsumption() bool {
    reset();
_=build();
const a=hgatp_write_attempt.object();
return object().write_attempt_checksum==a.checksum and object().write_attempt_request_checksum==a.attempt_request_checksum and object().request_value==a.planned_hgatp_value and object().source_fingerprint_before.write_attempt_ready==a.ready;
}
pub fn invariantCorruption() bool {
    return corrupt(.missing_write_attempt)==.missing_write_attempt and corrupt(.source_mutated)==.source_mutated and corrupt(.request_value_mismatch)==.request_value_mismatch and corrupt(.raw_asm_called)==.raw_asm_called;
}
fn blockerName(b: HgatpCsrInterfaceBlocker) []const u8 {
    return switch(b){
    .none=>"none",
    
    .empty_interface=>"empty-interface",
    
    .missing_write_attempt=>"missing-write-attempt",
    
    .invalid_write_attempt=>"invalid-write-attempt",
    
    .source_mutated=>"source-mutated",
    
    .request_value_mismatch=>"request-value-mismatch",
    
    .csr_write_called=>"csr-write-called",
    
    .raw_asm_called=>"raw-asm-called",
    
    .hgatp_write_attempted=>"hgatp-write-attempted",
    
    .hgatp_write_performed=>"hgatp-write-performed",
    
    .active_stage2_forbidden=>"active-stage2-forbidden" };
}
fn actionName(a: HgatpCsrInterfaceNextAction) []const u8 {
    return switch(a){
    .none=>"none",
    
    .build_write_attempt_externally=>"build-write-attempt-externally",
    
    .validate_write_attempt_externally=>"validate-write-attempt-externally",
    
    .investigate_source_mutation=>"investigate-source-mutation",
    
    .inspect_request_value=>"inspect-request-value",
    
    .keep_csr_denied_by_policy=>"keep-csr-denied-by-policy",
    
    .stop_csr_call_observed=>"stop-csr-call-observed",
    
    .stop_raw_asm_observed=>"stop-raw-asm-observed",
    
    .stop_hgatp_write_attempt_observed=>"stop-hgatp-write-attempt-observed",
    
    .stop_hgatp_write_performed_observed=>"stop-hgatp-write-performed-observed",
    
    .stop_active_stage2_observed=>"stop-active-stage2-observed" };
}
fn printBool(v: bool) void {
    uart.write(if(v) "true" else "false");
}
fn printResult(name: []const u8,
    b: HgatpCsrInterfaceBlocker) void {
    uart.write("hv: hgatp_csr_interface.");
uart.write(name);
uart.write("=");
uart.write(if(b==.none) "ok" else "rejected");
uart.write("\r\nhv: hgatp_csr_interface.result_blocker=");
uart.write(blockerName(b));
uart.write("\r\n");
}
fn printBlockers() void {
    const r=object();
uart.write("hv: hgatp_csr_interface.blocker_count=");
uart.writeDec(r.blocker_count);
uart.write("\r\nhv: hgatp_csr_interface.blocker=");
uart.write(blockerName(r.blocker));
uart.write("\r\n");
}
fn printSummary() void {
    const r=object();
uart.write("hv: hgatp_csr_interface=guarded-hgatp-csr-interface\r\nhv: hgatp_csr_interface.state=");
uart.write(@tagName(r.state));
uart.write("\r\nhv: hgatp_csr_interface.ready=");
printBool(r.ready);
uart.write("\r\nhv: hgatp_csr_interface.build_count=");
uart.writeDec(r.build_count);
uart.write("\r\nhv: hgatp_csr_interface.validate_count=");
uart.writeDec(r.validate_count);
uart.write("\r\nhv: hgatp_csr_interface.reject_count=");
uart.writeDec(r.reject_count);
uart.write("\r\nhv: hgatp_csr_interface.reset_count=");
uart.writeDec(r.reset_count);
uart.write("\r\n");
printBlockers();
}
fn printFields() void {
    const r=object();
uart.write("hv: hgatp_csr_interface.owner_vm_id=");
uart.writeDec(r.owner_vm_id);
uart.write("\r\nhv: hgatp_csr_interface.owner_vcpu_id=");
uart.writeDec(r.owner_vcpu_id);
uart.write("\r\nhv: hgatp_csr_interface.write_attempt_present=");
printBool(r.write_attempt_present);
uart.write("\r\nhv: hgatp_csr_interface.write_attempt_valid=");
printBool(r.write_attempt_valid);
uart.write("\r\nhv: hgatp_csr_interface.write_attempt_checksum=");
uart.writeHex(r.write_attempt_checksum);
uart.write("\r\nhv: hgatp_csr_interface.write_attempt_request_checksum=");
uart.writeHex(r.write_attempt_request_checksum);
uart.write("\r\nhv: hgatp_csr_interface.write_attempt_value=");
uart.writeHex(r.write_attempt_value);
uart.write("\r\nhv: hgatp_csr_interface.write_attempt_denied_before_csr=");
printBool(r.write_attempt_denied_before_csr);
uart.write("\r\nhv: hgatp_csr_interface.write_attempt_allowed_to_reach_csr=");
printBool(r.write_attempt_allowed_to_reach_csr);
uart.write("\r\nhv: hgatp_csr_interface.csr_interface_present=");
printBool(r.csr_interface_present);
uart.write("\r\nhv: hgatp_csr_interface.csr_write_function_present=");
printBool(r.csr_write_function_present);
uart.write("\r\nhv: hgatp_csr_interface.csr_write_function_called=");
printBool(r.csr_write_function_called);
uart.write("\r\nhv: hgatp_csr_interface.csr_write_call_denied_by_policy=");
printBool(r.csr_write_call_denied_by_policy);
uart.write("\r\nhv: hgatp_csr_interface.csr_write_call_allowed_by_policy=");
printBool(r.csr_write_call_allowed_by_policy);
uart.write("\r\nhv: hgatp_csr_interface.csr_write_call_blocked_before_asm=");
printBool(r.csr_write_call_blocked_before_asm);
uart.write("\r\nhv: hgatp_csr_interface.raw_asm_present=");
printBool(r.raw_asm_present);
uart.write("\r\nhv: hgatp_csr_interface.raw_asm_called=");
printBool(r.raw_asm_called);
uart.write("\r\nhv: hgatp_csr_interface.raw_asm_returned=");
printBool(r.raw_asm_returned);
uart.write("\r\nhv: hgatp_csr_interface.hgatp_write_attempted=");
printBool(r.hgatp_write_attempted);
uart.write("\r\nhv: hgatp_csr_interface.hgatp_write_performed=");
printBool(r.hgatp_write_performed);
uart.write("\r\nhv: hgatp_csr_interface.hgatp_readback_attempted=");
printBool(r.hgatp_readback_attempted);
uart.write("\r\nhv: hgatp_csr_interface.hgatp_readback_value=");
uart.writeHex(r.hgatp_readback_value);
uart.write("\r\nhv: hgatp_csr_interface.hgatp_readback_valid=");
printBool(r.hgatp_readback_valid);
uart.write("\r\nhv: hgatp_csr_interface.active_stage2=");
printBool(r.active_stage2);
uart.write("\r\nhv: hgatp_csr_interface.guest_entered=");
printBool(r.guest_entered);
uart.write("\r\nhv: hgatp_csr_interface.first_guest_instruction_executed=");
printBool(r.first_guest_instruction_executed);
uart.write("\r\nhv: hgatp_csr_interface.source_fingerprint_before=");
uart.writeHex(r.source_fingerprint_before.checksum);
uart.write("\r\nhv: hgatp_csr_interface.source_fingerprint_after=");
uart.writeHex(r.source_fingerprint_after.checksum);
uart.write("\r\nhv: hgatp_csr_interface.source_fingerprint_unchanged=");
printBool(r.source_fingerprint_unchanged);
uart.write("\r\n");
}
fn printRequest() void {
    const r=object();
uart.write("hv: hgatp_csr_interface.request_present=");
printBool(r.request_present);
uart.write("\r\nhv: hgatp_csr_interface.request_value=");
uart.writeHex(r.request_value);
uart.write("\r\nhv: hgatp_csr_interface.request_checksum=");
uart.writeHex(r.request_checksum);
uart.write("\r\n");
}
fn printResultFields() void {
    const r=object();
uart.write("hv: hgatp_csr_interface.result_present=");
printBool(r.result_present);
uart.write("\r\nhv: hgatp_csr_interface.result_code=");
uart.write(blockerName(r.result_code));
uart.write("\r\nhv: hgatp_csr_interface.result_checksum=");
uart.writeHex(r.result_checksum);
uart.write("\r\n");
}
pub fn printStatusCommand() void {
    printSummary();
printFields();
printRequest();
printResultFields();
}
pub fn printBuildCommand() void {
    printResult("build_result",
     build());
printSummary();
printFields();
printRequest();
printResultFields();
}
pub fn printValidateCommand() void {
    printResult("validate_result",
     validate());
printSummary();
printFields();
printRequest();
printResultFields();
}
pub fn printBlockersCommand() void {
    _=validate();
printBlockers();
}
pub fn printNextCommand() void {
    uart.write("hv: hgatp_csr_interface.next_action=");
uart.write(actionName(object().next_action));
uart.write("\r\n");
}
pub fn printChecksumCommand() void {
    uart.write("hv: hgatp_csr_interface.checksum=");
uart.writeHex(object().checksum);
uart.write("\r\n");
}
pub fn printResetCommand() void {
    reset();
uart.write("hv: hgatp_csr_interface.reset_result=ok\r\n");
printSummary();
}
pub fn printFieldsCommand() void {
    printFields();
}
pub fn printRequestCommand() void {
    printRequest();
}
pub fn printResultCommand() void {
    printResultFields();
}
pub fn printDecisionCommand() void {
    uart.write("hv: hgatp_csr_interface.decision=");
uart.write(@tagName(object().decision));
uart.write("\r\n");
}
pub fn printRequireAttemptTestCommand() void {
    printResult("require_attempt_test",
     corrupt(.missing_write_attempt));
printBlockers();
}
pub fn printInvalidAttemptTestCommand() void {
    printResult("invalid_attempt_test",
     corrupt(.invalid_write_attempt));
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
pub fn printCsrCalledTestCommand() void {
    printResult("csr_called_test",
     corrupt(.csr_write_called));
printBlockers();
}
pub fn printRawAsmCalledTestCommand() void {
    printResult("raw_asm_called_test",
     corrupt(.raw_asm_called));
printBlockers();
}
pub fn printWriteAttemptedTestCommand() void {
    printResult("write_attempted_test",
     corrupt(.hgatp_write_attempted));
printBlockers();
}
pub fn printWritePerformedTestCommand() void {
    printResult("write_performed_test",
     corrupt(.hgatp_write_performed));
printBlockers();
}
pub fn printActiveStage2TestCommand() void {
    printResult("active_stage2_test",
     corrupt(.active_stage2_forbidden));
printBlockers();
}
pub fn printInvariantConsumptionCommand() void {
    uart.write("hv: hgatp_csr_interface.invariant_consumption_result=");
uart.write(if(invariantConsumption()) "ok" else "rejected");
uart.write("\r\n");
}
pub fn printInvariantCorruptionCommand() void {
    uart.write("hv: hgatp_csr_interface.invariant_corruption_result=");
uart.write(if(invariantCorruption()) "ok" else "rejected");
uart.write("\r\n");
}
