/// Minimal CPU helpers for RISC-V bring-up.
pub fn halt() noreturn {
    while (true) {
        asm volatile ("wfi");
    }
}
