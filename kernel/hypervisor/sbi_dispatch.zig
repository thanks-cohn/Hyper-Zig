const uart = @import("../console/uart.zig");
const vm_model = @import("vm.zig");
const vcpu_model = @import("vcpu.zig");
const sbi = @import("sbi.zig");
const virtual_timer = @import("virtual_timer.zig");
const sbi_console = @import("sbi_console.zig");

pub const base_extension_id: usize = 0x10;
pub const timer_extension_id: usize = 0x54494d45;
pub const console_extension_id: usize = 0x1;

pub const State = enum { empty, ready, rejected };
pub const Target = enum { none, base, timer, console_putchar, console_getchar, unknown };
pub const Result = enum { ok, rejected };
pub const Error = enum { none, no_request, unknown_extension, unsupported_function, downstream_rejected };

pub const Request = struct { extension_id: usize, function_id: usize, args: [6]usize };

pub const Dispatcher = struct {
    owner_vm_id: vm_model.VmId,
    owner_vcpu_id: vcpu_model.VcpuId,
    state: State,
    has_request: bool,
    last_extension_id: usize,
    last_function_id: usize,
    last_target: Target,
    last_result: Result,
    last_error: Error,
    last_sbi_error_code: isize,
    last_sbi_return_value: isize,
    args: [6]usize,
    base_dispatch_count: usize,
    timer_dispatch_count: usize,
    console_dispatch_count: usize,
    unknown_dispatch_count: usize,
    validation_count: usize,
    rejection_count: usize,
    reset_count: usize,
    blocker_state: Error,
};

var state: Dispatcher = undefined;
var initialized = false;

pub fn init(owner_vm_id: vm_model.VmId, owner_vcpu_id: vcpu_model.VcpuId) void {
    state = empty(owner_vm_id, owner_vcpu_id, 0);
    initialized = true;
}

pub fn object() *const Dispatcher { return mutable(); }
fn mutable() *Dispatcher { if (!initialized) init(vm_model.object().id, vcpu_model.object().id); return &state; }

fn empty(owner_vm_id: vm_model.VmId, owner_vcpu_id: vcpu_model.VcpuId, reset_count: usize) Dispatcher {
    return .{
        .owner_vm_id = owner_vm_id, .owner_vcpu_id = owner_vcpu_id, .state = .empty, .has_request = false,
        .last_extension_id = 0, .last_function_id = 0, .last_target = .none, .last_result = .ok, .last_error = .none,
        .last_sbi_error_code = 0, .last_sbi_return_value = 0, .args = [_]usize{0} ** 6,
        .base_dispatch_count = 0, .timer_dispatch_count = 0, .console_dispatch_count = 0, .unknown_dispatch_count = 0,
        .validation_count = 0, .rejection_count = 0, .reset_count = reset_count, .blocker_state = .no_request,
    };
}

pub fn reset() void { const d = mutable(); state = empty(d.owner_vm_id, d.owner_vcpu_id, d.reset_count + 1); initialized = true; }

pub fn recordRequest(req: Request) void {
    const d = mutable();
    d.has_request = true; d.state = .ready; d.last_extension_id = req.extension_id; d.last_function_id = req.function_id; d.args = req.args;
    d.last_target = classify(req.extension_id, req.function_id); d.last_result = .ok; d.last_error = .none; d.last_sbi_error_code = 0; d.last_sbi_return_value = 0; d.blocker_state = .none;
}

pub fn dispatchLast() Result {
    const d = mutable();
    d.validation_count += 1;
    if (!d.has_request) return reject(.no_request, .none);
    const target = classify(d.last_extension_id, d.last_function_id);
    d.last_target = target;
    switch (target) {
        .base => return dispatchBase(),
        .timer => return dispatchTimer(),
        .console_putchar => return dispatchConsolePutchar(),
        .console_getchar => return dispatchConsoleGetchar(),
        .unknown => return reject(.unknown_extension, .unknown),
        .none => return reject(.unsupported_function, .none),
    }
}

fn dispatchBase() Result {
    const d = mutable();
    const before = sbi.object().record_count;
    const r = sbi.recordRequest(d.last_extension_id, d.last_function_id, d.args);
    captureSbiResult();
    if (r != .ok or sbi.object().record_count <= before) return reject(.downstream_rejected, .base);
    d.base_dispatch_count += 1; d.last_result = .ok; d.state = .ready; d.blocker_state = .none; return .ok;
}

fn dispatchTimer() Result {
    const d = mutable();
    const before = virtual_timer.object().set_request_count;
    const r = virtual_timer.applySbiTimerSet(d.args[0], 40);
    captureSbiResult();
    if (r != .ok or virtual_timer.object().set_request_count <= before) return reject(.downstream_rejected, .timer);
    d.timer_dispatch_count += 1; d.last_result = .ok; d.state = .ready; d.blocker_state = .none; return .ok;
}

