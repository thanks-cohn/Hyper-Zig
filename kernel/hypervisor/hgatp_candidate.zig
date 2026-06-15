const uart = @import("../console/uart.zig");
const pmm = @import("../memory/pmm.zig");
const vm_model = @import("vm.zig");
const vcpu_model = @import("vcpu.zig");
const guest_memory = @import("guest_memory.zig");
const guest_address_space = @import("guest_address_space.zig");
const second_stage = @import("second_stage.zig");
const stage2_table = @import("stage2_table.zig");
const h_extension = @import("h_extension.zig");

pub const HgatpCandidateState = enum {
   
empty,
    built,
    validated,
    rejected

};
pub const HgatpCandidateBlocker = enum {
   
none,
    empty_candidate,
    missing_vm_source,
    missing_vcpu_source,
    missing_guest_address_space_source,
    missing_stage2_metadata_source,
    missing_stage2_table_source,
    missing_h_extension_discovery_source,
    missing_csr_safety_source,
    invalid_mode,
    vmid_out_of_bounds,
    root_ppn_misaligned,
    root_ppn_out_of_bounds,
    hgatp_write_attempted,
    active_stage2_forbidden

};
pub const HgatpCandidateSourceSummary = struct {
   
vm_present: bool,
    vcpu_present: bool,
    guest_address_space_present: bool,
    stage2_metadata_present: bool,
    stage2_table_present: bool,
    h_extension_discovery_present: bool,
    csr_safety_present: bool

};
pub const HgatpCandidateFields = struct {
   
mode_name: []const u8,
    mode_value: usize,
    vmid: usize,
    vmid_bits: usize,
    root_table_gpa: usize,
    root_ppn: usize,
    candidate_value: usize,
    checksum: usize

};
pub const HgatpCandidate = struct {
   
    owner_vm_id: vm_model.VmId,
    owner_vcpu_id: vcpu_model.VcpuId,
    source_vm_present: bool,
    source_vcpu_present: bool,
    source_guest_address_space_present: bool,
    source_stage2_metadata_present: bool,
    source_stage2_table_present: bool,
    source_h_extension_discovery_present: bool,
    source_csr_safety_present: bool,
    mode_name: []const u8,
    mode_value: usize,
    mode_allowed: bool,
    vmid: usize,
    vmid_bits: usize,
    vmid_in_bounds: bool,
    root_table_gpa: usize,
    root_ppn: usize,
    root_ppn_aligned: bool,
    root_ppn_in_bounds: bool,
    candidate_value: usize,
    checksum: usize,
    state: HgatpCandidateState,
    ready: bool,
    last_error: HgatpCandidateBlocker,
    build_count: usize,
    validate_count: usize,
    reject_count: usize,
    reset_count: usize,
    hgatp_write_attempted: bool,
    active_stage2: bool,

};

const hgatp_mode_sv39x4: usize = 8;
const hgatp_vmid_bits: usize = 14;
const hgatp_ppn_bits: usize = 44;
const empty_mode_name = "none";
const sv39x4_mode_name = "sv39x4-software-candidate";
var candidate: HgatpCandidate = undefined;
var initialized: bool = false;

pub fn init(owner: vm_model.VmId,
    owner_vcpu: vcpu_model.VcpuId) void {
candidate = empty(owner,
    owner_vcpu,
    0);
initialized = true;
}
pub fn object() *const HgatpCandidate {
return mutable();
}
fn mutable() *HgatpCandidate {
if (!initialized) init(vm_model.object().id,
    vcpu_model.object().id);
return &candidate;
}
fn empty(owner: vm_model.VmId,
    owner_vcpu: vcpu_model.VcpuId,
    resets: usize) HgatpCandidate {
return .{
.owner_vm_id=owner,
    .owner_vcpu_id=owner_vcpu,
    .source_vm_present=false,
    .source_vcpu_present=false,
    .source_guest_address_space_present=false,
    .source_stage2_metadata_present=false,
    .source_stage2_table_present=false,
    .source_h_extension_discovery_present=false,
    .source_csr_safety_present=false,
    .mode_name=empty_mode_name,
    .mode_value=0,
    .mode_allowed=false,
    .vmid=0,
    .vmid_bits=hgatp_vmid_bits,
    .vmid_in_bounds=false,
    .root_table_gpa=0,
    .root_ppn=0,
    .root_ppn_aligned=false,
    .root_ppn_in_bounds=false,
    .candidate_value=0,
    .checksum=0,
    .state=.empty,
    .ready=false,
    .last_error=.none,
    .build_count=0,
    .validate_count=0,
    .reject_count=0,
    .reset_count=resets,
    .hgatp_write_attempted=false,
    .active_stage2=false

};
}
pub fn reset() void {
const c=mutable();
candidate = empty(c.owner_vm_id,
    c.owner_vcpu_id,
    c.reset_count + 1);
initialized = true;
}

