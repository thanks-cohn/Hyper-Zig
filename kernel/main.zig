const boot = @import("arch/riscv64/boot.zig");
const memory = @import("memory/pmm.zig");
const interrupts = @import("interrupt/timer.zig");
const scheduler = @import("scheduler/scheduler.zig");
const shell = @import("console/shell.zig");

/// V0 kernel entry after the architecture bootstrap hands control to Zig.
pub export fn kmain() noreturn {
    boot.markKernelEntry();
    memory.init();
    interrupts.init();
    scheduler.init();
    shell.start();

    while (true) {
        scheduler.idle();
    }
}