fn dispatchConsolePutchar() Result {
    const d = mutable();
    const before = sbi_console.object().output_len;
    const ch: u8 = @intCast(d.args[0] & 0xff);
    const r = sbi_console.recordPutchar(ch);
    captureSbiResult();
    if (r != .ok or sbi_console.object().output_len <= before) return reject(.downstream_rejected, .console_putchar);
    d.console_dispatch_count += 1; d.last_result = .ok; d.state = .ready; d.blocker_state = .none; return .ok;
}

fn dispatchConsoleGetchar() Result {
    const d = mutable();
    const before = sbi_console.object().getchar_request_count;
    const r = sbi_console.recordGetchar();
    captureSbiResult();
    d.last_sbi_return_value = sbi_console.object().last_getchar_result;
    if (r != .ok or sbi_console.object().getchar_request_count <= before) return reject(.downstream_rejected, .console_getchar);
    d.console_dispatch_count += 1; d.last_result = .ok; d.state = .ready; d.blocker_state = .none; return .ok;
}

fn reject(e: Error, target: Target) Result {
    const d = mutable();
    d.state = .rejected; d.last_result = .rejected; d.last_error = e; d.blocker_state = e; d.rejection_count += 1; d.last_sbi_error_code = -2; d.last_sbi_return_value = -1;
    if (target == .unknown) d.unknown_dispatch_count += 1;
    return .rejected;
}

fn captureSbiResult() void { const d = mutable(); d.last_sbi_error_code = sbi.object().error_code; d.last_sbi_return_value = sbi.object().return_value; }
fn classify(ext: usize, func: usize) Target {
    if (ext == base_extension_id) return if (func < 7) .base else .none;
    if (ext == timer_extension_id) return if (func == 0) .timer else .none;
    if (ext == console_extension_id) return if (func == 0) .console_putchar else if (func == 1) .console_getchar else .none;
    return .unknown;
}

pub fn printState() void { printImplementedMarker(); printFields(); printNonClaims(); }
pub fn printStatusCommand() void { printState(); }
pub fn printValidateCommand() void { const r = dispatchLast(); printResult("validate_result", r); printFields(); printNonClaims(); }
pub fn printResetCommand() void { reset(); uart.write("hv: sbi_dispatch.reset_result=ok\r\n"); printFields(); printNonClaims(); }
pub fn printBlockersCommand() void { _ = dispatchLast(); uart.write("hv: sbi_dispatch.blocker_count="); uart.writeDec(if (object().blocker_state == .none) 0 else 1); uart.write("\r\n"); uart.write("hv: sbi_dispatch.blocker="); uart.write(if (object().blocker_state == .none) "none" else errorName(object().blocker_state)); uart.write("\r\n"); uart.write("hv: sbi_dispatch.blockers=deterministic-from-dispatcher-state\r\n"); printNonClaims(); }
pub fn printBaseTestCommand() void { recordRequest(.{ .extension_id = base_extension_id, .function_id = 0, .args = [_]usize{0} ** 6 }); const r = dispatchLast(); printResult("base_test", r); printFields(); sbi.printStatusCommand(); printNonClaims(); }
pub fn printTimerTestCommand() void { recordRequest(.{ .extension_id = timer_extension_id, .function_id = 0, .args = [_]usize{ 100, 0, 0, 0, 0, 0 } }); const r = dispatchLast(); printResult("timer_test", r); printFields(); virtual_timer.printStatusCommand(); printNonClaims(); }
pub fn printConsolePutcharTestCommand() void { recordRequest(.{ .extension_id = console_extension_id, .function_id = 0, .args = [_]usize{ 90, 0, 0, 0, 0, 0 } }); const r = dispatchLast(); printResult("console_putchar_test", r); printFields(); sbi_console.printStatusCommand(); printNonClaims(); }
pub fn printConsoleGetcharTestCommand() void { recordRequest(.{ .extension_id = console_extension_id, .function_id = 1, .args = [_]usize{0} ** 6 }); const r = dispatchLast(); printResult("console_getchar_test", r); uart.write("hv: sbi_dispatch.getchar_result=no-input\r\n"); printFields(); sbi_console.printStatusCommand(); printNonClaims(); }
pub fn printUnknownTestCommand() void { recordRequest(.{ .extension_id = 0xffff, .function_id = 0, .args = [_]usize{0} ** 6 }); const r = dispatchLast(); printResult("unknown_test", r); printFields(); printNonClaims(); }
pub fn printUnsupportedFunctionTestCommand() void { recordRequest(.{ .extension_id = console_extension_id, .function_id = 9, .args = [_]usize{0} ** 6 }); const r = dispatchLast(); printResult("unsupported_function_test", r); printFields(); printNonClaims(); }