fn maxForBits(bits: usize) usize {
return (@as(usize,
    1) << @intCast(bits)) - 1;
}
fn sourceSummary() HgatpCandidateSourceSummary {
const v=vm_model.object();
const vc=vcpu_model.object();
const as=guest_address_space.object();
const ss=second_stage.object();
const table=stage2_table.object();
const he=h_extension.object();
return .{
.vm_present=(v.state == .defined),
    .vcpu_present=(vc.vm_id == v.id),
    .guest_address_space_present=(as.state == .configured and as.translated_page_count > 0),
    .stage2_metadata_present=(ss.state == .metadata_ready and ss.mapping.validated and !ss.mapping.active),
    .stage2_table_present=((table.state == .built or table.state == .validated) and table.entry_count > 0 and !table.active),
    .h_extension_discovery_present=(he.state == .discovered or he.state == .validated),
    .csr_safety_present=he.unsafe_csr_read_forbidden and he.hgatp_write_status == .not_attempted

};
}
fn encode(mode: usize,
    vmid: usize,
    ppn: usize) usize {
const mode_shift: u6 = 60;
const vmid_shift: u6 = 44;
return (mode << mode_shift) | (vmid << vmid_shift) | ppn;
}
fn checksumFor(c: HgatpCandidate) usize {
var x: usize = 0x9e37_79b9_7f4a_7c15;
x ^= @intCast(c.owner_vm_id);
x = x *% 0xbf58_476d_1ce4_e5b9;
x ^= @intCast(c.owner_vcpu_id);
x = x *% 0x94d0_49bb_1331_11eb;
x ^= c.mode_value;
x ^= c.vmid << 7;
x ^= c.root_table_gpa << 11;
x ^= c.root_ppn << 17;
x ^= c.candidate_value;
if (x == 0) return 1;
return x;
}
fn refreshDerived(c: *HgatpCandidate) void {
c.mode_allowed = c.mode_value == hgatp_mode_sv39x4;
c.vmid_in_bounds = c.vmid <= maxForBits(c.vmid_bits);
c.root_ppn_aligned = (c.root_table_gpa % pmm.page_size) == 0;
c.root_ppn = c.root_table_gpa / pmm.page_size;
c.root_ppn_in_bounds = c.root_ppn <= maxForBits(hgatp_ppn_bits);
c.candidate_value = encode(c.mode_value,
    c.vmid,
    c.root_ppn);
c.checksum = checksumFor(c.*);
}

fn ensurePrerequisites() void {
if (guest_memory.object().state != .configured) _ = guest_memory.configureDefault();
if (guest_address_space.object().state != .configured) _ = guest_address_space.ensureCreatedWithGuestMemory();
_ = second_stage.configureFromCurrentGuest();
_ = second_stage.validateCurrent();
_ = stage2_table.buildFromSecondStageMetadata();
_ = stage2_table.validateCurrent();
_ = h_extension.discoverSafe();
_ = h_extension.validate();
}

pub fn build() HgatpCandidateBlocker {
const c=mutable();
c.build_count += 1;
ensurePrerequisites();
const src=sourceSummary();
c.owner_vm_id = vm_model.object().id;
c.owner_vcpu_id = vcpu_model.object().id;
c.source_vm_present=src.vm_present;
c.source_vcpu_present=src.vcpu_present;
c.source_guest_address_space_present=src.guest_address_space_present;
c.source_stage2_metadata_present=src.stage2_metadata_present;
c.source_stage2_table_present=src.stage2_table_present;
c.source_h_extension_discovery_present=src.h_extension_discovery_present;
c.source_csr_safety_present=src.csr_safety_present;
c.mode_name=sv39x4_mode_name;
c.mode_value=hgatp_mode_sv39x4;
c.vmid=@intCast(c.owner_vm_id);
c.vmid_bits=hgatp_vmid_bits;
const table=stage2_table.object();
c.root_table_gpa = if (table.entry_count > 0) table.entries[0].guest_page_base else 0;
c.hgatp_write_attempted=false;
c.active_stage2=false;
refreshDerived(c);
c.state=.built;
c.ready=false;
c.last_error=.none;
return validate();
}

