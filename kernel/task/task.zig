const diag = @import("../diag/breadcrumb.zig");
const uart = @import("../console/uart.zig");

pub const TaskState = enum { running, ready };

pub const TaskRecord = struct {
    pid: u32,
    name: []const u8,
    state: TaskState,
    inspect_hint: []const u8,
};

pub const Status = struct {
    initialized: bool,
    task_count: usize,
    running_pid: u32,
    model: []const u8,
    inspect_hint: []const u8,
};

var initialized: bool = false;
var running_pid: u32 = 0;

const tasks = [_]TaskRecord{
    .{ .pid = 0, .name = "kernel", .state = .running, .inspect_hint = "kernel/task/task.zig static task table" },
    .{ .pid = 1, .name = "init", .state = .ready, .inspect_hint = "userspace init is still a placeholder; inspect userspace/init/init.zig" },
};

pub fn init() void {
    initialized = true;
    running_pid = 0;
    if (tasks.len < 2) {
        diag.err("TASK", "TASK999", "task table invalid during init; expected kernel and init records; inspect kernel/task/task.zig");
    }
    diag.info("TASK", "TASK001", "task subsystem initialized");
}

pub fn status() Status {
    return .{
        .initialized = initialized,
        .task_count = tasks.len,
        .running_pid = running_pid,
        .model = "static cooperative task table; no preemption",
        .inspect_hint = "inspect kernel/task/task.zig before changing scheduler semantics",
    };
}

pub fn printStatus() void {
    const s = status();
    uart.write("tasks: initialized=");
    uart.write(if (s.initialized) "yes" else "no");
    uart.write(" model=");
    uart.write(s.model);
    uart.write(" count=");
    uart.writeDec(s.task_count);
    uart.write(" running_pid=");
    uart.writeDec(s.running_pid);
    uart.write("\r\n");
    for (tasks) |task| {
        uart.write("  pid=");
        uart.writeDec(task.pid);
        uart.write(" name=");
        uart.write(task.name);
        uart.write(" state=");
        uart.write(stateName(task.state));
        uart.write(" inspect=");
        uart.write(task.inspect_hint);
        uart.write("\r\n");
    }
}

pub fn stateName(state: TaskState) []const u8 {
    return switch (state) {
        .running => "running",
        .ready => "ready",
    };
}
