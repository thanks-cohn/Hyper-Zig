const log = @import("../../kernel/log.zig");

pub fn start() void {
    log.warn("BOOT", "BOOT003", "userspace init stub reached");
}
