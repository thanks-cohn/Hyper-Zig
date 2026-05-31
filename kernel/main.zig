const runtime_mem = @import("runtime/mem.zig");
const std = @import("std");
const boot = @import("arch/riscv64/boot.zig");
const uart = @import("console/uart.zig");
const memory = @import("memory/pmm.zig");
const plic = @import("interrupt/plic.zig");
const timer = @import("interrupt/timer.zig");
const trap = @import("arch/riscv64/trap.zig");
const scheduler = @import("scheduler/scheduler.zig");
const task = @import("task/task.zig");
const device = @import("device/device.zig");
const syscall = @import("syscall/syscall.zig");
const net = @import("net/net.zig");
const phone = @import("phone/phone.zig");
const comm = @import("comm/comm.zig");
const diag = @import("diag/breadcrumb.zig");
const shell = @import("console/shell.zig");
const panic_mod = @import("panic/panic.zig");
const board = @import("board/board.zig");
const virtio_discovery = @import("virtio/discovery.zig");
const tarfs = @import("fs/tarfs.zig");
const ramfs = @import("fs/ramfs.zig");

pub export fn kmain() noreturn {
    runtime_mem.force_link();
    boot.markKernelEntry();
    uart.init();
    board.init();
    virtio_discovery.init();
    tarfs.init();
    ramfs.init();
    memory.init();
    trap.init();
    plic.init();
    timer.init();
    scheduler.init();
    task.init();
    device.init();
    syscall.init();
    net.init();
    phone.init();
    comm.init();
    userspace_init_stub();
    diag.bootStep("BOOT090", "boot sequence complete");
    shell.start();
}

pub fn panic(message: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    panic_mod.panic(message);
}


fn userspace_init_stub() void {
    uart.write("[ZIGN01D][WARN][INIT][INIT001] userspace not implemented; init stub only; no userspace boundary\r\n");
}
