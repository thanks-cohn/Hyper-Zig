const uart=@import("../console/uart.zig");
 const vm=@import("vm.zig");
 const vcpu=@import("vcpu.zig");
 const ss=@import("second_stage.zig");
 const tbl=@import("stage2_table.zig");
 const hext=@import("h_extension.zig");
 const hgatp=@import("hgatp_candidate.zig");

pub const State=enum{
empty,built,validated,rejected}
;
 pub const Next=enum{
none,build_hgatp,build_stage2,build_table,validate_csr_safety,wait_for_safe_hgatp_write_guard,blocked}
;
 pub const Result=enum{
ok,rejected}
;
 pub const Error=enum{
none,empty,not_built,require_hgatp,require_stage2,require_table,require_h_extension,require_csr_safety,hgatp_write_attempted,active_stage2_forbidden,checksum_zero}
;

pub const Plan=struct{
owner_vm_id:vm.VmId,owner_vcpu_id:vcpu.VcpuId,state:State,next:Next,hgatp_checksum:usize,hgatp_value:usize,stage2_pages:usize,table_entries:usize,h_extension_state:hext.DiscoveryState,csr_safety_blocked:bool,hgatp_write_attempted:bool,active_stage2:bool,checksum:usize,ready:bool,build_count:usize,validate_count:usize,reject_count:usize,reset_count:usize,last_error:Error,blocker:Error}
;
 var obj:Plan=undefined;
 var inited=false;

pub fn init(owner:vm.VmId,vc:vcpu.VcpuId)void{
obj=empty(owner,vc,0);
inited=true;
}
 pub fn object()*const Plan{
return mut();
}
 fn mut()*Plan{
if(!inited)init(vm.object().id,vcpu.object().id);
return &obj;
}
 fn empty(owner:vm.VmId,vc:vcpu.VcpuId,resets:usize)Plan{
return .{
.owner_vm_id=owner,.owner_vcpu_id=vc,.state=.empty,.next=.none,.hgatp_checksum=0,.hgatp_value=0,.stage2_pages=0,.table_entries=0,.h_extension_state=.empty,.csr_safety_blocked=false,.hgatp_write_attempted=false,.active_stage2=false,.checksum=0,.ready=false,.build_count=0,.validate_count=0,.reject_count=0,.reset_count=resets,.last_error=.none,.blocker=.empty}
;
}

pub fn reset()Result{
const p=mut();
obj=empty(p.owner_vm_id,p.owner_vcpu_id,p.reset_count+1);
inited=true;
return .ok;
}
 fn mix(a:usize,b:usize)usize{
return (a ^% (b+%0x517cc1b727220a95))*%0x94d049bb133111eb;
}
 fn checksum(p:Plan)usize{
var x:usize=0x53503235;
x=mix(x,p.owner_vm_id);
x=mix(x,p.owner_vcpu_id);
x=mix(x,p.hgatp_checksum);
x=mix(x,p.hgatp_value);
x=mix(x,p.stage2_pages);
x=mix(x,p.table_entries);
x=mix(x,@intFromEnum(p.h_extension_state));
x=mix(x,@intFromBool(p.csr_safety_blocked));
x=mix(x,@intFromBool(p.hgatp_write_attempted));
x=mix(x,@intFromBool(p.active_stage2));
return if(x==0)1 else x;
}
 fn deriveNext(e:Error)Next{
return switch(e){
.none=>.wait_for_safe_hgatp_write_guard,.empty,.not_built=>.none,.require_hgatp=>.build_hgatp,.require_stage2=>.build_stage2,.require_table=>.build_table,.require_csr_safety,.require_h_extension=>.validate_csr_safety,else=>.blocked}
;
}

pub fn build()Result{
const p=mut();
p.build_count+=1;
p.ready=false;
p.state=.built;
p.owner_vm_id=vm.object().id;
p.owner_vcpu_id=vcpu.object().id;
const hc=hgatp.object();
const meta=ss.object();
const t=tbl.object();
const h=hext.object();
p.hgatp_checksum=hc.checksum;
p.hgatp_value=hc.value;
p.stage2_pages=meta.mapping.guest_page_count;
p.table_entries=t.entry_count;
p.h_extension_state=h.state;
p.csr_safety_blocked=h.unsafe_csr_read_forbidden;
p.hgatp_write_attempted=hc.hgatp_write_attempted or h.hgatp_write_status!=.not_attempted;
p.active_stage2=hc.active_stage2 or meta.mapping.active or t.active;
p.checksum=checksum(p);
const e=firstBlocker();
p.next=deriveNext(e);
 if(e!=.none)return reject(e);
 p.blocker=.none;
p.last_error=.none;
return .ok;
}
 fn firstBlocker()Error{
const p=object();
const hc=hgatp.object();
 if(p.state==.empty)return .empty;
 if(p.state!=.built and p.state!=.validated and p.state!=.rejected)return .not_built;
 if(hc.state!=.validated or !hc.ready or hc.checksum==0)return .require_hgatp;
 if(p.stage2_pages==0 or ss.object().state!=.metadata_ready or !ss.object().mapping.validated)return .require_stage2;
 if(p.table_entries==0 or (tbl.object().state!=.built and tbl.object().state!=.validated))return .require_table;
 if(p.h_extension_state==.empty)return .require_h_extension;
 if(!p.csr_safety_blocked)return .require_csr_safety;
 if(p.active_stage2)return .active_stage2_forbidden;
 if(p.hgatp_write_attempted)return .hgatp_write_attempted;
 if(p.checksum==0)return .checksum_zero;
 return .none;
}
 pub fn validate()Result{
const p=mut();
p.validate_count+=1;
if(p.state==.empty)return reject(.empty);
const e=firstBlocker();
p.next=deriveNext(e);
if(e!=.none)return reject(e);
p.ready=true;
p.state=.validated;
p.last_error=.none;
p.blocker=.none;
return .ok;
}
 fn reject(e:Error)Result{
const p=mut();
p.reject_count+=1;
p.ready=false;
p.state=.rejected;
p.last_error=e;
p.blocker=e;
p.next=deriveNext(e);
return .rejected;
}

