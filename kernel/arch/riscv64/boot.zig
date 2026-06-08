const log = @import("../../log.zig");

pub fn markKernelEntry() void {
    log.info("BOOT", "BOOT001", "kernel entry reached");
    log.info("BOOT", "BOOT002", "ZIGN01D V1 diagnostic foundation");
    log.info("BOOT", "BOOT003", "ZIGN01D V2 machine boundary");
    log.info("BOOT", "BOOT004", "ZIGN01D V3 timer and trap recovery readiness");
    log.info("BOOT", "BOOT005", "ZIGN01D V4 guarded MMIO probe foundation");
    log.info("BOOT", "BOOT006", "ZIGN01D V5 CSR introspection foundation");
}
