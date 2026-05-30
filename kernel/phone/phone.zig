const diag = @import("../diag/breadcrumb.zig");
const uart = @import("../console/uart.zig");

pub const ComponentState = enum { missing, unknown, ready };

pub const Status = struct {
    initialized: bool,
    modem: ComponentState,
    cellular: ComponentState,
    audio_call_path: ComponentState,
    sms: ComponentState,
    inspect_hint: []const u8,
};

var initialized: bool = false;
var modem_state: ComponentState = .missing;
var cellular_state: ComponentState = .missing;
var audio_state: ComponentState = .missing;
var sms_state: ComponentState = .missing;

pub fn init() void {
    initialized = true;
    modem_state = .missing;
    cellular_state = .missing;
    audio_state = .missing;
    sms_state = .missing;
    diag.warn("PHONE", "PHONE001", "phone service placeholder active");
}

pub fn status() Status {
    return .{
        .initialized = initialized,
        .modem = modem_state,
        .cellular = cellular_state,
        .audio_call_path = audio_state,
        .sms = sms_state,
        .inspect_hint = "inspect kernel/phone/phone.zig, modem driver, cellular stack, audio route",
    };
}

pub fn printStatus() void {
    const s = status();
    uart.write("phone: initialized=");
    uart.write(if (s.initialized) "yes" else "no");
    uart.write(" inspect=");
    uart.write(s.inspect_hint);
    uart.write("\r\n");
    uart.write("  modem driver ");
    uart.write(componentPhrase(s.modem));
    uart.write("\r\n");
    uart.write("  cellular stack ");
    uart.write(componentPhrase(s.cellular));
    uart.write("\r\n");
    uart.write("  audio path ");
    uart.write(componentPhrase(s.audio_call_path));
    uart.write(" for calls\r\n");
    uart.write("  sms stack ");
    uart.write(componentPhrase(s.sms));
    uart.write("\r\n");
}

pub fn callUnavailable() void {
    diag.warn("PHONE", "PHONE002", "call unavailable; inspect kernel/phone/phone.zig, modem driver, cellular stack, audio route");
}

pub fn smsUnavailable() void {
    diag.warn("PHONE", "PHONE003", "sms unavailable; inspect kernel/phone/phone.zig, modem driver, cellular stack");
}

fn componentPhrase(state: ComponentState) []const u8 {
    return switch (state) {
        .missing => "missing",
        .unknown => "unknown",
        .ready => "ready",
    };
}
