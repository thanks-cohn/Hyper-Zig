const diag = @import("../diag/breadcrumb.zig");
const uart = @import("../console/uart.zig");

pub const NetworkState = enum { down, driver_missing, link_unknown };

pub const Status = struct {
    initialized: bool,
    current: NetworkState,
    driver: []const u8,
    inspect_hint: []const u8,
};

var initialized: bool = false;
var current_state: NetworkState = .down;

pub fn init() void {
    initialized = true;
    current_state = .driver_missing;
    diag.warn("NET", "NET001", "virtio-net driver placeholder active");
}

pub fn status() Status {
    return .{ .initialized = initialized, .current = current_state, .driver = "virtio-mmio-net0 missing", .inspect_hint = "inspect kernel/net/net.zig and virtio-mmio device registry" };
}

pub fn printStatus() void {
    const s = status();
    uart.write("net: initialized=");
    uart.write(if (s.initialized) "yes" else "no");
    uart.write(" state=");
    uart.write(stateName(s.current));
    uart.write(" driver=");
    uart.write(s.driver);
    uart.write(" inspect=");
    uart.write(s.inspect_hint);
    uart.write("\r\n");
}

pub fn pingUnavailable() void {
    diag.warn("NET", "NET002", "network driver not implemented; inspect kernel/net/net.zig and virtio-mmio device registry");
}

pub fn stateName(state: NetworkState) []const u8 {
    return switch (state) {
        .down => "down",
        .driver_missing => "driver_missing",
        .link_unknown => "link_unknown",
    };
}
