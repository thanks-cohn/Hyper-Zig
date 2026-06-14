const uart = @import("../console/uart.zig");
const vm_model = @import("vm.zig");
const guest_dtb = @import("guest_dtb.zig");

pub const fdt_magic: u32 = 0xd00dfeed;
const version: u32 = 17;
const last_comp_version: u32 = 16;
const token_begin_node: u32 = 1;
const token_end_node: u32 = 2;
const token_prop: u32 = 3;
const token_end: u32 = 9;
pub const default_capacity: usize = 4096;
const header_size: usize = 40;
const reserve_size: usize = 16;

pub const State = enum { empty, built };
pub const Result = enum { ok, rejected };
pub const Error = enum { none, dtb_contract_not_ready, missing_bootargs, buffer_too_small, overflow, invalid_node, invalid_property, header_mismatch, block_bounds };

pub const Header = struct { magic: u32, totalsize: u32, off_dt_struct: u32, off_dt_strings: u32, off_mem_rsvmap: u32, version: u32, last_comp_version: u32, boot_cpuid_phys: u32, size_dt_strings: u32, size_dt_struct: u32 };

pub const BinaryFdt = struct {
    owner_vm_id: vm_model.VmId,
    state: State,
    buffer: [default_capacity]u8,
    encoded_len: usize,
    header: Header,
    node_count: usize,
    property_count: usize,
    string_count: usize,
    checksum: u32,
    memory_node_encoded: bool,
    cpu_node_encoded: bool,
    chosen_node_encoded: bool,
    initrd_encoded: bool,
    bootargs: [guest_dtb.max_bootargs_bytes]u8,
    bootargs_len: usize,
    build_count: usize,
    validate_count: usize,
    reset_count: usize,
    reject_count: usize,
    last_error: Error,
};

