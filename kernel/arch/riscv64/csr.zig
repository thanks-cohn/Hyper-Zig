const uart = @import("../../console/uart.zig");

extern var zign01d_boot_hart_id: usize;

pub fn hartId() usize {
    // mhartid is M-mode-only. The firmware handoff value in a0 was saved by
    // boot/entry.S before kmain and is the safe S-mode source of hart identity.
    return zign01d_boot_hart_id;
}

pub inline fn readSstatus() usize {
    return asm volatile ("csrr %[value], sstatus"
        : [value] "=r" (-> usize),
    );
}

pub inline fn readSie() usize {
    return asm volatile ("csrr %[value], sie"
        : [value] "=r" (-> usize),
    );
}

pub inline fn readSip() usize {
    return asm volatile ("csrr %[value], sip"
        : [value] "=r" (-> usize),
    );
}

pub inline fn readStvec() usize {
    return asm volatile ("csrr %[value], stvec"
        : [value] "=r" (-> usize),
    );
}

pub inline fn readSepc() usize {
    return asm volatile ("csrr %[value], sepc"
        : [value] "=r" (-> usize),
    );
}

pub inline fn readScause() usize {
    return asm volatile ("csrr %[value], scause"
        : [value] "=r" (-> usize),
    );
}

pub inline fn readStval() usize {
    return asm volatile ("csrr %[value], stval"
        : [value] "=r" (-> usize),
    );
}

pub inline fn readSatp() usize {
    return asm volatile ("csrr %[value], satp"
        : [value] "=r" (-> usize),
    );
}

pub fn printStatus() void {
    uart.write("csr: privilege=supervisor source=live-safe-s-mode-reads\r\n");
    writeNamedDecHex("hart_id", hartId());
    writeNamedHex("sstatus", readSstatus());
    writeNamedHex("sie", readSie());
    writeNamedHex("sip", readSip());
    writeNamedHex("stvec", readStvec());
    writeNamedHex("sepc", readSepc());
    writeNamedHex("scause", readScause());
    writeNamedHex("stval", readStval());
    writeNamedHex("satp", readSatp());
    uart.write("csr: machine_mode_csrs=not-read reason=illegal-from-supervisor-mode\r\n");
}

fn writeNamedHex(name: []const u8, value: usize) void {
    uart.write("csr: ");
    uart.write(name);
    uart.write("=");
    uart.writeHex(value);
    uart.write("\r\n");
}

fn writeNamedDecHex(name: []const u8, value: usize) void {
    uart.write("csr: ");
    uart.write(name);
    uart.write("=");
    uart.writeDec(value);
    uart.write(" hex=");
    uart.writeHex(value);
    uart.write("\r\n");
}
