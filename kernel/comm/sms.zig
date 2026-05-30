const uart = @import("../console/uart.zig");

pub const Status = struct {
    backend: []const u8,
    bridge: []const u8,
    provider: []const u8,
    zbus_state: []const u8,
    real_modem: []const u8,
};

pub fn status() Status {
    return .{
        .backend = "none",
        .bridge = "not-connected",
        .provider = "zbus",
        .zbus_state = "not-connected",
        .real_modem = "not-attached",
    };
}

pub fn printInbox() void {
    const s = status();
    uart.write("sms: backend=");
    uart.write(s.backend);
    uart.write("\r\n");
    uart.write("sms: provider=");
    uart.write(s.provider);
    uart.write("\r\n");
    uart.write("sms: zbus=");
    uart.write(s.zbus_state);
    uart.write("\r\n");
    uart.write("sms: inbox=unavailable\r\n");
    uart.write("sms: bridge=");
    uart.write(s.bridge);
    uart.write("\r\n");
    uart.write("sms: real_modem=");
    uart.write(s.real_modem);
    uart.write("\r\n");
}

pub fn printSend(number: []const u8) void {
    const s = status();
    uart.write("sms: backend=");
    uart.write(s.backend);
    uart.write("\r\n");
    uart.write("sms: provider=");
    uart.write(s.provider);
    uart.write("\r\n");
    uart.write("sms: zbus=");
    uart.write(s.zbus_state);
    uart.write("\r\n");
    uart.write("sms: send=not-implemented\r\n");
    uart.write("sms: number=");
    if (number.len == 0) {
        uart.write("<missing>");
    } else {
        uart.write(number);
    }
    uart.write("\r\n");
    uart.write("sms: bridge=");
    uart.write(s.bridge);
    uart.write("\r\n");
    uart.write("sms: real_modem=");
    uart.write(s.real_modem);
    uart.write("\r\n");
    uart.write("sms: safety=not-sent\r\n");
}

pub fn printWait() void {
    const s = status();
    uart.write("sms: provider=");
    uart.write(s.provider);
    uart.write("\r\n");
    uart.write("sms: zbus=");
    uart.write(s.zbus_state);
    uart.write("\r\n");
    uart.write("sms: wait=not-implemented\r\n");
    uart.write("sms: incoming=unavailable\r\n");
    uart.write("sms: bridge=");
    uart.write(s.bridge);
    uart.write("\r\n");
}