const StringEntry = struct { name: []const u8, offset: u32 };
const Encoder = struct {
    f: *BinaryFdt,
    capacity: usize,
    struct_pos: usize,
    strings_pos: usize,
    strings: [24]StringEntry,
    strings_len: usize,

    fn ensure(self: *Encoder, pos: usize, n: usize) Result { if (n > self.capacity or pos > self.capacity - n) return rejectFor(self.f, .buffer_too_small); return .ok; }
    fn writeByte(self: *Encoder, pos: *usize, b: u8) Result { if (self.ensure(pos.*, 1) != .ok) return .rejected; self.f.buffer[pos.*] = b; pos.* += 1; return .ok; }
    fn writeBe32At(self: *Encoder, pos: usize, v: u32) Result { if (self.ensure(pos, 4) != .ok) return .rejected; self.f.buffer[pos+0] = @intCast((v >> 24) & 0xff); self.f.buffer[pos+1] = @intCast((v >> 16) & 0xff); self.f.buffer[pos+2] = @intCast((v >> 8) & 0xff); self.f.buffer[pos+3] = @intCast(v & 0xff); return .ok; }
    fn writeBe32(self: *Encoder, pos: *usize, v: u32) Result { if (self.writeBe32At(pos.*, v) != .ok) return .rejected; pos.* += 4; return .ok; }
    fn pad4(self: *Encoder, pos: *usize) Result { while ((pos.* & 3) != 0) if (self.writeByte(pos, 0) != .ok) return .rejected; return .ok; }
    fn writeBytes(self: *Encoder, pos: *usize, s: []const u8) Result { if (self.ensure(pos.*, s.len) != .ok) return .rejected; for (s, 0..) |b, i| self.f.buffer[pos.* + i] = b; pos.* += s.len; return .ok; }
    fn same(a: []const u8, b: []const u8) bool { if (a.len != b.len) return false; for (a, 0..) |ch, i| if (ch != b[i]) return false; return true; }
    fn stringOffset(self: *Encoder, name: []const u8) ?u32 { for (self.strings[0..self.strings_len]) |e| if (same(e.name, name)) return e.offset; return null; }
    fn intern(self: *Encoder, name: []const u8) ?u32 {
        if (name.len == 0) return null;
        if (self.stringOffset(name)) |off| return off;
        if (self.strings_len >= self.strings.len) return null;
        const off: u32 = @intCast(self.strings_pos - @as(usize, self.f.header.off_dt_strings));
        var p = self.strings_pos; if (self.writeBytes(&p, name) != .ok) return null; if (self.writeByte(&p, 0) != .ok) return null;
        self.strings[self.strings_len] = .{ .name = name, .offset = off }; self.strings_len += 1; self.strings_pos = p; self.f.string_count = self.strings_len; return off;
    }
    fn beginNode(self: *Encoder, name: []const u8) Result { if (name.len > 63) return rejectFor(self.f, .invalid_node); if (self.writeBe32(&self.struct_pos, token_begin_node) != .ok) return .rejected; if (self.writeBytes(&self.struct_pos, name) != .ok) return .rejected; if (self.writeByte(&self.struct_pos, 0) != .ok) return .rejected; if (self.pad4(&self.struct_pos) != .ok) return .rejected; self.f.node_count += 1; return .ok; }
    fn endNode(self: *Encoder) Result { return self.writeBe32(&self.struct_pos, token_end_node); }
    fn propRaw(self: *Encoder, name: []const u8, data: []const u8) Result { const off = self.intern(name) orelse return rejectFor(self.f, .invalid_property); if (self.writeBe32(&self.struct_pos, token_prop) != .ok) return .rejected; if (self.writeBe32(&self.struct_pos, @intCast(data.len)) != .ok) return .rejected; if (self.writeBe32(&self.struct_pos, off) != .ok) return .rejected; if (self.writeBytes(&self.struct_pos, data) != .ok) return .rejected; if (self.pad4(&self.struct_pos) != .ok) return .rejected; self.f.property_count += 1; return .ok; }
    fn propString(self: *Encoder, name: []const u8, value: []const u8) Result { var tmp: [160]u8 = undefined; if (value.len + 1 > tmp.len) return rejectFor(self.f, .invalid_property); for (value, 0..) |b, i| tmp[i] = b; tmp[value.len] = 0; return self.propRaw(name, tmp[0..value.len+1]); }
    fn propU32(self: *Encoder, name: []const u8, value: u32) Result { var tmp: [4]u8 = undefined; tmp[0]=@intCast((value>>24)&0xff); tmp[1]=@intCast((value>>16)&0xff); tmp[2]=@intCast((value>>8)&0xff); tmp[3]=@intCast(value&0xff); return self.propRaw(name, tmp[0..]); }
    fn propReg2(self: *Encoder, name: []const u8, a: usize, b: usize) Result { var tmp: [16]u8 = undefined; writeBe64(&tmp, 0, a); writeBe64(&tmp, 8, b); return self.propRaw(name, tmp[0..]); }
};

