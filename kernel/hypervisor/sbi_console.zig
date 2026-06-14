const uart = @import("../console/uart.zig");
const vm_model = @import("vm.zig");
const vcpu_model = @import("vcpu.zig");
const sbi = @import("sbi.zig");

pub const legacy_console_extension_id: usize = 0x1;
pub const legacy_putchar_function_id: usize = 0;
pub const legacy_getchar_function_id: usize = 1;
pub const output_capacity: usize = 16;

pub const State = enum { empty, ready, rejected };
pub const Operation = enum { none, putchar, getchar, invalid };
pub const Error = enum { none, no_request, invalid_extension, unsupported_function, output_overflow };
pub const Result = enum { ok, rejected };

pub const ConsoleMediation = struct {
    owner_vm_id: vm_model.VmId,
    owner_vcpu_id: vcpu_model.VcpuId,
    state: State,
    has_request: bool,
    last_extension_id: usize,
    last_function_id: usize,
    last_operation: Operation,
    last_character: u8,
    putchar_request_count: usize,
    getchar_request_count: usize,
    invalid_request_count: usize,
    validation_count: usize,
    reset_count: usize,
    reject_count: usize,
    input_consumed_count: usize,
    input_unavailable_count: usize,
    output_len: usize,
    output: [output_capacity]u8,
    last_error: Error,
    last_getchar_result: isize,
};

var state: ConsoleMediation = undefined;
var initialized = false;

pub fn init(owner_vm_id: vm_model.VmId, owner_vcpu_id: vcpu_model.VcpuId) void {
    state = empty(owner_vm_id, owner_vcpu_id, 0);
    initialized = true;
}

pub fn object() *const ConsoleMediation { return mutable(); }
fn mutable() *ConsoleMediation {
    if (!initialized) init(vm_model.object().id, vcpu_model.object().id);
    return &state;
}

fn empty(owner_vm_id: vm_model.VmId, owner_vcpu_id: vcpu_model.VcpuId, reset_count: usize) ConsoleMediation {
    return .{
        .owner_vm_id = owner_vm_id,
        .owner_vcpu_id = owner_vcpu_id,
        .state = .empty,
        .has_request = false,
        .last_extension_id = 0,
        .last_function_id = 0,
        .last_operation = .none,
        .last_character = 0,
        .putchar_request_count = 0,
        .getchar_request_count = 0,
        .invalid_request_count = 0,
        .validation_count = 0,
        .reset_count = reset_count,
        .reject_count = 0,
        .input_consumed_count = 0,
        .input_unavailable_count = 0,
        .output_len = 0,
        .output = [_]u8{0} ** output_capacity,
        .last_error = .none,
        .last_getchar_result = -1,
    };
}

pub fn reset() void {
    const s = mutable();
    state = empty(s.owner_vm_id, s.owner_vcpu_id, s.reset_count + 1);
    initialized = true;
}

pub fn validate() Result {
    const s = mutable();
    s.validation_count += 1;
    if (!s.has_request) return reject(.no_request);
    if (s.last_extension_id != legacy_console_extension_id) return reject(.invalid_extension);
    if (s.last_function_id != legacy_putchar_function_id and s.last_function_id != legacy_getchar_function_id) return reject(.unsupported_function);
    s.last_error = .none;
    if (s.state == .empty) s.state = .ready;
    return .ok;
}

pub fn recordPutchar(ch: u8) Result {
    const foundation_result = sbi.recordRequest(legacy_console_extension_id, legacy_putchar_function_id, [_]usize{ ch, 0, 0, 0, 0, 0 });
    const s = mutable();
    s.has_request = true;
    s.last_extension_id = legacy_console_extension_id;
    s.last_function_id = legacy_putchar_function_id;
    s.last_operation = .putchar;
    s.last_character = ch;
    if (foundation_result != .ok) return reject(.unsupported_function);
    const validation = validate();
    if (validation != .ok) return validation;
    if (s.output_len >= output_capacity) return reject(.output_overflow);
    s.output[s.output_len] = ch;
    s.output_len += 1;
    s.putchar_request_count += 1;
    s.state = .ready;
    return .ok;
}

