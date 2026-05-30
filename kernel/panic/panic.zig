const cpu = @import("../arch/riscv64/cpu.zig");
const log = @import("../log.zig");
const uart = @import("../console/uart.zig");

pub fn panic(message: []const u8) noreturn {
    panicWithCause("PANIC", "PANIC001", message, 0, "zig-panic");
}

pub fn panicWith(subsystem: []const u8, code: []const u8, message: []const u8) noreturn {
    panicWithCause(subsystem, code, message, 0, "kernel-panic");
}

pub fn panicWithCause(subsystem: []const u8, code: []const u8, message: []const u8, cause: usize, stage: []const u8) noreturn {
    report(subsystem, code, message, cause, stage);
    cpu.halt();
}

pub fn report(subsystem: []const u8, code: []const u8, message: []const u8, cause: usize, stage: []const u8) void {
    log.err("PANIC", "PANIC001", "panic boundary diagnostic report emitted");
    uart.write("[ZIGN01D][PANIC][");
    uart.write(subsystem);
    uart.write("][");
    uart.write(code);
    uart.write("] message=");
    uart.write(message);
    uart.write(" cause=");
    uart.writeHex(cause);
    uart.write(" stage=");
    uart.write(stage);
    uart.write(" last_breadcrumb=inspect-serial-log inspect=kernel/panic/panic.zig docs/TRAPS_AND_PANIC.md\r\n");
    uart.write("[ZIGN01D][WARN][PANIC][PANIC003] missing stack unwinder and trap frame dump; inspect kernel/arch/riscv64/trap.zig\r\n");
}
