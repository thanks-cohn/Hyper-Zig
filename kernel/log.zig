const uart = @import("console/uart.zig");

pub fn info(subsystem: []const u8, code: []const u8, message: []const u8) void {
    write("INFO", subsystem, code, message);
}

pub fn warn(subsystem: []const u8, code: []const u8, message: []const u8) void {
    write("WARN", subsystem, code, message);
}

pub fn err(subsystem: []const u8, code: []const u8, message: []const u8) void {
    write("ERROR", subsystem, code, message);
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
