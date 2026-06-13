const uart = @import("../console/uart.zig");
const vm_model = @import("vm.zig");
const vcpu_model = @import("vcpu.zig");

pub const Extension = enum { base, timer, console, unknown };
pub const Result = enum { ok, rejected };
pub const Error = enum { none, no_request, unknown_extension, unsupported_function, invalid_argument };

pub const ExtensionMetadata = struct { id: usize, name: []const u8, first_function: usize, function_count: usize, service_claim: []const u8 };
pub const Request = struct { extension: Extension, extension_id: usize, function_id: usize, args: [6]usize };

pub const SbiFoundation = struct {
    owner_vm_id: vm_model.VmId,
    owner_vcpu_id: vcpu_model.VcpuId,
    has_request: bool,
    last_extension: Extension,
    last_extension_id: usize,
    last_function_id: usize,
    args: [6]usize,
    return_value: isize,
    error_code: isize,
    record_count: usize,
    validate_count: usize,
    reset_count: usize,
    reject_count: usize,
    capability_lookup_count: usize,
    base_request_count: usize,
    timer_request_count: usize,
    console_request_count: usize,
    unknown_request_count: usize,
    last_error: Error,
};

const base_ext = ExtensionMetadata{ .id = 0x10, .name = "base", .first_function = 0, .function_count = 7, .service_claim = "metadata-only-no-service" };
const timer_ext = ExtensionMetadata{ .id = 0x54494d45, .name = "timer", .first_function = 0, .function_count = 1, .service_claim = "metadata-only-no-timer-service" };
const console_ext = ExtensionMetadata{ .id = 0x1, .name = "legacy-console", .first_function = 0, .function_count = 2, .service_claim = "metadata-only-no-console-service" };

var state: SbiFoundation = undefined;
var initialized = false;

pub fn init(owner_vm_id: vm_model.VmId, owner_vcpu_id: vcpu_model.VcpuId) void { state = empty(owner_vm_id, owner_vcpu_id, 0); initialized = true; }
pub fn object() *const SbiFoundation { return mutable(); }
fn mutable() *SbiFoundation { if (!initialized) init(vm_model.object().id, vcpu_model.object().id); return &state; }
fn empty(owner_vm_id: vm_model.VmId, owner_vcpu_id: vcpu_model.VcpuId, reset_count: usize) SbiFoundation { return .{ .owner_vm_id = owner_vm_id, .owner_vcpu_id = owner_vcpu_id, .has_request = false, .last_extension = .unknown, .last_extension_id = 0, .last_function_id = 0, .args = [_]usize{0} ** 6, .return_value = 0, .error_code = 0, .record_count = 0, .validate_count = 0, .reset_count = reset_count, .reject_count = 0, .capability_lookup_count = 0, .base_request_count = 0, .timer_request_count = 0, .console_request_count = 0, .unknown_request_count = 0, .last_error = .none }; }

pub fn reset() void { const s = mutable(); state = empty(s.owner_vm_id, s.owner_vcpu_id, s.reset_count + 1); initialized = true; }

pub fn lookupExtension(id: usize) ?ExtensionMetadata {
    const s = mutable(); s.capability_lookup_count += 1;
    if (id == base_ext.id) return base_ext;
    if (id == timer_ext.id) return timer_ext;
    if (id == console_ext.id) return console_ext;
    return null;
}
fn extensionFromId(id: usize) Extension { if (id == base_ext.id) return .base; if (id == timer_ext.id) return .timer; if (id == console_ext.id) return .console; return .unknown; }
fn metadataFor(e: Extension) ?ExtensionMetadata { return switch (e) { .base => base_ext, .timer => timer_ext, .console => console_ext, .unknown => null }; }

pub fn recordRequest(extension_id: usize, function_id: usize, args: [6]usize) Result {
    const s = mutable(); const ext = extensionFromId(extension_id);
    s.has_request = true; s.last_extension = ext; s.last_extension_id = extension_id; s.last_function_id = function_id; s.args = args; s.record_count += 1; s.return_value = 0; s.error_code = 0; s.last_error = .none;
    switch (ext) { .base => s.base_request_count += 1, .timer => s.timer_request_count += 1, .console => s.console_request_count += 1, .unknown => s.unknown_request_count += 1 }
    return validateLast();
}

pub fn validateLast() Result {
    const s = mutable(); s.validate_count += 1;
    if (!s.has_request) return reject(.no_request);
    const md = metadataFor(s.last_extension) orelse return reject(.unknown_extension);
    if (s.last_function_id < md.first_function or s.last_function_id >= md.first_function + md.function_count) return reject(.unsupported_function);
    if (s.last_extension == .timer and s.args[0] == 0 and s.args[1] == 0) return reject(.invalid_argument);
    s.last_error = .none; s.error_code = 0; s.return_value = 0; return .ok;
}
fn reject(e: Error) Result { const s = mutable(); s.reject_count += 1; s.last_error = e; s.error_code = -2; s.return_value = -1; return .rejected; }

