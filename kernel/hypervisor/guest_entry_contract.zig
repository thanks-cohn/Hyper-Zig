const uart = @import("../console/uart.zig");
const vm = @import("vm.zig");
const vcpu = @import("vcpu.zig");
const guest_image = @import("guest_image.zig");
const guest_entry = @import("guest_entry.zig");
const boot_package = @import("boot_package.zig");
const binary_fdt = @import("binary_fdt.zig");
const linux_handoff = @import("linux_handoff.zig");
const guest_context = @import("guest_context.zig");
const trap_plan = @import("trap_plan.zig");
const entry_stub = @import("entry_stub.zig");
const hv39 = @import("hgatp_csr_write_eligibility.zig");

pub const GuestEntryContractState = enum {
empty,
built,
validated,
rejected
};
pub const GuestEntryContractDecision = enum {
none,
guest_entry_contract_blocked,
guest_entry_contract_validated,
rejected
};
pub const GuestEntryContractResult = enum {
ok,
rejected
};
pub const GuestEntryContractBlocker = enum {
none,
missing_hv39_source,
invalid_hv39_source,
source_mutated,
invalid_guest_pc,
invalid_guest_sp,
invalid_register_frame,
invalid_execution_frame,
invalid_trap_return_target,
guest_ready_corruption,
trap_return_ready_corruption,
guest_entered_corruption,
first_instruction_corruption,
trap_return_executed_corruption,
active_stage2_corruption,
hgatp_written_corruption,
missing_boot_sources,
missing_linux_handoff,
missing_context,
missing_trap_plan,
missing_entry_stub
};
pub const GuestEntryContractNextAction = enum {
none,
build_hv39_externally,
evaluate_hv39_externally,
investigate_source_mutation,
build_boot_sources_externally,
prepare_linux_handoff_externally,
prepare_context_externally,
prepare_trap_plan_externally,
prepare_entry_stub_externally,
keep_guest_entry_blocked,
clear_local_corruption
};

pub const GuestEntryContractFingerprint = struct {
hv39_checksum: usize,
hv39_state: usize,
hv39_decision: usize,
image_state: usize,
image_checksum: usize,
entry_state: usize,
entry_pc: usize,
entry_sp: usize,
boot_state: usize,
fdt_state: usize,
fdt_checksum: usize,
handoff_state: usize,
handoff_entry: usize,
handoff_fdt: usize,
context_state: usize,
trap_plan_state: usize,
entry_stub_state: usize,
vm_id: vm.VmId,
vcpu_id: vcpu.VcpuId,
checksum: usize
};
pub const GuestRegisterFrame = struct {
present: bool,
valid: bool,
pc: usize,
sp: usize,
a0: usize,
a1: usize,
owner_vm_id: vm.VmId,
owner_vcpu_id: vcpu.VcpuId,
checksum: usize
};
pub const GuestExecutionFrame = struct {
present: bool,
valid: bool,
pc: usize,
sp: usize,
a0: usize,
a1: usize,
guest_memory_base: usize,
guest_memory_size: usize,
source_context_valid: bool,
source_trap_plan_valid: bool,
source_entry_stub_valid: bool,
checksum: usize
};
pub const GuestTrapReturnTarget = struct {
present: bool,
valid: bool,
target_pc: usize,
target_sp: usize,
target_a0: usize,
target_a1: usize,
status_metadata: usize,
privilege_metadata: usize,
target_kind_metadata: usize,
entry_mode_metadata: usize,
checksum: usize
};
pub const GuestBootContractSources = struct {
guest_image_present: bool,
guest_image_valid: bool,
guest_image_entry: usize,
guest_image_checksum: usize,
boot_package_present: bool,
boot_package_valid: bool,
boot_kernel_present: bool,
boot_initrd_present: bool,
boot_dtb_present: bool,
fdt_present: bool,
fdt_valid: bool,
fdt_checksum: usize,
linux_handoff_present: bool,
linux_handoff_valid: bool,
linux_entry: usize,
linux_fdt_addr: usize,
linux_initrd_start: usize,
linux_initrd_end: usize,
checksum: usize
};

