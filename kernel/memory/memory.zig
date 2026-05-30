const log = @import("../log.zig");
const uart = @import("../console/uart.zig");
const board = @import("../board/board.zig");

pub const ram_base: usize = board.ram_base;
pub const ram_size_bytes: usize = board.ram_size_bytes;
pub const ram_size_mib: usize = board.ram_size_mib;

extern var __kernel_start: u8;
extern var __kernel_end: u8;

pub fn init() void {
    log.info("MEMORY", "MEMORY000", "memory map scaffold present; allocator not implemented");
}

pub fn kernelStart() usize {
    return @intFromPtr(&__kernel_start);
}

pub fn kernelEnd() usize {
    return @intFromPtr(&__kernel_end);
}

pub fn kernelSizeBytes() usize {
    return kernelEnd() - kernelStart();
}

pub fn printMemory() void {
    uart.write("memory: interface=present\r\n");
    uart.write("memory: model=qemu-virt-fixed\r\n");
    uart.write("memory: board=");
    uart.write(board.board_name);
    uart.write("\r\n");
    uart.write("memory: ram_base=");
    uart.writeHex(ram_base);
    uart.write("\r\n");
    uart.write("memory: ram_size_bytes=");
    uart.writeDec(ram_size_bytes);
    uart.write("\r\n");
    uart.write("memory: ram_size_mib=");
    uart.writeDec(ram_size_mib);
    uart.write("\r\n");
    uart.write("memory: heap=not-implemented\r\n");
    uart.write("memory: allocator=not-implemented\r\n");
    uart.write("memory: paging=not-implemented\r\n");
    uart.write("memory: virtual_memory=not-implemented\r\n");
    uart.write("memory: userspace_memory=not-implemented\r\n");
}

pub fn printMemmap() void {
    uart.write("memmap: region=ram base=");
    uart.writeHex(ram_base);
    uart.write(" size_bytes=");
    uart.writeDec(ram_size_bytes);
    uart.write(" size_mib=");
    uart.writeDec(ram_size_mib);
    uart.write(" source=qemu-virt-assumption\r\n");
    uart.write("memmap: source=board-profile\r\n");
    uart.write("memmap: live_discovery=not-implemented\r\n");
    uart.write("memmap: device_tree_parse=not-implemented\r\n");
}

pub fn printKernelBounds() void {
    uart.write("kernel-bounds: start=");
    uart.writeHex(kernelStart());
    uart.write("\r\n");
    uart.write("kernel-bounds: end=");
    uart.writeHex(kernelEnd());
    uart.write("\r\n");
    uart.write("kernel-bounds: size_bytes=");
    uart.writeDec(kernelSizeBytes());
    uart.write("\r\n");
}

pub fn printStatusFields() void {
    uart.write("memory_interface=present\r\n");
    uart.write("memory_model=qemu-virt-fixed\r\n");
    uart.write("ram_base=");
    uart.writeHex(ram_base);
    uart.write("\r\n");
    uart.write("ram_size_mib=");
    uart.writeDec(ram_size_mib);
    uart.write("\r\n");
    uart.write("heap=not-implemented\r\n");
    uart.write("allocator=not-implemented\r\n");
    uart.write("paging=not-implemented\r\n");
}
