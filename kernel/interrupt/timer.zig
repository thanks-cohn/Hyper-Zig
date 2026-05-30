const log = @import("../log.zig");
const uart = @import("../console/uart.zig");

pub fn init() void {
    log.warn("TIMER", "TIMER001", "timer stub active; uptime uses rdtime polling; timer interrupts not enabled");
}

pub fn ticks() u64 {
    var value: u64 = 0;
    asm volatile ("rdtime %[value]"
        : [value] "=r" (value),
    );
    return value;
}

pub fn printTimeDiagnostic() void {
    uart.write("timer: source=rdtime-polling value=");
    uart.writeDec(ticks());
    uart.write("\r\n");
    printInterruptDiagnostic();
    uart.write("timer: scheduler_preemption=not-implemented\r\n");
}

pub fn printTicksDiagnostic() void {
    uart.write("ticks: source=rdtime-polling value=");
    uart.writeDec(ticks());
    uart.write("\r\n");
    printInterruptDiagnostic();
}

pub fn printHeartbeatDiagnostic() void {
    const first = ticks();
    const second = ticks();
    uart.write("heartbeat: source=rdtime-polling value=");
    uart.writeDec(second);
    const monotonic = second >= first;
    const delta = if (monotonic) second - first else 0;
    uart.write(" monotonic=");
    uart.write(if (monotonic) "yes" else "no");
    uart.write(" delta_probe=");
    uart.writeDec(delta);
    uart.write("\r\n");
    printInterruptDiagnostic();
    uart.write("heartbeat: scheduler_preemption=not-implemented\r\n");
}

pub fn printInterruptDiagnostic() void {
    uart.write("timer: interrupts=not-enabled\r\n");
}