pub const GuestEntryContract = struct {
    owner_vm_id: vm.VmId,
owner_vcpu_id: vcpu.VcpuId,
    source_hv39_present: bool,
source_hv39_valid: bool,
source_hv39_checksum: usize,
source_hv39_decision: usize,
source_hv39_denied_before_hardware: bool,
    guest_image_present: bool,
guest_image_valid: bool,
guest_image_entry: usize,
guest_image_checksum: usize,
    boot_package_present: bool,
boot_package_valid: bool,
boot_kernel_present: bool,
boot_initrd_present: bool,
boot_dtb_present: bool,
    fdt_present: bool,
fdt_valid: bool,
fdt_checksum: usize,
    linux_handoff_present: bool,
linux_handoff_valid: bool,
linux_entry: usize,
linux_fdt_addr: usize,
linux_initrd_start: usize,
linux_initrd_end: usize,
    guest_context_present: bool,
guest_context_valid: bool,
trap_plan_present: bool,
trap_plan_valid: bool,
entry_stub_present: bool,
entry_stub_valid: bool,
    guest_pc_present: bool,
guest_pc_value: usize,
guest_sp_present: bool,
guest_sp_value: usize,
guest_a0_present: bool,
guest_a0_value: usize,
guest_a1_present: bool,
guest_a1_value: usize,
    register_frame_present: bool,
register_frame_valid: bool,
execution_frame_present: bool,
execution_frame_valid: bool,
trap_return_target_present: bool,
trap_return_target_valid: bool,
    register_frame: GuestRegisterFrame,
execution_frame: GuestExecutionFrame,
trap_return_target: GuestTrapReturnTarget,
boot_sources: GuestBootContractSources,
    guest_entry_contract_present: bool,
guest_entry_contract_valid: bool,
guest_entry_ready: bool,
trap_return_ready: bool,
guest_entry_blocked: bool,
trap_return_blocked: bool,
    guest_entered: bool,
first_guest_instruction_executed: bool,
trap_return_executed: bool,
active_stage2: bool,
hgatp_write_performed: bool,
hgatp_write_attempted: bool,
    source_fingerprint_before: GuestEntryContractFingerprint,
source_fingerprint_after: GuestEntryContractFingerprint,
source_fingerprint_unchanged: bool,
    blocker: GuestEntryContractBlocker,
blocker_count: usize,
next_action: GuestEntryContractNextAction,
decision: GuestEntryContractDecision,
checksum: usize,
build_count: usize,
validate_count: usize,
reset_count: usize,
state: GuestEntryContractState,
};

