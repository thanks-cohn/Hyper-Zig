const diag = @import("../diag/breadcrumb.zig");
const uart = @import("../console/uart.zig");

pub const BoundaryStatus = enum {
    active,
    detected,
    placeholder,
    missing,
    unknown,
};

pub const DeviceRecord = struct {
    name: []const u8,
    subsystem: []const u8,
    boundary_status: BoundaryStatus,
    detail: []const u8,
    inspect_hint: []const u8,
};

pub const Status = struct {
    initialized: bool,
    device_count: usize,
    active_count: usize,
    detected_count: usize,
    placeholder_count: usize,
    missing_count: usize,
    unknown_count: usize,
    inspect_hint: []const u8,
};

var initialized: bool = false;

// V3 deliberately keeps virtio-mmio probing as design scaffolding only.
// Before this registry may claim a detected virtio-mmio transport, the trap path
// must prove it can recover from guarded load/store faults and resume after the
// faulting instruction. Until then, absent MMIO slots must not be scanned.
const devices = [_]DeviceRecord{
    .{ .name = "uart0", .subsystem = "UART", .boundary_status = .active, .detail = "polling 16550 mmio 0x10000000", .inspect_hint = "kernel/console/uart.zig" },
    .{ .name = "timer0", .subsystem = "TIMER", .boundary_status = .active, .detail = "rdtime polling; timer interrupts not enabled", .inspect_hint = "kernel/interrupt/timer.zig" },
    .{ .name = "plic0", .subsystem = "IRQ", .boundary_status = .placeholder, .detail = "qemu virt PLIC assumed but no claim/complete driver", .inspect_hint = "kernel/interrupt/plic.zig" },
    .{ .name = "ram0", .subsystem = "MEM", .boundary_status = .active, .detail = "qemu virt dram map", .inspect_hint = "kernel/memory/pmm.zig and boot/linker.ld" },
    .{ .name = "virtio-mmio-transport", .subsystem = "DEV", .boundary_status = .unknown, .detail = "probing deferred until guarded load/store fault recovery is proven", .inspect_hint = "kernel/device/device.zig docs/V3_TIMER_AND_TRAP_AUDIT.md" },
    .{ .name = "virtio-mmio-net0", .subsystem = "NET", .boundary_status = .missing, .detail = "network driver not implemented; no fake packet path", .inspect_hint = "kernel/net/net.zig then virtio-mmio transport" },
    .{ .name = "virtio-mmio-blk0", .subsystem = "DEV", .boundary_status = .missing, .detail = "block driver missing", .inspect_hint = "kernel/device/device.zig then virtio-blk driver" },
    .{ .name = "modem0", .subsystem = "PHONE", .boundary_status = .placeholder, .detail = "modem/cellular/audio/sms boundary only; no fake userspace", .inspect_hint = "kernel/phone/phone.zig then modem transport" },
};

pub fn init() void {
    initialized = true;
    if (devices.len == 0) {
        diag.err("DEV", "DEV999", "device registry empty during init; inspect kernel/device/device.zig");
    }
    diag.info("DEV", "DEV001", "device registry initialized with V3 honest boundary statuses");
    diag.warn("DEV", "DEV002", "virtio-mmio probing deferred until guarded load/store fault recovery is proven; inspect kernel/device/device.zig docs/V3_TIMER_AND_TRAP_AUDIT.md");
}

pub fn status() Status {
    var active_count: usize = 0;
    var detected_count: usize = 0;
    var placeholder_count: usize = 0;
    var missing_count: usize = 0;
    var unknown_count: usize = 0;
    for (devices) |dev| {
        switch (dev.boundary_status) {
            .active => active_count += 1,
            .detected => detected_count += 1,
            .placeholder => placeholder_count += 1,
            .missing => missing_count += 1,
            .unknown => unknown_count += 1,
        }
    }
    return .{
        .initialized = initialized,
        .device_count = devices.len,
        .active_count = active_count,
        .detected_count = detected_count,
        .placeholder_count = placeholder_count,
        .missing_count = missing_count,
        .unknown_count = unknown_count,
        .inspect_hint = "inspect kernel/device/device.zig for the static registry and deferred probe warning",
    };
}

pub fn printStatus() void {
    const s = status();
    uart.write("devices: initialized=");
    uart.write(if (s.initialized) "yes" else "no");
    uart.write(" count=");
    uart.writeDec(s.device_count);
    uart.write(" active=");
    uart.writeDec(s.active_count);
    uart.write(" detected=");
    uart.writeDec(s.detected_count);
    uart.write(" placeholders=");
    uart.writeDec(s.placeholder_count);
    uart.write(" missing=");
    uart.writeDec(s.missing_count);
    uart.write(" unknown=");
    uart.writeDec(s.unknown_count);
    uart.write("\r\n");
    for (devices) |dev| {
        uart.write("  name=");
        uart.write(dev.name);
        uart.write(" subsystem=");
        uart.write(dev.subsystem);
        uart.write(" boundary_status=");
        uart.write(statusName(dev.boundary_status));
        uart.write(" detail=");
        uart.write(dev.detail);
        uart.write(" inspect=");
        uart.write(dev.inspect_hint);
        uart.write("\r\n");
    }
    uart.write("devices: warning=placeholders and missing devices are not operational success; inspect=kernel/device/device.zig\r\n");
}

fn statusName(s: BoundaryStatus) []const u8 {
    return switch (s) {
        .active => "active",
        .detected => "detected",
        .placeholder => "placeholder",
        .missing => "missing",
        .unknown => "unknown",
    };
}