pub fn validate() HgatpCandidateBlocker {
const c=mutable();
c.validate_count += 1;
const b = firstBlocker(c.*);
if (b != .none) {
c.reject_count += 1;
c.state=.rejected;
c.ready=false;
c.last_error=b;
return b;
} c.state=.validated;
c.ready=true;
c.last_error=.none;
return .none;
}
fn firstBlocker(c: HgatpCandidate) HgatpCandidateBlocker {
if (c.state == .empty or c.candidate_value == 0 or c.checksum == 0) return .empty_candidate;
if (!c.source_vm_present) return .missing_vm_source;
if (!c.source_vcpu_present) return .missing_vcpu_source;
if (!c.source_guest_address_space_present) return .missing_guest_address_space_source;
if (!c.source_stage2_metadata_present) return .missing_stage2_metadata_source;
if (!c.source_stage2_table_present) return .missing_stage2_table_source;
if (!c.source_h_extension_discovery_present) return .missing_h_extension_discovery_source;
if (!c.source_csr_safety_present) return .missing_csr_safety_source;
if (!c.mode_allowed or c.mode_value != hgatp_mode_sv39x4) return .invalid_mode;
if (!c.vmid_in_bounds or c.vmid > maxForBits(c.vmid_bits)) return .vmid_out_of_bounds;
if (!c.root_ppn_aligned or (c.root_table_gpa % pmm.page_size) != 0) return .root_ppn_misaligned;
if (!c.root_ppn_in_bounds or c.root_ppn > maxForBits(hgatp_ppn_bits)) return .root_ppn_out_of_bounds;
if (c.hgatp_write_attempted) return .hgatp_write_attempted;
if (c.active_stage2) return .active_stage2_forbidden;
return .none;
}

pub fn mutateVmidForTest() bool {
reset();
_=build();
const c=mutable();
const old_value=c.candidate_value;
const old_sum=c.checksum;
c.vmid = (c.vmid + 1) & maxForBits(c.vmid_bits);
refreshDerived(c);
return old_value != c.candidate_value and old_sum != c.checksum;
}
pub fn mutateRootPpnForTest() bool {
reset();
_=build();
const c=mutable();
const old_value=c.candidate_value;
const old_sum=c.checksum;
c.root_table_gpa +%= pmm.page_size;
refreshDerived(c);
return old_value != c.candidate_value or old_sum != c.checksum;
}
fn corrupt(kind: HgatpCandidateBlocker) HgatpCandidateBlocker {
reset();
_=build();
const c=mutable();
switch (kind) {
.invalid_mode => {
c.mode_value=15;
c.mode_allowed=false;
},
    .vmid_out_of_bounds => {
c.vmid=maxForBits(c.vmid_bits)+1;
c.vmid_in_bounds=false;
},
    .root_ppn_misaligned => {
c.root_table_gpa += 1;
c.root_ppn_aligned=false;
},
    .missing_h_extension_discovery_source => c.source_h_extension_discovery_present=false,
    .hgatp_write_attempted => c.hgatp_write_attempted=true,
    .active_stage2_forbidden => c.active_stage2 = (kind == .active_stage2_forbidden),
    else => {}
} refreshDerived(c);
if (kind == .invalid_mode) c.mode_allowed=false;
if (kind == .vmid_out_of_bounds) c.vmid_in_bounds=false;
if (kind == .root_ppn_misaligned) c.root_ppn_aligned=false;
return validate();
}
pub fn corruptModeTest() HgatpCandidateBlocker {
return corrupt(.invalid_mode);
}
pub fn corruptVmidBoundsTest() HgatpCandidateBlocker {
return corrupt(.vmid_out_of_bounds);
}
pub fn corruptPpnAlignmentTest() HgatpCandidateBlocker {
return corrupt(.root_ppn_misaligned);
}
pub fn removeHExtensionSourceTest() HgatpCandidateBlocker {
return corrupt(.missing_h_extension_discovery_source);
}
pub fn writeAttemptTest() HgatpCandidateBlocker {
return corrupt(.hgatp_write_attempted);
}
pub fn activeStage2Test() HgatpCandidateBlocker {
return corrupt(.active_stage2_forbidden);
}

