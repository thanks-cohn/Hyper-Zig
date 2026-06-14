const uart = @import("../console/uart.zig");
const capability = @import("capability.zig");
const vm = @import("vm.zig");
const vcpu = @import("vcpu.zig");
const guest_memory = @import("guest_memory.zig");
const guest_address_space = @import("guest_address_space.zig");
const guest_image = @import("guest_image.zig");
const guest_entry = @import("guest_entry.zig");
const guest_exit = @import("guest_exit.zig");
const guest_run_attempt = @import("guest_run_attempt.zig");
const guest_execution = @import("guest_execution.zig");
const second_stage = @import("second_stage.zig");
const stage2_table = @import("stage2_table.zig");
const boot_package = @import("boot_package.zig");
const guest_dtb = @import("guest_dtb.zig");
const sbi = @import("sbi.zig");
const virtual_timer = @import("virtual_timer.zig");
const binary_fdt = @import("binary_fdt.zig");
const linux_handoff = @import("linux_handoff.zig");
const sbi_console = @import("sbi_console.zig");
const sbi_dispatch = @import("sbi_dispatch.zig");

pub fn init() void {
    vm.init();
    vcpu.init(vm.object().id);
    guest_memory.init(vm.object().id);
    guest_address_space.init(vm.object().id);
    guest_image.init(vm.object().id);
    guest_entry.init(vm.object().id, vcpu.object().id);
    guest_exit.init(vm.object().id, vcpu.object().id);
    guest_run_attempt.init(vm.object().id, vcpu.object().id);
    guest_execution.init(vm.object().id, vcpu.object().id);
    second_stage.init(vm.object().id);
    stage2_table.init(vm.object().id);
    boot_package.init(vm.object().id);
    guest_dtb.init(vm.object().id);
    sbi.init(vm.object().id, vcpu.object().id);
    virtual_timer.init(vm.object().id, vcpu.object().id);
    binary_fdt.init(vm.object().id);
    linux_handoff.init(vm.object().id, vcpu.object().id);
    sbi_console.init(vm.object().id, vcpu.object().id);
    sbi_dispatch.init(vm.object().id, vcpu.object().id);
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
    guest_run_attempt.printState();
    guest_execution.printState();
    second_stage.printState();
    stage2_table.printState();
    boot_package.printState();
    guest_dtb.printState();
    sbi.printState();
    virtual_timer.printState();
    sbi_dispatch.printState();
    binary_fdt.printState();
    linux_handoff.printState();
    sbi_console.printState();
    sbi_dispatch.printState();
    uart.write("hv: guest_trap_return=MISSING\r\n");
    uart.write("hv: second_stage_translation=MISSING\r\n");

    uart.write("hv: virtual_console=foundation-mediation-only\r\n");
    uart.write("hv: sbi_layer=foundation-metadata-only\r\n");
    uart.write("hv: virtio_for_linux=MISSING\r\n");
    uart.write("hv: next=controlled active guest-entry prerequisites or SBI dispatch integration (no Linux boot claim)\r\n");
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

pub fn printGuestRunAttempt() void {
    guest_run_attempt.printState();
}

pub fn checkGuestRunAttempt() void {
    guest_run_attempt.printCheckCommand();
}

pub fn armNoExecuteGuestRunAttempt() void {
    guest_run_attempt.printArmNoExecuteCommand();
}

pub fn resetGuestRunAttempt() void {
    guest_run_attempt.printResetCommand();
}

pub fn requireEntryTestGuestRunAttempt() void {
    guest_run_attempt.printRequireEntryTestCommand();
}

pub fn requireExitTestGuestRunAttempt() void {
    guest_run_attempt.printRequireExitTestCommand();
}

pub fn printSecondStage() void {
    second_stage.printState();
    boot_package.printState();
}

pub fn configureSecondStage() void {
    second_stage.printConfigureCommand();
}

pub fn validateSecondStage() void {
    second_stage.printValidateCommand();
}

pub fn lookupZeroSecondStage() void {
    second_stage.printLookupZeroCommand();
}

pub fn lookupPageSecondStage() void {
    second_stage.printLookupPageCommand();
}

pub fn boundsTestSecondStage() void {
    second_stage.printBoundsTestCommand();
}

pub fn alignmentTestSecondStage() void {
    second_stage.printAlignmentTestCommand();
}

pub fn executePermissionTestSecondStage() void {
    second_stage.printExecutePermissionTestCommand();
}

pub fn resetSecondStage() void {
    second_stage.printResetCommand();
}

pub fn printStage2Table() void {
    stage2_table.printState();
    boot_package.printState();
}

pub fn buildStage2Table() void {
    stage2_table.printBuildCommand();
}

pub fn validateStage2Table() void {
    stage2_table.printValidateCommand();
}

pub fn walkZeroStage2Table() void {
    stage2_table.printWalkZeroCommand();
}

pub fn walkPageStage2Table() void {
    stage2_table.printWalkPageCommand();
}

pub fn boundsTestStage2Table() void {
    stage2_table.printBoundsTestCommand();
}

pub fn alignmentTestStage2Table() void {
    stage2_table.printAlignmentTestCommand();
}

pub fn executePermissionTestStage2Table() void {
    stage2_table.printExecutePermissionTestCommand();
}

pub fn resetStage2Table() void {
    stage2_table.printResetCommand();
}

pub fn printBootPackage() void {
    boot_package.printState();
}

pub fn attachKernelBootPackage() void {
    boot_package.printAttachKernelCommand();
}

pub fn setEntryBootPackage() void {
    boot_package.printSetEntryCommand();
}

pub fn setCmdlineBootPackage(line: []const u8) void {
    boot_package.printSetCmdlineCommand(line);
}

pub fn attachInitrdBootPackage() void {
    boot_package.printAttachInitrdCommand();
}

pub fn attachDtbBootPackage() void {
    boot_package.printAttachDtbCommand();
}

pub fn validateBootPackage() void {
    boot_package.printValidateCommand();
}

pub fn blockersBootPackage() void {
    boot_package.printBlockersCommand();
}

pub fn overlapTestBootPackage() void {
    boot_package.printOverlapTestCommand();
}

pub fn boundsTestBootPackage() void {
    boot_package.printBoundsTestCommand();
}

pub fn resetBootPackage() void {
    boot_package.printResetCommand();
}

pub fn printDtbContract() void {
    guest_dtb.printState();
}

pub fn buildDtbContract() void {
    guest_dtb.printBuildCommand();
}

pub fn validateDtbContract() void {
    guest_dtb.printValidateCommand();
}

pub fn blockersDtbContract() void {
    guest_dtb.printBlockersCommand();
}

pub fn nodesDtbContract() void {
    guest_dtb.printNodesCommand();
}

pub fn boundsTestDtbContract() void {
    guest_dtb.printBoundsTestCommand();
}

pub fn overlapTestDtbContract() void {
    guest_dtb.printOverlapTestCommand();
}

pub fn resetDtbContract() void {
    guest_dtb.printResetCommand();
}

pub fn printGuestExecution() void {
    guest_execution.printStatusCommand();
}

pub fn validateGuestExecution() void {
    guest_execution.printValidateCommand();
}

pub fn armGuestExecution() void {
    guest_execution.printArmCommand();
}

pub fn blockersGuestExecution() void {
    guest_execution.printBlockersCommand();
}

pub fn resetGuestExecution() void {
    guest_execution.printResetCommand();
}

pub fn requirePrereqTestGuestExecution() void {
    guest_execution.printRequirePrereqTestCommand();
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
    guest_run_attempt.printState();
    guest_execution.printState();
    second_stage.printState();
    boot_package.printState();
    guest_dtb.printState();
    sbi.printState();
    virtual_timer.printState();
    sbi_dispatch.printState();
    binary_fdt.printState();
}

pub fn printSbi() void { sbi.printStatusCommand(); }
pub fn validateSbi() void { sbi.printValidateCommand(); }
pub fn resetSbi() void { sbi.printResetCommand(); }
pub fn blockersSbi() void { sbi.printBlockersCommand(); }
pub fn baseTestSbi() void { sbi.printBaseTestCommand(); }
pub fn timerTestSbi() void { sbi.printTimerTestCommand(); }
pub fn consoleTestSbi() void { sbi.printConsoleTestCommand(); }

pub fn printSbiConsole() void { sbi_console.printStatusCommand(); }
pub fn validateSbiConsole() void { sbi_console.printValidateCommand(); }
pub fn blockersSbiConsole() void { sbi_console.printBlockersCommand(); }
pub fn putcharTestSbiConsole() void { sbi_console.printPutcharTestCommand(); }
pub fn putstringTestSbiConsole() void { sbi_console.printPutstringTestCommand(); }
pub fn getcharTestSbiConsole() void { sbi_console.printGetcharTestCommand(); }
pub fn invalidTestSbiConsole() void { sbi_console.printInvalidTestCommand(); }
pub fn overflowTestSbiConsole() void { sbi_console.printOverflowTestCommand(); }
pub fn bufferSbiConsole() void { sbi_console.printBufferCommand(); }
pub fn resetSbiConsole() void { sbi_console.printResetCommand(); }

pub fn printVirtualTimer() void { virtual_timer.printStatusCommand(); }
pub fn armVirtualTimer() void { virtual_timer.printArmCommand(); }
pub fn validateVirtualTimer() void { virtual_timer.printValidateCommand(); }
pub fn blockersVirtualTimer() void { virtual_timer.printBlockersCommand(); }
pub fn pendingTestVirtualTimer() void { virtual_timer.printPendingTestCommand(); }
pub fn sbiSetTestVirtualTimer() void { virtual_timer.printSbiSetTestCommand(); }
pub fn invalidTestVirtualTimer() void { virtual_timer.printInvalidTestCommand(); }
pub fn resetVirtualTimer() void { virtual_timer.printResetCommand(); }


pub fn printSbiDispatch() void { sbi_dispatch.printStatusCommand(); }
pub fn validateSbiDispatch() void { sbi_dispatch.printValidateCommand(); }
pub fn blockersSbiDispatch() void { sbi_dispatch.printBlockersCommand(); }
pub fn resetSbiDispatch() void { sbi_dispatch.printResetCommand(); }
pub fn baseTestSbiDispatch() void { sbi_dispatch.printBaseTestCommand(); }
pub fn timerTestSbiDispatch() void { sbi_dispatch.printTimerTestCommand(); }
pub fn consolePutcharTestSbiDispatch() void { sbi_dispatch.printConsolePutcharTestCommand(); }
pub fn consoleGetcharTestSbiDispatch() void { sbi_dispatch.printConsoleGetcharTestCommand(); }
pub fn unknownTestSbiDispatch() void { sbi_dispatch.printUnknownTestCommand(); }
pub fn unsupportedFunctionTestSbiDispatch() void { sbi_dispatch.printUnsupportedFunctionTestCommand(); }

pub fn printBinaryFdt() void { binary_fdt.printState(); }
pub fn buildBinaryFdt() void { binary_fdt.printBuildCommand(); }
pub fn validateBinaryFdt() void { binary_fdt.printValidateCommand(); }
pub fn headerBinaryFdt() void { binary_fdt.printHeaderCommand(); }
pub fn nodesBinaryFdt() void { binary_fdt.printNodesCommand(); }
pub fn stringsBinaryFdt() void { binary_fdt.printStringsCommand(); }
pub fn checksumBinaryFdt() void { binary_fdt.printChecksumCommand(); }
pub fn boundsTestBinaryFdt() void { binary_fdt.printBoundsTestCommand(); }
pub fn missingContractTestBinaryFdt() void { binary_fdt.printMissingContractTestCommand(); }
pub fn resetBinaryFdt() void { binary_fdt.printResetCommand(); }

pub fn printLinuxHandoff() void { linux_handoff.printState(); }
pub fn prepareLinuxHandoff() void { linux_handoff.printPrepareCommand(); }
pub fn validateLinuxHandoff() void { linux_handoff.printValidateCommand(); }
pub fn blockersLinuxHandoff() void { linux_handoff.printBlockersCommand(); }
pub fn rangesLinuxHandoff() void { linux_handoff.printRangesCommand(); }
pub fn summaryLinuxHandoff() void { linux_handoff.printSummaryCommand(); }
pub fn overlapTestLinuxHandoff() void { linux_handoff.printOverlapTestCommand(); }
pub fn boundsTestLinuxHandoff() void { linux_handoff.printBoundsTestCommand(); }
pub fn missingFdtTestLinuxHandoff() void { linux_handoff.printMissingFdtTestCommand(); }
pub fn missingBootpkgTestLinuxHandoff() void { linux_handoff.printMissingBootpkgTestCommand(); }
pub fn resetLinuxHandoff() void { linux_handoff.printResetCommand(); }

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

