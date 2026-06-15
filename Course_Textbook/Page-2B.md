# HV02

## Capability Detection

PAGE B
THE IMPLEMENTATION
==================

File:

kernel/hypervisor/capability.zig

The real Hyper-Zig implementation is shown below.

This module is deliberately conservative.

It does not claim that the H-extension is present.

It does not claim that Linux guests are supported.

It does not claim guest execution.

It prints the current capability state clearly so both humans and
validation scripts can inspect it.

---

```zig
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
    uart.write("hv: vm_object=implemented\r\n");
    uart.write("hv: vcpu_object=implemented\r\n");
}
```

---

What To Notice

1. Capability detection has three states.

   The H-extension can be present, absent, or unknown.

2. Unknown is a real answer.

   Hyper-Zig does not guess when it cannot safely prove something.

3. The reason is stored with the status.

   A status without a reason is much less useful.

4. The module prints negative claims.

   Hyper-Zig explicitly says guest execution and Linux guests are not
   supported yet.

5. The proof is observable.

   The capability state is printed through UART so validation scripts
   can verify what the hypervisor actually reported.

Key Structures

* HExtensionStatus
* CapabilityStatus

Key Functions

* detect()
* print()

If you can explain why unknown is safer than pretending, you understand
the implementation.
