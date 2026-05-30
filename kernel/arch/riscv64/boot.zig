const log = @import("../../log.zig");

pub fn markKernelEntry() void {
    log.info("BOOT", "BOOT001", "kernel entry reached");
    log.info("BOOT", "BOOT002", "ZIGN01D V0");
}