pub fn printImplementedMarker() void { uart.write("hv: sbi_dispatch=foundation-routing-only\r\n"); }
fn printResult(name: []const u8, r: Result) void { uart.write("hv: sbi_dispatch."); uart.write(name); uart.write("="); uart.write(if (r == .ok) "ok" else "rejected"); uart.write("\r\n"); }
fn printFields() void { const d = object(); uart.write("hv: sbi_dispatch.owner_vm_id="); uart.writeDec(d.owner_vm_id); uart.write("\r\n"); uart.write("hv: sbi_dispatch.owner_vcpu_id="); uart.writeDec(d.owner_vcpu_id); uart.write("\r\n"); uart.write("hv: sbi_dispatch.state="); uart.write(stateName(d.state)); uart.write("\r\n"); uart.write("hv: sbi_dispatch.has_request="); uart.write(if (d.has_request) "true" else "false"); uart.write("\r\n"); uart.write("hv: sbi_dispatch.last_extension_id="); uart.writeHex(d.last_extension_id); uart.write("\r\n"); uart.write("hv: sbi_dispatch.last_function_id="); uart.writeDec(d.last_function_id); uart.write("\r\n"); uart.write("hv: sbi_dispatch.last_target="); uart.write(targetName(d.last_target)); uart.write("\r\n"); uart.write("hv: sbi_dispatch.last_result="); uart.write(if (d.last_result == .ok) "ok" else "rejected"); uart.write("\r\n"); uart.write("hv: sbi_dispatch.last_error="); uart.write(errorName(d.last_error)); uart.write("\r\n"); uart.write("hv: sbi_dispatch.last_sbi_error_code="); writeSigned(d.last_sbi_error_code); uart.write("\r\n"); uart.write("hv: sbi_dispatch.last_sbi_return_value="); writeSigned(d.last_sbi_return_value); uart.write("\r\n"); var i: usize = 0; while (i < 6) : (i += 1) { uart.write("hv: sbi_dispatch.arg"); uart.writeDec(i); uart.write("="); uart.writeHex(d.args[i]); uart.write("\r\n"); } uart.write("hv: sbi_dispatch.base_dispatch_count="); uart.writeDec(d.base_dispatch_count); uart.write("\r\n"); uart.write("hv: sbi_dispatch.timer_dispatch_count="); uart.writeDec(d.timer_dispatch_count); uart.write("\r\n"); uart.write("hv: sbi_dispatch.console_dispatch_count="); uart.writeDec(d.console_dispatch_count); uart.write("\r\n"); uart.write("hv: sbi_dispatch.unknown_dispatch_count="); uart.writeDec(d.unknown_dispatch_count); uart.write("\r\n"); uart.write("hv: sbi_dispatch.validation_count="); uart.writeDec(d.validation_count); uart.write("\r\n"); uart.write("hv: sbi_dispatch.rejection_count="); uart.writeDec(d.rejection_count); uart.write("\r\n"); uart.write("hv: sbi_dispatch.reset_count="); uart.writeDec(d.reset_count); uart.write("\r\n"); uart.write("hv: sbi_dispatch.blocker_state="); uart.write(errorName(d.blocker_state)); uart.write("\r\n"); }
fn stateName(v: State) []const u8 { return switch (v) { .empty => "empty", .ready => "ready", .rejected => "rejected" }; }
fn targetName(v: Target) []const u8 { return switch (v) { .none => "none", .base => "base", .timer => "timer", .console_putchar => "console-putchar", .console_getchar => "console-getchar", .unknown => "unknown" }; }
fn errorName(v: Error) []const u8 { return switch (v) { .none => "none", .no_request => "no-request", .unknown_extension => "unknown-extension", .unsupported_function => "unsupported-function", .downstream_rejected => "downstream-rejected" }; }
fn writeSigned(value: isize) void { if (value < 0) { uart.write("-"); uart.writeDec(@as(usize, @intCast(-value))); } else uart.writeDec(@as(usize, @intCast(value))); }
fn printNonClaims() void { uart.write("hv: sbi_dispatch.base=metadata-only\r\n"); uart.write("hv: sbi_dispatch.timer=mediated-metadata-only\r\n"); uart.write("hv: sbi_dispatch.console=mediated-buffer-only\r\n"); uart.write("hv: linux_guest=not-supported-yet\r\n"); uart.write("hv: guest_execution=not-supported-yet\r\n"); uart.write("hv: second_stage_translation=MISSING\r\n"); uart.write("hv: printk=not-proven-yet\r\n"); uart.write("hv: console_guest_integration=not-attempted\r\n"); uart.write("hv: guest_entered=no\r\n"); uart.write("hv: sbi_services=not-implemented\r\n"); uart.write("hv: timer_interrupt_delivery=not-implemented\r\n"); }
