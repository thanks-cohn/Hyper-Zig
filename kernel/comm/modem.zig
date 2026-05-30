const uart = @import("../console/uart.zig");

pub const Status = struct {
    backend: []const u8,
    provider: []const u8,
    zbus_state: []const u8,
    real_modem: []const u8,
    sim: []const u8,
    signal: []const u8,
    network_registration: []const u8,
};

pub fn status() Status {
    return .{
        .backend = "none",
        .provider = "zbus",
        .zbus_state = "not-connected",
        .real_modem = "not-attached",
        .sim = "unknown",
        .signal = "unknown",
        .network_registration = "unknown",
    };
}

pub fn printStatus() void {
    const s = status();
    uart.write("modem: backend=");
    uart.write(s.backend);
    uart.write("\r\n");
    uart.write("modem: provider=");
    uart.write(s.provider);
    uart.write("\r\n");
    uart.write("modem: zbus=");
    uart.write(s.zbus_state);
    uart.write("\r\n");
    uart.write("modem: real_modem=");
    uart.write(s.real_modem);
    uart.write("\r\n");
    uart.write("modem: sim=");
    uart.write(s.sim);
    uart.write("\r\n");
    uart.write("modem: signal=");
    uart.write(s.signal);
    uart.write("\r\n");
    uart.write("modem: network_registration=");
    uart.write(s.network_registration);
    uart.write("\r\n");
}
