const uart = @import("../console/uart.zig");

pub const Status = struct {
    backend: []const u8,
    bridge: []const u8,
    internet: []const u8,
    direct_virtio_net: []const u8,
};

pub fn status() Status {
    return .{
        .backend = "none",
        .bridge = "not-connected",
        .internet = "not-implemented",
        .direct_virtio_net = "not-implemented",
    };
}

pub fn printStatus() void {
    const s = status();
    uart.write("net: backend=");
    uart.write(s.backend);
    uart.write("\r\n");
    uart.write("net: bridge=");
    uart.write(s.bridge);
    uart.write("\r\n");
    uart.write("net: internet=");
    uart.write(s.internet);
    uart.write("\r\n");
    uart.write("net: direct_virtio_net=");
    uart.write(s.direct_virtio_net);
    uart.write("\r\n");
    uart.write("net: safety=no packets sent\r\n");
}

pub fn printGet(url: []const u8) void {
    const s = status();
    uart.write("net: backend=");
    uart.write(s.backend);
    uart.write("\r\n");
    uart.write("net: get=not-implemented\r\n");
    uart.write("net: url=");
    if (url.len == 0) {
        uart.write("<missing>");
    } else {
        uart.write(url);
    }
    uart.write("\r\n");
    uart.write("net: bridge=");
    uart.write(s.bridge);
    uart.write("\r\n");
    uart.write("net: safety=no network request sent\r\n");
}
