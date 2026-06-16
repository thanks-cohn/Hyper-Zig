const uart = @import("../console/uart.zig");
const vm = @import("vm.zig");
const vcpu = @import("vcpu.zig");
const executor = @import("hgatp_hardware_executor.zig");

pub const HgatpTrapCapturePrepState = enum {
empty,
built,
prepared,
rejected
};
pub const HgatpTrapCapturePrepBlocker = enum {
none,
missing_executor,
invalid_executor,
source_mutated,
fake_trap_observed,
fake_fault_observed,
csr_write_called,
raw_write_called,
readback_attempted,
readback_valid,
hgatp_write_attempted,
hgatp_write_performed,
active_stage2_forbidden,
guest_entered_forbidden,
first_instruction_forbidden
};
pub const HgatpTrapCapturePrepNextAction = enum {
none,
build_executor_externally,
execute_executor_externally,
investigate_source_mutation,
clear_trap_slot,
clear_fault_slot,
keep_csr_write_uncalled,
keep_raw_write_uncalled,
keep_readback_disabled,
stop_hgatp_write_attempt,
stop_hgatp_write_performed,
stop_stage2_activation,
stop_guest_entry,
stop_first_instruction,
ready_for_hv38_guarded_csr_path
};
pub const HgatpTrapCapturePrepDecision = enum {
none,
safe_denied_before_csr,
rejected
};
pub const HgatpTrapCapturePrepResultCode = enum {
none,
trap_capture_prep_ready,
missing_executor,
invalid_executor,
source_mutated,
fake_trap_observed,
fake_fault_observed,
csr_write_called,
raw_write_called,
readback_attempted,
readback_valid,
hgatp_write_attempted,
hgatp_write_performed,
active_stage2_forbidden,
guest_entered_forbidden,
first_instruction_forbidden
};

pub const HgatpTrapCapturePrepFingerprint = struct {
    executor_checksum: usize,
executor_state: usize,
executor_decision: usize,
executor_result_code: usize,
    executor_request_value: usize,
executor_request_checksum: usize,
executor_entered: bool,
executor_returned: bool,
    executor_step_count: usize,
csr_write_function_called: bool,
raw_write_function_called: bool,
trap_observed: bool,
    readback_attempted: bool,
readback_valid: bool,
hgatp_write_attempted: bool,
hgatp_write_performed: bool,
    active_stage2: bool,
guest_entered: bool,
first_guest_instruction_executed: bool,
vm_id: vm.VmId,
vcpu_id: vcpu.VcpuId,
checksum: usize,
};

pub const TrapSlot = struct {
present: bool,
capture_armed: bool,
observed: bool,
scause: usize,
stval: usize,
sepc: usize
};
pub const FaultSlot = struct {
present: bool,
capture_armed: bool,
observed: bool,
scause: usize,
stval: usize,
sepc: usize
};

pub const HgatpTrapCapturePrep = struct {
    owner_vm_id: vm.VmId,
owner_vcpu_id: vcpu.VcpuId,
    executor_present: bool,
executor_valid: bool,
executor_checksum: usize,
executor_state: usize,
executor_decision: usize,
    executor_result_code: usize,
executor_request_value: usize,
executor_request_checksum: usize,
    executor_entered: bool,
executor_returned: bool,
executor_step_count: usize,
    capture_request_present: bool,
capture_request_value: usize,
capture_request_checksum: usize,
    build_entered: bool,
build_returned: bool,
build_count: usize,
    prepare_entered: bool,
prepare_returned: bool,
prepare_count: usize,
prepare_step_count: usize,
    step_source_loaded: bool,
step_executor_checked: bool,
step_trap_slot_prepared: bool,
step_fault_slot_prepared: bool,
    step_csr_guard_checked: bool,
step_raw_guard_checked: bool,
step_no_trap_observed: bool,
step_no_fault_observed: bool,
    step_result_recorded: bool,
step_safe_return_recorded: bool,
    csr_write_function_called: bool,
raw_write_function_called: bool,
    trap_slot_present: bool,
trap_capture_armed: bool,
trap_observed: bool,
trap_scause: usize,
trap_stval: usize,
trap_sepc: usize,
    fault_slot_present: bool,
fault_capture_armed: bool,
fault_observed: bool,
fault_scause: usize,
fault_stval: usize,
fault_sepc: usize,
    readback_attempted: bool,
readback_valid: bool,
hgatp_write_attempted: bool,
hgatp_write_performed: bool,
    active_stage2: bool,
guest_entered: bool,
first_guest_instruction_executed: bool,
    safe_denied_before_csr: bool,
source_fingerprint_before_build: HgatpTrapCapturePrepFingerprint,
source_fingerprint_after_build: HgatpTrapCapturePrepFingerprint,
    source_fingerprint_before_prepare: HgatpTrapCapturePrepFingerprint,
source_fingerprint_after_prepare: HgatpTrapCapturePrepFingerprint,
    source_fingerprint_unchanged: bool,
result_present: bool,
result_code: HgatpTrapCapturePrepResultCode,
result_checksum: usize,
    blocker: HgatpTrapCapturePrepBlocker,
blocker_count: usize,
next_action: HgatpTrapCapturePrepNextAction,
decision: HgatpTrapCapturePrepDecision,
    checksum: usize,
validate_count: usize,
reject_count: usize,
reset_count: usize,
state: HgatpTrapCapturePrepState,
};

