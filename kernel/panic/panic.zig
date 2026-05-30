const cpu = @import("../arch/riscv64/cpu.zig");

/// Kernel panic endpoint.
pub fn panic(_: []const u8) noreturn {
    // TODO: print panic details over UART before halting.
    cpu.halt();
}
