const uart = @import("uart.zig");

/// Start the V0 interactive command shell.
pub fn start() void {
    uart.init();
    uart.write("ZIGN01D V0 shell\n");
    // TODO: implement help, mem, uptime, reboot, and shutdown.
}