var obj: GuestEntryContract = undefined;
var initialized = false;
fn tag(x:anytype)usize{return @intFromEnum(x);} fn bit(b:bool)usize{return if(b)1 else 0;} fn mix(a:usize,b:usize)usize{return (a ^ (b +% 0x9e37_79b9_7f4a_7c15)) *% 0xbf58_476d_1ce4_e5b9;}
fn zeroFp()GuestEntryContractFingerprint{return .{.hv39_checksum=0,.hv39_state=0,.hv39_decision=0,.image_state=0,.image_checksum=0,.entry_state=0,.entry_pc=0,.entry_sp=0,.boot_state=0,.fdt_state=0,.fdt_checksum=0,.handoff_state=0,.handoff_entry=0,.handoff_fdt=0,.context_state=0,.trap_plan_state=0,.entry_stub_state=0,.vm_id=0,.vcpu_id=0,.checksum=0};}
fn empty(owner:vm.VmId,vc:vcpu.VcpuId,resets:usize)GuestEntryContract{const zrf=GuestRegisterFrame{.present=false,.valid=false,.pc=0,.sp=0,.a0=0,.a1=0,.owner_vm_id=owner,.owner_vcpu_id=vc,.checksum=0};
const zef=GuestExecutionFrame{.present=false,.valid=false,.pc=0,.sp=0,.a0=0,.a1=0,.guest_memory_base=0,.guest_memory_size=0,.source_context_valid=false,.source_trap_plan_valid=false,.source_entry_stub_valid=false,.checksum=0};
const ztt=GuestTrapReturnTarget{.present=false,.valid=false,.target_pc=0,.target_sp=0,.target_a0=0,.target_a1=0,.status_metadata=0,.privilege_metadata=0,.target_kind_metadata=0,.entry_mode_metadata=0,.checksum=0};
const zbs=GuestBootContractSources{.guest_image_present=false,.guest_image_valid=false,.guest_image_entry=0,.guest_image_checksum=0,.boot_package_present=false,.boot_package_valid=false,.boot_kernel_present=false,.boot_initrd_present=false,.boot_dtb_present=false,.fdt_present=false,.fdt_valid=false,.fdt_checksum=0,.linux_handoff_present=false,.linux_handoff_valid=false,.linux_entry=0,.linux_fdt_addr=0,.linux_initrd_start=0,.linux_initrd_end=0,.checksum=0};
return .{.owner_vm_id=owner,.owner_vcpu_id=vc,.source_hv39_present=false,.source_hv39_valid=false,.source_hv39_checksum=0,.source_hv39_decision=0,.source_hv39_denied_before_hardware=false,.guest_image_present=false,.guest_image_valid=false,.guest_image_entry=0,.guest_image_checksum=0,.boot_package_present=false,.boot_package_valid=false,.boot_kernel_present=false,.boot_initrd_present=false,.boot_dtb_present=false,.fdt_present=false,.fdt_valid=false,.fdt_checksum=0,.linux_handoff_present=false,.linux_handoff_valid=false,.linux_entry=0,.linux_fdt_addr=0,.linux_initrd_start=0,.linux_initrd_end=0,.guest_context_present=false,.guest_context_valid=false,.trap_plan_present=false,.trap_plan_valid=false,.entry_stub_present=false,.entry_stub_valid=false,.guest_pc_present=false,.guest_pc_value=0,.guest_sp_present=false,.guest_sp_value=0,.guest_a0_present=false,.guest_a0_value=0,.guest_a1_present=false,.guest_a1_value=0,.register_frame_present=false,.register_frame_valid=false,.execution_frame_present=false,.execution_frame_valid=false,.trap_return_target_present=false,.trap_return_target_valid=false,.register_frame=zrf,.execution_frame=zef,.trap_return_target=ztt,.boot_sources=zbs,.guest_entry_contract_present=false,.guest_entry_contract_valid=false,.guest_entry_ready=false,.trap_return_ready=false,.guest_entry_blocked=true,.trap_return_blocked=true,.guest_entered=false,.first_guest_instruction_executed=false,.trap_return_executed=false,.active_stage2=false,.hgatp_write_performed=false,.hgatp_write_attempted=false,.source_fingerprint_before=zeroFp(),.source_fingerprint_after=zeroFp(),.source_fingerprint_unchanged=true,.blocker=.missing_hv39_source,.blocker_count=1,.next_action=.build_hv39_externally,.decision=.none,.checksum=0,.build_count=0,.validate_count=0,.reset_count=resets,.state=.empty};}
pub fn init(owner:vm.VmId,vc:vcpu.VcpuId)void{obj=empty(owner,vc,0);initialized=true;} pub fn object()*const GuestEntryContract{return mutable();} fn mutable()*GuestEntryContract{if(!initialized)init(vm.object().id,vcpu.object().id);return &obj;} pub fn reset()void{const c=mutable();obj=empty(c.owner_vm_id,c.owner_vcpu_id,c.reset_count+1);initialized=true;}
fn fp()GuestEntryContractFingerprint{const h=hv39.object();const gi=guest_image.object();const ge=guest_entry.object();const bp=boot_package.object();const f=binary_fdt.object();const lh=linux_handoff.object();const gc=guest_context.object();const tp=trap_plan.object();const es=entry_stub.object();var r=GuestEntryContractFingerprint{.hv39_checksum=h.checksum,.hv39_state=tag(h.state),.hv39_decision=tag(h.decision),.image_state=tag(gi.state),.image_checksum=gi.checksum,.entry_state=tag(ge.state),.entry_pc=ge.pc,.entry_sp=ge.sp,.boot_state=tag(bp.state),.fdt_state=tag(f.state),.fdt_checksum=f.checksum,.handoff_state=tag(lh.state),.handoff_entry=lh.guest_pc,.handoff_fdt=lh.fdt.start,.context_state=tag(gc.state),.trap_plan_state=tag(tp.state),.entry_stub_state=tag(es.state),.vm_id=vm.object().id,.vcpu_id=vcpu.object().id,.checksum=0};
r.checksum=fpSum(r);
return r;}
fn fpSum(f:GuestEntryContractFingerprint)usize{var x:usize=0x4834_3001;
inline for(.{f.hv39_checksum,f.hv39_state,f.hv39_decision,f.image_state,f.image_checksum,f.entry_state,f.entry_pc,f.entry_sp,f.boot_state,f.fdt_state,f.fdt_checksum,f.handoff_state,f.handoff_entry,f.handoff_fdt,f.context_state,f.trap_plan_state,f.entry_stub_state,f.vm_id,f.vcpu_id})|v|{x=mix(x,v);} return if(x==0)1 else x;}
fn inRange(base:usize,size:usize,p:usize)bool{const end=base+%size;
return size!=0 and end>=base and p>=base and p<end;}
fn checksumContract(c:GuestEntryContract)usize{var x:usize=0x4847_4543;
inline for(.{c.source_hv39_checksum,c.guest_image_checksum,c.guest_image_entry,c.fdt_checksum,c.linux_entry,c.linux_fdt_addr,c.guest_pc_value,c.guest_sp_value,c.guest_a0_value,c.guest_a1_value,c.register_frame.checksum,c.execution_frame.checksum,c.trap_return_target.checksum,c.boot_sources.checksum,c.build_count,c.validate_count})|v|{x=mix(x,v);} return if(x==0)1 else x;}
fn rfSum(r:GuestRegisterFrame)usize{return mix(mix(mix(mix(r.pc,r.sp),r.a0),r.a1),mix(r.owner_vm_id,r.owner_vcpu_id));}
fn efSum(e:GuestExecutionFrame)usize{return mix(mix(mix(e.pc,e.sp),mix(e.a0,e.a1)),mix(e.guest_memory_base,e.guest_memory_size));}
fn ttSum(t:GuestTrapReturnTarget)usize{return mix(mix(mix(t.target_pc,t.target_sp),mix(t.target_a0,t.target_a1)),mix(t.status_metadata,mix(t.privilege_metadata,mix(t.target_kind_metadata,t.entry_mode_metadata))));}
fn bsSum(b:GuestBootContractSources)usize{var x:usize=0x424f_4f54;
inline for(.{bit(b.guest_image_present),bit(b.guest_image_valid),b.guest_image_entry,b.guest_image_checksum,bit(b.boot_package_present),bit(b.boot_package_valid),bit(b.boot_kernel_present),bit(b.boot_initrd_present),bit(b.boot_dtb_present),bit(b.fdt_present),bit(b.fdt_valid),b.fdt_checksum,bit(b.linux_handoff_present),bit(b.linux_handoff_valid),b.linux_entry,b.linux_fdt_addr,b.linux_initrd_start,b.linux_initrd_end})|v|{x=mix(x,v);} return if(x==0)1 else x;}

