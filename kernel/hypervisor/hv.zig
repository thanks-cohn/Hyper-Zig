const uart = @import("../console/uart.zig");
const capability = @import("capability.zig");
const vm = @import("vm.zig");
const vcpu = @import("vcpu.zig");
const guest_memory = @import("guest_memory.zig");

pub fn init() void {
    vm.init();
    vcpu.init(vm.object().id);
    guest_memory.init(vm.object().id);
}

pub fn printStatus() void {
    uart.write("hv: branch=hypervisor-v0\r\n");
    uart.write("hv: target=zig-0.14.x\r\n");
    uart.write("hv: status=experimental-hypervisor-candidate\r\n");
    uart.write("hv: privilege=supervisor\r\n");
    uart.write("hv: h_extension=unknown reason=no-safe-detection-yet\r\n");
    uart.write("hv: linux_guest=not-supported-yet\r\n");
    uart.write("hv: rust_guest_toolchain=not-supported-yet\r\n");
    uart.write("hv: guest_execution=not-supported-yet\r\n");
    vm.printImplementedMarker();
    vcpu.printImplementedMarker();
    guest_memory.printState();
    uart.write("hv: guest_trap_return=MISSING\r\n");
    uart.write("hv: second_stage_translation=MISSING\r\n");
    uart.write("hv: virtual_timer=MISSING\r\n");
    uart.write("hv: virtual_console=MISSING\r\n");
    uart.write("hv: sbi_layer=MISSING\r\n");
    uart.write("hv: virtio_for_linux=MISSING\r\n");
    uart.write("hv: next=HV5 guest execution research\r\n");
}

pub fn printCapability() void {
    capability.print();
}

pub fn printVm() void {
    vm.printObject();
    printNonClaims();
}

pub fn printVcpu() void {
    vcpu.printObject();
    printNonClaims();
}

pub fn printVcpuLifecycle() void {
    vcpu.printLifecycle();
    printNonClaims();
}

pub fn initializeVcpu() void {
    const result = vcpu.initializeLifecycle();
    vcpu.printTransition("initialize", result);
    printNonClaims();
}

pub fn prepareVcpu() void {
    const result = vcpu.prepareRunnable();
    vcpu.printTransition("prepare-runnable", result);
    printNonClaims();
}

pub fn haltVcpu() void {
    const result = vcpu.halt();
    vcpu.printTransition("halt", result);
    printNonClaims();
}

pub fn resetVcpu() void {
    const result = vcpu.reset();
    vcpu.printTransition("reset", result);
    printNonClaims();
}

pub fn printInspect() void {
    vm.printObject();
    vcpu.printObject();
    guest_memory.printState();
}

pub fn printObjects() void {
    printInspect();
}

pub fn printGuestMemory() void {
    guest_memory.printState();
}

pub fn allocGuestMemory() void {
    guest_memory.printAllocCommand();
}

pub fn freeGuestMemory() void {
    guest_memory.printFreeCommand();
}

pub fn resetGuestMemory() void {
    guest_memory.printResetCommand();
}

pub fn boundsTestGuestMemory() void {
    guest_memory.printBoundsTest();
}

pub fn doubleFreeTestGuestMemory() void {
    guest_memory.printDoubleFreeTest();
}

pub fn overflowTestGuestMemory() void {
    guest_memory.printOverflowTest();
}

fn printNonClaims() void {
    uart.write("hv: guest_execution=not-supported-yet\r\n");
    uart.write("hv: linux_guest=not-supported-yet\r\n");
    uart.write("hv: guest_entry=MISSING\r\n");
    uart.write("hv: second_stage_translation=MISSING\r\n");
}
