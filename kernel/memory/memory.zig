const log = @import("../log.zig");
const uart = @import("../console/uart.zig");
const board = @import("../board/board.zig");
const heap = @import("heap.zig");

pub const ram_base: usize = board.ram_base;
pub const ram_size_bytes: usize = board.ram_size_bytes;
pub const ram_size_mib: usize = board.ram_size_mib;

extern var __kernel_start: u8;
extern var __kernel_end: u8;

pub fn init() void {
    log.info("MEMORY", "MEMORY000", "memory map scaffold present; heap allocator implemented-v0; paging not implemented");
    heap.init();
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
    const hs = heap.stats();
    uart.write("memory: heap=implemented-v0\r\n");
    uart.write("memory: pmm=implemented-v0\r\n");
    uart.write("memory: allocator=kernel-bump-reset-v0\r\n");
    uart.write("memory: heap_total_bytes=");
    uart.writeDec(hs.total_bytes);
    uart.write("\r\n");
    uart.write("memory: heap_used_bytes=");
    uart.writeDec(hs.used_bytes);
    uart.write("\r\n");
    uart.write("memory: heap_free_bytes=");
    uart.writeDec(hs.free_bytes);
    uart.write("\r\n");
    uart.write("memory: heap_reset_supported=yes\r\n");
    uart.write("memory: heap_free_individual_blocks=not-implemented\r\n");
    uart.write("memory: paging=not-implemented\r\n");
    uart.write("memory: virtual_memory=not-implemented\r\n");
    uart.write("memory: userspace_memory=not-implemented\r\n");
    uart.write("memory: swap=not-implemented\r\n");
    uart.write("memory: numa=not-implemented\r\n");
    uart.write("memory: memory_hotplug=not-implemented\r\n");
    uart.write("memory: page_cache=not-implemented\r\n");
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
    uart.write("memmap: region=kernel-heap\r\n");
    uart.write("memmap: heap_source=static-kernel-region\r\n");
    uart.write("memmap: heap_total_bytes=");
    uart.writeDec(heap.heap_total_bytes);
    uart.write("\r\n");
    uart.write("memmap: region=pmm-managed-ram\r\n");
    uart.write("memmap: pmm_page_size=4096\r\n");
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
    heap.printStatusFields();
    uart.write("allocator=kernel-bump-reset-v0\r\n");
    uart.write("paging=not-implemented\r\n");
    uart.write("virtual_memory=not-implemented\r\n");
    uart.write("userspace_memory=not-implemented\r\n");
    uart.write("memory_hotplug=not-implemented\r\n");
    uart.write("page_cache=not-implemented\r\n");
}
