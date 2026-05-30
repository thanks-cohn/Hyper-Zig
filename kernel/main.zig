const runtime_mem = @import("runtime/mem.zig");
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
    runtime_mem.force_link();
    boot.markKernelEntry();
    uart.init();
    memory.init();
    trap.init();
    plic.init();
    timer.init();
    scheduler.init();
    userspace_init_stub();
    shell.start();
}

pub fn panic(message: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    panic_mod.panic(message);
}


fn userspace_init_stub() void {
    uart.write("[ZIGN01D][WARN][INIT][INIT001] userspace init stub active\r\n");
}
