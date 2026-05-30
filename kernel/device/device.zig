const diag = @import("../diag/breadcrumb.zig");
const uart = @import("../console/uart.zig");

pub const DeviceRecord = struct {
    name: []const u8,
    subsystem: []const u8,
    status: []const u8,
    inspect_hint: []const u8,
};

pub const Status = struct {
    initialized: bool,
    device_count: usize,
    placeholder_count: usize,
    inspect_hint: []const u8,
};

var initialized: bool = false;

const devices = [_]DeviceRecord{
    .{ .name = "uart0", .subsystem = "UART", .status = "active polling 16550 mmio 0x10000000", .inspect_hint = "kernel/console/uart.zig" },
    .{ .name = "timer0", .subsystem = "TIMER", .status = "active rdtime polling; interrupt driver missing", .inspect_hint = "kernel/interrupt/timer.zig" },
    .{ .name = "plic0", .subsystem = "IRQ", .status = "placeholder; polling shell currently used", .inspect_hint = "kernel/interrupt/plic.zig" },
    .{ .name = "ram0", .subsystem = "MEM", .status = "active qemu virt dram map", .inspect_hint = "kernel/memory/pmm.zig and boot/linker.ld" },
    .{ .name = "virtio-mmio-net0", .subsystem = "NET", .status = "placeholder; driver missing", .inspect_hint = "kernel/net/net.zig then virtio-mmio transport" },
    .{ .name = "virtio-mmio-blk0", .subsystem = "DEV", .status = "placeholder; block driver missing", .inspect_hint = "kernel/device/device.zig then virtio-blk driver" },
    .{ .name = "modem0", .subsystem = "PHONE", .status = "placeholder; modem driver missing", .inspect_hint = "kernel/phone/phone.zig then modem transport" },
};

pub fn init() void {
    initialized = true;
    if (devices.len == 0) {
        diag.err("DEV", "DEV999", "device registry empty during init; inspect kernel/device/device.zig");
    }
    diag.info("DEV", "DEV001", "device registry initialized");
}

pub fn status() Status {
    return .{ .initialized = initialized, .device_count = devices.len, .placeholder_count = 3, .inspect_hint = "inspect kernel/device/device.zig for the static registry" };
}

pub fn printStatus() void {
    const s = status();
    uart.write("devices: initialized=");
    uart.write(if (s.initialized) "yes" else "no");
    uart.write(" count=");
    uart.writeDec(s.device_count);
    uart.write(" placeholders=");
    uart.writeDec(s.placeholder_count);
    uart.write("\r\n");
    for (devices) |dev| {
        uart.write("  name=");
        uart.write(dev.name);
        uart.write(" subsystem=");
        uart.write(dev.subsystem);
        uart.write(" status=");
        uart.write(dev.status);
        uart.write(" inspect=");
        uart.write(dev.inspect_hint);
        uart.write("\r\n");
    }
}