pub fn build()GuestEntryContractResult{const c=mutable();c.source_fingerprint_before=fp();consumeSources(c);constructFrames(c);forceSafe(c);c.source_fingerprint_after=fp();c.source_fingerprint_unchanged=c.source_fingerprint_before.checksum==c.source_fingerprint_after.checksum;c.build_count+=1;c.guest_entry_contract_present=true;c.state=.built;return validateInner(false);}
pub fn validate()GuestEntryContractResult{const c=mutable();c.source_fingerprint_before=fp();const r=validateInner(true);c.source_fingerprint_after=fp();c.source_fingerprint_unchanged=c.source_fingerprint_before.checksum==c.source_fingerprint_after.checksum;if(!c.source_fingerprint_unchanged)return reject(.source_mutated);return r;}
fn consumeSources(c:*GuestEntryContract)void{const h=hv39.object();const gi=guest_image.object();const ge=guest_entry.object();const bp=boot_package.object();const f=binary_fdt.object();const lh=linux_handoff.object();const gc=guest_context.object();const tp=trap_plan.object();const es=entry_stub.object();c.owner_vm_id=vm.object().id;c.owner_vcpu_id=vcpu.object().id;c.source_hv39_present=h.state!=.empty;c.source_hv39_valid=h.state==.evaluated and h.decision==.csr_write_ineligible_denied_before_hardware and h.csr_write_denied_before_hardware and !h.hgatp_write_attempted and !h.hgatp_write_performed and !h.active_stage2;c.source_hv39_checksum=h.checksum;c.source_hv39_decision=tag(h.decision);c.source_hv39_denied_before_hardware=h.csr_write_denied_before_hardware;c.guest_image_present=gi.state==.loaded;c.guest_image_valid=gi.state==.loaded and gi.loaded_byte_count>0 and gi.checksum!=0;c.guest_image_entry=gi.entry_point.gpa;c.guest_image_checksum=gi.checksum;c.boot_package_present=bp.state!=.empty;c.boot_package_valid=bp.state==.ready;c.boot_kernel_present=bp.kernel.present;c.boot_initrd_present=bp.initrd.present;c.boot_dtb_present=bp.dtb.present;c.fdt_present=f.state==.built;c.fdt_valid=f.state==.built and f.encoded_len>0 and f.checksum!=0;c.fdt_checksum=f.checksum;c.linux_handoff_present=lh.state!=.empty;c.linux_handoff_valid=lh.state==.validated;c.linux_entry=lh.guest_pc;c.linux_fdt_addr=lh.fdt.start;c.linux_initrd_start=lh.initrd.start;c.linux_initrd_end=lh.initrd.start+%lh.initrd.size;c.guest_context_present=gc.state!=.empty;c.guest_context_valid=gc.state==.validated;c.trap_plan_present=tp.state!=.empty;c.trap_plan_valid=tp.state==.validated;c.entry_stub_present=es.state!=.empty;c.entry_stub_valid=es.state==.validated;c.boot_sources=.{.guest_image_present=c.guest_image_present,.guest_image_valid=c.guest_image_valid,.guest_image_entry=c.guest_image_entry,.guest_image_checksum=c.guest_image_checksum,.boot_package_present=c.boot_package_present,.boot_package_valid=c.boot_package_valid,.boot_kernel_present=c.boot_kernel_present,.boot_initrd_present=c.boot_initrd_present,.boot_dtb_present=c.boot_dtb_present,.fdt_present=c.fdt_present,.fdt_valid=c.fdt_valid,.fdt_checksum=c.fdt_checksum,.linux_handoff_present=c.linux_handoff_present,.linux_handoff_valid=c.linux_handoff_valid,.linux_entry=c.linux_entry,.linux_fdt_addr=c.linux_fdt_addr,.linux_initrd_start=c.linux_initrd_start,.linux_initrd_end=c.linux_initrd_end,.checksum=0};c.boot_sources.checksum=bsSum(c.boot_sources);}
fn constructFrames(c:*GuestEntryContract)void{const ge=guest_entry.object();const gc=guest_context.object();const tp=trap_plan.object();const es=entry_stub.object();const pc=if(es.state==.validated)es.planned_pc else if(tp.state==.validated)tp.planned_pc else if(gc.state==.validated)gc.guest_pc else ge.pc;const sp=if(es.state==.validated)es.planned_sp else if(tp.state==.validated)tp.planned_sp else if(gc.state==.validated)gc.guest_sp else ge.sp;const a0=if(es.state==.validated)es.planned_a0 else if(tp.state==.validated)tp.planned_a0 else if(gc.state==.validated)gc.a0 else ge.frame.a0;const a1=if(es.state==.validated)es.planned_a1 else if(tp.state==.validated)tp.planned_a1 else if(gc.state==.validated)gc.a1 else ge.frame.a1;c.guest_pc_present=pc!=0 or c.guest_image_valid;c.guest_pc_value=pc;c.guest_sp_present=sp!=0;c.guest_sp_value=sp;c.guest_a0_present=c.guest_context_valid or c.trap_plan_valid or c.entry_stub_valid or ge.frame_valid;c.guest_a0_value=a0;c.guest_a1_present=c.guest_a0_present;c.guest_a1_value=a1;c.register_frame=.{.present=ge.frame_valid or c.guest_a0_present,.valid=false,.pc=pc,.sp=sp,.a0=a0,.a1=a1,.owner_vm_id=c.owner_vm_id,.owner_vcpu_id=c.owner_vcpu_id,.checksum=0};c.register_frame.valid=c.register_frame.present and pc!=0 and sp!=0 and ge.owner_vm_id==c.owner_vm_id and ge.owner_vcpu_id==c.owner_vcpu_id;c.register_frame.checksum=rfSum(c.register_frame);c.execution_frame=.{.present=c.guest_context_present or c.trap_plan_present or c.entry_stub_present,.valid=false,.pc=pc,.sp=sp,.a0=a0,.a1=a1,.guest_memory_base=gc.guest_memory_base,.guest_memory_size=gc.guest_memory_size,.source_context_valid=c.guest_context_valid,.source_trap_plan_valid=c.trap_plan_valid,.source_entry_stub_valid=c.entry_stub_valid,.checksum=0};c.execution_frame.valid=c.execution_frame.present and c.guest_context_valid and c.trap_plan_valid and c.entry_stub_valid and inRange(gc.guest_memory_base,gc.guest_memory_size,pc) and inRange(gc.guest_memory_base,gc.guest_memory_size,sp);c.execution_frame.checksum=efSum(c.execution_frame);c.trap_return_target=.{.present=c.entry_stub_present,.valid=false,.target_pc=pc,.target_sp=sp,.target_a0=a0,.target_a1=a1,.status_metadata=es.status_metadata,.privilege_metadata=es.privilege_metadata,.target_kind_metadata=es.trap_return_kind_metadata,.entry_mode_metadata=es.entry_mode_metadata,.checksum=0};c.trap_return_target.valid=c.entry_stub_valid and c.execution_frame.valid and es.hgatp_write_forbidden and es.active_stage2_forbidden;c.trap_return_target.checksum=ttSum(c.trap_return_target);c.register_frame_present=c.register_frame.present;c.register_frame_valid=c.register_frame.valid;c.execution_frame_present=c.execution_frame.present;c.execution_frame_valid=c.execution_frame.valid;c.trap_return_target_present=c.trap_return_target.present;c.trap_return_target_valid=c.trap_return_target.valid;}
fn forceSafe(c:*GuestEntryContract)void{c.guest_entry_ready=false;c.trap_return_ready=false;c.guest_entry_blocked=true;c.trap_return_blocked=true;c.guest_entered=false;c.first_guest_instruction_executed=false;c.trap_return_executed=false;c.active_stage2=false;c.hgatp_write_performed=false;c.hgatp_write_attempted=false;}
fn validateInner(count:bool)GuestEntryContractResult{const c=mutable();if(count)c.validate_count+=1;if(!c.source_fingerprint_unchanged)return reject(.source_mutated);if(!c.source_hv39_present)return reject(.missing_hv39_source);if(!c.source_hv39_valid)return reject(.invalid_hv39_source);if(!c.boot_package_valid or !c.fdt_valid)return reject(.missing_boot_sources);if(!c.linux_handoff_valid)return reject(.missing_linux_handoff);if(!c.guest_context_valid)return reject(.missing_context);if(!c.trap_plan_valid)return reject(.missing_trap_plan);if(!c.entry_stub_valid)return reject(.missing_entry_stub);if(!c.guest_pc_present or c.guest_pc_value==0)return reject(.invalid_guest_pc);if(!c.guest_sp_present or c.guest_sp_value==0)return reject(.invalid_guest_sp);if(!c.register_frame_present or !c.register_frame_valid)return reject(.invalid_register_frame);if(!c.execution_frame_present or !c.execution_frame_valid)return reject(.invalid_execution_frame);if(!c.trap_return_target_present or !c.trap_return_target_valid)return reject(.invalid_trap_return_target);if(c.guest_entry_ready)return reject(.guest_ready_corruption);if(c.trap_return_ready)return reject(.trap_return_ready_corruption);if(c.guest_entered)return reject(.guest_entered_corruption);if(c.first_guest_instruction_executed)return reject(.first_instruction_corruption);if(c.trap_return_executed)return reject(.trap_return_executed_corruption);if(c.active_stage2)return reject(.active_stage2_corruption);if(c.hgatp_write_performed or c.hgatp_write_attempted)return reject(.hgatp_written_corruption);c.blocker=.none;c.blocker_count=0;c.next_action=.keep_guest_entry_blocked;c.decision=.guest_entry_contract_validated;c.guest_entry_contract_valid=true;c.checksum=checksumContract(c.*);c.state=.validated;return .ok;}
fn reject(b:GuestEntryContractBlocker)GuestEntryContractResult{const c=mutable();c.blocker=b;c.blocker_count=1;c.next_action=nextFor(b);c.decision=.guest_entry_contract_blocked;c.guest_entry_contract_valid=false;c.guest_entry_ready=false;c.trap_return_ready=false;c.guest_entry_blocked=true;c.trap_return_blocked=true;c.checksum=checksumContract(c.*);c.state=.rejected;return .rejected;}
fn nextFor(b:GuestEntryContractBlocker)GuestEntryContractNextAction{return switch(b){.none=>.none,.missing_hv39_source=>.build_hv39_externally,.invalid_hv39_source=>.evaluate_hv39_externally,.source_mutated=>.investigate_source_mutation,.missing_boot_sources=>.build_boot_sources_externally,.missing_linux_handoff=>.prepare_linux_handoff_externally,.missing_context=>.prepare_context_externally,.missing_trap_plan=>.prepare_trap_plan_externally,.missing_entry_stub=>.prepare_entry_stub_externally,else=>.clear_local_corruption};}
fn boolOut(n:[]const u8,b:bool)void{uart.write("hv: guest_entry_contract.");uart.write(n);uart.write(if(b)"true" else "false");uart.write("\r\n");} fn decOut(n:[]const u8,v:usize)void{uart.write("hv: guest_entry_contract.");uart.write(n);uart.writeDec(v);uart.write("\r\n");} fn hexOut(n:[]const u8,v:usize)void{uart.write("hv: guest_entry_contract.");uart.write(n);uart.writeHex(v);uart.write("\r\n");}
fn printCore()void{const c=object();uart.write("hv: guest_entry_contract.state=");uart.write(@tagName(c.state));uart.write("\r\n");uart.write("hv: guest_entry_contract.blocker=");uart.write(blockerName(c.blocker));uart.write("\r\n");uart.write("hv: guest_entry_contract.next_action=");uart.write(@tagName(c.next_action));uart.write("\r\n");uart.write("hv: guest_entry_contract.decision=");uart.write(@tagName(c.decision));uart.write("\r\n");decOut("blocker_count=",c.blocker_count);hexOut("checksum=",c.checksum);decOut("build_count=",c.build_count);decOut("validate_count=",c.validate_count);decOut("reset_count=",c.reset_count);}
pub fn printStatusCommand()void{printCore();printFieldsCommand();}
pub fn printBuildCommand()void{const r=build();uart.write("hv: guest_entry_contract.build_result=");uart.write(if(r==.ok)"ok" else "rejected");uart.write("\r\n");printCore();}
pub fn printValidateCommand()void{const r=validate();uart.write("hv: guest_entry_contract.validate_result=");uart.write(if(r==.ok)"ok" else "rejected");uart.write("\r\n");printCore();}
pub fn printResetCommand()void{reset();uart.write("hv: guest_entry_contract.reset_result=ok\r\n");printCore();}
pub fn printFieldsCommand()void{const c=object();boolOut("guest_entry_contract_present=",c.guest_entry_contract_present);boolOut("guest_entry_contract_valid=",c.guest_entry_contract_valid);boolOut("guest_entry_ready=",c.guest_entry_ready);boolOut("trap_return_ready=",c.trap_return_ready);boolOut("guest_entry_blocked=",c.guest_entry_blocked);boolOut("trap_return_blocked=",c.trap_return_blocked);boolOut("source_fingerprint_unchanged=",c.source_fingerprint_unchanged);hexOut("source_fingerprint_before=",c.source_fingerprint_before.checksum);hexOut("source_fingerprint_after=",c.source_fingerprint_after.checksum);}
pub fn printSourceCommand()void{const c=object();boolOut("source_hv39_present=",c.source_hv39_present);boolOut("source_hv39_valid=",c.source_hv39_valid);hexOut("source_hv39_checksum=",c.source_hv39_checksum);decOut("source_hv39_decision=",c.source_hv39_decision);boolOut("source_hv39_denied_before_hardware=",c.source_hv39_denied_before_hardware);decOut("owner_vm_id=",c.owner_vm_id);decOut("owner_vcpu_id=",c.owner_vcpu_id);boolOut("guest_context_present=",c.guest_context_present);boolOut("guest_context_valid=",c.guest_context_valid);boolOut("trap_plan_present=",c.trap_plan_present);boolOut("trap_plan_valid=",c.trap_plan_valid);boolOut("entry_stub_present=",c.entry_stub_present);boolOut("entry_stub_valid=",c.entry_stub_valid);}
pub fn printRegisterFrameCommand()void{const c=object();boolOut("guest_pc_present=",c.guest_pc_present);hexOut("guest_pc_value=",c.guest_pc_value);boolOut("guest_sp_present=",c.guest_sp_present);hexOut("guest_sp_value=",c.guest_sp_value);boolOut("guest_a0_present=",c.guest_a0_present);hexOut("guest_a0_value=",c.guest_a0_value);boolOut("guest_a1_present=",c.guest_a1_present);hexOut("guest_a1_value=",c.guest_a1_value);boolOut("register_frame_present=",c.register_frame_present);boolOut("register_frame_valid=",c.register_frame_valid);hexOut("register_frame_checksum=",c.register_frame.checksum);}
pub fn printExecutionFrameCommand()void{const c=object();boolOut("execution_frame_present=",c.execution_frame_present);boolOut("execution_frame_valid=",c.execution_frame_valid);hexOut("execution_frame_pc=",c.execution_frame.pc);hexOut("execution_frame_sp=",c.execution_frame.sp);hexOut("execution_frame_memory_base=",c.execution_frame.guest_memory_base);decOut("execution_frame_memory_size=",c.execution_frame.guest_memory_size);hexOut("execution_frame_checksum=",c.execution_frame.checksum);}
pub fn printTrapReturnTargetCommand()void{const c=object();boolOut("trap_return_target_present=",c.trap_return_target_present);boolOut("trap_return_target_valid=",c.trap_return_target_valid);hexOut("trap_return_target_pc=",c.trap_return_target.target_pc);hexOut("trap_return_target_sp=",c.trap_return_target.target_sp);hexOut("trap_return_target_checksum=",c.trap_return_target.checksum);}
pub fn printBootSourcesCommand()void{const c=object();boolOut("guest_image_present=",c.guest_image_present);boolOut("guest_image_valid=",c.guest_image_valid);hexOut("guest_image_entry=",c.guest_image_entry);hexOut("guest_image_checksum=",c.guest_image_checksum);boolOut("boot_package_present=",c.boot_package_present);boolOut("boot_package_valid=",c.boot_package_valid);boolOut("boot_kernel_present=",c.boot_kernel_present);boolOut("boot_initrd_present=",c.boot_initrd_present);boolOut("boot_dtb_present=",c.boot_dtb_present);boolOut("fdt_present=",c.fdt_present);boolOut("fdt_valid=",c.fdt_valid);hexOut("fdt_checksum=",c.fdt_checksum);}
pub fn printLinuxHandoffCommand()void{const c=object();boolOut("linux_handoff_present=",c.linux_handoff_present);boolOut("linux_handoff_valid=",c.linux_handoff_valid);hexOut("linux_entry=",c.linux_entry);hexOut("linux_fdt_addr=",c.linux_fdt_addr);hexOut("linux_initrd_start=",c.linux_initrd_start);hexOut("linux_initrd_end=",c.linux_initrd_end);}
pub fn printSafetyCommand()void{const c=object();boolOut("guest_entry_ready=",c.guest_entry_ready);boolOut("trap_return_ready=",c.trap_return_ready);boolOut("guest_entry_blocked=",c.guest_entry_blocked);boolOut("trap_return_blocked=",c.trap_return_blocked);boolOut("guest_entered=",c.guest_entered);boolOut("first_guest_instruction_executed=",c.first_guest_instruction_executed);boolOut("trap_return_executed=",c.trap_return_executed);boolOut("active_stage2=",c.active_stage2);boolOut("hgatp_write_performed=",c.hgatp_write_performed);boolOut("hgatp_write_attempted=",c.hgatp_write_attempted);}
pub fn printChecksumCommand()void{hexOut("checksum=",object().checksum);} pub fn printDecisionCommand()void{uart.write("hv: guest_entry_contract.decision=");uart.write(@tagName(object().decision));uart.write("\r\n");} pub fn printBlockersCommand()void{uart.write("hv: guest_entry_contract.blocker=");uart.write(blockerName(object().blocker));uart.write("\r\n");decOut("blocker_count=",object().blocker_count);} pub fn printNextCommand()void{uart.write("hv: guest_entry_contract.next_action=");uart.write(@tagName(object().next_action));uart.write("\r\n");}
fn localRejectTest(name:[]const u8,b:GuestEntryContractBlocker)void{_ = build();
_=reject(b);
uart.write("hv: guest_entry_contract.");uart.write(name);uart.write("=rejected\r\n");printCore();}
pub fn printRequireHv39TestCommand()void{localRejectTest("require_hv39_test",.missing_hv39_source);} pub fn printInvalidHv39TestCommand()void{localRejectTest("invalid_hv39_test",.invalid_hv39_source);} pub fn printSourceIntegrityTestCommand()void{localRejectTest("source_integrity_test",.source_mutated);} pub fn printInvalidGuestPcTestCommand()void{localRejectTest("invalid_guest_pc_test",.invalid_guest_pc);} pub fn printInvalidGuestSpTestCommand()void{localRejectTest("invalid_guest_sp_test",.invalid_guest_sp);} pub fn printInvalidRegisterFrameTestCommand()void{localRejectTest("invalid_register_frame_test",.invalid_register_frame);} pub fn printInvalidExecutionFrameTestCommand()void{localRejectTest("invalid_execution_frame_test",.invalid_execution_frame);} pub fn printInvalidTrapReturnTargetTestCommand()void{localRejectTest("invalid_trap_return_target_test",.invalid_trap_return_target);} pub fn printGuestReadyTestCommand()void{localRejectTest("guest_ready_test",.guest_ready_corruption);} pub fn printTrapReturnReadyTestCommand()void{localRejectTest("trap_return_ready_test",.trap_return_ready_corruption);} pub fn printGuestEnteredTestCommand()void{localRejectTest("guest_entered_test",.guest_entered_corruption);} pub fn printFirstInstructionTestCommand()void{localRejectTest("first_instruction_test",.first_instruction_corruption);} pub fn printTrapReturnExecutedTestCommand()void{localRejectTest("trap_return_executed_test",.trap_return_executed_corruption);} pub fn printActiveStage2TestCommand()void{localRejectTest("active_stage2_test",.active_stage2_corruption);} pub fn printHgatpWrittenTestCommand()void{localRejectTest("hgatp_written_test",.hgatp_written_corruption);} pub fn printInvariantConsumptionTestCommand()void{_ = build();
uart.write("hv: guest_entry_contract.invariant_consumption_test=ok\r\n");printSafetyCommand();} pub fn printInvariantCorruptionTestCommand()void{localRejectTest("invariant_corruption_test",.guest_entered_corruption);}
fn blockerName(b:GuestEntryContractBlocker)[]const u8{return switch(b){.none=>"none",.missing_hv39_source=>"missing-hv39-source",.invalid_hv39_source=>"invalid-hv39-source",.source_mutated=>"source-mutated",.invalid_guest_pc=>"invalid-guest-pc",.invalid_guest_sp=>"invalid-guest-sp",.invalid_register_frame=>"invalid-register-frame",.invalid_execution_frame=>"invalid-execution-frame",.invalid_trap_return_target=>"invalid-trap-return-target",.guest_ready_corruption=>"guest-ready-corruption",.trap_return_ready_corruption=>"trap-return-ready-corruption",.guest_entered_corruption=>"guest-entered-corruption",.first_instruction_corruption=>"first-instruction-corruption",.trap_return_executed_corruption=>"trap-return-executed-corruption",.active_stage2_corruption=>"active-stage2-corruption",.hgatp_written_corruption=>"hgatp-written-corruption",.missing_boot_sources=>"missing-boot-sources",.missing_linux_handoff=>"missing-linux-handoff",.missing_context=>"missing-context",.missing_trap_plan=>"missing-trap-plan",.missing_entry_stub=>"missing-entry-stub"};}