pub fn invariantLifecycle() bool {
reset();
const empty_reject = validate() == .empty_candidate;
const before_build = object().build_count;
_=build();
const build_inc = object().build_count == before_build + 1;
const checksum_nonzero = object().checksum != 0;
const before_validate = object().validate_count;
_=validate();
const validate_inc = object().validate_count == before_validate + 1;
reset();
const cleared = object().state == .empty and object().candidate_value == 0 and !object().ready;
return empty_reject and build_inc and checksum_nonzero and validate_inc and cleared;
}
pub fn invariantDerivation() bool {
const vmid_changed = mutateVmidForTest();
const root_changed = mutateRootPpnForTest();
return vmid_changed and root_changed;
}
pub fn invariantCorruption() bool {
return corruptModeTest() == .invalid_mode and corruptVmidBoundsTest() == .vmid_out_of_bounds and corruptPpnAlignmentTest() == .root_ppn_misaligned and removeHExtensionSourceTest() == .missing_h_extension_discovery_source and writeAttemptTest() == .hgatp_write_attempted and activeStage2Test() == .active_stage2_forbidden;
}

pub fn printStatusCommand() void {
printSummary();
printBlockers();
printPolicy();
}
pub fn printBuildCommand() void {
const b=build();
printBlockerResult("build_result",
    b);
printSummary();
printPolicy();
}
pub fn printValidateCommand() void {
const b=validate();
printBlockerResult("validate_result",
    b);
printSummary();
printBlockers();
printPolicy();
}
pub fn printBlockersCommand() void {
_=validate();
printBlockers();
printPolicy();
}
pub fn printFieldsCommand() void {
printFields();
printPolicy();
}
pub fn printChecksumCommand() void {
const c=object();
uart.write("hv: hgatp_candidate.checksum=");
uart.writeHex(c.checksum);
uart.write("\r\n");
printPolicy();
}
pub fn printResetCommand() void {
reset();
uart.write("hv: hgatp_candidate.reset_result=ok\r\n");
printSummary();
printPolicy();
}
pub fn printInvariantLifecycleCommand() void {
uart.write("hv: hgatp_candidate.invariant_lifecycle_result=");
uart.write(if (invariantLifecycle()) "ok" else "rejected");
uart.write("\r\n");
printSummary();
printPolicy();
}
pub fn printInvariantDerivationCommand() void {
uart.write("hv: hgatp_candidate.invariant_derivation_result=");
uart.write(if (invariantDerivation()) "ok" else "rejected");
uart.write("\r\n");
printSummary();
printPolicy();
}
pub fn printInvariantCorruptionCommand() void {
uart.write("hv: hgatp_candidate.invariant_corruption_result=");
uart.write(if (invariantCorruption()) "ok" else "rejected");
uart.write("\r\n");
printSummary();
printPolicy();
}
pub fn printModeTestCommand() void {
printBlockerResult("mode_test",
    corruptModeTest());
printBlockers();
printPolicy();
}
pub fn printPpnAlignmentTestCommand() void {
printBlockerResult("ppn_alignment_test",
    corruptPpnAlignmentTest());
printBlockers();
printPolicy();
}
pub fn printVmidBoundsTestCommand() void {
printBlockerResult("vmid_bounds_test",
    corruptVmidBoundsTest());
printBlockers();
printPolicy();
}
pub fn printRequireHextTestCommand() void {
printBlockerResult("require_hext_test",
    removeHExtensionSourceTest());
printBlockers();
printPolicy();
}
pub fn printWriteAttemptTestCommand() void {
printBlockerResult("write_attempt_test",
    writeAttemptTest());
printBlockers();
printPolicy();
}
pub fn printActiveStage2TestCommand() void {
printBlockerResult("active_stage2_test",
    activeStage2Test());
printBlockers();
printPolicy();
}