pub fn printState() void { printImplementedMarker(); printFields(); printCapabilities(); printNonClaims(); }
pub fn printStatusCommand() void { printState(); }
pub fn printValidateCommand() void { const r = validateLast(); printResult("validate_result", r); printFields(); printNonClaims(); }
pub fn printResetCommand() void { reset(); uart.write("hv: sbi.reset_result=ok\r\n"); printFields(); printNonClaims(); }
pub fn printBlockersCommand() void { const r = validateLast(); const blocker_count: usize = if (r == .ok) 0 else 1; uart.write("hv: sbi.blocker_count="); uart.writeDec(blocker_count); uart.write("\r\n"); if (r == .ok) uart.write("hv: sbi.blocker=none\r\n") else { uart.write("hv: sbi.blocker="); uart.write(errorName(object().last_error)); uart.write("\r\n"); } printNonClaims(); }
pub fn printBaseTestCommand() void { const r = recordRequest(base_ext.id, 0, [_]usize{0} ** 6); printResult("base_test", r); printFields(); printCapabilities(); printNonClaims(); }
pub fn printTimerTestCommand() void { const r = recordRequest(timer_ext.id, 0, [_]usize{ 1, 0, 0, 0, 0, 0 }); printResult("timer_test", r); printFields(); printCapabilities(); printNonClaims(); }
pub fn printConsoleTestCommand() void { const r = recordRequest(console_ext.id, 0, [_]usize{ 65, 0, 0, 0, 0, 0 }); printResult("console_test", r); printFields(); printCapabilities(); printNonClaims(); }
pub fn printUnknownTestCommand() void { const r = recordRequest(0xffff, 0, [_]usize{0} ** 6); printResult("unknown_test", r); printFields(); printNonClaims(); }

pub fn printImplementedMarker() void { uart.write("hv: sbi_foundation=implemented\r\n"); }
fn printResult(name: []const u8, r: Result) void { uart.write("hv: sbi."); uart.write(name); uart.write("="); uart.write(if (r == .ok) "ok" else "rejected"); uart.write("\r\n"); }
fn printFields() void { const s = object(); uart.write("hv: sbi.owner_vm_id="); uart.writeDec(s.owner_vm_id); uart.write("\r\n"); uart.write("hv: sbi.owner_vcpu_id="); uart.writeDec(s.owner_vcpu_id); uart.write("\r\n"); uart.write("hv: sbi.has_request="); uart.write(if (s.has_request) "true" else "false"); uart.write("\r\n"); uart.write("hv: sbi.last_extension="); uart.write(extensionName(s.last_extension)); uart.write("\r\n"); uart.write("hv: sbi.last_extension_id="); uart.writeHex(s.last_extension_id); uart.write("\r\n"); uart.write("hv: sbi.last_function_id="); uart.writeDec(s.last_function_id); uart.write("\r\n"); var i: usize = 0; while (i < 6) : (i += 1) { uart.write("hv: sbi.arg"); uart.writeDec(i); uart.write("="); uart.writeHex(s.args[i]); uart.write("\r\n"); } uart.write("hv: sbi.return_value="); writeSigned(s.return_value); uart.write("\r\n"); uart.write("hv: sbi.error_code="); writeSigned(s.error_code); uart.write("\r\n"); uart.write("hv: sbi.record_count="); uart.writeDec(s.record_count); uart.write("\r\n"); uart.write("hv: sbi.validate_count="); uart.writeDec(s.validate_count); uart.write("\r\n"); uart.write("hv: sbi.reset_count="); uart.writeDec(s.reset_count); uart.write("\r\n"); uart.write("hv: sbi.reject_count="); uart.writeDec(s.reject_count); uart.write("\r\n"); uart.write("hv: sbi.capability_lookup_count="); uart.writeDec(s.capability_lookup_count); uart.write("\r\n"); uart.write("hv: sbi.base_request_count="); uart.writeDec(s.base_request_count); uart.write("\r\n"); uart.write("hv: sbi.timer_request_count="); uart.writeDec(s.timer_request_count); uart.write("\r\n"); uart.write("hv: sbi.console_request_count="); uart.writeDec(s.console_request_count); uart.write("\r\n"); uart.write("hv: sbi.unknown_request_count="); uart.writeDec(s.unknown_request_count); uart.write("\r\n"); uart.write("hv: sbi.last_error="); uart.write(errorName(s.last_error)); uart.write("\r\n"); }
fn writeSigned(value: isize) void { if (value < 0) { uart.write("-"); uart.writeDec(@as(usize, @intCast(-value))); } else uart.writeDec(@as(usize, @intCast(value))); }
fn printCapabilities() void { printCapability(base_ext); printCapability(timer_ext); printCapability(console_ext); }
fn printCapability(md: ExtensionMetadata) void { _ = lookupExtension(md.id); uart.write("hv: sbi.extension."); uart.write(md.name); uart.write(".id="); uart.writeHex(md.id); uart.write("\r\n"); uart.write("hv: sbi.extension."); uart.write(md.name); uart.write(".function_count="); uart.writeDec(md.function_count); uart.write("\r\n"); uart.write("hv: sbi.extension."); uart.write(md.name); uart.write(".claim="); uart.write(md.service_claim); uart.write("\r\n"); }
fn extensionName(e: Extension) []const u8 { return switch (e) { .base => "base", .timer => "timer", .console => "legacy-console", .unknown => "unknown" }; }
fn errorName(e: Error) []const u8 { return switch (e) { .none => "none", .no_request => "no-request", .unknown_extension => "unknown-extension", .unsupported_function => "unsupported-function", .invalid_argument => "invalid-argument" }; }
fn printNonClaims() void { uart.write("hv: linux_guest=not-supported-yet\r\n"); uart.write("hv: guest_execution=not-supported-yet\r\n"); uart.write("hv: sbi_services=not-implemented\r\n"); uart.write("hv: h_extension=unknown reason=no-safe-detection-yet\r\n"); }
