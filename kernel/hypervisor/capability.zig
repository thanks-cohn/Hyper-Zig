const uart = @import("../console/uart.zig");

pub const HExtensionStatus = enum {
    present,
    absent,
    unknown,
};

pub const CapabilityStatus = struct {
    source: []const u8,
    h_extension: HExtensionStatus,
    reason: []const u8,
};

pub fn detect() CapabilityStatus {
    return CapabilityStatus{
        .source = "supervisor-mode-safe-static-policy",
        .h_extension = .unknown,
        .reason = "no-safe-detection-yet",
    };
}

pub fn print() void {
    const status = detect();

    uart.write("hv: branch=hypervisor-v0\r\n");
    uart.write("hv: target=zig-0.14.x\r\n");
    uart.write("hv: capability_detection=implemented\r\n");
    uart.write("hv: capability_source=");
    uart.write(status.source);
    uart.write("\r\n");
    uart.write("hv: h_extension=");
    switch (status.h_extension) {
        .present => uart.write("present"),
        .absent => uart.write("absent"),
        .unknown => uart.write("unknown"),
    }
    uart.write(" reason=");
    uart.write(status.reason);
    uart.write("\r\n");
    uart.write("hv: guest_execution=not-supported-yet\r\n");
    uart.write("hv: linux_guest=not-supported-yet\r\n");
    uart.write("hv: vm_object=MISSING\r\n");
    uart.write("hv: vcpu_object=MISSING\r\n");
}
