const uart=@import("../console/uart.zig");

const pmm=@import("../memory/pmm.zig");

const vm=@import("vm.zig");
 const vcpu=@import("vcpu.zig");
 const gm=@import("guest_memory.zig");
 const gas=@import("guest_address_space.zig");
 const ss=@import("second_stage.zig");
 const tbl=@import("stage2_table.zig");
 const hext=@import("h_extension.zig");

pub const State=enum{
empty,built,validated,rejected}
;
 pub const Mode=enum{
bare,sv39x4,invalid}
;
 pub const Result=enum{
ok,rejected}
;
 pub const Error=enum{
none,empty,not_built,owner_mismatch,guest_memory_missing,address_space_missing,stage2_missing,table_missing,h_extension_missing,csr_safety_missing,invalid_mode,ppn_misaligned,invalid_vmid,hgatp_write_attempted,active_stage2_forbidden,checksum_zero}
;

pub const Candidate=struct{
owner_vm_id:vm.VmId,owner_vcpu_id:vcpu.VcpuId,state:State,mode:Mode,vmid:u16,vmid_bits:u8,root_host_address:usize,root_ppn:usize,root_page_size:usize,guest_base:usize,guest_size:usize,stage2_pages:usize,table_entries:usize,h_extension_state:hext.DiscoveryState,csr_safety_blocked:bool,hgatp_write_attempted:bool,active_stage2:bool,value:usize,checksum:usize,ready:bool,build_count:usize,validate_count:usize,reject_count:usize,reset_count:usize,last_error:Error,blocker:Error}
;

var obj:Candidate=undefined;
 var inited=false;

pub fn init(owner:vm.VmId,vc:vcpu.VcpuId)void{
obj=empty(owner,vc,0);
inited=true;
}
 pub fn object()*const Candidate{
return mut();
}
 fn mut()*Candidate{
if(!inited)init(vm.object().id,vcpu.object().id);
return &obj;
}
 fn empty(owner:vm.VmId,vc:vcpu.VcpuId,resets:usize)Candidate{
return .{
.owner_vm_id=owner,.owner_vcpu_id=vc,.state=.empty,.mode=.bare,.vmid=0,.vmid_bits=14,.root_host_address=0,.root_ppn=0,.root_page_size=pmm.page_size,.guest_base=0,.guest_size=0,.stage2_pages=0,.table_entries=0,.h_extension_state=.empty,.csr_safety_blocked=false,.hgatp_write_attempted=false,.active_stage2=false,.value=0,.checksum=0,.ready=false,.build_count=0,.validate_count=0,.reject_count=0,.reset_count=resets,.last_error=.none,.blocker=.empty}
;
}

pub fn reset()Result{
const c=mut();
obj=empty(c.owner_vm_id,c.owner_vcpu_id,c.reset_count+1);
inited=true;
return .ok;
}

fn mix(a:usize,b:usize)usize{
return (a ^% (b +% 0x9e3779b97f4a7c15)) *% 0xbf58476d1ce4e5b9;
}
 fn modeBits(m:Mode)usize{
return switch(m){
.bare=>0,.sv39x4=>8,.invalid=>15}
;
}

fn computeValue(c:Candidate)usize{
return (modeBits(c.mode)<<60)|(@as(usize,c.vmid)<<44)|(c.root_ppn & 0x00000fffffffffff);
}
 fn computeChecksum(c:Candidate)usize{
var x:usize=0x48563235;
 x=mix(x,c.owner_vm_id);
x=mix(x,c.owner_vcpu_id);
x=mix(x,modeBits(c.mode));
x=mix(x,c.vmid);
x=mix(x,c.root_host_address);
x=mix(x,c.root_ppn);
x=mix(x,c.guest_base);
x=mix(x,c.guest_size);
x=mix(x,c.stage2_pages);
x=mix(x,c.table_entries);
x=mix(x,@intFromEnum(c.h_extension_state));
x=mix(x,@intFromBool(c.csr_safety_blocked));
x=mix(x,c.value);
return if(x==0)1 else x;
}

