const uart = @import("../console/uart.zig");
const board = @import("../board/board.zig");

pub const interface = "present";
pub const transport = "mmio";
pub const virtio_board = board.board_name;
pub const source = "board-profile";
pub const slot_count = board.virtio_mmio_count;
pub const slot_stride = board.virtio_mmio_stride;
pub const base = board.virtio_mmio_base;
pub const live_probe = "not-implemented";
pub const magic_read = "not-implemented";
pub const driver_negotiation = "not-implemented";
pub const queue_setup = "not-implemented";
pub const interrupt_setup = "not-implemented";
pub const slot_status = "expected-by-board-profile";

pub const Slot = struct {
    index: usize,
    address: usize,
    status: []const u8,
};

pub fn init() void {
    uart.write("[ZIGN01D][INFO][VIRTIO][VIRTIO000] virtio-mmio discovery table present; live probing not implemented\r\n");
}

pub fn slotAddress(index: usize) usize {
    return base + (index * slot_stride);
}

pub fn slot(index: usize) Slot {
    return .{
        .index = index,
        .address = slotAddress(index),
        .status = slot_status,
    };
}

pub fn printInfo() void {
    uart.write("virtio: interface=");
    uart.write(interface);
    uart.write("\r\n");
    uart.write("virtio: transport=");
    uart.write(transport);
    uart.write("\r\n");
    uart.write("virtio: board=");
    uart.write(virtio_board);
    uart.write("\r\n");
    uart.write("virtio: source=");
    uart.write(source);
    uart.write("\r\n");
    uart.write("virtio: base=");
    uart.writeHex(base);
    uart.write("\r\n");
    uart.write("virtio: stride=");
    uart.writeHex(slot_stride);
    uart.write("\r\n");
    uart.write("virtio: slot_count=");
    uart.writeDec(slot_count);
    uart.write("\r\n");
    uart.write("virtio: live_probe=");
    uart.write(live_probe);
    uart.write("\r\n");
    uart.write("virtio: magic_read=");
    uart.write(magic_read);
    uart.write("\r\n");
    uart.write("virtio: driver_negotiation=");
    uart.write(driver_negotiation);
    uart.write("\r\n");
    uart.write("virtio: queue_setup=");
    uart.write(queue_setup);
    uart.write("\r\n");
    uart.write("virtio: interrupt_setup=");
    uart.write(interrupt_setup);
    uart.write("\r\n");
}

pub fn printSummary() void {
    uart.write("virtio-summary: transport=");
    uart.write(transport);
    uart.write("\r\n");
    uart.write("virtio-summary: slots=");
    uart.writeDec(slot_count);
    uart.write("\r\n");
    uart.write("virtio-summary: computed_from=");
    uart.write(source);
    uart.write("\r\n");
    uart.write("virtio-summary: live_probe=");
    uart.write(live_probe);
    uart.write("\r\n");
    uart.write("virtio-summary: driver_binding=not-implemented\r\n");
}

pub fn printSlots() void {
    var index: usize = 0;
    while (index < slot_count) : (index += 1) {
        const current = slot(index);
        uart.write("virtio-slot: index=");
        uart.writeDec(current.index);
        uart.write(" addr=");
        uart.writeHex(current.address);
        uart.write(" status=");
        uart.write(current.status);
        uart.write("\r\n");
    }
}

pub fn printStatusFields() void {
    uart.write("virtio_discovery_interface=");
    uart.write(interface);
    uart.write("\r\n");
    uart.write("virtio_transport=");
    uart.write(transport);
    uart.write("\r\n");
    uart.write("virtio_board=");
    uart.write(virtio_board);
    uart.write("\r\n");
    uart.write("virtio_source=");
    uart.write(source);
    uart.write("\r\n");
    uart.write("virtio_slot_count=");
    uart.writeDec(slot_count);
    uart.write("\r\n");
    uart.write("virtio_slot_stride=");
    uart.writeHex(slot_stride);
    uart.write("\r\n");
    uart.write("virtio_base=");
    uart.writeHex(base);
    uart.write("\r\n");
    uart.write("virtio_live_probe=");
    uart.write(live_probe);
    uart.write("\r\n");
    uart.write("virtio_magic_read=");
    uart.write(magic_read);
    uart.write("\r\n");
    uart.write("virtio_driver_negotiation=");
    uart.write(driver_negotiation);
    uart.write("\r\n");
    uart.write("virtio_queue_setup=");
    uart.write(queue_setup);
    uart.write("\r\n");
    uart.write("virtio_interrupt_setup=");
    uart.write(interrupt_setup);
    uart.write("\r\n");
}
