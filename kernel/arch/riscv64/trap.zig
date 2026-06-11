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
var seen_live_trap: bool = false;

pub fn init() void {
    const vector_addr = @intFromPtr(&zign01d_trap_vector);
    asm volatile ("csrw stvec, %[vector]"
        :
        : [vector] "r" (vector_addr),
    );
    installed = true;
    diag.info("TRAP", "TRAP001", "supervisor trap vector installed; unhandled traps halt honestly; cause names available");
}

pub fn isInstalled() bool {
    return installed;
}

pub fn causeName(cause: usize) []const u8 {
    const interrupt_bit: usize = (@as(usize, 1) << (@bitSizeOf(usize) - 1));
    if ((cause & interrupt_bit) != 0) return "interrupt cause";

    return switch (cause) {
        2 => "illegal instruction",
        3 => "breakpoint",
        5 => "load access fault",
        7 => "store access fault",
        8 => "ecall from U-mode",
        9 => "ecall from S-mode",
        12 => "instruction page fault",
        13 => "load page fault",
        15 => "store page fault",
        else => "unknown cause",
    };
}

fn lastCauseName() []const u8 {
    if (!seen_live_trap and last_cause == 0 and last_epc == 0 and last_tval == 0) return "none";
    return causeName(last_cause);
}

pub fn printStatus() void {
    uart.write("trap: installed=");
    uart.write(if (installed) "yes" else "no");
    uart.write(" stvec=");
    uart.writeHex(cpu.readStvec());
    uart.write(" handler=zign01d_trap_vector\r\n");
    uart.write("trap: last_cause=");
    uart.writeHex(last_cause);
    uart.write(" last_cause_name=");
    uart.write(lastCauseName());
    uart.write(" last_epc=");
    uart.writeHex(last_epc);
    uart.write(" last_tval=");
    uart.writeHex(last_tval);
    uart.write("\r\n");
    uart.write("trap: recovery=limited policy=panic-on-unhandled cause_names=available inspect=kernel/arch/riscv64/trap.zig boot/entry.S docs/TRAPS_AND_PANIC.md docs/V3_TIMER_AND_TRAP_AUDIT.md\r\n");
}

pub export fn zign01d_handle_trap(cause: usize, epc: usize, tval: usize) noreturn {
    seen_live_trap = true;
    last_cause = cause;
    last_epc = epc;
    last_tval = tval;
    log.err("TRAP", "TRAP002", "unhandled supervisor trap reached kernel boundary");
    uart.write("[ZIGN01D][ERROR][TRAP][TRAP003] cause=");
    uart.writeHex(cause);
    uart.write(" cause_name=");
    uart.write(causeName(cause));
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

pub fn syntheticTrapTest() void {
    uart.write("trap-test: mode=synthetic\r\n");
    uart.write("trap-test: illegal-instruction name=");
    uart.write(causeName(2));
    uart.write("\r\n");
    uart.write("trap-test: breakpoint name=");
    uart.write(causeName(3));
    uart.write("\r\n");
    uart.write("trap-test: load-access-fault name=");
    uart.write(causeName(5));
    uart.write("\r\n");
    uart.write("trap-test: store-access-fault name=");
    uart.write(causeName(7));
    uart.write("\r\n");
    uart.write("trap-test: ecall-u-mode name=");
    uart.write(causeName(8));
    uart.write("\r\n");
    uart.write("trap-test: ecall-s-mode name=");
    uart.write(causeName(9));
    uart.write("\r\n");
    uart.write("trap-test: instruction-page-fault name=");
    uart.write(causeName(12));
    uart.write("\r\n");
    uart.write("trap-test: load-page-fault name=");
    uart.write(causeName(13));
    uart.write("\r\n");
    uart.write("trap-test: store-page-fault name=");
    uart.write(causeName(15));
    uart.write("\r\n");
    uart.write("trap-test: unknown-cause name=");
    uart.write(causeName(0xffff));
    uart.write("\r\n");
    uart.write("trap-test: recovery=not-implemented\r\n");
    uart.write("trap-test: live fault injection deferred until safe recovery exists\r\n");
}
