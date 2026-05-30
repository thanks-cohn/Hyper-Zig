const log = @import("../log.zig");
const uart = @import("../console/uart.zig");

extern var __kernel_start: u8;
extern var __kernel_end: u8;
extern var __bss_start: u8;
extern var __bss_end: u8;

pub fn init() void {
    log.info("MEM", "MEM001", "memory map initialized for qemu virt dram");
    report();
}

pub fn report() void {
    uart.write("[ZIGN01D][INFO][MEM][MEM002] dram base=0x80000000 kernel_start=");
    uart.writeHex(@intFromPtr(&__kernel_start));
    uart.write(" kernel_end=");
    uart.writeHex(@intFromPtr(&__kernel_end));
    uart.write(" bss=");
    uart.writeHex(@intFromPtr(&__bss_start));
    uart.write("..");
    uart.writeHex(@intFromPtr(&__bss_end));
    uart.write("\r\n");
}
