const log = @import("../log.zig");

pub fn init() void {
    log.warn("TIMER", "TIMER001", "timer stub active; uptime uses rdtime polling");
}

pub fn ticks() u64 {
    var value: u64 = 0;
    asm volatile ("rdtime %[value]"
        : [value] "=r" (value),
    );
    return value;
}
