const diag = @import("../diag/breadcrumb.zig");
const uart = @import("../console/uart.zig");

pub const SyscallRecord = struct {
    id: u32,
    name: []const u8,
    status: []const u8,
    inspect_hint: []const u8,
};

pub const Status = struct {
    initialized: bool,
    syscall_count: usize,
    trap_boundary: []const u8,
    inspect_hint: []const u8,
};

var initialized: bool = false;

const syscalls = [_]SyscallRecord{
    .{ .id = 0, .name = "write", .status = "table entry only; trap boundary not implemented", .inspect_hint = "kernel/syscall/syscall.zig and kernel/arch/riscv64/trap.zig" },
    .{ .id = 1, .name = "read", .status = "table entry only; trap boundary not implemented", .inspect_hint = "kernel/syscall/syscall.zig and console input path" },
    .{ .id = 2, .name = "uptime", .status = "table entry only; shell uses live rdtime directly", .inspect_hint = "kernel/interrupt/timer.zig" },
    .{ .id = 3, .name = "device_list", .status = "table entry only; shell exposes registry directly", .inspect_hint = "kernel/device/device.zig" },
    .{ .id = 4, .name = "net_status", .status = "table entry only; no userspace boundary", .inspect_hint = "kernel/net/net.zig" },
    .{ .id = 5, .name = "phone_status", .status = "table entry only; no userspace boundary", .inspect_hint = "kernel/phone/phone.zig" },
};

pub fn init() void {
    initialized = true;
    if (syscalls.len == 0) {
        diag.err("SYSCALL", "SYS999", "syscall table empty during init; inspect kernel/syscall/syscall.zig");
    }
    diag.info("SYSCALL", "SYS001", "syscall table initialized");
}

pub fn status() Status {
    return .{ .initialized = initialized, .syscall_count = syscalls.len, .trap_boundary = "not implemented", .inspect_hint = "inspect kernel/syscall/syscall.zig and kernel/arch/riscv64/trap.zig" };
}

pub fn printStatus() void {
    const s = status();
    uart.write("syscalls: initialized=");
    uart.write(if (s.initialized) "yes" else "no");
    uart.write(" count=");
    uart.writeDec(s.syscall_count);
    uart.write(" table present, trap boundary not implemented\r\n");
    for (syscalls) |sc| {
        uart.write("  id=");
        uart.writeDec(sc.id);
        uart.write(" name=");
        uart.write(sc.name);
        uart.write(" status=");
        uart.write(sc.status);
        uart.write(" inspect=");
        uart.write(sc.inspect_hint);
        uart.write("\r\n");
    }
}