var fdt: BinaryFdt = undefined; var initialized = false;
pub fn init(owner_vm_id: vm_model.VmId) void { fdt = empty(owner_vm_id, 0); initialized = true; }
pub fn object() *const BinaryFdt { return mutable(); }
fn mutable() *BinaryFdt { if (!initialized) init(vm_model.object().id); return &fdt; }
fn empty(owner: vm_model.VmId, reset_count: usize) BinaryFdt { return .{ .owner_vm_id=owner, .state=.empty, .buffer=[_]u8{0} ** default_capacity, .encoded_len=0, .header=.{ .magic=0,.totalsize=0,.off_dt_struct=0,.off_dt_strings=0,.off_mem_rsvmap=0,.version=version,.last_comp_version=last_comp_version,.boot_cpuid_phys=0,.size_dt_strings=0,.size_dt_struct=0 }, .node_count=0,.property_count=0,.string_count=0,.checksum=0,.memory_node_encoded=false,.cpu_node_encoded=false,.chosen_node_encoded=false,.initrd_encoded=false,.bootargs=[_]u8{0} ** guest_dtb.max_bootargs_bytes,.bootargs_len=0,.build_count=0,.validate_count=0,.reset_count=reset_count,.reject_count=0,.last_error=.none }; }
pub fn reset() void { const old = mutable(); fdt = empty(old.owner_vm_id, old.reset_count + 1); initialized = true; }
fn rejectFor(obj: *BinaryFdt, e: Error) Result { obj.reject_count += 1; obj.last_error = e; obj.state = .empty; obj.encoded_len = 0; obj.checksum = 0; return .rejected; }
fn align4(n: usize) usize { return (n + 3) & ~@as(usize, 3); }
fn writeBe64(buf: []u8, off: usize, v: usize) void { const x: u64 = @intCast(v); buf[off+0]=@intCast((x>>56)&0xff); buf[off+1]=@intCast((x>>48)&0xff); buf[off+2]=@intCast((x>>40)&0xff); buf[off+3]=@intCast((x>>32)&0xff); buf[off+4]=@intCast((x>>24)&0xff); buf[off+5]=@intCast((x>>16)&0xff); buf[off+6]=@intCast((x>>8)&0xff); buf[off+7]=@intCast(x&0xff); }

