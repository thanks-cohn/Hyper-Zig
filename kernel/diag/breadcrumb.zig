const uart = @import("../console/uart.zig");

pub fn info(subsystem: []const u8, code: []const u8, message: []const u8) void {
    write("INFO", subsystem, code, message);
}

pub fn warn(subsystem: []const u8, code: []const u8, message: []const u8) void {
    write("WARN", subsystem, code, message);
}

pub fn err(subsystem: []const u8, code: []const u8, message: []const u8) void {
    write("ERROR", subsystem, code, message);
}

pub fn panicMarker(subsystem: []const u8, code: []const u8, message: []const u8) void {
    write("PANIC", subsystem, code, message);
}

pub fn bootStep(code: []const u8, message: []const u8) void {
    info("BOOT", code, message);
}

pub fn initStep(subsystem: []const u8, code: []const u8, message: []const u8) void {
    info(subsystem, code, message);
}

pub fn write(level: []const u8, subsystem: []const u8, code: []const u8, message: []const u8) void {
    uart.write("[ZIGN01D][");
    uart.write(level);
    uart.write("][");
    uart.write(subsystem);
    uart.write("][");
    uart.write(code);
    uart.write("] ");
    uart.write(message);
    uart.write("\r\n");
}

pub fn printDoctrineStatus() void {
    uart.write("breadcrumbs: format=[ZIGN01D][LEVEL][SUBSYSTEM][CODE] message\r\n");
    uart.write("breadcrumbs: errors include subsystem code stage observed-state likely-cause inspect-hint next-check\r\n");
    uart.write("breadcrumbs: inspect docs/LOGGING_AND_BREADCRUMBS.md and kernel/diag/breadcrumb.zig\r\n");
}