pub fn build()Result{
const c=mut();
c.build_count+=1;
c.ready=false;
c.state=.built;
c.owner_vm_id=vm.object().id;
c.owner_vcpu_id=vcpu.object().id;
const mem=gm.object();
const as=gas.object();
const meta=ss.object();
const t=tbl.object();
const h=hext.object();
c.mode=.sv39x4;
c.vmid=@intCast(c.owner_vm_id+1);
c.vmid_bits=14;
c.root_host_address=t.root_host_address;
c.root_ppn=t.root_host_address/pmm.page_size;
c.root_page_size=t.page_size;
c.guest_base=as.guest_base.value;
c.guest_size=as.guest_size_bytes;
c.stage2_pages=meta.mapping.guest_page_count;
c.table_entries=t.entry_count;
c.h_extension_state=h.state;
c.csr_safety_blocked=h.unsafe_csr_read_forbidden;
c.hgatp_write_attempted=h.hgatp_write_status!=.not_attempted;
c.active_stage2=meta.mapping.active or t.active;
 if(mem.state!=.configured or as.state!=.configured or meta.state!=.metadata_ready or t.state==.empty){
c.value=computeValue(c);
c.checksum=computeChecksum(c);
return reject(firstBlocker());
}
 c.value=computeValue(c);
c.checksum=computeChecksum(c);
c.last_error=.none;
c.blocker=.none;
return .ok;
}

fn firstBlocker()Error{
const c=object();
 if(c.state==.empty)return .empty;
 if(c.state!=.built and c.state!=.validated and c.state!=.rejected)return .not_built;
 if(c.owner_vm_id!=vm.object().id or c.owner_vcpu_id!=vcpu.object().id)return .owner_mismatch;
 if(gm.object().state!=.configured)return .guest_memory_missing;
 if(gas.object().state!=.configured)return .address_space_missing;
 if(ss.object().state!=.metadata_ready or !ss.object().mapping.validated)return .stage2_missing;
 if(tbl.object().state!=.built and tbl.object().state!=.validated)return .table_missing;
 if(c.h_extension_state==.empty)return .h_extension_missing;
 if(!c.csr_safety_blocked)return .csr_safety_missing;
 if(c.hgatp_write_attempted)return .hgatp_write_attempted;
 if(c.active_stage2)return .active_stage2_forbidden;
 if(c.mode!=.sv39x4)return .invalid_mode;
 if(c.root_page_size!=pmm.page_size or c.root_host_address%pmm.page_size!=0)return .ppn_misaligned;
 if(c.vmid==0 or @as(usize,c.vmid)>((@as(usize,1)<<c.vmid_bits)-1))return .invalid_vmid;
 if(c.checksum==0)return .checksum_zero;
 return .none;
}

pub fn validate()Result{
const c=mut();
c.validate_count+=1;
 if(c.state==.empty)return reject(.empty);
 if(c.state!=.built and c.state!=.validated and c.state!=.rejected)return reject(.not_built);
 const e=firstBlocker();
 if(e!=.none)return reject(e);
 c.ready=true;
c.state=.validated;
c.last_error=.none;
c.blocker=.none;
return .ok;
}
 fn reject(e:Error)Result{
const c=mut();
c.reject_count+=1;
c.ready=false;
c.state=.rejected;
c.last_error=e;
c.blocker=e;
return .rejected;
}

pub fn corruptMode()Result{
_ = build();
 mut().mode=.invalid;
 mut().value=computeValue(mut().*);
 mut().checksum=computeChecksum(mut().*);
 return validate();
}
 pub fn corruptPpn()Result{
_ = build();
 mut().root_host_address+=1;
 mut().root_ppn=mut().root_host_address/pmm.page_size;
 mut().checksum=computeChecksum(mut().*);
 return validate();
}
 pub fn corruptVmid()Result{
_ = build();
 mut().vmid=0;
 mut().value=computeValue(mut().*);
 mut().checksum=computeChecksum(mut().*);
 return validate();
}
 pub fn removeHext()Result{
_ = build();
 mut().h_extension_state=.empty;
 mut().checksum=computeChecksum(mut().*);
 return validate();
}
 pub fn markWriteAttempt()Result{
_ = build();
 mut().hgatp_write_attempted=true;
 mut().checksum=computeChecksum(mut().*);
 return validate();
}
 pub fn markActiveStage2()Result{
_ = build();
 mut().active_stage2=true;
 mut().checksum=computeChecksum(mut().*);
 return validate();
}