pub fn buildFromDtbContract(capacity: usize) Result {
    const obj = mutable(); obj.owner_vm_id = vm_model.object().id;
    if (capacity < header_size + reserve_size + 32 or capacity > default_capacity) return rejectFor(obj, .buffer_too_small);
    if (guest_dtb.validate() != .ok or guest_dtb.object().state != .built) return rejectFor(obj, .dtb_contract_not_ready);
    const c = guest_dtb.object(); if (c.bootargs_len == 0) return rejectFor(obj, .missing_bootargs);
    const resets = obj.reset_count; const builds = obj.build_count + 1; const rejects = obj.reject_count; obj.* = empty(obj.owner_vm_id, resets); obj.build_count = builds; obj.reject_count = rejects;
    obj.header.off_mem_rsvmap = header_size; obj.header.off_dt_struct = header_size + reserve_size; obj.header.off_dt_strings = @intCast(capacity / 2); obj.header.version = version; obj.header.last_comp_version = last_comp_version; obj.header.boot_cpuid_phys = @intCast(c.cpu_hart_id);
    var enc = Encoder{ .f=obj, .capacity=capacity, .struct_pos=@intCast(obj.header.off_dt_struct), .strings_pos=@intCast(obj.header.off_dt_strings), .strings=undefined, .strings_len=0 };
    var z: usize = 0; while (z < capacity) : (z += 1) obj.buffer[z] = 0;
    var rsv: usize = header_size; if (enc.writeBe32(&rsv, 0) != .ok or enc.writeBe32(&rsv, 0) != .ok or enc.writeBe32(&rsv, 0) != .ok or enc.writeBe32(&rsv, 0) != .ok) return .rejected;
    if (enc.beginNode("") != .ok) return .rejected;
    if (enc.propString("compatible", "hyper-zig,hv17-minimal-fdt") != .ok) return .rejected;
    if (enc.propString("model", "Hyper-Zig minimal virtual machine") != .ok) return .rejected;
    if (enc.propU32("#address-cells", 2) != .ok) return .rejected;
    if (enc.propU32("#size-cells", 2) != .ok) return .rejected;
    if (enc.beginNode("memory") != .ok) return .rejected; if (enc.propString("device_type", "memory") != .ok) return .rejected; if (enc.propReg2("reg", c.memory_base, c.memory_size) != .ok) return .rejected; if (enc.endNode() != .ok) return .rejected; obj.memory_node_encoded = true;
    if (enc.beginNode("cpus") != .ok) return .rejected; if (enc.propU32("#address-cells", 1) != .ok) return .rejected; if (enc.propU32("#size-cells", 0) != .ok) return .rejected; if (enc.beginNode("cpu@0") != .ok) return .rejected; if (enc.propString("device_type", "cpu") != .ok) return .rejected; if (enc.propU32("reg", @intCast(c.cpu_hart_id)) != .ok) return .rejected; if (enc.propString("riscv,isa", c.cpu_isa) != .ok) return .rejected; if (enc.endNode() != .ok) return .rejected; if (enc.endNode() != .ok) return .rejected; obj.cpu_node_encoded = true;
    if (enc.beginNode("chosen") != .ok) return .rejected; if (enc.propString("bootargs", c.bootargs[0..c.bootargs_len]) != .ok) return .rejected; if (enc.propString("stdout-path", c.console_path) != .ok) return .rejected; if (c.initrd_present) { if (enc.propU32("linux,initrd-start", @intCast(c.initrd_start)) != .ok) return .rejected; if (enc.propU32("linux,initrd-end", @intCast(c.initrd_end)) != .ok) return .rejected; obj.initrd_encoded = true; } if (enc.endNode() != .ok) return .rejected; obj.chosen_node_encoded = true;
    if (enc.endNode() != .ok) return .rejected; if (enc.writeBe32(&enc.struct_pos, token_end) != .ok) return .rejected;
    const old_strings_off: usize = @intCast(obj.header.off_dt_strings);
    const strings_len = enc.strings_pos - old_strings_off;
    const final_strings_off = align4(enc.struct_pos);
    if (final_strings_off + strings_len > capacity) return rejectFor(obj, .buffer_too_small);
    var mv: usize = 0; while (mv < strings_len) : (mv += 1) obj.buffer[final_strings_off + mv] = obj.buffer[old_strings_off + mv];
    obj.header.off_dt_strings = @intCast(final_strings_off);
    obj.header.size_dt_struct = @intCast(enc.struct_pos - @as(usize, obj.header.off_dt_struct)); obj.header.size_dt_strings = @intCast(strings_len); obj.header.totalsize = @intCast(final_strings_off + strings_len); obj.header.magic = fdt_magic; obj.encoded_len = final_strings_off + strings_len;
    if (writeHeader(&enc) != .ok) return .rejected; copyBootargs(obj, c.bootargs[0..c.bootargs_len]); obj.checksum = byteSum(obj.buffer[0..obj.encoded_len]); obj.last_error = .none; obj.state = .built; return validate();
}
fn writeHeader(enc: *Encoder) Result { const h = enc.f.header; var p: usize = 0; if (enc.writeBe32(&p,h.magic)!=.ok) return .rejected; if (enc.writeBe32(&p,h.totalsize)!=.ok) return .rejected; if (enc.writeBe32(&p,h.off_dt_struct)!=.ok) return .rejected; if (enc.writeBe32(&p,h.off_dt_strings)!=.ok) return .rejected; if (enc.writeBe32(&p,h.off_mem_rsvmap)!=.ok) return .rejected; if (enc.writeBe32(&p,h.version)!=.ok) return .rejected; if (enc.writeBe32(&p,h.last_comp_version)!=.ok) return .rejected; if (enc.writeBe32(&p,h.boot_cpuid_phys)!=.ok) return .rejected; if (enc.writeBe32(&p,h.size_dt_strings)!=.ok) return .rejected; if (enc.writeBe32(&p,h.size_dt_struct)!=.ok) return .rejected; return .ok; }
fn copyBootargs(obj: *BinaryFdt, s: []const u8) void { var i: usize = 0; while (i < obj.bootargs.len) : (i += 1) obj.bootargs[i] = 0; i = 0; while (i < s.len and i < obj.bootargs.len) : (i += 1) obj.bootargs[i] = s[i]; obj.bootargs_len = s.len; }
fn byteSum(s: []const u8) u32 { var sum: u32 = 0; for (s) |b| sum +%= b; return sum; }

