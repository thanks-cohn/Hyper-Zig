const uart = @import("../console/uart.zig");

pub const Status = struct {
    connected: []const u8,
    transport: []const u8,
    target: []const u8,
    purpose: []const u8,
};

pub fn status() Status {
    return .{
        .connected = "no",
        .transport = "none",
        .target = "none",
        .purpose = "future host bridge for internet, SMS, and modem status",
    };
}

pub fn printStatus() void {
    const s = status();
    uart.write("bridge: connected=");
    uart.write(s.connected);
    uart.write("\r\n");
    uart.write("bridge: transport=");
    uart.write(s.transport);
    uart.write("\r\n");
    uart.write("bridge: target=");
    uart.write(s.target);
    uart.write("\r\n");
    uart.write("bridge: purpose=");
    uart.write(s.purpose);
    uart.write("\r\n");
}
