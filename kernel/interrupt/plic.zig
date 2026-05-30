const log = @import("../log.zig");

pub fn init() void {
    log.warn("IRQ", "IRQ001", "interrupt controller stub active; polling uart shell enabled");
}
