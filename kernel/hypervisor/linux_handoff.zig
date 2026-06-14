const uart = @import("../console/uart.zig");
const vm = @import("vm.zig");
const vcpu = @import("vcpu.zig");
const guest_memory = @import("guest_memory.zig");
const guest_image = @import("guest_image.zig");
const guest_entry = @import("guest_entry.zig");
const boot_package = @import("boot_package.zig");
const guest_dtb = @import("guest_dtb.zig");
const binary_fdt = @import("binary_fdt.zig");
const sbi = @import("sbi.zig");
const virtual_timer = @import("virtual_timer.zig");
const second_stage = @import("second_stage.zig");
const stage2_table = @import("stage2_table.zig");

pub const FdtPlacement = enum { none, guest_memory, metadata_only };
pub const State = enum { empty, assembled, validated };
pub const Result = enum { ok, rejected };
pub const Error = enum { none, owner_mismatch, guest_memory_missing, guest_image_missing, boot_package_missing, dtb_contract_missing, binary_fdt_missing, kernel_bounds, entry_bounds, initrd_bounds, fdt_bounds, range_overlap, pc_mismatch, bootargs_missing, guest_entry_missing, sbi_missing, virtual_timer_missing, active_stage2_forbidden, stage2_metadata_missing };

const Range = struct { present: bool, start: usize, size: usize };

pub const Package = struct {
    owner_vm_id: vm.VmId, owner_vcpu_id: vcpu.VcpuId, state: State,
    guest_memory_base: usize, guest_memory_size: usize,
    guest_image_start: usize, guest_image_size: usize,
    kernel_load_gpa: usize, kernel_entry_gpa: usize,
    initrd: Range, fdt: Range, fdt_placement: FdtPlacement,
    bootargs: [boot_package.max_cmdline_bytes]u8, bootargs_len: usize,
    guest_pc: usize, guest_sp: usize,
    fdt_magic: u32, fdt_totalsize: u32, fdt_version: u32, fdt_struct_size: u32, fdt_strings_size: u32, fdt_checksum: u32,
    sbi_ready: bool, virtual_timer_ready: bool, stage2_metadata_ready: bool, active_stage2_claimed: bool,
    prepare_count: usize, validate_count: usize, reject_count: usize, reset_count: usize,
    last_error: Error,
};

var pkg: Package = undefined;
var initialized = false;

pub fn init(owner: vm.VmId, owner_vcpu: vcpu.VcpuId) void { pkg = empty(owner, owner_vcpu, 0); initialized = true; }
pub fn object() *const Package { return mutable(); }
fn mutable() *Package { if (!initialized) init(vm.object().id, vcpu.object().id); return &pkg; }
fn empty(owner: vm.VmId, owner_vcpu: vcpu.VcpuId, resets: usize) Package { return .{ .owner_vm_id=owner,.owner_vcpu_id=owner_vcpu,.state=.empty,.guest_memory_base=0,.guest_memory_size=0,.guest_image_start=0,.guest_image_size=0,.kernel_load_gpa=0,.kernel_entry_gpa=0,.initrd=.{.present=false,.start=0,.size=0},.fdt=.{.present=false,.start=0,.size=0},.fdt_placement=.none,.bootargs=[_]u8{0} ** boot_package.max_cmdline_bytes,.bootargs_len=0,.guest_pc=0,.guest_sp=0,.fdt_magic=0,.fdt_totalsize=0,.fdt_version=0,.fdt_struct_size=0,.fdt_strings_size=0,.fdt_checksum=0,.sbi_ready=false,.virtual_timer_ready=false,.stage2_metadata_ready=false,.active_stage2_claimed=false,.prepare_count=0,.validate_count=0,.reject_count=0,.reset_count=resets,.last_error=.none }; }
pub fn reset() void { const p=mutable(); pkg = empty(p.owner_vm_id, p.owner_vcpu_id, p.reset_count + 1); initialized = true; }