fn printBlockerResult(label: []const u8,
    b: HgatpCandidateBlocker) void {
uart.write("hv: hgatp_candidate.");
uart.write(label);
uart.write("=");
uart.write(if (b == .none) "ok" else "rejected");
uart.write("\r\n");
uart.write("hv: hgatp_candidate.result_blocker=");
uart.write(blockerName(b));
uart.write("\r\n");
}
fn printSummary() void {
const c=object();
uart.write("hv: hgatp_candidate=software-only\r\n");
uart.write("hv: hgatp_candidate.state=");
uart.write(@tagName(c.state));
uart.write("\r\n");
uart.write("hv: hgatp_candidate.ready=");
uart.write(if (c.ready) "true" else "false");
uart.write("\r\n");
uart.write("hv: hgatp_candidate.owner_vm_id=");
uart.writeDec(c.owner_vm_id);
uart.write("\r\n");
uart.write("hv: hgatp_candidate.owner_vcpu_id=");
uart.writeDec(c.owner_vcpu_id);
uart.write("\r\n");
uart.write("hv: hgatp_candidate.build_count=");
uart.writeDec(c.build_count);
uart.write("\r\n");
uart.write("hv: hgatp_candidate.validate_count=");
uart.writeDec(c.validate_count);
uart.write("\r\n");
uart.write("hv: hgatp_candidate.reject_count=");
uart.writeDec(c.reject_count);
uart.write("\r\n");
uart.write("hv: hgatp_candidate.reset_count=");
uart.writeDec(c.reset_count);
uart.write("\r\n");
uart.write("hv: hgatp_candidate.last_error=");
uart.write(blockerName(c.last_error));
uart.write("\r\n");
}
fn printFields() void {
const c=object();
uart.write("hv: hgatp_candidate.mode=");
uart.write(c.mode_name);
uart.write("\r\n");
uart.write("hv: hgatp_candidate.mode_value=");
uart.writeDec(c.mode_value);
uart.write("\r\n");
uart.write("hv: hgatp_candidate.vmid=");
uart.writeDec(c.vmid);
uart.write("\r\n");
uart.write("hv: hgatp_candidate.root_table_gpa=");
uart.writeHex(c.root_table_gpa);
uart.write("\r\n");
uart.write("hv: hgatp_candidate.root_ppn=");
uart.writeHex(c.root_ppn);
uart.write("\r\n");
uart.write("hv: hgatp_candidate.candidate_value=");
uart.writeHex(c.candidate_value);
uart.write("\r\n");
uart.write("hv: hgatp_candidate.checksum=");
uart.writeHex(c.checksum);
uart.write("\r\n");
}
fn printBlockers() void {
const c=object();
const count: usize = if (c.last_error == .none) 0 else 1;
uart.write("hv: hgatp_candidate.blocker_count=");
uart.writeDec(count);
uart.write("\r\n");
uart.write("hv: hgatp_candidate.blocker=");
uart.write(blockerName(c.last_error));
uart.write("\r\n");
}
fn printPolicy() void {
const c=object();
uart.write("hv: hgatp_candidate.hgatp_write_attempted=");
uart.write(if (c.hgatp_write_attempted) "yes" else "no");
uart.write("\r\n");
uart.write("hv: hgatp_candidate.active_stage2=");
uart.write(if (c.active_stage2) "yes" else "no");
uart.write("\r\n");
uart.write("hv: hgatp_candidate.software_only=true\r\n");
uart.write("hv: hgatp_write=not-attempted\r\n");
uart.write("hv: second_stage_translation=MISSING\r\n");
uart.write("hv: guest_execution=not-supported-yet\r\n");
uart.write("hv: linux_guest=not-supported-yet\r\n");
}
fn blockerName(b: HgatpCandidateBlocker) []const u8 {
return switch (b) {
.none=>"none",
    .empty_candidate=>"empty-candidate",
    .missing_vm_source=>"missing-vm-source",
    .missing_vcpu_source=>"missing-vcpu-source",
    .missing_guest_address_space_source=>"missing-guest-address-space-source",
    .missing_stage2_metadata_source=>"missing-stage2-metadata-source",
    .missing_stage2_table_source=>"missing-stage2-table-source",
    .missing_h_extension_discovery_source=>"missing-h-extension-discovery-source",
    .missing_csr_safety_source=>"missing-csr-safety-source",
    .invalid_mode=>"invalid-mode",
    .vmid_out_of_bounds=>"vmid-out-of-bounds",
    .root_ppn_misaligned=>"root-ppn-misaligned",
    .root_ppn_out_of_bounds=>"root-ppn-out-of-bounds",
    .hgatp_write_attempted=>"hgatp-write-attempted",
    .active_stage2_forbidden=>"active-stage2-forbidden"

};
}
