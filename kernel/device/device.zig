const diag = @import("../diag/breadcrumb.zig");
const uart = @import("../console/uart.zig");
const mmio_probe = @import("mmio_probe.zig");

pub const BoundaryStatus = enum {
    active,
    detected,
    placeholder,
    missing,
    absent,
    deferred,
    unsafe,
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
    absent_count: usize,
    deferred_count: usize,
    unsafe_count: usize,
    unknown_count: usize,
    inspect_hint: []const u8,
};

var initialized: bool = false;

// V4 adds a guarded MMIO probe scaffold with a tiny fixed QEMU virt address allowlist.
// Live reads remain disabled until trap recovery can safely resume after absent or
// faulting MMIO, so the registry reports the transport as deferred rather than
// pretending a virtio driver exists.
const devices = [_]DeviceRecord{
    .{ .name = "uart0", .subsystem = "UART", .boundary_status = .active, .detail = "polling 16550 mmio 0x10000000", .inspect_hint = "kernel/console/uart.zig" },
    .{ .name = "timer0", .subsystem = "TIMER", .boundary_status = .active, .detail = "rdtime polling; timer interrupts not enabled", .inspect_hint = "kernel/interrupt/timer.zig" },
    .{ .name = "plic0", .subsystem = "IRQ", .boundary_status = .placeholder, .detail = "qemu virt PLIC assumed but no claim/complete driver", .inspect_hint = "kernel/interrupt/plic.zig" },
    .{ .name = "ram0", .subsystem = "MEM", .boundary_status = .active, .detail = "qemu virt dram map", .inspect_hint = "kernel/memory/pmm.zig and boot/linker.ld" },
    .{ .name = "virtio-mmio-transport", .subsystem = "DEV", .boundary_status = .deferred, .detail = "guarded probing scaffold present; live probing disabled until trap recovery is proven; probing deferred until guarded load/store fault recovery is proven", .inspect_hint = "kernel/device/mmio_probe.zig kernel/device/device.zig docs/V4_GUARDED_MMIO_AUDIT.md" },
    .{ .name = "virtio-mmio-net0", .subsystem = "NET", .boundary_status = .missing, .detail = "network driver not implemented; no fake packet path", .inspect_hint = "kernel/net/net.zig then virtio-mmio transport" },
    .{ .name = "virtio-mmio-blk0", .subsystem = "DEV", .boundary_status = .missing, .detail = "block driver missing", .inspect_hint = "kernel/device/device.zig then virtio-blk driver" },
    .{ .name = "modem0", .subsystem = "PHONE", .boundary_status = .placeholder, .detail = "modem/cellular/audio/sms boundary only; no fake userspace", .inspect_hint = "kernel/phone/phone.zig then modem transport" },
};

pub fn init() void {
    initialized = true;
    if (devices.len == 0) {
        diag.err("DEV", "DEV999", "device registry empty during init; inspect kernel/device/device.zig");
    }
    diag.info("DEV", "DEV001", "device registry initialized with V4 guarded MMIO boundary statuses");
    diag.warn("DEV", "DEV002", "virtio-mmio probing deferred until guarded load/store fault recovery is proven; live probing disabled; inspect kernel/device/mmio_probe.zig docs/V4_GUARDED_MMIO_AUDIT.md");
}

pub fn status() Status {
    var active_count: usize = 0;
    var detected_count: usize = 0;
    var placeholder_count: usize = 0;
    var missing_count: usize = 0;
    var absent_count: usize = 0;
    var deferred_count: usize = 0;
    var unsafe_count: usize = 0;
    var unknown_count: usize = 0;
    for (devices) |dev| {
        switch (dev.boundary_status) {
            .active => active_count += 1,
            .detected => detected_count += 1,
            .placeholder => placeholder_count += 1,
            .missing => missing_count += 1,
            .absent => absent_count += 1,
            .deferred => deferred_count += 1,
            .unsafe => unsafe_count += 1,
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
        .absent_count = absent_count,
        .deferred_count = deferred_count,
        .unsafe_count = unsafe_count,
        .unknown_count = unknown_count,
        .inspect_hint = "inspect kernel/device/mmio_probe.zig for the fixed guarded probe policy",
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
    uart.write(" absent=");
    uart.writeDec(s.absent_count);
    uart.write(" deferred=");
    uart.writeDec(s.deferred_count);
    uart.write(" unsafe=");
    uart.writeDec(s.unsafe_count);
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
    uart.write("devices: mmio_policy=");
    uart.write(mmio_probe.POLICY);
    uart.write(" live_probe=");
    uart.write(if (mmio_probe.LIVE_PROBE_ENABLED) "enabled" else "disabled");
    uart.write(" boundary_status=unknown retained only as a legacy/unclassified status, not used for V4 virtio-mmio\r\n");
    uart.write("devices: warning=placeholders, deferred, absent, unsafe, and missing devices are not operational success; inspect=kernel/device/mmio_probe.zig kernel/device/device.zig\r\n");
}

fn statusName(s: BoundaryStatus) []const u8 {
    return switch (s) {
        .active => "active",
        .detected => "detected",
        .placeholder => "placeholder",
        .missing => "missing",
        .absent => "absent",
        .deferred => "deferred",
        .unsafe => "unsafe",
        .unknown => "unknown",
    };
}