pub const Blockers = struct {
    owner_mismatch: bool=false, guest_memory_missing: bool=false, guest_image_missing: bool=false, boot_package_missing: bool=false, dtb_contract_missing: bool=false, binary_fdt_missing: bool=false, kernel_bounds: bool=false, entry_bounds: bool=false, initrd_bounds: bool=false, fdt_bounds: bool=false, range_overlap: bool=false, pc_mismatch: bool=false, bootargs_missing: bool=false, guest_entry_missing: bool=false, sbi_missing: bool=false, virtual_timer_missing: bool=false, active_stage2_forbidden: bool=false, stage2_metadata_missing: bool=false,
    fn any(self: Blockers) bool { return self.count() != 0; }
    fn count(self: Blockers) usize { var n:usize=0; inline for (@typeInfo(Blockers).Struct.fields) |f| if (@field(self, f.name)) n += 1; return n; }
};

fn end(r: Range) ?usize { if (!r.present) return r.start; if (r.size == 0 or r.start > (~@as(usize,0)) - r.size) return null; return r.start + r.size; }
fn inGuest(base: usize, size: usize, r: Range) bool { const e=end(r) orelse return false; return r.present and r.start >= base and e <= base + size; }
fn pointInGuest(base: usize, size: usize, p: usize) bool { return p >= base and p < base + size; }
fn overlap(a: Range, b: Range) bool { const ae=end(a) orelse return true; const be=end(b) orelse return true; return a.present and b.present and a.start < be and b.start < ae; }
fn copyArgs(dst: *Package, src: []const u8) void { var i:usize=0; while (i < dst.bootargs.len) : (i+=1) dst.bootargs[i]=0; i=0; while (i<src.len and i<dst.bootargs.len) : (i+=1) dst.bootargs[i]=src[i]; dst.bootargs_len=src.len; }
fn reject(e: Error) Result { const p=mutable(); p.reject_count += 1; p.last_error=e; if (p.state == .validated) p.state = .assembled; return .rejected; }

pub fn preparePrerequisites() Result {
    if (guest_memory.object().state != .configured and guest_memory.configureDefault() != .ok) return reject(.guest_memory_missing);
    if (guest_image.object().state != .loaded and guest_image.loadTiny().result != .ok) return reject(.guest_image_missing);
    boot_package.reset();
    if (boot_package.attachKernelFromHv6Tiny() != .ok) return reject(.boot_package_missing);
    if (boot_package.setCmdline("root=/dev/ram0 console=hvc0 earlycon") != .ok) return reject(.bootargs_missing);
    if (boot_package.setEntry(guest_image.object().entry_point.gpa) != .ok) return reject(.entry_bounds);
    if (boot_package.attachInitrd(boot_package.default_initrd_gpa, boot_package.default_initrd_size) != .ok) return reject(.initrd_bounds);
    if (boot_package.attachDtb(boot_package.default_dtb_gpa, boot_package.default_dtb_size) != .ok) return reject(.fdt_bounds);
    if (boot_package.validate() != .ok) return reject(.boot_package_missing);
    guest_dtb.reset(); if (guest_dtb.buildFromBootPackage(guest_dtb.default_dtb_gpa, guest_dtb.default_payload_size) != .ok) return reject(.dtb_contract_missing);
    binary_fdt.reset(); if (binary_fdt.buildFromDtbContract(binary_fdt.default_capacity) != .ok) return reject(.binary_fdt_missing);
    if (guest_entry.prepare().result != .ok) return reject(.guest_entry_missing);
    _ = sbi.recordRequest(0x10, 0, [_]usize{0} ** 6);
    if (virtual_timer.applySbiTimerSet(100, 40) != .ok) return reject(.virtual_timer_missing);
    if (second_stage.object().state != .metadata_ready and second_stage.configureFromCurrentGuest() != .ok) return reject(.stage2_metadata_missing);
    if (stage2_table.object().state == .empty and stage2_table.buildFromSecondStageMetadata().result != .ok) return reject(.stage2_metadata_missing);
    return assemble();
}