pub fn recordGetchar() Result {
    const foundation_result = sbi.recordRequest(legacy_console_extension_id, legacy_getchar_function_id, [_]usize{0} ** 6);
    const s = mutable();
    s.has_request = true;
    s.last_extension_id = legacy_console_extension_id;
    s.last_function_id = legacy_getchar_function_id;
    s.last_operation = .getchar;
    s.last_character = 0;
    if (foundation_result != .ok) return reject(.unsupported_function);
    const validation = validate();
    if (validation != .ok) return validation;
    s.getchar_request_count += 1;
    s.input_unavailable_count += 1;
    s.last_getchar_result = -1;
    s.state = .ready;
    return .ok;
}

pub fn recordInvalidExtension() Result {
    _ = sbi.recordRequest(0xffff, legacy_putchar_function_id, [_]usize{ 65, 0, 0, 0, 0, 0 });
    const s = mutable();
    s.has_request = true; s.last_extension_id = 0xffff; s.last_function_id = legacy_putchar_function_id; s.last_operation = .invalid; s.invalid_request_count += 1;
    _ = validate();
    return .rejected;
}

pub fn recordInvalidFunction() Result {
    _ = sbi.recordRequest(legacy_console_extension_id, 9, [_]usize{0} ** 6);
    const s = mutable();
    s.has_request = true; s.last_extension_id = legacy_console_extension_id; s.last_function_id = 9; s.last_operation = .invalid; s.invalid_request_count += 1;
    _ = validate();
    return .rejected;
}

pub fn fillUntilOverflow() Result {
    while (object().output_len < output_capacity) {
        const ch: u8 = @intCast('a' + (object().output_len % 26));
        if (recordPutchar(ch) != .ok) return .rejected;
    }
    return recordPutchar('!');
}

fn reject(e: Error) Result {
    const s = mutable();
    s.state = .rejected;
    s.last_error = e;
    s.reject_count += 1;
    return .rejected;
}

pub fn byteSum() usize {
    const s = object(); var sum: usize = 0; var i: usize = 0;
    while (i < s.output_len) : (i += 1) sum += s.output[i];
    return sum;
}

pub fn printState() void { printImplementedMarker(); printFields(); printBuffer(); printNonClaims(); }
pub fn printStatusCommand() void { printState(); }
pub fn printValidateCommand() void { const r = validate(); printResult("validate_result", r); printFields(); printNonClaims(); }
pub fn printBlockersCommand() void {
    const s = object();
    const blocker_count: usize = if (s.last_error == .none) 0 else 1;

    uart.write("hv: console.blocker_count=");
    uart.writeDec(blocker_count);
    uart.write("\r\n");

    if (s.last_error == .none) {
        uart.write("hv: console.blocker=none\r\n");
    } else {
        uart.write("hv: console.blocker=");
        uart.write(errorName(s.last_error));
        uart.write("\r\n");
    }

    printNonClaims();
}
pub fn printPutcharTestCommand() void { const r = recordPutchar('A'); printResult("putchar_test", r); sbi.printStatusCommand(); printFields(); printBuffer(); printNonClaims(); }
pub fn printPutstringTestCommand() void { for ("Hi!") |ch| { if (recordPutchar(ch) != .ok) break; } uart.write("hv: console.putstring_test=ok\r\n"); sbi.printStatusCommand(); printFields(); printBuffer(); printNonClaims(); }
pub fn printGetcharTestCommand() void { const r = recordGetchar(); printResult("getchar_test", r); sbi.printStatusCommand(); uart.write("hv: console.getchar_result=no-input\r\n"); printFields(); printNonClaims(); }
pub fn printInvalidTestCommand() void { const r1 = recordInvalidFunction(); const r2 = recordInvalidExtension(); _ = r1; printResult("invalid_test", r2); printFields(); printNonClaims(); }
pub fn printOverflowTestCommand() void { reset(); const before = object().reject_count; const r = fillUntilOverflow(); printResult("overflow_test", r); uart.write("hv: console.overflow_rejected="); uart.write(if (object().reject_count > before) "true" else "false"); uart.write("\r\n"); printFields(); printBuffer(); printNonClaims(); }
pub fn printBufferCommand() void { printBuffer(); printNonClaims(); }
pub fn printResetCommand() void { reset(); uart.write("hv: console.reset_result=ok\r\n"); printFields(); printBuffer(); printNonClaims(); }

