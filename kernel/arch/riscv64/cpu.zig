const uart = @import("../../console/uart.zig");

extern var zign01d_boot_hart_id: usize;

pub fn halt() noreturn {
    while (true) {
        asm volatile ("wfi");
    }
}

pub fn hartId() usize {
    return zign01d_boot_hart_id;
}

pub fn readTime() u64 {
    var value: u64 = 0;
    asm volatile ("rdtime %[value]"
        : [value] "=r" (value),
    );
    return value;
}

pub fn readStvec() usize {
    var value: usize = 0;
    asm volatile ("csrr %[value], stvec"
        : [value] "=r" (value),
    );
    return value;
}

pub fn readSie() usize {
    var value: usize = 0;
    asm volatile ("csrr %[value], sie"
        : [value] "=r" (value),
    );
    return value;
}

pub fn readSip() usize {
    var value: usize = 0;
    asm volatile ("csrr %[value], sip"
        : [value] "=r" (value),
    );
    return value;
}

pub fn readSstatus() usize {
    var value: usize = 0;
    asm volatile ("csrr %[value], sstatus"
        : [value] "=r" (value),
    );
    return value;
}

pub fn printMachineStatus() void {
    uart.write("machine: hart_id=");
    uart.writeDec(hartId());
    uart.write(" privilege=supervisor-via-opensbi-or-compatible boot_mode=qemu-virt-kernel-entry\r\n");
    uart.write("machine: qemu_virt_assumptions=uart@0x10000000 dram@0x80000000 reset-finisher@0x100000\r\n");
    uart.write("machine: timer_source=rdtime-polling value=");
    uart.writeDec(readTime());
    uart.write(" interrupts=not-enabled trap_vector_stvec=");
    uart.writeHex(readStvec());
    uart.write(" sie=");
    uart.writeHex(readSie());
    uart.write(" sip=");
    uart.writeHex(readSip());
    uart.write("\r\n");
    uart.write("machine: interrupt_controller=placeholder plic driver does not claim/complete IRQs inspect=kernel/interrupt/plic.zig\r\n");
    uart.write("machine: privilege_detail=machine-mode CSRs not read from supervisor kernel to avoid illegal-instruction trap inspect=kernel/arch/riscv64/cpu.zig\r\n");
}
