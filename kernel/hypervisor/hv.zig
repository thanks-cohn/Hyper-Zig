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
const guest_context = @import("guest_context.zig");
const trap_plan = @import("trap_plan.zig");
const entry_stub = @import("entry_stub.zig");
const h_extension = @import("h_extension.zig");
const hgatp_candidate = @import("hgatp_candidate.zig");
const stage2_activation_plan = @import("stage2_activation_plan.zig");
const guest_entry_frame = @import("guest_entry_frame.zig");
const trap_return_frame = @import("trap_return_frame.zig");
const first_instruction_plan = @import("first_instruction_plan.zig");
const hv26_invariants = @import("hv26_invariants.zig");

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
    guest_context.init(vm.object().id, vcpu.object().id);
    trap_plan.init(vm.object().id, vcpu.object().id);
    entry_stub.init(vm.object().id, vcpu.object().id);
    h_extension.init(vm.object().id, vcpu.object().id);
    hgatp_candidate.init(vm.object().id, vcpu.object().id);
    stage2_activation_plan.init(vm.object().id, vcpu.object().id);
    guest_entry_frame.init(vm.object().id, vcpu.object().id);
    trap_return_frame.init(vm.object().id, vcpu.object().id);
    first_instruction_plan.init(vm.object().id, vcpu.object().id);
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
    guest_context.printStatusCommand();
    trap_plan.printStatusCommand();
    entry_stub.printStatusCommand();
    h_extension.printStatusCommand();
    hgatp_candidate.printStatusCommand();
    stage2_activation_plan.printStatusCommand();
    uart.write("hv: guest_trap_return=MISSING\r\n");
    uart.write("hv: second_stage_translation=MISSING\r\n");

    uart.write("hv: virtual_console=foundation-mediation-only\r\n");
    uart.write("hv: sbi_layer=foundation-metadata-only\r\n");
    uart.write("hv: virtio_for_linux=MISSING\r\n");
    uart.write("hv: next=controlled active guest-entry prerequisites or SBI dispatch integration (no Linux boot claim)\r\n");
}


fn prepareHv25Prereqs() void {
    _ = guest_memory.configureDefault();
    _ = guest_address_space.ensureCreatedWithGuestMemory();
    _ = second_stage.configureFromCurrentGuest();
    _ = stage2_table.buildFromSecondStageMetadata();
    _ = h_extension.discoverSafe();
    _ = h_extension.validate();
}

pub fn printHgatp() void { hgatp_candidate.printStatusCommand(); }
pub fn buildHgatp() void { prepareHv25Prereqs(); hgatp_candidate.printBuildCommand(); }
pub fn validateHgatp() void { hgatp_candidate.printValidateCommand(); }
pub fn blockersHgatp() void { hgatp_candidate.printBlockersCommand(); }
pub fn fieldsHgatp() void { hgatp_candidate.printFieldsCommand(); }
pub fn candidateHgatp() void { hgatp_candidate.printCandidateCommand(); }
pub fn checksumHgatp() void { hgatp_candidate.printChecksumCommand(); }
pub fn resetHgatp() void { hgatp_candidate.printResetCommand(); }
pub fn hgatpLifecycleInvariant() void { _=hgatp_candidate.reset(); const r0=hgatp_candidate.validate(); prepareHv25Prereqs(); const r1=hgatp_candidate.build(); const b=hgatp_candidate.object().build_count; const cs=hgatp_candidate.object().checksum; const r2=hgatp_candidate.validate(); const v=hgatp_candidate.object().validate_count; const pass = r0==.rejected and r1==.ok and r2==.ok and b>0 and v>0 and cs!=0; uart.write("hv: hv25.hgatp.lifecycle_invariant="); uart.write(if(pass) "ok" else "rejected"); uart.write("\r\n"); hgatp_candidate.printStatusCommand(); }
pub fn hgatpDerivationInvariant() void { prepareHv25Prereqs(); _=hgatp_candidate.build(); const a=hgatp_candidate.object().value; const c=hgatp_candidate.object().checksum; const b=hgatp_candidate.mutateVmid(2); const d=hgatp_candidate.object().checksum; const e=hgatp_candidate.mutateRootPpn(1); const f=hgatp_candidate.object().checksum; const pass = a!=b and b!=e and c!=d and d!=f; uart.write("hv: hv25.hgatp.derivation_invariant="); uart.write(if(pass) "ok" else "rejected"); uart.write("\r\n"); hgatp_candidate.printStatusCommand(); }
pub fn hgatpCorruptionInvariant() void { prepareHv25Prereqs(); const r1=hgatp_candidate.corruptMode(); const e1=hgatp_candidate.object().last_error; prepareHv25Prereqs(); const r2=hgatp_candidate.corruptPpn(); const e2=hgatp_candidate.object().last_error; prepareHv25Prereqs(); const r3=hgatp_candidate.corruptVmid(); const e3=hgatp_candidate.object().last_error; const pass = r1==.rejected and e1==.invalid_mode and r2==.rejected and e2==.ppn_misaligned and r3==.rejected and e3==.invalid_vmid; uart.write("hv: hv25.hgatp.corruption_invariant="); uart.write(if(pass) "ok" else "rejected"); uart.write("\r\n"); hgatp_candidate.printStatusCommand(); }