pub fn mutateVmid(new:u16)usize{
_ = build();
 mut().vmid=new;
 mut().value=computeValue(mut().*);
 mut().checksum=computeChecksum(mut().*);
 return mut().value;
}
 pub fn mutateRootPpn(delta:usize)usize{
_ = build();
 mut().root_host_address+=delta*pmm.page_size;
 mut().root_ppn=mut().root_host_address/pmm.page_size;
 mut().value=computeValue(mut().*);
 mut().checksum=computeChecksum(mut().*);
 return mut().value;
}

fn en(e:Error)[]const u8{
return switch(e){
.none=>"none",.empty=>"empty",.not_built=>"not-built",.owner_mismatch=>"owner-mismatch",.guest_memory_missing=>"guest-memory-missing",.address_space_missing=>"address-space-missing",.stage2_missing=>"stage2-missing",.table_missing=>"table-missing",.h_extension_missing=>"h-extension-missing",.csr_safety_missing=>"csr-safety-missing",.invalid_mode=>"invalid-mode",.ppn_misaligned=>"ppn-misaligned",.invalid_vmid=>"invalid-vmid",.hgatp_write_attempted=>"hgatp-write-attempted",.active_stage2_forbidden=>"active-stage2-forbidden",.checksum_zero=>"checksum-zero"}
;
}
 fn rn(r:Result)[]const u8{
return if(r==.ok)"ok" else "rejected";
}

fn printCore()void{
const c=object();
uart.write("hv: hgatp_candidate.state=");
uart.write(@tagName(c.state));
uart.write("\r\n");
uart.write("hv: hgatp_candidate.ready=");
uart.write(if(c.ready)"true" else "false");
uart.write("\r\n");
uart.write("hv: hgatp.owner_vm_id=");
uart.writeDec(c.owner_vm_id);
uart.write("\r\n");
uart.write("hv: hgatp.owner_vcpu_id=");
uart.writeDec(c.owner_vcpu_id);
uart.write("\r\n");
uart.write("hv: hgatp.mode=");
uart.write(@tagName(c.mode));
uart.write("\r\n");
uart.write("hv: hgatp.vmid=");
uart.writeDec(c.vmid);
uart.write("\r\n");
uart.write("hv: hgatp.root_ppn=");
uart.writeDec(c.root_ppn);
uart.write("\r\n");
uart.write("hv: hgatp.root_host_address=");
uart.writeHex(c.root_host_address);
uart.write("\r\n");
uart.write("hv: hgatp.value=");
uart.writeHex(c.value);
uart.write("\r\n");
uart.write("hv: hgatp.checksum=");
uart.writeHex(c.checksum);
uart.write("\r\n");
uart.write("hv: hgatp.build_count=");
uart.writeDec(c.build_count);
uart.write("\r\n");
uart.write("hv: hgatp.validate_count=");
uart.writeDec(c.validate_count);
uart.write("\r\n");
uart.write("hv: hgatp.last_error=");
uart.write(en(c.last_error));
uart.write("\r\n");
}

pub fn printStatusCommand()void{
printCore();
printBlockersCommand();
printNonClaims();
}
 pub fn printBuildCommand()void{
const r=build();
uart.write("hv: hgatp.build_result=");
uart.write(rn(r));
uart.write("\r\n");
printCore();
printNonClaims();
}
 pub fn printValidateCommand()void{
const r=validate();
uart.write("hv: hgatp.validate_result=");
uart.write(rn(r));
uart.write("\r\n");
printCore();
printBlockersCommand();
printNonClaims();
}
 pub fn printBlockersCommand()void{
const c=object();
const n:usize=if(c.blocker==.none)0 else 1;
uart.write("hv: hgatp.blocker_count=");
uart.writeDec(n);
uart.write("\r\n");
uart.write("hv: hgatp.blocker=");
uart.write(en(c.blocker));
uart.write("\r\n");
}
 pub fn printFieldsCommand()void{
printCore();
}
 pub fn printCandidateCommand()void{
uart.write("hv: hgatp.candidate=");
uart.writeHex(object().value);
uart.write("\r\n");
}
 pub fn printChecksumCommand()void{
uart.write("hv: hgatp.checksum=");
uart.writeHex(object().checksum);
uart.write("\r\n");
}
 pub fn printResetCommand()void{
const r=reset();
uart.write("hv: hgatp.reset_result=");
uart.write(rn(r));
uart.write("\r\n");
printCore();
}

pub fn printNegativeResult(label:[]const u8,r:Result)void{
uart.write("hv: hgatp.");
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
uart.write("hv: guest_execution=not-supported-yet\r\n");
}

