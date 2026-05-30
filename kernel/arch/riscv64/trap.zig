const cpu = @import("cpu.zig");
const diag = @import("../../diag/breadcrumb.zig");
const log = @import("../../log.zig");
const panic_mod = @import("../../panic/panic.zig");
const uart = @import("../../console/uart.zig");

extern fn zign01d_trap_vector() callconv(.C) void;

var installed: bool = false;
var last_cause: usize = 0;
var last_epc: usize = 0;
var last_tval: usize = 0;

pub fn init() void {
    const vector_addr = @intFromPtr(&zign01d_trap_vector);
    asm volatile ("csrw stvec, %[vector]"
        :
        : [vector] "r" (vector_addr),
    );
    installed = true;
    diag.info("TRAP", "TRAP001", "supervisor trap vector installed; trap dispatch panics honestly on unhandled traps");
}

pub fn isInstalled() bool {
    return installed;
}

pub fn printStatus() void {
    uart.write("trap: installed=");
    uart.write(if (installed) "yes" else "no");
    uart.write(" stvec=");
    uart.writeHex(cpu.readStvec());
    uart.write(" handler=zign01d_trap_vector policy=panic-on-unhandled\r\n");
    uart.write("trap: last_cause=");
    uart.writeHex(last_cause);
    uart.write(" last_epc=");
    uart.writeHex(last_epc);
    uart.write(" last_tval=");
    uart.writeHex(last_tval);
    uart.write(" inspect=kernel/arch/riscv64/trap.zig boot/entry.S docs/TRAPS_AND_PANIC.md\r\n");
}

pub export fn zign01d_handle_trap(cause: usize, epc: usize, tval: usize) noreturn {
    last_cause = cause;
    last_epc = epc;
    last_tval = tval;
    log.err("TRAP", "TRAP002", "unhandled supervisor trap reached kernel boundary");
    uart.write("[ZIGN01D][ERROR][TRAP][TRAP003] cause=");
    uart.writeHex(cause);
    uart.write(" epc=");
    uart.writeHex(epc);
    uart.write(" tval=");
    uart.writeHex(tval);
    uart.write(" inspect=kernel/arch/riscv64/trap.zig boot/entry.S\r\n");
    panic_mod.panicWithCause("TRAP", "TRAP004", "unhandled supervisor trap", cause, "trap-vector");
}

pub fn controlledPanicReport() void {
    diag.panicMarker("PANIC", "PANIC900", "panic-test controlled report; kernel not halted by smoke-safe diagnostic path");
    panic_mod.report("SHELL", "PANIC901", "panic-test requested controlled panic report", 0x900, "shell-command panic-test");
}
