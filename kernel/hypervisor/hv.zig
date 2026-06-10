const uart = @import("../console/uart.zig");
const capability = @import("capability.zig");

pub fn printStatus() void {
    uart.write("hv: branch=hypervisor-v0\r\n");
    uart.write("hv: target=zig-0.14.x\r\n");
    uart.write("hv: status=research-scaffold\r\n");
    uart.write("hv: privilege=supervisor\r\n");
    uart.write("hv: h_extension=unknown reason=no-safe-detection-yet\r\n");
    uart.write("hv: linux_guest=not-supported-yet\r\n");
    uart.write("hv: rust_guest_toolchain=not-supported-yet\r\n");
    uart.write("hv: guest_execution=not-supported-yet\r\n");
    uart.write("hv: vm_object=MISSING\r\n");
    uart.write("hv: vcpu_object=MISSING\r\n");
    uart.write("hv: guest_memory=MISSING\r\n");
    uart.write("hv: guest_entry=MISSING\r\n");
    uart.write("hv: guest_trap_return=MISSING\r\n");
    uart.write("hv: second_stage_translation=MISSING\r\n");
    uart.write("hv: virtual_timer=MISSING\r\n");
    uart.write("hv: virtual_console=MISSING\r\n");
    uart.write("hv: sbi_layer=MISSING\r\n");
    uart.write("hv: virtio_for_linux=MISSING\r\n");
    uart.write("hv: next=HV1 detect hypervisor capability and define VM/vCPU data model\r\n");
}

pub fn printCapability() void {
    capability.print();
}
