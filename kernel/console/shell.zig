const uart = @import("uart.zig");
const log = @import("../log.zig");
const mem = @import("../memory/pmm.zig");
const timer = @import("../interrupt/timer.zig");
const cpu = @import("../arch/riscv64/cpu.zig");

const RESET_BASE: usize = 0x0010_0000;
const FINISHER_PASS: u32 = 0x5555;
const FINISHER_RESET: u32 = 0x7777;

fn finisher() *volatile u32 {
    return @ptrFromInt(RESET_BASE);
}

pub fn start() noreturn {
    log.info("SHELL", "SHELL001", "shell ready");
    uart.write("ZIGN01D V0 interactive shell\r\n");
    uart.write("Type 'help' for commands.\r\n");

    var line: [128]u8 = undefined;
    while (true) {
        uart.write("zign01d> ");
        const len = readLine(&line);
        handle(line[0..len]);
    }
}

fn readLine(buf: []u8) usize {
    var len: usize = 0;
    while (true) {
        const byte = uart.readByteBlocking();
        switch (byte) {
            '\r', '\n' => {
                uart.write("\r\n");
                return len;
            },
            0x08, 0x7f => {
                if (len > 0) {
                    len -= 1;
                    uart.write("\x08 \x08");
                }
            },
            else => {
                if (byte >= 0x20 and byte <= 0x7e and len < buf.len) {
                    buf[len] = byte;
                    len += 1;
                    uart.putByte(byte);
                }
            },
        }
    }
}

fn handle(cmd: []const u8) void {
    if (cmd.len == 0) return;
    if (equals(cmd, "help")) return help();
    if (equals(cmd, "mem")) return mem.report();
    if (equals(cmd, "uptime")) return uptime();
    if (equals(cmd, "reboot")) return reboot();
    if (equals(cmd, "shutdown")) return shutdown();
    if (equals(cmd, "log")) return logCommand();
    if (equals(cmd, "status")) return status();

    log.warn("SHELL", "SHELL002", "unknown shell command");
    uart.write("unknown command: ");
    uart.write(cmd);
    uart.write("\r\n");
}

fn help() void {
    uart.write("commands: help mem uptime reboot shutdown log status\r\n");
}

fn uptime() void {
    uart.write("[ZIGN01D][INFO][TIMER][TIMER002] uptime ticks=");
    uart.writeDec(timer.ticks());
    uart.write("\r\n");
}

fn reboot() noreturn {
    log.warn("SHELL", "SHELL003", "reboot requested via qemu virt finisher");
    finisher().* = FINISHER_RESET;
    cpu.halt();
}

fn shutdown() noreturn {
    log.warn("SHELL", "SHELL004", "shutdown requested via qemu virt finisher");
    finisher().* = FINISHER_PASS;
    cpu.halt();
}

fn logCommand() void {
    log.info("SHELL", "SHELL005", "log command reached; boot log is visible in serial transcript");
}

fn status() void {
    uart.write("ZIGN01D V0 status: boot=real uart=real mem=reported irq=stub timer=stub scheduler=stub shell=real\r\n");
}

fn equals(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;
    for (a, 0..) |ch, i| {
        if (ch != b[i]) return false;
    }
    return true;
}
