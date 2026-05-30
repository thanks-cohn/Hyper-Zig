/// V0 scheduler placeholder.
pub fn init() void {
    // TODO: create the idle task and userspace init task.
}

pub fn idle() void {
    asm volatile ("wfi");
}