pub fn validate() Result { const obj = mutable(); obj.validate_count += 1; if (obj.state != .built or obj.encoded_len == 0) return rejectFor(obj, .dtb_contract_not_ready); const h = obj.header; if (h.magic != fdt_magic or h.totalsize != obj.encoded_len) return rejectFor(obj, .header_mismatch); if (h.off_mem_rsvmap != header_size or h.off_dt_struct < h.off_mem_rsvmap + reserve_size or h.off_dt_strings < h.off_dt_struct + h.size_dt_struct) return rejectFor(obj, .block_bounds); if (h.off_dt_strings + h.size_dt_strings != h.totalsize or h.totalsize > default_capacity) return rejectFor(obj, .block_bounds); if (obj.node_count < 5 or obj.property_count < 10 or obj.string_count == 0) return rejectFor(obj, .header_mismatch); obj.last_error = .none; return .ok; }

pub fn printState() void { printImplementedMarker(); printSummary(); printNonClaims(); }
pub fn printBuildCommand() void { const r = buildFromDtbContract(default_capacity); printResult("build_result", r); printSummary(); printNonClaims(); }
pub fn printValidateCommand() void { const r = validate(); printResult("validate_result", r); printSummary(); printNonClaims(); }
pub fn printHeaderCommand() void { printHeader(); printNonClaims(); }
pub fn printNodesCommand() void { printNodes(); printNonClaims(); }
pub fn printStringsCommand() void { printStrings(); printNonClaims(); }
pub fn printChecksumCommand() void { const o=object(); uart.write("hv: fdt.checksum="); uart.writeHex(o.checksum); uart.write("\r\n"); uart.write("hv: fdt.encoded_len="); uart.writeDec(o.encoded_len); uart.write("\r\n"); printNonClaims(); }
pub fn printResetCommand() void { reset(); uart.write("hv: fdt.reset_result=ok\r\n"); printSummary(); printNonClaims(); }
pub fn printBoundsTestCommand() void { const r = buildFromDtbContract(64); uart.write("hv: fdt.bounds_test="); uart.write(if (r == .rejected) "rejected" else "failed-to-reject"); uart.write("\r\n"); printSummary(); printNonClaims(); }
pub fn printMissingContractTestCommand() void { guest_dtb.reset(); const r = buildFromDtbContract(default_capacity); uart.write("hv: fdt.missing_contract_test="); uart.write(if (r == .rejected) "rejected" else "failed-to-reject"); uart.write("\r\n"); printSummary(); printNonClaims(); }
pub fn printImplementedMarker() void { uart.write("hv: fdt_encoder=foundation-binary-buffer\r\n"); }
fn printResult(name: []const u8, r: Result) void { uart.write("hv: fdt."); uart.write(name); uart.write("="); uart.write(if (r == .ok) "ok" else "rejected"); uart.write("\r\n"); }
fn printSummary() void { const o=object(); uart.write("hv: binary_fdt="); uart.write(if (o.state == .built) "encoded-minimal" else "empty"); uart.write("\r\n"); uart.write("hv: fdt.state="); uart.write(if (o.state == .built) "built" else "empty"); uart.write("\r\n"); uart.write("hv: fdt.built="); uart.write(if (o.state == .built) "true" else "false"); uart.write("\r\n"); uart.write("hv: fdt.encoded_len="); uart.writeDec(o.encoded_len); uart.write("\r\n"); printHeader(); uart.write("hv: fdt.node_count="); uart.writeDec(o.node_count); uart.write("\r\n"); uart.write("hv: fdt.property_count="); uart.writeDec(o.property_count); uart.write("\r\n"); uart.write("hv: fdt.string_count="); uart.writeDec(o.string_count); uart.write("\r\n"); uart.write("hv: fdt.bootargs="); uart.write(o.bootargs[0..o.bootargs_len]); uart.write("\r\n"); uart.write("hv: fdt.checksum="); uart.writeHex(o.checksum); uart.write("\r\n"); uart.write("hv: fdt.build_count="); uart.writeDec(o.build_count); uart.write("\r\n"); uart.write("hv: fdt.validate_count="); uart.writeDec(o.validate_count); uart.write("\r\n"); uart.write("hv: fdt.reset_count="); uart.writeDec(o.reset_count); uart.write("\r\n"); uart.write("hv: fdt.reject_count="); uart.writeDec(o.reject_count); uart.write("\r\n"); uart.write("hv: fdt.last_error="); uart.write(errorName(o.last_error)); uart.write("\r\n"); printNodes(); }
fn printHeader() void { const h=object().header; uart.write("hv: fdt.header.magic="); uart.writeHex(h.magic); uart.write("\r\n"); uart.write("hv: fdt.header.totalsize="); uart.writeDec(h.totalsize); uart.write("\r\n"); uart.write("hv: fdt.header.off_dt_struct="); uart.writeDec(h.off_dt_struct); uart.write("\r\n"); uart.write("hv: fdt.header.off_dt_strings="); uart.writeDec(h.off_dt_strings); uart.write("\r\n"); uart.write("hv: fdt.header.off_mem_rsvmap="); uart.writeDec(h.off_mem_rsvmap); uart.write("\r\n"); uart.write("hv: fdt.header.version="); uart.writeDec(h.version); uart.write("\r\n"); uart.write("hv: fdt.header.last_comp_version="); uart.writeDec(h.last_comp_version); uart.write("\r\n"); uart.write("hv: fdt.header.boot_cpuid_phys="); uart.writeDec(h.boot_cpuid_phys); uart.write("\r\n"); uart.write("hv: fdt.header.size_dt_strings="); uart.writeDec(h.size_dt_strings); uart.write("\r\n"); uart.write("hv: fdt.header.size_dt_struct="); uart.writeDec(h.size_dt_struct); uart.write("\r\n"); }
fn printNodes() void { const o=object(); uart.write("hv: fdt.node=/ encoded=true\r\n"); uart.write("hv: fdt.node=/memory encoded="); uart.write(if (o.memory_node_encoded) "true" else "false"); uart.write("\r\n"); uart.write("hv: fdt.node=/cpus encoded=true\r\n"); uart.write("hv: fdt.node=/cpus/cpu@0 encoded="); uart.write(if (o.cpu_node_encoded) "true" else "false"); uart.write("\r\n"); uart.write("hv: fdt.node=/chosen encoded="); uart.write(if (o.chosen_node_encoded) "true" else "false"); uart.write(" bootargs="); uart.write(o.bootargs[0..o.bootargs_len]); uart.write("\r\n"); uart.write("hv: fdt.initrd_metadata_encoded="); uart.write(if (o.initrd_encoded) "true" else "false"); uart.write("\r\n"); }
fn printStrings() void { const o=object(); uart.write("hv: fdt.strings.size="); uart.writeDec(o.header.size_dt_strings); uart.write("\r\n"); uart.write("hv: fdt.strings.source=property-name-table\r\n"); }
fn errorName(e: Error) []const u8 { return switch(e){ .none=>"none", .dtb_contract_not_ready=>"dtb-contract-not-ready", .missing_bootargs=>"bootargs-missing", .buffer_too_small=>"buffer-too-small", .overflow=>"overflow", .invalid_node=>"invalid-node", .invalid_property=>"invalid-property", .header_mismatch=>"header-mismatch", .block_bounds=>"block-bounds"}; }
fn printNonClaims() void { uart.write("hv: linux_guest=not-supported-yet\r\n"); uart.write("hv: guest_execution=not-supported-yet\r\n"); uart.write("hv: second_stage_translation=MISSING\r\n"); uart.write("hv: fdt_linux_acceptance=not-proven-yet\r\n"); }