pub fn printStage2Plan() void { stage2_activation_plan.printStatusCommand(); }
pub fn buildStage2Plan() void { prepareHv25Prereqs(); _=hgatp_candidate.build(); _=hgatp_candidate.validate(); stage2_activation_plan.printBuildCommand(); }
pub fn validateStage2Plan() void { stage2_activation_plan.printValidateCommand(); }
pub fn blockersStage2Plan() void { stage2_activation_plan.printBlockersCommand(); }
pub fn nextStage2Plan() void { stage2_activation_plan.printNextCommand(); }
pub fn checksumStage2Plan() void { stage2_activation_plan.printChecksumCommand(); }
pub fn resetStage2Plan() void { stage2_activation_plan.printResetCommand(); }
pub fn stage2PlanLifecycleInvariant() void { _=stage2_activation_plan.reset(); const r0=stage2_activation_plan.validate(); prepareHv25Prereqs(); _=hgatp_candidate.build(); _=hgatp_candidate.validate(); const r1=stage2_activation_plan.build(); const c=stage2_activation_plan.object().checksum; const r2=stage2_activation_plan.validate(); const pass=r0==.rejected and r1==.ok and r2==.ok and c!=0; uart.write("hv: hv25.stage2_plan.lifecycle_invariant="); uart.write(if(pass) "ok" else "rejected"); uart.write("\r\n"); stage2_activation_plan.printStatusCommand(); }
pub fn stage2PlanConsumptionInvariant() void { prepareHv25Prereqs(); _=hgatp_candidate.build(); _=hgatp_candidate.validate(); _=stage2_activation_plan.build(); const c1=stage2_activation_plan.object().checksum; _=hgatp_candidate.mutateVmid(3); _=hgatp_candidate.validate(); _=stage2_activation_plan.build(); const c2=stage2_activation_plan.object().checksum; const pass=c1!=0 and c2!=0 and c1!=c2 and stage2_activation_plan.object().hgatp_checksum==hgatp_candidate.object().checksum; uart.write("hv: hv25.stage2_plan.consumption_invariant="); uart.write(if(pass) "ok" else "rejected"); uart.write("\r\n"); stage2_activation_plan.printStatusCommand(); }
pub fn stage2PlanCorruptionInvariant() void { prepareHv25Prereqs(); _=hgatp_candidate.build(); _=hgatp_candidate.validate(); const r1=stage2_activation_plan.removeHgatp(); const e1=stage2_activation_plan.object().last_error; prepareHv25Prereqs(); _=hgatp_candidate.build(); _=hgatp_candidate.validate(); const r2=stage2_activation_plan.removeTable(); const e2=stage2_activation_plan.object().last_error; prepareHv25Prereqs(); _=hgatp_candidate.build(); _=hgatp_candidate.validate(); const r3=stage2_activation_plan.markActiveStage2(); const e3=stage2_activation_plan.object().last_error; const pass=r1==.rejected and e1==.require_hgatp and r2==.rejected and e2==.require_table and r3==.rejected and e3==.active_stage2_forbidden; uart.write("hv: hv25.stage2_plan.corruption_invariant="); uart.write(if(pass) "ok" else "rejected"); uart.write("\r\n"); stage2_activation_plan.printStatusCommand(); }
pub fn hv25InvariantAll() void { hgatpLifecycleInvariant(); hgatpDerivationInvariant(); hgatpCorruptionInvariant(); stage2PlanLifecycleInvariant(); stage2PlanConsumptionInvariant(); stage2PlanCorruptionInvariant(); }
pub fn hgatpRequireHextTest() void { prepareHv25Prereqs(); hgatp_candidate.printNegativeResult("require_hext_test", hgatp_candidate.removeHext()); }
pub fn hgatpModeTest() void { prepareHv25Prereqs(); hgatp_candidate.printNegativeResult("mode_test", hgatp_candidate.corruptMode()); }
pub fn hgatpPpnAlignmentTest() void { prepareHv25Prereqs(); hgatp_candidate.printNegativeResult("ppn_alignment_test", hgatp_candidate.corruptPpn()); }
pub fn hgatpVmidBoundsTest() void { prepareHv25Prereqs(); hgatp_candidate.printNegativeResult("vmid_bounds_test", hgatp_candidate.corruptVmid()); }
pub fn hgatpWriteAttemptTest() void { prepareHv25Prereqs(); hgatp_candidate.printNegativeResult("write_attempt_test", hgatp_candidate.markWriteAttempt()); }
pub fn hgatpActiveStage2Test() void { prepareHv25Prereqs(); hgatp_candidate.printNegativeResult("active_stage2_test", hgatp_candidate.markActiveStage2()); }
pub fn stage2PlanRequireHgatpTest() void { prepareHv25Prereqs(); stage2_activation_plan.printNegativeResult("require_hgatp_test", stage2_activation_plan.removeHgatp()); }
pub fn stage2PlanRequireStage2Test() void { prepareHv25Prereqs(); _=hgatp_candidate.build(); _=hgatp_candidate.validate(); stage2_activation_plan.printNegativeResult("require_stage2_test", stage2_activation_plan.removeStage2()); }
pub fn stage2PlanRequireTableTest() void { prepareHv25Prereqs(); _=hgatp_candidate.build(); _=hgatp_candidate.validate(); stage2_activation_plan.printNegativeResult("require_table_test", stage2_activation_plan.removeTable()); }
pub fn stage2PlanRequireCsrSafetyTest() void { prepareHv25Prereqs(); _=hgatp_candidate.build(); _=hgatp_candidate.validate(); stage2_activation_plan.printNegativeResult("require_csr_safety_test", stage2_activation_plan.removeCsrSafety()); }
pub fn stage2PlanActiveStage2Test() void { prepareHv25Prereqs(); _=hgatp_candidate.build(); _=hgatp_candidate.validate(); stage2_activation_plan.printNegativeResult("active_stage2_test", stage2_activation_plan.markActiveStage2()); }
pub fn stage2PlanWriteAttemptTest() void { prepareHv25Prereqs(); _=hgatp_candidate.build(); _=hgatp_candidate.validate(); stage2_activation_plan.printNegativeResult("write_attempt_test", stage2_activation_plan.markWriteAttempt()); }

