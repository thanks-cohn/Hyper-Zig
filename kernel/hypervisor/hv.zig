const uart = @import("../console/uart.zig");
const capability = @import("capability.zig");
const vm = @import("vm.zig");
const vcpu = @import("vcpu.zig");
const guest_memory = @import("guest_memory.zig");
const guest_address_space = @import("guest_address_space.zig");
const guest_image = @import("guest_image.zig");
const guest_entry = @import("guest_entry.zig");
const guest_exit = @import("guest_exit.zig");

pub fn init() void {
    vm.init();
    vcpu.init(vm.object().id);
    guest_memory.init(vm.object().id);
    guest_address_space.init(vm.object().id);
    guest_image.init(vm.object().id);
    guest_entry.init(vm.object().id, vcpu.object().id);
    guest_exit.init(vm.object().id, vcpu.object().id);
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
    guest_address_space.printState();
    guest_image.printState();
    guest_entry.printState();
    guest_exit.printState();
    uart.write("hv: guest_trap_return=MISSING\r\n");
    uart.write("hv: second_stage_translation=MISSING\r\n");
    uart.write("hv: virtual_timer=MISSING\r\n");
    uart.write("hv: virtual_console=MISSING\r\n");
    uart.write("hv: sbi_layer=MISSING\r\n");
    uart.write("hv: virtio_for_linux=MISSING\r\n");
    uart.write("hv: next=HV9 controlled guest-entry attempt research\r\n");
}

pub fn printCapability() void {
    capability.print();
}


pub fn printGuestExit() void {
    guest_exit.printState();
}

pub fn recordInstructionGuestExit() void {
    guest_exit.printRecordInstructionCommand();
}

pub fn recordMemoryFaultGuestExit() void {
    guest_exit.printRecordMemoryFaultCommand();
}

pub fn recordTimerGuestExit() void {
    guest_exit.printRecordTimerCommand();
}

pub fn recordHaltGuestExit() void {
    guest_exit.printRecordHaltCommand();
}

pub fn resetGuestExit() void {
    guest_exit.printResetCommand();
}

pub fn requireEntryTestGuestExit() void {
    guest_exit.printRequireEntryTestCommand();
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
    guest_address_space.printState();
    guest_image.printState();
    guest_entry.printState();
    guest_exit.printState();
}

pub fn printObjects() void {
    printInspect();
}

pub fn printGuestMemory() void {
    guest_memory.printState();
    guest_address_space.printState();
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


pub fn printAddressSpace() void {
    guest_address_space.printState();
}

pub fn createAddressSpace() void {
    guest_address_space.printCreateCommand();
}

pub fn resetAddressSpace() void {
    guest_address_space.printResetCommand();
}

pub fn lookupZeroAddressSpace() void {
    guest_address_space.printLookupZeroCommand();
}

pub fn lookupPageAddressSpace() void {
    guest_address_space.printLookupPageCommand();
}

pub fn boundsTestAddressSpace() void {
    guest_address_space.printBoundsTestCommand();
}

pub fn alignmentTestAddressSpace() void {
    guest_address_space.printAlignmentTestCommand();
}

pub fn printGuestImage() void {
    guest_image.printState();
}

pub fn loadTinyGuestImage() void {
    guest_image.printLoadTinyCommand();
}

pub fn verifyGuestImage() void {
    guest_image.printVerifyCommand();
}

pub fn resetGuestImage() void {
    guest_image.printResetCommand();
}

pub fn boundsTestGuestImage() void {
    guest_image.printBoundsTestCommand();
}

pub fn printGuestEntry() void {
    guest_entry.printState();
    guest_exit.printState();
}

pub fn prepareGuestEntry() void {
    guest_entry.printPrepareCommand();
}

pub fn resetGuestEntry() void {
    guest_entry.printResetCommand();
}

pub fn boundsTestGuestEntry() void {
    guest_entry.printBoundsTestCommand();
}

pub fn requireImageTestGuestEntry() void {
    guest_entry.printRequireImageTestCommand();
}

fn printNonClaims() void {
    uart.write("hv: guest_execution=not-supported-yet\r\n");
    uart.write("hv: linux_guest=not-supported-yet\r\n");
    uart.write("hv: guest_entry=implemented\r\n");
    uart.write("hv: second_stage_translation=MISSING\r\n");
}
