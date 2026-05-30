const log = @import("../log.zig");
const uart = @import("../console/uart.zig");
pub const bridge = @import("bridge.zig");
pub const net = @import("net.zig");
pub const sms = @import("sms.zig");
pub const modem = @import("modem.zig");

pub const Status = struct {
    interface: []const u8,
    bridge_state: []const u8,
    bridge_transport: []const u8,
    net_backend: []const u8,
    sms_backend: []const u8,
    modem_backend: []const u8,
    real_internet: []const u8,
    real_sms_send: []const u8,
    real_sms_receive: []const u8,
    real_modem: []const u8,
    real_calls: []const u8,
    wifi_calling: []const u8,
};

pub fn init() void {
    log.info("COMM", "COMM000", "communication scaffold present; bridge not connected");
}

pub fn status() Status {
    return .{
        .interface = "present",
        .bridge_state = "not-connected",
        .bridge_transport = "none",
        .net_backend = "none",
        .sms_backend = "none",
        .modem_backend = "none",
        .real_internet = "not-implemented",
        .real_sms_send = "not-implemented",
        .real_sms_receive = "not-implemented",
        .real_modem = "not-attached",
        .real_calls = "not-implemented",
        .wifi_calling = "not-implemented",
    };
}

pub fn printStatus() void {
    const s = status();
    uart.write("comm: interface=");
    uart.write(s.interface);
    uart.write("\r\n");
    uart.write("comm: bridge=");
    uart.write(s.bridge_state);
    uart.write("\r\n");
    uart.write("comm: bridge_transport=");
    uart.write(s.bridge_transport);
    uart.write("\r\n");
    uart.write("comm: net_backend=");
    uart.write(s.net_backend);
    uart.write("\r\n");
    uart.write("comm: sms_backend=");
    uart.write(s.sms_backend);
    uart.write("\r\n");
    uart.write("comm: modem_backend=");
    uart.write(s.modem_backend);
    uart.write("\r\n");
    uart.write("comm: real_internet=");
    uart.write(s.real_internet);
    uart.write("\r\n");
    uart.write("comm: real_sms_send=");
    uart.write(s.real_sms_send);
    uart.write("\r\n");
    uart.write("comm: real_sms_receive=");
    uart.write(s.real_sms_receive);
    uart.write("\r\n");
    uart.write("comm: real_modem=");
    uart.write(s.real_modem);
    uart.write("\r\n");
    uart.write("comm: real_calls=");
    uart.write(s.real_calls);
    uart.write("\r\n");
    uart.write("comm: wifi_calling=");
    uart.write(s.wifi_calling);
    uart.write("\r\n");
}

pub fn printStatusSummary() void {
    const s = status();
    uart.write("comm_interface=");
    uart.write(s.interface);
    uart.write("\r\n");
    uart.write("comm_bridge=");
    uart.write(s.bridge_state);
    uart.write("\r\n");
    uart.write("comm_net_backend=");
    uart.write(s.net_backend);
    uart.write("\r\n");
    uart.write("comm_sms_backend=");
    uart.write(s.sms_backend);
    uart.write("\r\n");
    uart.write("comm_modem_backend=");
    uart.write(s.modem_backend);
    uart.write("\r\n");
    uart.write("real_internet=");
    uart.write(s.real_internet);
    uart.write("\r\n");
    uart.write("real_sms=");
    uart.write(s.real_sms_send);
    uart.write("\r\n");
    uart.write("real_calls=");
    uart.write(s.real_calls);
    uart.write("\r\n");
}
