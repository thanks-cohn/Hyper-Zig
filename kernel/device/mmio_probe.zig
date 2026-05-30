const uart = @import("../console/uart.zig");
const board = @import("../board/board.zig");
const virtio_discovery = @import("../virtio/discovery.zig");

pub const VIRTIO_MMIO_MAGIC: u32 = 0x7472_6976;
pub const POLICY = "fixed-qemu-virt-window";
pub const LIVE_PROBE_ENABLED = false;
pub const DISABLED_REASON = "trap recovery not strong enough for absent MMIO";

pub const fixed_qemu_virtio_mmio_addresses = [_]usize{
    virtio_discovery.slotAddress(0),
    virtio_discovery.slotAddress(1),
    virtio_discovery.slotAddress(2),
    virtio_discovery.slotAddress(3),
    virtio_discovery.slotAddress(4),
    virtio_discovery.slotAddress(5),
    virtio_discovery.slotAddress(6),
    virtio_discovery.slotAddress(7),
};

pub const ProbeStatus = enum {
    present,
    absent,
    unsafe,
    deferred,
    faulted,
    unknown,
};

pub const ProbeResult = struct {
    address: usize,
    status: ProbeStatus,
    magic: u32,
    is_virtio_mmio: bool,
    detail: []const u8,
};

pub fn probe32(address: usize) ProbeResult {
    if (!isFixedQemuVirtioMmioAddress(address)) {
        return .{
            .address = address,
            .status = .unsafe,
            .magic = 0,
            .is_virtio_mmio = false,
            .detail = "address outside fixed QEMU virtio-mmio allowlist; broad MMIO scanning disabled",
        };
    }

    if (!LIVE_PROBE_ENABLED) {
        return .{
            .address = address,
            .status = .deferred,
            .magic = 0,
            .is_virtio_mmio = false,
            .detail = DISABLED_REASON,
        };
    }

    // This live-read branch is intentionally gated off for V4. It may only be
    // enabled after the trap path can recover from absent or faulting MMIO.
    const ptr: *volatile u32 = @ptrFromInt(address);
    const magic = ptr.*;
    return .{
        .address = address,
        .status = if (magic == VIRTIO_MMIO_MAGIC) .present else .absent,
        .magic = magic,
        .is_virtio_mmio = magic == VIRTIO_MMIO_MAGIC,
        .detail = if (magic == VIRTIO_MMIO_MAGIC) "virtio magic found; driver negotiation not implemented" else "read completed but virtio magic not found",
    };
}

pub fn printReport() void {
    uart.write("mmio: board=");
    uart.write(board.board_name);
    uart.write(" source=board-profile\r\n");
    uart.write("mmio: policy=");
    uart.write(POLICY);
    uart.write("\r\n");
    uart.write("mmio: live_probe=");
    uart.write(if (LIVE_PROBE_ENABLED) "enabled" else "disabled");
    uart.write("\r\n");
    uart.write("mmio: virtio_discovery=");
    uart.write(virtio_discovery.interface);
    uart.write("\r\n");
    uart.write("mmio: virtio_slots=");
    uart.writeDec(virtio_discovery.slot_count);
    uart.write("\r\n");
    uart.write("mmio: virtio_slot_table=computed\r\n");
    if (!LIVE_PROBE_ENABLED) {
        uart.write("mmio: reason=");
        uart.write(DISABLED_REASON);
        uart.write("\r\n");
        uart.write("mmio: scaffold=present\r\n");
    }

    for (fixed_qemu_virtio_mmio_addresses) |address| {
        const result = probe32(address);
        uart.write("mmio: addr=");
        uart.writeHex(address);
        uart.write(" result=");
        uart.write(statusName(result.status));
        if (LIVE_PROBE_ENABLED) {
            uart.write(" magic=");
            writeHex32(result.magic);
            if (result.is_virtio_mmio) {
                uart.write(" device=virtio-mmio");
            } else {
                uart.write(" device=none");
            }
        } else {
            uart.write(" magic=not-read device=unknown");
        }
        uart.write(" detail=");
        uart.write(result.detail);
        uart.write("\r\n");
    }

    uart.write("mmio: virtio_magic=0x74726976 expected_ascii=virt\r\n");
    uart.write("mmio: driver_negotiation=not-implemented\r\n");
    uart.write("mmio: queue_setup=not-implemented\r\n");
    uart.write("mmio: interrupt_setup=not-implemented\r\n");
}

pub fn statusName(status: ProbeStatus) []const u8 {
    return switch (status) {
        .present => "present",
        .absent => "absent",
        .unsafe => "unsafe",
        .deferred => "deferred",
        .faulted => "faulted",
        .unknown => "unknown",
    };
}

fn isFixedQemuVirtioMmioAddress(address: usize) bool {
    for (fixed_qemu_virtio_mmio_addresses) |known| {
        if (address == known) return true;
    }
    return false;
}

fn writeHex32(value: u32) void {
    uart.write("0x");
    var shift: usize = 28;
    while (true) {
        const nibble: u8 = @intCast((value >> @intCast(shift)) & 0xf);
        uart.putByte(if (nibble < 10) '0' + nibble else 'a' + (nibble - 10));
        if (shift == 0) break;
        shift -= 4;
    }
}
