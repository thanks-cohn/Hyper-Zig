const uart = @import("../console/uart.zig");

pub const board_name = "qemu-virt";
pub const board_arch = "riscv64";
pub const board_source = "fixed-assumption";
pub const board_detection = "not-implemented";
pub const device_tree_parse = "not-implemented";

pub const ram_base: usize = 0x8000_0000;
pub const ram_size_bytes: usize = 134_217_728;
pub const ram_size_mib: usize = 128;
pub const uart0_base: usize = 0x1000_0000;
pub const virtio_mmio_base: usize = 0x1000_1000;
pub const virtio_mmio_stride: usize = 0x1000;
pub const virtio_mmio_count: usize = 8;
pub const plic_base: usize = 0x0c00_0000;
pub const clint_base: usize = 0x0200_0000;

pub fn init() void {
    uart.write("[ZIGN01D][INFO][BOARD][BOARD000] board profile present; qemu-virt fixed assumptions active\r\n");
}

pub fn virtioMmioAddress(index: usize) usize {
    return virtio_mmio_base + (index * virtio_mmio_stride);
}

pub fn printBoard() void {
    uart.write("board: name=");
    uart.write(board_name);
    uart.write("\r\n");
    uart.write("board: arch=");
    uart.write(board_arch);
    uart.write("\r\n");
    uart.write("board: source=");
    uart.write(board_source);
    uart.write("\r\n");
    uart.write("board: detection=");
    uart.write(board_detection);
    uart.write("\r\n");
    uart.write("board: device_tree_parse=");
    uart.write(device_tree_parse);
    uart.write("\r\n");
}

pub fn printProfile() void {
    uart.write("board-profile: name=");
    uart.write(board_name);
    uart.write("\r\n");
    uart.write("board-profile: ram_base=");
    uart.writeHex(ram_base);
    uart.write("\r\n");
    uart.write("board-profile: ram_size_mib=");
    uart.writeDec(ram_size_mib);
    uart.write("\r\n");
    uart.write("board-profile: uart0_base=");
    uart.writeHex(uart0_base);
    uart.write("\r\n");
    uart.write("board-profile: virtio_mmio_base=");
    uart.writeHex(virtio_mmio_base);
    uart.write("\r\n");
    uart.write("board-profile: virtio_mmio_count=");
    uart.writeDec(virtio_mmio_count);
    uart.write("\r\n");
    uart.write("board-profile: plic_base=0x0c000000\r\n");
    uart.write("board-profile: clint_base=0x02000000\r\n");
}

pub fn printDevices() void {
    uart.write("board-devices: uart0=present-assumed\r\n");
    uart.write("board-devices: virtio_mmio=present-assumed\r\n");
    uart.write("board-devices: virtio_discovery=present\r\n");
    uart.write("board-devices: virtio_slots=");
    uart.writeDec(virtio_mmio_count);
    uart.write("\r\n");
    uart.write("board-devices: virtio_source=board-profile\r\n");
    uart.write("board-devices: plic=present-assumed\r\n");
    uart.write("board-devices: clint=present-assumed\r\n");
    uart.write("board-devices: live_probe=not-implemented\r\n");
    uart.write("board-devices: driver_binding=not-implemented\r\n");
}

pub fn printStatusFields() void {
    uart.write("board_interface=present\r\n");
    uart.write("board_name=");
    uart.write(board_name);
    uart.write("\r\n");
    uart.write("board_arch=");
    uart.write(board_arch);
    uart.write("\r\n");
    uart.write("board_source=");
    uart.write(board_source);
    uart.write("\r\n");
    uart.write("board_detection=");
    uart.write(board_detection);
    uart.write("\r\n");
    uart.write("device_tree_parse=");
    uart.write(device_tree_parse);
    uart.write("\r\n");
}