pub fn assemble() Result {
    const p=mutable(); p.owner_vm_id=vm.object().id; p.owner_vcpu_id=vcpu.object().id;
    const gm=guest_memory.object(); const img=guest_image.object(); const bp=boot_package.object(); const dtb=guest_dtb.object(); const fdt=binary_fdt.object(); const ge=guest_entry.object(); const timer=virtual_timer.object(); const st=stage2_table.object();
    p.guest_memory_base = 0; p.guest_memory_size = gm.size_bytes; p.guest_image_start=img.guest_load_base; p.guest_image_size=img.loaded_byte_count; p.kernel_load_gpa=bp.kernel_load_gpa; p.kernel_entry_gpa=bp.entry_gpa; p.initrd=.{.present=bp.initrd.present,.start=bp.initrd.start,.size=bp.initrd.size};
    p.fdt = .{ .present = fdt.state == .built, .start = dtb.payload_gpa, .size = fdt.encoded_len }; p.fdt_placement = if (fdt.state == .built) .metadata_only else .none;
    copyArgs(p, fdt.bootargs[0..fdt.bootargs_len]); p.guest_pc=ge.pc; p.guest_sp=ge.sp; p.fdt_magic=fdt.header.magic; p.fdt_totalsize=fdt.header.totalsize; p.fdt_version=fdt.header.version; p.fdt_struct_size=fdt.header.size_dt_struct; p.fdt_strings_size=fdt.header.size_dt_strings; p.fdt_checksum=fdt.checksum;
    p.sbi_ready = sbi.object().has_request and sbi.object().last_error == .none; p.virtual_timer_ready = timer.armed and timer.last_validation_result == .ok; p.stage2_metadata_ready = st.state == .built or st.state == .validated; p.active_stage2_claimed = st.active;
    p.prepare_count += 1; p.state=.assembled; p.last_error=.none; return validate();
}

pub fn computeBlockers() Blockers {
    const p=object(); const gm=guest_memory.object(); const img=guest_image.object(); const bp=boot_package.object(); const dtb=guest_dtb.object(); const fdt=binary_fdt.object(); const ge=guest_entry.object();
    var b=Blockers{}; if (p.owner_vm_id != vm.object().id or p.owner_vcpu_id != vcpu.object().id) b.owner_mismatch=true; if (gm.state != .configured or gm.size_bytes == 0) b.guest_memory_missing=true; if (img.state != .loaded or img.loaded_byte_count == 0) b.guest_image_missing=true; if (bp.state != .ready) b.boot_package_missing=true; if (dtb.state != .built) b.dtb_contract_missing=true; if (fdt.state != .built or fdt.encoded_len == 0 or fdt.header.magic != binary_fdt.fdt_magic) b.binary_fdt_missing=true; if (ge.state != .prepared or !ge.frame_valid) b.guest_entry_missing=true;
    const base:usize=0; const size=gm.size_bytes; const kernel=Range{.present=bp.kernel.present,.start=bp.kernel.start,.size=bp.kernel.size}; if (kernel.present and !inGuest(base,size,kernel)) b.kernel_bounds=true; if (bp.entry_present and !pointInGuest(base,size,bp.entry_gpa)) b.entry_bounds=true; if (bp.initrd.present and !inGuest(base,size,p.initrd)) b.initrd_bounds=true; if (p.fdt.present and p.fdt_placement == .guest_memory and !inGuest(base,size,p.fdt)) b.fdt_bounds=true; if (overlap(kernel,p.initrd) or (p.fdt_placement == .guest_memory and (overlap(kernel,p.fdt) or overlap(p.initrd,p.fdt)))) b.range_overlap=true; if (ge.pc != bp.entry_gpa) b.pc_mismatch=true; if (p.bootargs_len == 0) b.bootargs_missing=true; if (!p.sbi_ready) b.sbi_missing=true; if (!p.virtual_timer_ready) b.virtual_timer_missing=true; if (p.active_stage2_claimed) b.active_stage2_forbidden=true; if (!p.stage2_metadata_ready) b.stage2_metadata_missing=true; return b;
}
fn first(b: Blockers) Error { if (b.owner_mismatch) return .owner_mismatch; if (b.guest_memory_missing) return .guest_memory_missing; if (b.guest_image_missing) return .guest_image_missing; if (b.boot_package_missing) return .boot_package_missing; if (b.dtb_contract_missing) return .dtb_contract_missing; if (b.binary_fdt_missing) return .binary_fdt_missing; if (b.kernel_bounds) return .kernel_bounds; if (b.entry_bounds) return .entry_bounds; if (b.initrd_bounds) return .initrd_bounds; if (b.fdt_bounds) return .fdt_bounds; if (b.range_overlap) return .range_overlap; if (b.pc_mismatch) return .pc_mismatch; if (b.bootargs_missing) return .bootargs_missing; if (b.guest_entry_missing) return .guest_entry_missing; if (b.sbi_missing) return .sbi_missing; if (b.virtual_timer_missing) return .virtual_timer_missing; if (b.active_stage2_forbidden) return .active_stage2_forbidden; if (b.stage2_metadata_missing) return .stage2_metadata_missing; return .none; }
pub fn validate() Result { const p=mutable(); p.validate_count += 1; const b=computeBlockers(); if (b.any()) return reject(first(b)); p.state=.validated; p.last_error=.none; return .ok; }

