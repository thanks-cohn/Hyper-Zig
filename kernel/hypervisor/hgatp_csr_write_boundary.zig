const uart = @import("../console/uart.zig");
const vm = @import("vm.zig");
const vcpu = @import("vcpu.zig");
const trap = @import("hgatp_trap_capture_prep.zig");

pub const BoundaryState = enum {
empty, created, validated, ready, denied
};
pub const BoundaryBlocker = enum {
none, missing_trap_capture, invalid_trap_capture, source_mutated, replay_detected, csr_called, raw_called, trap_observed, fault_observed, readback_attempted, hgatp_write_attempted, hgatp_write_performed, active_stage2, guest_entered, first_instruction
};
pub const BoundaryDecision = enum {
none, denied_before_write, ready_no_write, rejected
};
pub const BoundaryResult = enum {
none, created, validated, execution_ready_without_write, denied, rejected
};
pub const SourceFingerprint = struct {
checksum: usize, state: usize, decision: usize, result_code: usize, request_value: usize, request_checksum: usize, safe_denied: bool, trap_observed: bool, fault_observed: bool, hgatp_write_attempted: bool, hgatp_write_performed: bool, active_stage2: bool, guest_entered: bool, first_guest_instruction_executed: bool, vm_id: vm.VmId, vcpu_id: vcpu.VcpuId
};
pub const ExecutionRecord = struct {
present: bool, sequence: usize, source_checksum: usize, boundary_checksum: usize, request_value: usize, result: BoundaryResult, decision: BoundaryDecision, denied_before_csr: bool, ready_without_write: bool, hgatp_write_attempted: bool, hgatp_write_performed: bool
};
pub const CsrWriteBoundary = struct {
owner_vm_id: vm.VmId, owner_vcpu_id: vcpu.VcpuId, source_present: bool, source_valid: bool, source_checksum: usize, source_request_value: usize, source_request_checksum: usize, fingerprint_before: SourceFingerprint, fingerprint_after: SourceFingerprint, fingerprint_unchanged: bool, request_present: bool, request_value: usize, request_checksum: usize, authorization_evaluated: bool, authorized_to_prepare: bool, authorized_to_write: bool, denied_before_csr: bool, lifecycle_generation: usize, replay_nonce: usize, last_executed_nonce: usize, create_count: usize, validate_count: usize, execute_count: usize, denial_count: usize, ready_count: usize, reset_count: usize, inspection_count: usize, accounting_checksum: usize, boundary_checksum: usize, execution_record: ExecutionRecord, csr_write_function_called: bool, raw_write_function_called: bool, trap_observed: bool, fault_observed: bool, readback_attempted: bool, hgatp_write_attempted: bool, hgatp_write_performed: bool, active_stage2: bool, guest_entered: bool, first_guest_instruction_executed: bool, blocker: BoundaryBlocker, blocker_count: usize, decision: BoundaryDecision, result: BoundaryResult, state: BoundaryState
};
var obj: CsrWriteBoundary = undefined;
var initialized=false;
fn tag(e:anytype)usize{return @intFromEnum(e);} fn b(v:bool)usize{return if(v)1 else 0;} fn mix(a:usize,c:usize)usize{return (a^c)*%0x9e37_79b9_7f4a_7c15;}
fn emptyFp() SourceFingerprint {
return .{
.checksum=0,.state=0,.decision=0,.result_code=0,.request_value=0,.request_checksum=0,.safe_denied=false,.trap_observed=false,.fault_observed=false,.hgatp_write_attempted=false,.hgatp_write_performed=false,.active_stage2=false,.guest_entered=false,.first_guest_instruction_executed=false,.vm_id=0,.vcpu_id=0
};
}
fn emptyRec() ExecutionRecord {
return .{
.present=false,.sequence=0,.source_checksum=0,.boundary_checksum=0,.request_value=0,.result=.none,.decision=.none,.denied_before_csr=false,.ready_without_write=false,.hgatp_write_attempted=false,.hgatp_write_performed=false
};
}
fn empty(owner:vm.VmId, vc:vcpu.VcpuId, resets:usize) CsrWriteBoundary {
return .{
.owner_vm_id=owner,.owner_vcpu_id=vc,.source_present=false,.source_valid=false,.source_checksum=0,.source_request_value=0,.source_request_checksum=0,.fingerprint_before=emptyFp(),.fingerprint_after=emptyFp(),.fingerprint_unchanged=false,.request_present=false,.request_value=0,.request_checksum=0,.authorization_evaluated=false,.authorized_to_prepare=false,.authorized_to_write=false,.denied_before_csr=true,.lifecycle_generation=0,.replay_nonce=0,.last_executed_nonce=0,.create_count=0,.validate_count=0,.execute_count=0,.denial_count=0,.ready_count=0,.reset_count=resets,.inspection_count=0,.accounting_checksum=0,.boundary_checksum=0,.execution_record=emptyRec(),.csr_write_function_called=false,.raw_write_function_called=false,.trap_observed=false,.fault_observed=false,.readback_attempted=false,.hgatp_write_attempted=false,.hgatp_write_performed=false,.active_stage2=false,.guest_entered=false,.first_guest_instruction_executed=false,.blocker=.none,.blocker_count=0,.decision=.none,.result=.none,.state=.empty
};
}
pub fn init(owner:vm.VmId, vc:vcpu.VcpuId)void{obj=empty(owner,vc,0);initialized=true;} fn mutable()*CsrWriteBoundary{if(!initialized)init(vm.object().id,vcpu.object().id);return &obj;} pub fn object()*const CsrWriteBoundary{return mutable();}
pub fn reset()void{const r=mutable().reset_count+1;obj=empty(vm.object().id,vcpu.object().id,r);initialized=true;}
fn fpChecksum(f:SourceFingerprint)usize{var x:usize=0x3838;
x=mix(x,f.state);
x=mix(x,f.decision);
x=mix(x,f.result_code);
x=mix(x,f.request_value);
x=mix(x,f.request_checksum);
x=mix(x,b(f.safe_denied));
x=mix(x,b(f.trap_observed));
x=mix(x,b(f.fault_observed));
x=mix(x,b(f.hgatp_write_attempted));
x=mix(x,b(f.hgatp_write_performed));
x=mix(x,b(f.active_stage2));
x=mix(x,b(f.guest_entered));
x=mix(x,b(f.first_guest_instruction_executed));
x=mix(x,@intCast(f.vm_id));
x=mix(x,@intCast(f.vcpu_id));
return if(x==0)1 else x;}
fn readFp()SourceFingerprint{const s=trap.object();
var f=SourceFingerprint{
.checksum=0,.state=tag(s.state),.decision=tag(s.decision),.result_code=tag(s.result_code),.request_value=s.capture_request_value,.request_checksum=s.capture_request_checksum,.safe_denied=s.safe_denied_before_csr,.trap_observed=s.trap_observed,.fault_observed=s.fault_observed,.hgatp_write_attempted=s.hgatp_write_attempted,.hgatp_write_performed=s.hgatp_write_performed,.active_stage2=s.active_stage2,.guest_entered=s.guest_entered,.first_guest_instruction_executed=s.first_guest_instruction_executed,.vm_id=vm.object().id,.vcpu_id=vcpu.object().id
};
f.checksum=fpChecksum(f);
return f;}
fn same(a:SourceFingerprint,c:SourceFingerprint)bool{return a.checksum==c.checksum and a.request_value==c.request_value and a.request_checksum==c.request_checksum and a.safe_denied==c.safe_denied and a.vm_id==c.vm_id and a.vcpu_id==c.vcpu_id;}
fn load(r:*CsrWriteBoundary)void{const s=trap.object();
r.source_present=s.state!=.empty and s.checksum!=0;
r.source_valid=s.state==.prepared and s.safe_denied_before_csr and s.result_code==.trap_capture_prep_ready;
r.source_checksum=s.checksum;
r.source_request_value=s.capture_request_value;
r.source_request_checksum=s.capture_request_checksum;
r.request_present=s.capture_request_present;
r.request_value=s.capture_request_value;
r.request_checksum=s.capture_request_checksum ^ 0x3838;
r.csr_write_function_called=s.csr_write_function_called;
r.raw_write_function_called=s.raw_write_function_called;
r.trap_observed=s.trap_observed;
r.fault_observed=s.fault_observed;
r.readback_attempted=s.readback_attempted;
r.hgatp_write_attempted=s.hgatp_write_attempted;
r.hgatp_write_performed=s.hgatp_write_performed;
r.active_stage2=s.active_stage2;
r.guest_entered=s.guest_entered;
r.first_guest_instruction_executed=s.first_guest_instruction_executed;}
fn first(r:CsrWriteBoundary)BoundaryBlocker{if(!r.source_present)return .missing_trap_capture;
if(!r.source_valid)return .invalid_trap_capture;
if(!r.fingerprint_unchanged)return .source_mutated;
if(r.replay_nonce!=0 and r.replay_nonce==r.last_executed_nonce)return .replay_detected;
if(r.csr_write_function_called)return .csr_called;
if(r.raw_write_function_called)return .raw_called;
if(r.trap_observed)return .trap_observed;
if(r.fault_observed)return .fault_observed;
if(r.readback_attempted)return .readback_attempted;
if(r.hgatp_write_attempted)return .hgatp_write_attempted;
if(r.hgatp_write_performed)return .hgatp_write_performed;
if(r.active_stage2)return .active_stage2;
if(r.guest_entered)return .guest_entered;
if(r.first_guest_instruction_executed)return .first_instruction;
return .none;}
fn checksum(r:CsrWriteBoundary)usize{var x:usize=0x38;
x=mix(x,r.fingerprint_before.checksum);
x=mix(x,r.fingerprint_after.checksum);
x=mix(x,r.request_value);
x=mix(x,r.request_checksum);
x=mix(x,r.lifecycle_generation);
x=mix(x,r.replay_nonce);
x=mix(x,tag(r.result));
x=mix(x,tag(r.decision));
return if(x==0)1 else x;}
fn finish(r:*CsrWriteBoundary)BoundaryBlocker{const k=first(r.*);
r.blocker=k;
r.blocker_count=if(k==.none)0 else 1;
r.authorization_evaluated=true;
r.authorized_to_prepare=k==.none;
r.authorized_to_write=false;
r.denied_before_csr=true;
if(k==.none){r.result=if(r.execute_count>0) .execution_ready_without_write else if(r.validate_count>0) .validated else .created;
r.decision=if(r.execute_count>0) .ready_no_write else .denied_before_write;
r.state=if(r.execute_count>0) .ready else if(r.validate_count>0) .validated else .created;
if(r.execute_count>0)r.ready_count+=1;}else{r.result=.rejected;
r.decision=.rejected;
r.state=.denied;
r.denial_count+=1;} r.boundary_checksum=checksum(r.*);
r.accounting_checksum=r.boundary_checksum ^ r.create_count ^ (r.validate_count<<1) ^ (r.execute_count<<2) ^ (r.denial_count<<3) ^ (r.ready_count<<4);
return k;}
pub fn create()BoundaryBlocker{const r=mutable();
r.create_count+=1;
r.lifecycle_generation+=1;
r.replay_nonce=r.lifecycle_generation*%0x10001+%r.create_count;
r.fingerprint_before=readFp();
load(r);
r.fingerprint_after=readFp();
r.fingerprint_unchanged=same(r.fingerprint_before,r.fingerprint_after);
return finish(r);} 
pub fn validate()BoundaryBlocker{const r=mutable();
r.validate_count+=1;
return finish(r);} 
pub fn execute()BoundaryBlocker{const r=mutable();
r.execute_count+=1;
const k=finish(r);
r.execution_record=.{
.present=true,.sequence=r.execute_count,.source_checksum=r.source_checksum,.boundary_checksum=r.boundary_checksum,.request_value=r.request_value,.result=r.result,.decision=r.decision,.denied_before_csr=true,.ready_without_write=k==.none,.hgatp_write_attempted=false,.hgatp_write_performed=false
};
if(k==.none) r.last_executed_nonce=r.replay_nonce;
return k;}
fn corrupt(k:BoundaryBlocker)BoundaryBlocker{_=create();
const r=mutable();
switch(k){.missing_trap_capture=>r.source_present=false,.invalid_trap_capture=>r.source_valid=false,.source_mutated=>r.fingerprint_unchanged=false,.replay_detected=>r.last_executed_nonce=r.replay_nonce,.csr_called=>r.csr_write_function_called=true,.raw_called=>r.raw_write_function_called=true,.trap_observed=>r.trap_observed=true,.fault_observed=>r.fault_observed=true,.readback_attempted=>r.readback_attempted=true,.hgatp_write_attempted=>r.hgatp_write_attempted=true,.hgatp_write_performed=>r.hgatp_write_performed=true,.active_stage2=>r.active_stage2=true,.guest_entered=>r.guest_entered=true,.first_instruction=>r.first_guest_instruction_executed=true,.none=>{}} return validate();}
fn pb(v:bool)void{uart.write(if(v)"true" else "false");} fn lineB(n:[]const u8,v:bool)void{uart.write("hv: csr_boundary.");uart.write(n);uart.write("=");pb(v);uart.write("\r\n");} fn lineU(n:[]const u8,v:usize)void{uart.write("hv: csr_boundary.");uart.write(n);uart.write("=");uart.writeDec(v);uart.write("\r\n");} fn lineH(n:[]const u8,v:usize)void{uart.write("hv: csr_boundary.");uart.write(n);uart.write("=");uart.writeHex(v);uart.write("\r\n");}
fn pr(n:[]const u8,k:BoundaryBlocker)void{uart.write("hv: csr_boundary.");uart.write(n);uart.write("=");uart.write(@tagName(object().result));uart.write(" blocker=");uart.write(@tagName(k));uart.write("\r\n");}
pub fn printSummary()void{const r=object();uart.write("hv: csr_boundary.state=");uart.write(@tagName(r.state));uart.write(" decision=");uart.write(@tagName(r.decision));uart.write(" result=");uart.write(@tagName(r.result));uart.write(" blocker=");uart.write(@tagName(r.blocker));uart.write(" checksum=");uart.writeHex(r.boundary_checksum);uart.write("\r\n");}
pub fn printFields()void{const r=object();lineB("source_present",r.source_present);lineB("source_valid",r.source_valid);lineH("source_checksum",r.source_checksum);lineH("request_value",r.request_value);lineH("request_checksum",r.request_checksum);lineB("fingerprint_unchanged",r.fingerprint_unchanged);lineB("authorization_evaluated",r.authorization_evaluated);lineB("authorized_to_prepare",r.authorized_to_prepare);lineB("authorized_to_write",r.authorized_to_write);lineB("denied_before_csr",r.denied_before_csr);lineU("lifecycle_generation",r.lifecycle_generation);lineU("replay_nonce",r.replay_nonce);lineU("last_executed_nonce",r.last_executed_nonce);lineU("create_count",r.create_count);lineU("validate_count",r.validate_count);lineU("execute_count",r.execute_count);lineU("denial_count",r.denial_count);lineU("ready_count",r.ready_count);lineU("reset_count",r.reset_count);lineH("accounting_checksum",r.accounting_checksum);lineH("boundary_checksum",r.boundary_checksum);lineB("csr_write_function_called",r.csr_write_function_called);lineB("raw_write_function_called",r.raw_write_function_called);lineB("hgatp_write_attempted",r.hgatp_write_attempted);lineB("hgatp_write_performed",r.hgatp_write_performed);lineB("active_stage2",r.active_stage2);lineB("guest_entered",r.guest_entered);lineB("first_guest_instruction_executed",r.first_guest_instruction_executed);}
pub fn printRecord()void{const r=object().execution_record;
lineB("record_present",r.present);lineU("record_sequence",r.sequence);lineH("record_source_checksum",r.source_checksum);lineH("record_boundary_checksum",r.boundary_checksum);lineH("record_request_value",r.request_value);uart.write("hv: csr_boundary.record_result=");uart.write(@tagName(r.result));uart.write("\r\n");uart.write("hv: csr_boundary.record_decision=");uart.write(@tagName(r.decision));uart.write("\r\n");lineB("record_denied_before_csr",r.denied_before_csr);lineB("record_ready_without_write",r.ready_without_write);lineB("record_hgatp_write_attempted",r.hgatp_write_attempted);lineB("record_hgatp_write_performed",r.hgatp_write_performed);}
pub fn printStatusCommand()void{mutable().inspection_count+=1;
printSummary();
printFields();
printRecord();}
pub fn printCreateCommand()void{pr("create_result",create());
printStatusCommand();}
pub fn printValidateCommand()void{pr("validate_result",validate());
printStatusCommand();}
pub fn printExecuteCommand()void{pr("execute_result",execute());
printStatusCommand();}
pub fn printInspectCommand()void{printStatusCommand();}
pub fn printResetCommand()void{reset();
uart.write("hv: csr_boundary.reset_result=ok\r\n");
printStatusCommand();}
pub fn printDenialTestCommand()void{pr("denial_test",corrupt(.csr_called));
printStatusCommand();}
pub fn printReplayTestCommand()void{_=create();_=validate();_=execute();
pr("replay_test",validate());
printStatusCommand();}
pub fn printNoWriteInvariantTestCommand()void{_=create();_=validate();_=execute();
const r=object();
uart.write("hv: csr_boundary.no_write_invariant_result=");
uart.write(if(!r.hgatp_write_attempted and !r.hgatp_write_performed and !r.active_stage2 and !r.guest_entered and !r.first_guest_instruction_executed and r.authorized_to_write==false)"ok" else "rejected");
uart.write("\r\n");
printFields();
printRecord();}