var obj: HgatpTrapCapturePrep = undefined;
var initialized = false;
fn tag(e: anytype) usize {
return @intFromEnum(e);
}
fn b(v: bool) usize {
return if (v) 1 else 0;
}
fn mix(a: usize,
c: usize) usize {
return (a ^ c) *% 0x9e37_79b9_7f4a_7c15;
}
fn emptyFp() HgatpTrapCapturePrepFingerprint {
return .{
.executor_checksum=0,.executor_state=0,.executor_decision=0,.executor_result_code=0,.executor_request_value=0,.executor_request_checksum=0,.executor_entered=false,.executor_returned=false,.executor_step_count=0,.csr_write_function_called=false,.raw_write_function_called=false,.trap_observed=false,.readback_attempted=false,.readback_valid=false,.hgatp_write_attempted=false,.hgatp_write_performed=false,.active_stage2=false,.guest_entered=false,.first_guest_instruction_executed=false,.vm_id=0,.vcpu_id=0,.checksum=0
};
}
fn empty(owner: vm.VmId,
vc: vcpu.VcpuId,
resets: usize) HgatpTrapCapturePrep {
return .{
.owner_vm_id=owner,.owner_vcpu_id=vc,.executor_present=false,.executor_valid=false,.executor_checksum=0,.executor_state=0,.executor_decision=0,.executor_result_code=0,.executor_request_value=0,.executor_request_checksum=0,.executor_entered=false,.executor_returned=false,.executor_step_count=0,.capture_request_present=false,.capture_request_value=0,.capture_request_checksum=0,.build_entered=false,.build_returned=false,.build_count=0,.prepare_entered=false,.prepare_returned=false,.prepare_count=0,.prepare_step_count=0,.step_source_loaded=false,.step_executor_checked=false,.step_trap_slot_prepared=false,.step_fault_slot_prepared=false,.step_csr_guard_checked=false,.step_raw_guard_checked=false,.step_no_trap_observed=false,.step_no_fault_observed=false,.step_result_recorded=false,.step_safe_return_recorded=false,.csr_write_function_called=false,.raw_write_function_called=false,.trap_slot_present=false,.trap_capture_armed=false,.trap_observed=false,.trap_scause=0,.trap_stval=0,.trap_sepc=0,.fault_slot_present=false,.fault_capture_armed=false,.fault_observed=false,.fault_scause=0,.fault_stval=0,.fault_sepc=0,.readback_attempted=false,.readback_valid=false,.hgatp_write_attempted=false,.hgatp_write_performed=false,.active_stage2=false,.guest_entered=false,.first_guest_instruction_executed=false,.safe_denied_before_csr=false,.source_fingerprint_before_build=emptyFp(),.source_fingerprint_after_build=emptyFp(),.source_fingerprint_before_prepare=emptyFp(),.source_fingerprint_after_prepare=emptyFp(),.source_fingerprint_unchanged=false,.result_present=false,.result_code=.none,.result_checksum=0,.blocker=.none,.blocker_count=0,.next_action=.none,.decision=.none,.checksum=0,.validate_count=0,.reject_count=0,.reset_count=resets,.state=.empty
};
}
pub fn init(owner: vm.VmId,
vc: vcpu.VcpuId) void {
obj = empty(owner,
vc,
0);
initialized = true;
}
fn mutable() *HgatpTrapCapturePrep {
if (!initialized) init(vm.object().id,
vcpu.object().id);
return &obj;
}
pub fn object() *const HgatpTrapCapturePrep {
return mutable();
}
pub fn reset() void {
const r = mutable().reset_count + 1;
obj = empty(vm.object().id,
vcpu.object().id,
r);
initialized = true;
}
fn fpChecksum(f: HgatpTrapCapturePrepFingerprint) usize {
var x:usize=0x3737;
x=mix(x,f.executor_checksum);
x=mix(x,f.executor_state);
x=mix(x,f.executor_decision);
x=mix(x,f.executor_result_code);
x=mix(x,f.executor_request_value);
x=mix(x,f.executor_request_checksum);
x=mix(x,b(f.executor_entered));
x=mix(x,b(f.executor_returned));
x=mix(x,f.executor_step_count);
x=mix(x,b(f.csr_write_function_called));
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
pub fn readSourceFingerprint() HgatpTrapCapturePrepFingerprint {
const s=executor.object();
var f=HgatpTrapCapturePrepFingerprint{
.executor_checksum=s.checksum,.executor_state=tag(s.state),.executor_decision=tag(s.decision),.executor_result_code=tag(s.result_code),.executor_request_value=s.hardware_request_value,.executor_request_checksum=s.hardware_request_checksum,.executor_entered=s.executor_entered,.executor_returned=s.executor_returned,.executor_step_count=s.executor_step_count,.csr_write_function_called=s.csr_write_function_called,.raw_write_function_called=s.raw_write_function_called,.trap_observed=s.trap_observed,.readback_attempted=s.readback_attempted,.readback_valid=s.readback_valid,.hgatp_write_attempted=s.hgatp_write_attempted,.hgatp_write_performed=s.hgatp_write_performed,.active_stage2=s.active_stage2,.guest_entered=s.guest_entered,.first_guest_instruction_executed=s.first_guest_instruction_executed,.vm_id=vm.object().id,.vcpu_id=vcpu.object().id,.checksum=0
};
f.checksum=fpChecksum(f);
return f;
}
fn sameFp(a:HgatpTrapCapturePrepFingerprint,c:HgatpTrapCapturePrepFingerprint) bool {
return a.checksum==c.checksum and a.executor_checksum==c.executor_checksum and a.executor_request_value==c.executor_request_value and a.executor_request_checksum==c.executor_request_checksum and a.executor_entered==c.executor_entered and a.executor_returned==c.executor_returned and a.vm_id==c.vm_id and a.vcpu_id==c.vcpu_id;
}
fn sourcePresent() bool {
const s=executor.object();
return s.state != .empty and s.checksum != 0;
}
fn sourceValid() bool {
const s=executor.object();
return s.state == .executed and s.result_present and s.result_code == .hardware_executor_denied_before_csr and s.executor_entered and s.executor_returned and s.hardware_request_present;
}
fn loadSource(r:*HgatpTrapCapturePrep) void {
const s=executor.object();
r.executor_present=sourcePresent();
r.executor_valid=sourceValid();
r.executor_checksum=s.checksum;
r.executor_state=tag(s.state);
r.executor_decision=tag(s.decision);
r.executor_result_code=tag(s.result_code);
r.executor_request_value=s.hardware_request_value;
r.executor_request_checksum=s.hardware_request_checksum;
r.executor_entered=s.executor_entered;
r.executor_returned=s.executor_returned;
r.executor_step_count=s.executor_step_count;
r.capture_request_present=r.executor_present;
r.capture_request_value=s.hardware_request_value;
r.capture_request_checksum=s.hardware_request_checksum;
r.csr_write_function_called=s.csr_write_function_called;
r.raw_write_function_called=s.raw_write_function_called;
r.trap_observed=s.trap_observed;
r.trap_scause=s.trap_scause;
r.trap_stval=s.trap_stval;
r.trap_sepc=s.trap_sepc;
r.readback_attempted=s.readback_attempted;
r.readback_valid=s.readback_valid;
r.hgatp_write_attempted=s.hgatp_write_attempted;
r.hgatp_write_performed=s.hgatp_write_performed;
r.active_stage2=s.active_stage2;
r.guest_entered=s.guest_entered;
r.first_guest_instruction_executed=s.first_guest_instruction_executed;
}
fn resultFrom(k:HgatpTrapCapturePrepBlocker) HgatpTrapCapturePrepResultCode {
return switch(k){
.none=>.trap_capture_prep_ready,.missing_executor=>.missing_executor,.invalid_executor=>.invalid_executor,.source_mutated=>.source_mutated,.fake_trap_observed=>.fake_trap_observed,.fake_fault_observed=>.fake_fault_observed,.csr_write_called=>.csr_write_called,.raw_write_called=>.raw_write_called,.readback_attempted=>.readback_attempted,.readback_valid=>.readback_valid,.hgatp_write_attempted=>.hgatp_write_attempted,.hgatp_write_performed=>.hgatp_write_performed,.active_stage2_forbidden=>.active_stage2_forbidden,.guest_entered_forbidden=>.guest_entered_forbidden,.first_instruction_forbidden=>.first_instruction_forbidden
};
}
fn actionFrom(k:HgatpTrapCapturePrepBlocker) HgatpTrapCapturePrepNextAction {
return switch(k){
.none=>.ready_for_hv38_guarded_csr_path,.missing_executor=>.build_executor_externally,.invalid_executor=>.execute_executor_externally,.source_mutated=>.investigate_source_mutation,.fake_trap_observed=>.clear_trap_slot,.fake_fault_observed=>.clear_fault_slot,.csr_write_called=>.keep_csr_write_uncalled,.raw_write_called=>.keep_raw_write_uncalled,.readback_attempted=>.keep_readback_disabled,.readback_valid=>.keep_readback_disabled,.hgatp_write_attempted=>.stop_hgatp_write_attempt,.hgatp_write_performed=>.stop_hgatp_write_performed,.active_stage2_forbidden=>.stop_stage2_activation,.guest_entered_forbidden=>.stop_guest_entry,.first_instruction_forbidden=>.stop_first_instruction
};
}
fn first(r:HgatpTrapCapturePrep) HgatpTrapCapturePrepBlocker {
if(!r.executor_present) return .missing_executor;
if(!r.executor_valid) return .invalid_executor;
if(!r.source_fingerprint_unchanged) return .source_mutated;
if(r.trap_capture_armed or r.trap_observed or r.trap_scause!=0 or r.trap_stval!=0 or r.trap_sepc!=0) return .fake_trap_observed;
if(r.fault_capture_armed or r.fault_observed or r.fault_scause!=0 or r.fault_stval!=0 or r.fault_sepc!=0) return .fake_fault_observed;
if(r.csr_write_function_called) return .csr_write_called;
if(r.raw_write_function_called) return .raw_write_called;
if(r.readback_attempted) return .readback_attempted;
if(r.readback_valid) return .readback_valid;
if(r.hgatp_write_attempted) return .hgatp_write_attempted;
if(r.hgatp_write_performed) return .hgatp_write_performed;
if(r.active_stage2) return .active_stage2_forbidden;
if(r.guest_entered) return .guest_entered_forbidden;
if(r.first_guest_instruction_executed) return .first_instruction_forbidden;
return .none;
}
fn checksum(r:HgatpTrapCapturePrep) usize {
var x:usize=0x37;
x=mix(x,r.source_fingerprint_before_build.checksum);
x=mix(x,r.source_fingerprint_after_build.checksum);
x=mix(x,r.source_fingerprint_before_prepare.checksum);
x=mix(x,r.source_fingerprint_after_prepare.checksum);
x=mix(x,r.executor_checksum);
x=mix(x,r.capture_request_value);
x=mix(x,r.prepare_step_count);
x=mix(x,tag(r.result_code));
return if (x==0) 1 else x;
}
fn finish(r:*HgatpTrapCapturePrep) HgatpTrapCapturePrepBlocker {
const k=first(r.*);
r.blocker=k;
r.blocker_count=if(k==.none)0 else 1;
r.next_action=actionFrom(k);
r.result_present=true;
r.result_code=resultFrom(k);
r.decision=if(k==.none).safe_denied_before_csr else .rejected;
r.safe_denied_before_csr=k==.none;
r.state=if(k==.none and r.prepare_returned).prepared else if(k==.none).built else .rejected;
if(k!=.none) r.reject_count+=1;
r.checksum=checksum(r.*);
r.result_checksum=r.checksum ^ 0x3737;
return k;
}
pub fn build() HgatpTrapCapturePrepBlocker {
const r=mutable();
r.build_count+=1;
r.owner_vm_id=vm.object().id;
r.owner_vcpu_id=vcpu.object().id;
r.source_fingerprint_before_build=readSourceFingerprint();
loadSource(r);
r.build_entered=true;
r.build_returned=false;
r.prepare_entered=false;
r.prepare_returned=false;
r.prepare_count=0;
r.prepare_step_count=0;
r.step_source_loaded=false;
r.step_executor_checked=false;
r.step_trap_slot_prepared=false;
r.step_fault_slot_prepared=false;
r.step_csr_guard_checked=false;
r.step_raw_guard_checked=false;
r.step_no_trap_observed=false;
r.step_no_fault_observed=false;
r.step_result_recorded=false;
r.step_safe_return_recorded=false;
r.trap_slot_present=true;
r.trap_capture_armed=false;
r.trap_observed=false;
r.trap_scause=0;
r.trap_stval=0;
r.trap_sepc=0;
r.fault_slot_present=true;
r.fault_capture_armed=false;
r.fault_observed=false;
r.fault_scause=0;
r.fault_stval=0;
r.fault_sepc=0;
r.build_returned=true;
r.source_fingerprint_after_build=readSourceFingerprint();
r.source_fingerprint_unchanged=sameFp(r.source_fingerprint_before_build,r.source_fingerprint_after_build);
return finish(r);
}
pub fn validate() HgatpTrapCapturePrepBlocker {
const r=mutable();
r.validate_count+=1;
return finish(r);
}
pub fn prepare() HgatpTrapCapturePrepBlocker {
const r=mutable();
r.prepare_count+=1;
r.source_fingerprint_before_prepare=readSourceFingerprint();
loadSource(r);
r.prepare_entered=true;
r.prepare_returned=false;
r.prepare_step_count=0;
r.step_source_loaded=true;
r.prepare_step_count+=1;
r.step_executor_checked=r.executor_present and r.executor_valid;
r.prepare_step_count+=1;
r.trap_slot_present=true;
r.trap_capture_armed=false;
r.trap_observed=false;
r.trap_scause=0;
r.trap_stval=0;
r.trap_sepc=0;
r.step_trap_slot_prepared=true;
r.prepare_step_count+=1;
r.fault_slot_present=true;
r.fault_capture_armed=false;
r.fault_observed=false;
r.fault_scause=0;
r.fault_stval=0;
r.fault_sepc=0;
r.step_fault_slot_prepared=true;
r.prepare_step_count+=1;
r.step_csr_guard_checked=!r.csr_write_function_called;
r.prepare_step_count+=1;
r.step_raw_guard_checked=!r.raw_write_function_called;
r.prepare_step_count+=1;
r.step_no_trap_observed=!r.trap_observed;
r.prepare_step_count+=1;
r.step_no_fault_observed=!r.fault_observed;
r.prepare_step_count+=1;
r.step_result_recorded=true;
r.result_present=true;
r.prepare_step_count+=1;
r.step_safe_return_recorded=true;
r.prepare_returned=true;
r.prepare_step_count+=1;
r.source_fingerprint_after_prepare=readSourceFingerprint();
r.source_fingerprint_unchanged=sameFp(r.source_fingerprint_before_prepare,r.source_fingerprint_after_prepare);
return finish(r);
}
fn corrupt(k:HgatpTrapCapturePrepBlocker) HgatpTrapCapturePrepBlocker {
_=build();
const r=mutable();
switch(k){
.missing_executor=>r.executor_present=false,.invalid_executor=>r.executor_valid=false,.source_mutated=>r.source_fingerprint_unchanged=false,.fake_trap_observed=>r.trap_observed=true,.fake_fault_observed=>r.fault_observed=true,.csr_write_called=>r.csr_write_function_called=true,.raw_write_called=>r.raw_write_function_called=true,.readback_attempted=>r.readback_attempted=true,.readback_valid=>r.readback_valid=true,.hgatp_write_attempted=>r.hgatp_write_attempted=true,.hgatp_write_performed=>r.hgatp_write_performed=true,.active_stage2_forbidden=>r.active_stage2=true,.guest_entered_forbidden=>r.guest_entered=true,.first_instruction_forbidden=>r.first_guest_instruction_executed=true,.none=>{}
} return validate();
}
pub fn invariantConsumption() bool {
_=build();
const s=executor.object();
return object().executor_checksum==s.checksum and object().executor_request_value==s.hardware_request_value and object().executor_request_checksum==s.hardware_request_checksum and object().executor_decision==tag(s.decision) and object().capture_request_value==s.hardware_request_value;
}
pub fn invariantCorruption() bool {
_=corrupt(.source_mutated);
return object().blocker==.source_mutated and object().result_code==.source_mutated;
}
fn pb(v:bool)void{uart.write(if(v)"true" else "false");}
fn lineB(n:[]const u8,v:bool)void{uart.write("hv: hgatp_trap_capture_prep.");uart.write(n);uart.write("=");pb(v);uart.write("\r\n");}
fn lineU(n:[]const u8,v:usize)void{uart.write("hv: hgatp_trap_capture_prep.");uart.write(n);uart.write("=");uart.writeDec(v);uart.write("\r\n");}
fn lineH(n:[]const u8,v:usize)void{uart.write("hv: hgatp_trap_capture_prep.");uart.write(n);uart.write("=");uart.writeHex(v);uart.write("\r\n");}
fn pr(label:[]const u8,k:HgatpTrapCapturePrepBlocker)void{uart.write("hv: hgatp_trap_capture_prep.");uart.write(label);uart.write("=");uart.write(@tagName(resultFrom(k)));uart.write(" blocker=");uart.write(@tagName(k));uart.write("\r\n");}
pub fn printSummary()void{const r=object();uart.write("hv: hgatp_trap_capture_prep.state=");uart.write(@tagName(r.state));uart.write(" decision=");uart.write(@tagName(r.decision));uart.write(" result_code=");uart.write(@tagName(r.result_code));uart.write(" blocker=");uart.write(@tagName(r.blocker));uart.write(" checksum=");uart.writeHex(r.checksum);uart.write("\r\n");}
pub fn printAllFields()void{const r=object();lineB("executor_present",r.executor_present);lineB("executor_valid",r.executor_valid);lineH("executor_checksum",r.executor_checksum);lineU("executor_state",r.executor_state);lineU("executor_decision",r.executor_decision);lineU("executor_result_code",r.executor_result_code);lineH("executor_request_value",r.executor_request_value);lineH("executor_request_checksum",r.executor_request_checksum);lineB("capture_request_present",r.capture_request_present);lineB("prepare_entered",r.prepare_entered);lineB("prepare_returned",r.prepare_returned);lineU("prepare_count",r.prepare_count);lineU("prepare_step_count",r.prepare_step_count);lineB("source_fingerprint_unchanged",r.source_fingerprint_unchanged);lineB("csr_write_function_called",r.csr_write_function_called);lineB("raw_write_function_called",r.raw_write_function_called);lineB("readback_attempted",r.readback_attempted);lineB("readback_valid",r.readback_valid);lineB("hgatp_write_attempted",r.hgatp_write_attempted);lineB("hgatp_write_performed",r.hgatp_write_performed);lineB("active_stage2",r.active_stage2);lineB("guest_entered",r.guest_entered);lineB("first_guest_instruction_executed",r.first_guest_instruction_executed);}
pub fn printSteps()void{const r=object();lineB("step_source_loaded",r.step_source_loaded);lineB("step_executor_checked",r.step_executor_checked);lineB("step_trap_slot_prepared",r.step_trap_slot_prepared);lineB("step_fault_slot_prepared",r.step_fault_slot_prepared);lineB("step_csr_guard_checked",r.step_csr_guard_checked);lineB("step_raw_guard_checked",r.step_raw_guard_checked);lineB("step_no_trap_observed",r.step_no_trap_observed);lineB("step_no_fault_observed",r.step_no_fault_observed);lineB("step_result_recorded",r.step_result_recorded);lineB("step_safe_return_recorded",r.step_safe_return_recorded);lineU("prepare_step_count",r.prepare_step_count);}
pub fn printTrapSlot()void{const r=object();lineB("trap_slot_present",r.trap_slot_present);lineB("trap_capture_armed",r.trap_capture_armed);lineB("trap_observed",r.trap_observed);lineU("trap_scause",r.trap_scause);lineU("trap_stval",r.trap_stval);lineU("trap_sepc",r.trap_sepc);}
pub fn printFaultSlot()void{const r=object();lineB("fault_slot_present",r.fault_slot_present);lineB("fault_capture_armed",r.fault_capture_armed);lineB("fault_observed",r.fault_observed);lineU("fault_scause",r.fault_scause);lineU("fault_stval",r.fault_stval);lineU("fault_sepc",r.fault_sepc);}
pub fn printResult()void{const r=object();lineB("result_present",r.result_present);uart.write("hv: hgatp_trap_capture_prep.result_code=");uart.write(@tagName(r.result_code));uart.write("\r\n");lineH("result_checksum",r.result_checksum);}
pub fn printDecisionCommand()void{uart.write("hv: hgatp_trap_capture_prep.decision=");uart.write(@tagName(object().decision));uart.write("\r\n");lineB("safe_denied_before_csr",object().safe_denied_before_csr);}
pub fn printBlockers()void{const r=object();uart.write("hv: hgatp_trap_capture_prep.blocker=");uart.write(@tagName(r.blocker));uart.write("\r\n");lineU("blocker_count",r.blocker_count);}
pub fn printStatusCommand()void{printSummary();printAllFields();printSteps();printTrapSlot();printFaultSlot();printResult();}
pub fn printBuildCommand()void{pr("build_result",build());printStatusCommand();}
pub fn printValidateCommand()void{pr("validate_result",validate());printStatusCommand();}
pub fn printPrepareCommand()void{pr("prepare_result",prepare());printStatusCommand();}
pub fn printBlockersCommand()void{_=validate();printBlockers();}
pub fn printNextCommand()void{uart.write("hv: hgatp_trap_capture_prep.next_action=");uart.write(@tagName(object().next_action));uart.write("\r\n");}
pub fn printChecksumCommand()void{lineH("checksum",object().checksum);}
pub fn printResetCommand()void{reset();uart.write("hv: hgatp_trap_capture_prep.reset_result=ok\r\n");printSummary();}
pub fn printFieldsCommand()void{printAllFields();printSteps();}
pub fn printTrapSlotCommand()void{printTrapSlot();}
pub fn printFaultSlotCommand()void{printFaultSlot();}
pub fn printResultCommand()void{printResult();}
pub fn printRequireExecutorTestCommand()void{pr("require_executor_test",corrupt(.missing_executor));printBlockers();}
pub fn printInvalidExecutorTestCommand()void{pr("invalid_executor_test",corrupt(.invalid_executor));printBlockers();}
pub fn printSourceIntegrityTestCommand()void{pr("source_integrity_test",corrupt(.source_mutated));printBlockers();}
pub fn printFakeTrapTestCommand()void{pr("fake_trap_test",corrupt(.fake_trap_observed));printBlockers();}
pub fn printFakeFaultTestCommand()void{pr("fake_fault_test",corrupt(.fake_fault_observed));printBlockers();}
pub fn printCsrCalledTestCommand()void{pr("csr_called_test",corrupt(.csr_write_called));printBlockers();}
pub fn printRawCalledTestCommand()void{pr("raw_called_test",corrupt(.raw_write_called));printBlockers();}
pub fn printReadbackTestCommand()void{pr("readback_test",corrupt(.readback_attempted));printBlockers();}
pub fn printReadbackValidTestCommand()void{pr("readback_valid_test",corrupt(.readback_valid));printBlockers();}
pub fn printWriteAttemptedTestCommand()void{pr("write_attempted_test",corrupt(.hgatp_write_attempted));printBlockers();}
pub fn printWritePerformedTestCommand()void{pr("write_performed_test",corrupt(.hgatp_write_performed));printBlockers();}
pub fn printActiveStage2TestCommand()void{pr("active_stage2_test",corrupt(.active_stage2_forbidden));printBlockers();}
pub fn printGuestEnteredTestCommand()void{pr("guest_entered_test",corrupt(.guest_entered_forbidden));printBlockers();}
pub fn printFirstInstructionTestCommand()void{pr("first_instruction_test",corrupt(.first_instruction_forbidden));printBlockers();}
pub fn printInvariantConsumptionCommand()void{uart.write("hv: hgatp_trap_capture_prep.invariant_consumption_result=");uart.write(if(invariantConsumption())"ok" else "rejected");uart.write("\r\n");}
pub fn printInvariantCorruptionCommand()void{uart.write("hv: hgatp_trap_capture_prep.invariant_corruption_result=");uart.write(if(invariantCorruption())"ok" else "rejected");uart.write("\r\n");}