pub fn removeHgatp()Result{
_ = build();
mut().hgatp_checksum=0;
mut().checksum=checksum(mut().*);
return validate();
}
 pub fn removeStage2()Result{
_ = build();
mut().stage2_pages=0;
mut().checksum=checksum(mut().*);
return validate();
}
 pub fn removeTable()Result{
_ = build();
mut().table_entries=0;
mut().checksum=checksum(mut().*);
return validate();
}
 pub fn removeCsrSafety()Result{
_ = build();
mut().csr_safety_blocked=false;
mut().checksum=checksum(mut().*);
return validate();
}
 pub fn markActiveStage2()Result{
_ = build();
mut().active_stage2=true;
mut().checksum=checksum(mut().*);
return validate();
}
 pub fn markWriteAttempt()Result{
_ = build();
mut().hgatp_write_attempted=true;
mut().checksum=checksum(mut().*);
return validate();
}

fn en(e:Error)[]const u8{
return switch(e){
.none=>"none",.empty=>"empty",.not_built=>"not-built",.require_hgatp=>"require-hgatp",.require_stage2=>"require-stage2",.require_table=>"require-table",.require_h_extension=>"require-h-extension",.require_csr_safety=>"require-csr-safety",.hgatp_write_attempted=>"hgatp-write-attempted",.active_stage2_forbidden=>"active-stage2-forbidden",.checksum_zero=>"checksum-zero"}
;
}
 fn rn(r:Result)[]const u8{
return if(r==.ok)"ok" else "rejected";
}
 fn printCore()void{
const p=object();
uart.write("hv: stage2_plan.state=");
uart.write(@tagName(p.state));
uart.write("\r\n");
uart.write("hv: stage2_plan.ready=");
uart.write(if(p.ready)"true" else "false");
uart.write("\r\n");
uart.write("hv: stage2_plan.next=");
uart.write(@tagName(p.next));
uart.write("\r\n");
uart.write("hv: stage2_plan.hgatp_checksum=");
uart.writeHex(p.hgatp_checksum);
uart.write("\r\n");
uart.write("hv: stage2_plan.stage2_pages=");
uart.writeDec(p.stage2_pages);
uart.write("\r\n");
uart.write("hv: stage2_plan.table_entries=");
uart.writeDec(p.table_entries);
uart.write("\r\n");
uart.write("hv: stage2_plan.checksum=");
uart.writeHex(p.checksum);
uart.write("\r\n");
uart.write("hv: stage2_plan.build_count=");
uart.writeDec(p.build_count);
uart.write("\r\n");
uart.write("hv: stage2_plan.validate_count=");
uart.writeDec(p.validate_count);
uart.write("\r\n");
uart.write("hv: stage2_plan.last_error=");
uart.write(en(p.last_error));
uart.write("\r\n");
}

pub fn printStatusCommand()void{
printCore();
printBlockersCommand();
printNonClaims();
}
 pub fn printBuildCommand()void{
const r=build();
uart.write("hv: stage2_plan.build_result=");
uart.write(rn(r));
uart.write("\r\n");
printCore();
printBlockersCommand();
printNonClaims();
}
 pub fn printValidateCommand()void{
const r=validate();
uart.write("hv: stage2_plan.validate_result=");
uart.write(rn(r));
uart.write("\r\n");
printCore();
printBlockersCommand();
printNonClaims();
}
 pub fn printBlockersCommand()void{
const p=object();
const n:usize=if(p.blocker==.none)0 else 1;
uart.write("hv: stage2_plan.blocker_count=");
uart.writeDec(n);
uart.write("\r\n");
uart.write("hv: stage2_plan.blocker=");
uart.write(en(p.blocker));
uart.write("\r\n");
}
 pub fn printNextCommand()void{
uart.write("hv: stage2_plan.next=");
uart.write(@tagName(object().next));
uart.write("\r\n");
}
 pub fn printChecksumCommand()void{
uart.write("hv: stage2_plan.checksum=");
uart.writeHex(object().checksum);
uart.write("\r\n");
}
 pub fn printResetCommand()void{
const r=reset();
uart.write("hv: stage2_plan.reset_result=");
uart.write(rn(r));
uart.write("\r\n");
printCore();
}
 pub fn printNegativeResult(label:[]const u8,r:Result)void{
uart.write("hv: stage2_plan.");
uart.write(label);
uart.write("=");
uart.write(rn(r));
uart.write("\r\n");
printCore();
printBlockersCommand();
printNonClaims();
}
 fn printNonClaims()void{
uart.write("hv: hgatp_write_attempted=false\r\n");
uart.write("hv: active_stage2=false\r\n");
uart.write("hv: second_stage_translation=MISSING\r\n");
}