pub fn printHExtension() void { h_extension.printStatusCommand(); }
pub fn discoverHExtension() void { h_extension.printDiscoverCommand(); }
pub fn validateHExtension() void { h_extension.printValidateCommand(); }
pub fn blockersHExtension() void { h_extension.printBlockersCommand(); }
pub fn csrTableHExtension() void { h_extension.printCsrTableCommand(); }
pub fn safetyHExtension() void { h_extension.printSafetyCommand(); }
pub fn fakeDetectedTestHExtension() void { h_extension.printFakeDetectedTestCommand(); }
pub fn unsafeProbeTestHExtension() void { h_extension.printUnsafeProbeTestCommand(); }
pub fn resetHExtension() void { h_extension.printResetCommand(); }

pub fn printEntryStub() void { entry_stub.printStatusCommand(); }
pub fn prepareEntryStub() void { entry_stub.printPrepareCommand(); }
pub fn validateEntryStub() void { entry_stub.printValidateCommand(); }
pub fn blockersEntryStub() void { entry_stub.printBlockersCommand(); }
pub fn registersEntryStub() void { entry_stub.printRegistersCommand(); }
pub fn gatesEntryStub() void { entry_stub.printGatesCommand(); }
pub fn descriptorEntryStub() void { entry_stub.printDescriptorCommand(); }
pub fn checksumEntryStub() void { entry_stub.printChecksumCommand(); }
pub fn attemptEntryStub() void { entry_stub.printAttemptCommand(); }
pub fn requirePlanTestEntryStub() void { entry_stub.printRequirePlanTestCommand(); }
pub fn pcBoundsTestEntryStub() void { entry_stub.printPcBoundsTestCommand(); }
pub fn spBoundsTestEntryStub() void { entry_stub.printSpBoundsTestCommand(); }
pub fn fdtBoundsTestEntryStub() void { entry_stub.printFdtBoundsTestCommand(); }
pub fn activeStage2TestEntryStub() void { entry_stub.printActiveStage2TestCommand(); }
pub fn resetEntryStub() void { entry_stub.printResetCommand(); }

