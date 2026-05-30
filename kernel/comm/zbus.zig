const log = @import("../log.zig");
const uart = @import("../console/uart.zig");

pub const Status = struct {
    interface: []const u8,
    transport: []const u8,
    connected: []const u8,
    providers: []const u8,
    net: []const u8,
    sms: []const u8,
    modem: []const u8,
    files: []const u8,
    time: []const u8,
};

pub fn init() void {
    log.info("ZBUS", "ZBUS000", "host capability bus scaffold present; transport not connected");
}

pub fn status() Status {
    return .{
        .interface = "present",
        .transport = "none",
        .connected = "no",
        .providers = "none",
        .net = "not-implemented",
        .sms = "not-implemented",
        .modem = "not-implemented",
        .files = "not-implemented",
        .time = "not-implemented",
    };
}

pub fn printStatus() void {
    const s = status();
    uart.write("zbus: interface=");
    uart.write(s.interface);
    uart.write("\r\n");
    uart.write("zbus: transport=");
    uart.write(s.transport);
    uart.write("\r\n");
    uart.write("zbus: connected=");
    uart.write(s.connected);
    uart.write("\r\n");
    uart.write("zbus: providers=");
    uart.write(s.providers);
    uart.write("\r\n");
    uart.write("zbus: net=");
    uart.write(s.net);
    uart.write("\r\n");
    uart.write("zbus: sms=");
    uart.write(s.sms);
    uart.write("\r\n");
    uart.write("zbus: modem=");
    uart.write(s.modem);
    uart.write("\r\n");
    uart.write("zbus: files=");
    uart.write(s.files);
    uart.write("\r\n");
    uart.write("zbus: time=");
    uart.write(s.time);
    uart.write("\r\n");
}

pub fn printProviders() void {
    const s = status();
    uart.write("zbus: providers=");
    uart.write(s.providers);
    uart.write("\r\n");
    uart.write("zbus: net=");
    uart.write(s.net);
    uart.write("\r\n");
    uart.write("zbus: sms=");
    uart.write(s.sms);
    uart.write("\r\n");
    uart.write("zbus: modem=");
    uart.write(s.modem);
    uart.write("\r\n");
    uart.write("zbus: files=");
    uart.write(s.files);
    uart.write("\r\n");
    uart.write("zbus: time=");
    uart.write(s.time);
    uart.write("\r\n");
}

pub fn printPing() void {
    uart.write("zbus: ping=not-implemented\r\n");
    uart.write("zbus: reason=no transport connected\r\n");
    uart.write("zbus: safety=no host request sent\r\n");
}

pub fn printSummaryFields() void {
    const s = status();
    uart.write("zbus_interface=");
    uart.write(s.interface);
    uart.write("\r\n");
    uart.write("zbus_transport=");
    uart.write(s.transport);
    uart.write("\r\n");
    uart.write("zbus_connected=");
    uart.write(s.connected);
    uart.write("\r\n");
    uart.write("zbus_providers=");
    uart.write(s.providers);
    uart.write("\r\n");
}