pub fn printState() void { printSummary(); printBlockers(); printNonClaims(); }
pub fn printPrepareCommand() void { const r=preparePrerequisites(); result("prepare_result", r); boot_package.printState(); guest_dtb.printState(); binary_fdt.printState(); printSummary(); printBlockers(); printNonClaims(); }
pub fn printValidateCommand() void { const r=validate(); result("validate_result", r); printSummary(); printBlockers(); printNonClaims(); }
pub fn printBlockersCommand() void { printBlockers(); printNonClaims(); }
pub fn printRangesCommand() void { printRanges(); printNonClaims(); }
pub fn printSummaryCommand() void { printSummary(); printNonClaims(); }
pub fn printResetCommand() void { reset(); uart.write("hv: handoff.reset_result=ok\r\n"); printSummary(); printBlockers(); printNonClaims(); }
pub fn printMissingFdtTestCommand() void { _=preparePrerequisites(); binary_fdt.reset(); const r=assemble(); uart.write("hv: handoff.missing_fdt_test="); uart.write(if (r==.rejected) "rejected" else "failed-to-reject"); uart.write("\r\n"); printSummary(); printBlockers(); printNonClaims(); }
pub fn printMissingBootpkgTestCommand() void { _=preparePrerequisites(); boot_package.reset(); const r=assemble(); uart.write("hv: handoff.missing_bootpkg_test="); uart.write(if (r==.rejected) "rejected" else "failed-to-reject"); uart.write("\r\n"); printSummary(); printBlockers(); printNonClaims(); }
pub fn printOverlapTestCommand() void { _=preparePrerequisites(); const p=mutable(); p.fdt_placement=.guest_memory; p.fdt=.{.present=true,.start=p.initrd.start,.size=64}; const r=validate(); uart.write("hv: handoff.overlap_test="); uart.write(if (r==.rejected) "rejected" else "failed-to-reject"); uart.write("\r\n"); printSummary(); printBlockers(); printNonClaims(); }
pub fn printBoundsTestCommand() void { _=preparePrerequisites(); const p=mutable(); p.initrd=.{.present=true,.start=p.guest_memory_size + 4096,.size=128}; const r=validate(); uart.write("hv: handoff.bounds_test="); uart.write(if (r==.rejected) "rejected" else "failed-to-reject"); uart.write("\r\n"); printSummary(); printBlockers(); printNonClaims(); }
fn result(name: []const u8, r: Result) void { uart.write("hv: handoff."); uart.write(name); uart.write("="); uart.write(if (r==.ok) "ok" else "rejected"); uart.write("\r\n"); }
fn printSummary() void { const p=object(); uart.write("hv: linux_handoff="); uart.write(if (p.state==.validated) "validated" else if (p.state==.assembled) "assembled-not-ready" else "empty"); uart.write("\r\n"); uart.write("hv: handoff.state="); uart.write(@tagName(p.state)); uart.write("\r\n"); uart.write("hv: handoff.ready="); uart.write(if (p.state==.validated) "true" else "false"); uart.write("\r\n"); uart.write("hv: handoff.owner_vm_id="); uart.writeDec(p.owner_vm_id); uart.write("\r\n"); uart.write("hv: handoff.owner_vcpu_id="); uart.writeDec(p.owner_vcpu_id); uart.write("\r\n"); printRanges(); uart.write("hv: handoff.bootargs="); uart.write(p.bootargs[0..p.bootargs_len]); uart.write("\r\n"); uart.write("hv: handoff.guest_pc="); uart.writeHex(p.guest_pc); uart.write("\r\n"); uart.write("hv: handoff.guest_sp="); uart.writeHex(p.guest_sp); uart.write("\r\n"); uart.write("hv: handoff.fdt.header.magic="); uart.writeHex(p.fdt_magic); uart.write("\r\n"); uart.write("hv: handoff.fdt.header.totalsize="); uart.writeDec(p.fdt_totalsize); uart.write("\r\n"); uart.write("hv: handoff.fdt.header.version="); uart.writeDec(p.fdt_version); uart.write("\r\n"); uart.write("hv: handoff.fdt.header.size_dt_struct="); uart.writeDec(p.fdt_struct_size); uart.write("\r\n"); uart.write("hv: handoff.fdt.header.size_dt_strings="); uart.writeDec(p.fdt_strings_size); uart.write("\r\n"); uart.write("hv: handoff.fdt.checksum="); uart.writeHex(p.fdt_checksum); uart.write("\r\n"); uart.write("hv: handoff.prepare_count="); uart.writeDec(p.prepare_count); uart.write("\r\n"); uart.write("hv: handoff.validate_count="); uart.writeDec(p.validate_count); uart.write("\r\n"); uart.write("hv: handoff.reject_count="); uart.writeDec(p.reject_count); uart.write("\r\n"); uart.write("hv: handoff.reset_count="); uart.writeDec(p.reset_count); uart.write("\r\n"); uart.write("hv: handoff.last_error="); uart.write(errorName(p.last_error)); uart.write("\r\n"); }
fn printRanges() void { const p=object(); uart.write("hv: handoff.guest_memory.base="); uart.writeHex(p.guest_memory_base); uart.write("\r\n"); uart.write("hv: handoff.guest_memory.size="); uart.writeDec(p.guest_memory_size); uart.write("\r\n"); uart.write("hv: handoff.guest_image.start="); uart.writeHex(p.guest_image_start); uart.write("\r\n"); uart.write("hv: handoff.guest_image.size="); uart.writeDec(p.guest_image_size); uart.write("\r\n"); uart.write("hv: handoff.kernel_load_gpa="); uart.writeHex(p.kernel_load_gpa); uart.write("\r\n"); uart.write("hv: handoff.kernel_entry_gpa="); uart.writeHex(p.kernel_entry_gpa); uart.write("\r\n"); uart.write("hv: handoff.initrd.start="); uart.writeHex(p.initrd.start); uart.write("\r\n"); uart.write("hv: handoff.initrd.end="); uart.writeHex((end(p.initrd) orelse 0)); uart.write("\r\n"); uart.write("hv: handoff.fdt.placement="); uart.write(@tagName(p.fdt_placement)); uart.write("\r\n"); uart.write("hv: handoff.fdt.gpa="); uart.writeHex(p.fdt.start); uart.write("\r\n"); uart.write("hv: handoff.fdt.size="); uart.writeDec(p.fdt.size); uart.write("\r\n"); }
fn printBlockers() void { const b=computeBlockers(); uart.write("hv: handoff.blocker_count="); uart.writeDec(b.count()); uart.write("\r\n"); if (!b.any()) { uart.write("hv: handoff.blocker=none\r\n"); return; } inline for (@typeInfo(Blockers).Struct.fields) |f| if (@field(b, f.name)) { uart.write("hv: handoff.blocker="); uart.write(f.name); uart.write("\r\n"); } }
fn errorName(e: Error) []const u8 { return switch(e){ .none=>"none", .owner_mismatch=>"owner-mismatch", .guest_memory_missing=>"guest-memory-missing", .guest_image_missing=>"guest-image-missing", .boot_package_missing=>"boot-package-missing", .dtb_contract_missing=>"dtb-contract-missing", .binary_fdt_missing=>"binary-fdt-missing", .kernel_bounds=>"kernel-bounds", .entry_bounds=>"entry-bounds", .initrd_bounds=>"initrd-bounds", .fdt_bounds=>"fdt-bounds", .range_overlap=>"range-overlap", .pc_mismatch=>"pc-mismatch", .bootargs_missing=>"bootargs-missing", .guest_entry_missing=>"guest-entry-missing", .sbi_missing=>"sbi-missing", .virtual_timer_missing=>"virtual-timer-missing", .active_stage2_forbidden=>"active-stage2-forbidden", .stage2_metadata_missing=>"stage2-metadata-missing"}; }
fn printNonClaims() void { uart.write("hv: linux_guest=not-supported-yet\r\n"); uart.write("hv: guest_execution=not-supported-yet\r\n"); uart.write("hv: second_stage_translation=MISSING\r\n"); uart.write("hv: fdt_linux_acceptance=not-proven-yet\r\n"); uart.write("hv: handoff_execution=not-attempted\r\n"); uart.write("hv: guest_entered=no\r\n"); }
