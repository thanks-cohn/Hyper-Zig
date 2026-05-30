const log = @import("../log.zig");

pub fn init() void {
    log.info("SCHED", "SCHED001", "scheduler stub active");
}

pub fn idle() void {
    asm volatile ("wfi");
}