pub fn printTrapPlan() void { trap_plan.printStatusCommand(); }
pub fn prepareTrapPlan() void { trap_plan.printPrepareCommand(); }
pub fn validateTrapPlan() void { trap_plan.printValidateCommand(); }
pub fn blockersTrapPlan() void { trap_plan.printBlockersCommand(); }
pub fn registersTrapPlan() void { trap_plan.printRegistersCommand(); }
pub fn gatesTrapPlan() void { trap_plan.printGatesCommand(); }
pub fn attemptTrapPlan() void { trap_plan.printAttemptCommand(); }
pub fn requireContextTestTrapPlan() void { trap_plan.printRequireContextTestCommand(); }
pub fn pcBoundsTestTrapPlan() void { trap_plan.printPcBoundsTestCommand(); }
pub fn spBoundsTestTrapPlan() void { trap_plan.printSpBoundsTestCommand(); }
pub fn fdtBoundsTestTrapPlan() void { trap_plan.printFdtBoundsTestCommand(); }
pub fn activeStage2TestTrapPlan() void { trap_plan.printActiveStage2TestCommand(); }
pub fn resetTrapPlan() void { trap_plan.printResetCommand(); }

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

pub fn printGuestContext() void { guest_context.printStatusCommand(); }
pub fn prepareGuestContext() void { guest_context.printPrepareCommand(); }
pub fn validateGuestContext() void { guest_context.printValidateCommand(); }
pub fn blockersGuestContext() void { guest_context.printBlockersCommand(); }
pub fn registersGuestContext() void { guest_context.printRegistersCommand(); }
pub fn rangesGuestContext() void { guest_context.printRangesCommand(); }
pub fn requireHandoffTestGuestContext() void { guest_context.printRequireHandoffTestCommand(); }
pub fn requireFdtTestGuestContext() void { guest_context.printRequireFdtTestCommand(); }
pub fn boundsTestGuestContext() void { guest_context.printBoundsTestCommand(); }
pub fn resetGuestContext() void { guest_context.printResetCommand(); }

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


