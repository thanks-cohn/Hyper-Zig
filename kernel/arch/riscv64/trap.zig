/// Install the RISC-V trap vector and dispatch exceptions/interrupts.
pub fn init() void {
    // TODO: set stvec/mtvec and connect trap dispatch to panic/interrupt code.
}

pub fn handleTrap() void {
    // TODO: decode cause, preserve context, and route to the right subsystem.
}