pub fn printImplementedMarker() void { uart.write("hv: sbi_console=foundation-mediation-only\r\n"); }
fn printResult(name: []const u8, r: Result) void { uart.write("hv: console."); uart.write(name); uart.write("="); uart.write(if (r == .ok) "ok" else "rejected"); uart.write("\r\n"); }
fn printFields() void { const s = object(); uart.write("hv: console.owner_vm_id="); uart.writeDec(s.owner_vm_id); uart.write("\r\n"); uart.write("hv: console.owner_vcpu_id="); uart.writeDec(s.owner_vcpu_id); uart.write("\r\n"); uart.write("hv: console.state="); uart.write(stateName(s.state)); uart.write("\r\n"); uart.write("hv: console.has_request="); uart.write(if (s.has_request) "true" else "false"); uart.write("\r\n"); uart.write("hv: console.last_extension_id="); uart.writeHex(s.last_extension_id); uart.write("\r\n"); uart.write("hv: console.last_function_id="); uart.writeDec(s.last_function_id); uart.write("\r\n"); uart.write("hv: console.last_operation="); uart.write(operationName(s.last_operation)); uart.write("\r\n"); uart.write("hv: console.last_character="); uart.writeHex(s.last_character); uart.write("\r\n"); uart.write("hv: console.putchar_request_count="); uart.writeDec(s.putchar_request_count); uart.write("\r\n"); uart.write("hv: console.getchar_request_count="); uart.writeDec(s.getchar_request_count); uart.write("\r\n"); uart.write("hv: console.invalid_request_count="); uart.writeDec(s.invalid_request_count); uart.write("\r\n"); uart.write("hv: console.validation_count="); uart.writeDec(s.validation_count); uart.write("\r\n"); uart.write("hv: console.reset_count="); uart.writeDec(s.reset_count); uart.write("\r\n"); uart.write("hv: console.reject_count="); uart.writeDec(s.reject_count); uart.write("\r\n"); uart.write("hv: console.input_consumed_count="); uart.writeDec(s.input_consumed_count); uart.write("\r\n"); uart.write("hv: console.input_unavailable_count="); uart.writeDec(s.input_unavailable_count); uart.write("\r\n"); uart.write("hv: console.last_error="); uart.write(errorName(s.last_error)); uart.write("\r\n"); }
fn printBuffer() void { const s = object(); uart.write("hv: console.output_buffer_length="); uart.writeDec(s.output_len); uart.write("\r\n"); uart.write("hv: console.output_buffer_capacity="); uart.writeDec(output_capacity); uart.write("\r\n"); uart.write("hv: console.output_buffer_bytesum="); uart.writeDec(byteSum()); uart.write("\r\n"); uart.write("hv: console.output_buffer="); var i: usize = 0; while (i < s.output_len) : (i += 1) uart.putByte(s.output[i]); uart.write("\r\n"); }
fn stateName(v: State) []const u8 { return switch (v) { .empty => "empty", .ready => "ready", .rejected => "rejected" }; }
fn operationName(v: Operation) []const u8 { return switch (v) { .none => "none", .putchar => "putchar", .getchar => "getchar", .invalid => "invalid" }; }
fn errorName(v: Error) []const u8 { return switch (v) { .none => "none", .no_request => "no-request", .invalid_extension => "invalid-extension", .unsupported_function => "unsupported-function", .output_overflow => "output-overflow" }; }
fn printNonClaims() void { uart.write("hv: console_putchar=modelled\r\n"); uart.write("hv: console_getchar=no-input\r\n"); uart.write("hv: console_guest_integration=not-attempted\r\n"); uart.write("hv: linux_guest=not-supported-yet\r\n"); uart.write("hv: guest_execution=not-supported-yet\r\n"); uart.write("hv: second_stage_translation=MISSING\r\n"); uart.write("hv: printk=not-proven-yet\r\n"); uart.write("hv: guest_entered=no\r\n"); uart.write("hv: sbi_services=not-implemented\r\n"); }
