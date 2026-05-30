const log = @import("../../log.zig");

pub fn markKernelEntry() void {
    log.info("BOOT", "BOOT001", "kernel entry reached");
    log.info("BOOT", "BOOT002", "ZIGN01D V1 diagnostic foundation");
    log.info("BOOT", "BOOT003", "ZIGN01D V2 machine boundary");
}
