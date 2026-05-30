const cpu = @import("../arch/riscv64/cpu.zig");
const log = @import("../log.zig");
const uart = @import("../console/uart.zig");

pub fn panic(message: []const u8) noreturn {
    panicWith("PANIC", "PANIC001", message);
}

pub fn panicWith(subsystem: []const u8, code: []const u8, message: []const u8) noreturn {
    log.err("PANIC", "PANIC001", "panic reached");
    uart.write("[ZIGN01D][ERROR][PANIC][PANIC002] subsystem=");
    uart.write(subsystem);
    uart.write(" code=");
    uart.write(code);
    uart.write(" message=");
    uart.write(message);
    uart.write("\r\n");
    cpu.halt();
}
