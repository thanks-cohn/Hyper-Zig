const std = @import("std");
const boot = @import("arch/riscv64/boot.zig");
const uart = @import("console/uart.zig");
const memory = @import("memory/pmm.zig");
const plic = @import("interrupt/plic.zig");
const timer = @import("interrupt/timer.zig");
const trap = @import("arch/riscv64/trap.zig");
const scheduler = @import("scheduler/scheduler.zig");
const shell = @import("console/shell.zig");
const panic_mod = @import("panic/panic.zig");

pub export fn kmain() noreturn {
    boot.markKernelEntry();
    uart.init();
    memory.init();
    trap.init();
    plic.init();
    timer.init();
    scheduler.init();
    @import("../userspace/init/init.zig").start();
    shell.start();
}

pub fn panic(message: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    panic_mod.panic(message);
}