pub fn printGuestEntryFrame() void { guest_entry_frame.printStatusCommand(); }
pub fn buildGuestEntryFrame() void { guest_entry_frame.printBuildCommand(); }
pub fn validateGuestEntryFrame() void { guest_entry_frame.printValidateCommand(); }
pub fn blockersGuestEntryFrame() void { guest_entry_frame.printBlockersCommand(); }
pub fn fieldsGuestEntryFrame() void { guest_entry_frame.printFieldsCommand(); }
pub fn registersGuestEntryFrame() void { guest_entry_frame.printRegistersCommand(); }
pub fn checksumGuestEntryFrame() void { guest_entry_frame.printChecksumCommand(); }
pub fn resetGuestEntryFrame() void { guest_entry_frame.printResetCommand(); }
pub fn gefLifecycle() void { _ = hv26_invariants.guestEntryLifecycle(); }
pub fn gefMutation() void { _ = hv26_invariants.guestEntryMutation(); }
pub fn gefRequireActivation() void { guest_entry_frame.printTest("require_activation_plan_test", guest_entry_frame.missingActivationPlan()); }
pub fn gefRequireContext() void { guest_entry_frame.printTest("require_context_test", guest_entry_frame.missingContext()); }
pub fn gefPcMutation() void { _=guest_entry_frame.build(); const before=guest_entry_frame.object().checksum; const after=guest_entry_frame.mutatePc(); uart.write("hv: guest_entry_frame.pc_mutation_test=ok\r\n"); uart.write("hv: guest_entry_frame.before_checksum="); uart.writeHex(before); uart.write("\r\nhv: guest_entry_frame.after_checksum="); uart.writeHex(after); uart.write("\r\n"); }
pub fn gefSpMutation() void { _=guest_entry_frame.build(); const before=guest_entry_frame.object().checksum; const after=guest_entry_frame.mutateSp(); uart.write("hv: guest_entry_frame.sp_mutation_test=ok\r\n"); uart.write("hv: guest_entry_frame.before_checksum="); uart.writeHex(before); uart.write("\r\nhv: guest_entry_frame.after_checksum="); uart.writeHex(after); uart.write("\r\n"); }
pub fn gefRegisterCorruption() void { guest_entry_frame.printTest("register_corruption_test", guest_entry_frame.corruptRegister()); }
pub fn gefGuestEntered() void { guest_entry_frame.printTest("guest_entered_test", guest_entry_frame.markGuestEntered()); }
pub fn gefInstruction() void { guest_entry_frame.printTest("instruction_executed_test", guest_entry_frame.markInstruction()); }
pub fn printTrapReturnFrame() void { trap_return_frame.printStatusCommand(); }
pub fn buildTrapReturnFrame() void { trap_return_frame.printBuildCommand(); }
pub fn validateTrapReturnFrame() void { trap_return_frame.printValidateCommand(); }
pub fn blockersTrapReturnFrame() void { trap_return_frame.printBlockersCommand(); }
pub fn fieldsTrapReturnFrame() void { trap_return_frame.printFieldsCommand(); }
pub fn checksumTrapReturnFrame() void { trap_return_frame.printChecksumCommand(); }
pub fn resetTrapReturnFrame() void { trap_return_frame.printResetCommand(); }
pub fn trfLifecycle() void { _ = hv26_invariants.trapLifecycle(); }
pub fn trfMutation() void { _ = hv26_invariants.trapMutation(); }
pub fn trfRequireEntry() void { trap_return_frame.printTest("require_entry_frame_test", trap_return_frame.missingEntry()); }
pub fn trfRequireCsr() void { trap_return_frame.printTest("require_csr_safety_test", trap_return_frame.missingCsr()); }
pub fn trfRequireHext() void { trap_return_frame.printTest("require_hext_test", trap_return_frame.missingHext()); }
pub fn trfSepc() void { trap_return_frame.printTest("sepc_corruption_test", trap_return_frame.corruptSepc()); }
pub fn trfStatus() void { trap_return_frame.printTest("status_corruption_test", trap_return_frame.corruptStatus()); }
pub fn trfExecuted() void { trap_return_frame.printTest("executed_test", trap_return_frame.markExecuted()); }
pub fn printFirstInstructionPlan() void { first_instruction_plan.printStatusCommand(); }
pub fn buildFirstInstructionPlan() void { first_instruction_plan.printBuildCommand(); }
pub fn validateFirstInstructionPlan() void { first_instruction_plan.printValidateCommand(); }
pub fn blockersFirstInstructionPlan() void { first_instruction_plan.printBlockersCommand(); }
pub fn nextFirstInstructionPlan() void { first_instruction_plan.printNextCommand(); }
pub fn chainFirstInstructionPlan() void { first_instruction_plan.printChainCommand(); }
pub fn checksumFirstInstructionPlan() void { first_instruction_plan.printChecksumCommand(); }
pub fn resetFirstInstructionPlan() void { first_instruction_plan.printResetCommand(); }
pub fn fipConsumption() void { _=hv26_invariants.firstConsumption(); }
pub fn fipCorruption() void { _=hv26_invariants.firstCorruption(); }
pub fn hv26Hv25Consumption() void { _=hv26_invariants.hv25Consumption(); }
pub fn hv26All() void { hv26_invariants.allInvariants(); }
pub fn fipRequireHgatp() void { first_instruction_plan.printTest("require_hgatp_test", first_instruction_plan.missingHgatp()); }
pub fn fipRequireActivation() void { first_instruction_plan.printTest("require_activation_plan_test", first_instruction_plan.missingActivation()); }
pub fn fipRequireEntry() void { first_instruction_plan.printTest("require_entry_frame_test", first_instruction_plan.missingEntry()); }
pub fn fipRequireTrap() void { first_instruction_plan.printTest("require_trap_return_frame_test", first_instruction_plan.missingTrap()); }
pub fn fipGuest() void { first_instruction_plan.printTest("guest_entered_test", first_instruction_plan.markGuest()); }
pub fn fipInstruction() void { first_instruction_plan.printTest("instruction_executed_test", first_instruction_plan.markInstruction()); }
pub fn fipTrap() void { first_instruction_plan.printTest("trap_return_executed_test", first_instruction_plan.markTrap()); }
pub fn fipStage2() void { first_instruction_plan.printTest("active_stage2_test", first_instruction_plan.markStage2()); }
pub fn fipHgatpWritten() void { first_instruction_plan.printTest("hgatp_written_test", first_instruction_plan.markHgatpWritten()); }
