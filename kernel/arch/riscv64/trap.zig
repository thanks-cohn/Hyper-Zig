const log = @import("../../log.zig");

pub fn init() void {
    log.warn("IRQ", "IRQ002", "trap vector stub active");
}

pub fn handleTrap() void {
    log.err("IRQ", "IRQ003", "unhandled trap reached stub handler");
}
