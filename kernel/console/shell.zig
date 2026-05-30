const uart = @import("uart.zig");
const log = @import("../log.zig");
const diag = @import("../diag/breadcrumb.zig");
const mem = @import("../memory/pmm.zig");
const timer = @import("../interrupt/timer.zig");
const cpu = @import("../arch/riscv64/cpu.zig");
const task = @import("../task/task.zig");
const device = @import("../device/device.zig");
const syscall = @import("../syscall/syscall.zig");
const net = @import("../net/net.zig");
const phone = @import("../phone/phone.zig");
const trap = @import("../arch/riscv64/trap.zig");

const RESET_BASE: usize = 0x0010_0000;
const FINISHER_PASS: u32 = 0x5555;
const FINISHER_RESET: u32 = 0x7777;
const VERSION = "ZIGN01D V2 machine boundary";
const BUILD_MODE = "ReleaseSmall";
const TARGET = "riscv64-freestanding-none";

fn finisher() *volatile u32 {
    return @ptrFromInt(RESET_BASE);
}

pub fn start() noreturn {
    log.info("SHELL", "SHELL001", "shell ready");
    uart.write("ZIGN01D V1 interactive diagnostic shell\r\n");
    uart.write("Type 'help' for commands. Placeholders report missing drivers honestly.\r\n");

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
    if (equals(cmd, "logs")) return logsCommand();
    if (equals(cmd, "status")) return statusCommand();
    if (equals(cmd, "machine") or equals(cmd, "cpu")) return machineCommand();
    if (equals(cmd, "panic-test")) return panicTestCommand();
    if (equals(cmd, "version")) return versionCommand();
    if (equals(cmd, "build")) return buildCommand();
    if (equals(cmd, "breadcrumbs")) return breadcrumbsCommand();
    if (equals(cmd, "tasks")) return task.printStatus();
    if (equals(cmd, "devices")) return device.printStatus();
    if (equals(cmd, "syscalls")) return syscall.printStatus();
    if (equals(cmd, "net")) return net.printStatus();
    if (startsWith(cmd, "ping")) return pingCommand(cmd);
    if (equals(cmd, "phone")) return phone.printStatus();
    if (startsWith(cmd, "call")) return callCommand(cmd);
    if (startsWith(cmd, "sms")) return smsCommand(cmd);

    log.warn("SHELL", "SHELL002", "unknown shell command; inspect kernel/console/shell.zig command table");
    uart.write("unknown command: ");
    uart.write(cmd);
    uart.write("\r\n");
}

fn help() void {
    uart.write("commands: help mem uptime reboot shutdown log status version build breadcrumbs logs machine cpu tasks devices syscalls net ping phone call sms panic-test\r\n");
}

fn uptime() void {
    const first = timer.ticks();
    const second = timer.ticks();
    uart.write("[ZIGN01D][INFO][TIMER][TIMER002] uptime ticks=");
    uart.writeDec(second);
    uart.write(" delta_probe=");
    uart.writeDec(second - first);
    uart.write(" source=rdtime\r\n");
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

fn logsCommand() void {
    logCommand();
    uart.write("logs: no ring buffer yet; inspect serial transcript and docs/LOGGING_AND_BREADCRUMBS.md\r\n");
}

fn versionCommand() void {
    uart.write("version: ");
    uart.write(VERSION);
    uart.write("\r\n");
}

fn buildCommand() void {
    uart.write("build: mode=");
    uart.write(BUILD_MODE);
    uart.write(" target=");
    uart.write(TARGET);
    uart.write(" output=zig-out/bin/zign01d-v0 compiler_rt=disabled\r\n");
}

fn breadcrumbsCommand() void {
    diag.printDoctrineStatus();
}

fn statusCommand() void {
    uart.write("status: kernel_version=");
    uart.write(VERSION);
    uart.write(" build_mode=");
    uart.write(BUILD_MODE);
    uart.write(" target=");
    uart.write(TARGET);
    uart.write(" boot_stage=complete\r\n");
    uart.write("status: uart=active polling-mmio memory=qemu-virt-dram timer=rdtime-polling scheduler=cooperative-stub shell=active\r\n");
    task.printStatus();
    device.printStatus();
    syscall.printStatus();
    net.printStatus();
    phone.printStatus();
    trap.printStatus();
    uart.write("status: placeholders active=plic timer-interrupts userspace-traps virtio-net virtio-blk modem cellular audio sms; none are fake success\r\n");
}

fn machineCommand() void {
    cpu.printMachineStatus();
    trap.printStatus();
}

fn panicTestCommand() void {
    trap.controlledPanicReport();
}


fn pingCommand(cmd: []const u8) void {
    if (cmd.len == "ping".len or startsWith(cmd, "ping ")) {
        net.pingUnavailable();
        return;
    }
    unknownArgument("NET", "NET003", "ping command malformed; expected ping <target>; inspect kernel/console/shell.zig");
}

fn callCommand(cmd: []const u8) void {
    if (cmd.len == "call".len or startsWith(cmd, "call ")) {
        phone.callUnavailable();
        return;
    }
    unknownArgument("PHONE", "PHONE004", "call command malformed; expected call <number>; inspect kernel/console/shell.zig");
}

fn smsCommand(cmd: []const u8) void {
    if (cmd.len == "sms".len or startsWith(cmd, "sms ")) {
        phone.smsUnavailable();
        return;
    }
    unknownArgument("PHONE", "PHONE005", "sms command malformed; expected sms <number> <message>; inspect kernel/console/shell.zig");
}

fn unknownArgument(subsystem: []const u8, code: []const u8, message: []const u8) void {
    diag.warn(subsystem, code, message);
}

fn equals(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;
    for (a, 0..) |ch, i| {
        if (ch != b[i]) return false;
    }
    return true;
}

fn startsWith(a: []const u8, prefix: []const u8) bool {
    if (a.len < prefix.len) return false;
    for (prefix, 0..) |ch, i| {
        if (a[i] != ch) return false;
    }
    return true;
}
