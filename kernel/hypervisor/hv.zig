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
const hgatp_readiness = @import("hgatp_activation_readiness.zig");
const hgatp_write_plan = @import("hgatp_write_plan.zig");
const hgatp_write_gate = @import("hgatp_write_gate.zig");
const hgatp_write_boundary = @import("hgatp_write_boundary.zig");
const hgatp_write_attempt = @import("hgatp_write_attempt.zig");
const hgatp_csr_interface = @import("hgatp_csr_interface.zig");
const hgatp_csr_result = @import("hgatp_csr_result.zig");
const hgatp_hardware_write_prep = @import("hgatp_hardware_write_prep.zig");
const hgatp_hardware_write_operation = @import("hgatp_hardware_write_operation.zig");
const hgatp_execution_dry_run = @import("hgatp_execution_dry_run.zig");
const hgatp_hardware_executor = @import("hgatp_hardware_executor.zig");
const hgatp_trap_capture_prep = @import("hgatp_trap_capture_prep.zig");
const hgatp_csr_write_boundary = @import("hgatp_csr_write_boundary.zig");

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
    hgatp_readiness.init(vm.object().id, vcpu.object().id);
    hgatp_write_plan.init(vm.object().id, vcpu.object().id);
    hgatp_write_gate.init(vm.object().id, vcpu.object().id);
    hgatp_write_boundary.init(vm.object().id, vcpu.object().id);
    hgatp_write_attempt.init(vm.object().id, vcpu.object().id);
    hgatp_csr_interface.init(vm.object().id, vcpu.object().id);
    hgatp_csr_result.init(vm.object().id, vcpu.object().id);
    hgatp_hardware_write_prep.init(vm.object().id, vcpu.object().id);
    hgatp_hardware_write_operation.init(vm.object().id, vcpu.object().id);
    hgatp_execution_dry_run.init(vm.object().id, vcpu.object().id);
    hgatp_hardware_executor.init(vm.object().id, vcpu.object().id);
    hgatp_trap_capture_prep.init(vm.object().id, vcpu.object().id);
    hgatp_csr_write_boundary.init(vm.object().id, vcpu.object().id);
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
    hgatp_readiness.printStatusCommand();
    hgatp_write_gate.printStatusCommand();
    hgatp_write_boundary.printStatusCommand();
    hgatp_write_attempt.printStatusCommand();
    hgatp_csr_interface.printStatusCommand();
    hgatp_csr_result.printStatusCommand();
    hgatp_hardware_write_prep.printStatusCommand();
    hgatp_hardware_executor.printStatusCommand();
    hgatp_trap_capture_prep.printStatusCommand();
    hgatp_csr_write_boundary.printStatusCommand();
    uart.write("hv: guest_trap_return=MISSING\r\n");
    uart.write("hv: second_stage_translation=MISSING\r\n");

    uart.write("hv: virtual_console=foundation-mediation-only\r\n");
    uart.write("hv: sbi_layer=foundation-metadata-only\r\n");
    uart.write("hv: virtio_for_linux=MISSING\r\n");
    uart.write("hv: next=controlled active guest-entry prerequisites or SBI dispatch integration (no Linux boot claim)\r\n");
}







pub fn printCsrBoundary() void { hgatp_csr_write_boundary.printStatusCommand(); }
pub fn createCsrBoundary() void { hgatp_csr_write_boundary.printCreateCommand(); }
pub fn inspectCsrBoundary() void { hgatp_csr_write_boundary.printInspectCommand(); }
pub fn validateCsrBoundary() void { hgatp_csr_write_boundary.printValidateCommand(); }
pub fn executeCsrBoundary() void { hgatp_csr_write_boundary.printExecuteCommand(); }
pub fn resetCsrBoundary() void { hgatp_csr_write_boundary.printResetCommand(); }
pub fn denialTestCsrBoundary() void { hgatp_csr_write_boundary.printDenialTestCommand(); }
pub fn replayTestCsrBoundary() void { hgatp_csr_write_boundary.printReplayTestCommand(); }
pub fn noWriteInvariantTestCsrBoundary() void { hgatp_csr_write_boundary.printNoWriteInvariantTestCommand(); }

pub fn printHgatpTrapCapturePrep() void { hgatp_trap_capture_prep.printStatusCommand(); }
pub fn buildHgatpTrapCapturePrep() void { hgatp_trap_capture_prep.printBuildCommand(); }
pub fn validateHgatpTrapCapturePrep() void { hgatp_trap_capture_prep.printValidateCommand(); }
pub fn prepareHgatpTrapCapturePrep() void { hgatp_trap_capture_prep.printPrepareCommand(); }
pub fn blockersHgatpTrapCapturePrep() void { hgatp_trap_capture_prep.printBlockersCommand(); }
pub fn nextHgatpTrapCapturePrep() void { hgatp_trap_capture_prep.printNextCommand(); }
pub fn checksumHgatpTrapCapturePrep() void { hgatp_trap_capture_prep.printChecksumCommand(); }
pub fn resetHgatpTrapCapturePrep() void { hgatp_trap_capture_prep.printResetCommand(); }
pub fn fieldsHgatpTrapCapturePrep() void { hgatp_trap_capture_prep.printFieldsCommand(); }
pub fn trapSlotHgatpTrapCapturePrep() void { hgatp_trap_capture_prep.printTrapSlotCommand(); }
pub fn faultSlotHgatpTrapCapturePrep() void { hgatp_trap_capture_prep.printFaultSlotCommand(); }
pub fn resultHgatpTrapCapturePrep() void { hgatp_trap_capture_prep.printResultCommand(); }
pub fn decisionHgatpTrapCapturePrep() void { hgatp_trap_capture_prep.printDecisionCommand(); }
pub fn requireExecutorTestHgatpTrapCapturePrep() void { hgatp_trap_capture_prep.printRequireExecutorTestCommand(); }
pub fn invalidExecutorTestHgatpTrapCapturePrep() void { hgatp_trap_capture_prep.printInvalidExecutorTestCommand(); }
pub fn sourceIntegrityTestHgatpTrapCapturePrep() void { hgatp_trap_capture_prep.printSourceIntegrityTestCommand(); }
pub fn fakeTrapTestHgatpTrapCapturePrep() void { hgatp_trap_capture_prep.printFakeTrapTestCommand(); }
pub fn fakeFaultTestHgatpTrapCapturePrep() void { hgatp_trap_capture_prep.printFakeFaultTestCommand(); }
pub fn csrCalledTestHgatpTrapCapturePrep() void { hgatp_trap_capture_prep.printCsrCalledTestCommand(); }
pub fn rawCalledTestHgatpTrapCapturePrep() void { hgatp_trap_capture_prep.printRawCalledTestCommand(); }
pub fn readbackTestHgatpTrapCapturePrep() void { hgatp_trap_capture_prep.printReadbackTestCommand(); }
pub fn readbackValidTestHgatpTrapCapturePrep() void { hgatp_trap_capture_prep.printReadbackValidTestCommand(); }
pub fn writeAttemptedTestHgatpTrapCapturePrep() void { hgatp_trap_capture_prep.printWriteAttemptedTestCommand(); }
pub fn writePerformedTestHgatpTrapCapturePrep() void { hgatp_trap_capture_prep.printWritePerformedTestCommand(); }
pub fn activeStage2TestHgatpTrapCapturePrep() void { hgatp_trap_capture_prep.printActiveStage2TestCommand(); }
pub fn guestEnteredTestHgatpTrapCapturePrep() void { hgatp_trap_capture_prep.printGuestEnteredTestCommand(); }
pub fn firstInstructionTestHgatpTrapCapturePrep() void { hgatp_trap_capture_prep.printFirstInstructionTestCommand(); }
pub fn invariantConsumptionTestHgatpTrapCapturePrep() void { hgatp_trap_capture_prep.printInvariantConsumptionCommand(); }
pub fn invariantCorruptionTestHgatpTrapCapturePrep() void { hgatp_trap_capture_prep.printInvariantCorruptionCommand(); }

pub fn printHgatpHardwareExecutor() void { hgatp_hardware_executor.printStatusCommand(); }
pub fn buildHgatpHardwareExecutor() void { hgatp_hardware_executor.printBuildCommand(); }
pub fn validateHgatpHardwareExecutor() void { hgatp_hardware_executor.printValidateCommand(); }
pub fn executeHgatpHardwareExecutor() void { hgatp_hardware_executor.printExecuteCommand(); }
pub fn blockersHgatpHardwareExecutor() void { hgatp_hardware_executor.printBlockersCommand(); }
pub fn nextHgatpHardwareExecutor() void { hgatp_hardware_executor.printNextCommand(); }
pub fn checksumHgatpHardwareExecutor() void { hgatp_hardware_executor.printChecksumCommand(); }
pub fn resetHgatpHardwareExecutor() void { hgatp_hardware_executor.printResetCommand(); }
pub fn fieldsHgatpHardwareExecutor() void { hgatp_hardware_executor.printFieldsCommand(); }
pub fn requestHgatpHardwareExecutor() void { hgatp_hardware_executor.printRequestCommand(); }
pub fn stepsHgatpHardwareExecutor() void { hgatp_hardware_executor.printStepsCommand(); }
pub fn resultHgatpHardwareExecutor() void { hgatp_hardware_executor.printResultCommand(); }
pub fn trapSlotHgatpHardwareExecutor() void { hgatp_hardware_executor.printTrapSlotCommand(); }
pub fn readbackHgatpHardwareExecutor() void { hgatp_hardware_executor.printReadbackCommand(); }
pub fn decisionHgatpHardwareExecutor() void { hgatp_hardware_executor.printDecisionCommand(); }
pub fn requireDryRunTestHgatpHardwareExecutor() void { hgatp_hardware_executor.printRequireDryRunTestCommand(); }
pub fn invalidDryRunTestHgatpHardwareExecutor() void { hgatp_hardware_executor.printInvalidDryRunTestCommand(); }
pub fn sourceIntegrityTestHgatpHardwareExecutor() void { hgatp_hardware_executor.printSourceIntegrityTestCommand(); }
pub fn requestValueTestHgatpHardwareExecutor() void { hgatp_hardware_executor.printRequestValueTestCommand(); }
pub fn policyAllowsTestHgatpHardwareExecutor() void { hgatp_hardware_executor.printPolicyAllowsTestCommand(); }
pub fn boundaryBypassTestHgatpHardwareExecutor() void { hgatp_hardware_executor.printBoundaryBypassTestCommand(); }
pub fn csrReachedTestHgatpHardwareExecutor() void { hgatp_hardware_executor.printCsrReachedTestCommand(); }
pub fn csrCalledTestHgatpHardwareExecutor() void { hgatp_hardware_executor.printCsrCalledTestCommand(); }
pub fn rawReachedTestHgatpHardwareExecutor() void { hgatp_hardware_executor.printRawReachedTestCommand(); }
pub fn rawCalledTestHgatpHardwareExecutor() void { hgatp_hardware_executor.printRawCalledTestCommand(); }
pub fn fakeTrapTestHgatpHardwareExecutor() void { hgatp_hardware_executor.printFakeTrapTestCommand(); }
pub fn fakeReadbackTestHgatpHardwareExecutor() void { hgatp_hardware_executor.printFakeReadbackTestCommand(); }
pub fn writeAttemptedTestHgatpHardwareExecutor() void { hgatp_hardware_executor.printWriteAttemptedTestCommand(); }
pub fn writePerformedTestHgatpHardwareExecutor() void { hgatp_hardware_executor.printWritePerformedTestCommand(); }
pub fn activeStage2TestHgatpHardwareExecutor() void { hgatp_hardware_executor.printActiveStage2TestCommand(); }
pub fn guestEnteredTestHgatpHardwareExecutor() void { hgatp_hardware_executor.printGuestEnteredTestCommand(); }
pub fn firstInstructionTestHgatpHardwareExecutor() void { hgatp_hardware_executor.printFirstInstructionTestCommand(); }
pub fn invariantConsumptionTestHgatpHardwareExecutor() void { hgatp_hardware_executor.printInvariantConsumptionCommand(); }
pub fn invariantCorruptionTestHgatpHardwareExecutor() void { hgatp_hardware_executor.printInvariantCorruptionCommand(); }

pub fn printHgatpExecutionDryRun() void { hgatp_execution_dry_run.printStatusCommand(); }
pub fn buildHgatpExecutionDryRun() void { hgatp_execution_dry_run.printBuildCommand(); }
pub fn validateHgatpExecutionDryRun() void { hgatp_execution_dry_run.printValidateCommand(); }
pub fn executeHgatpExecutionDryRun() void { hgatp_execution_dry_run.printExecuteCommand(); }
pub fn blockersHgatpExecutionDryRun() void { hgatp_execution_dry_run.printBlockersCommand(); }
pub fn nextHgatpExecutionDryRun() void { hgatp_execution_dry_run.printNextCommand(); }
pub fn checksumHgatpExecutionDryRun() void { hgatp_execution_dry_run.printChecksumCommand(); }
pub fn resetHgatpExecutionDryRun() void { hgatp_execution_dry_run.printResetCommand(); }
pub fn fieldsHgatpExecutionDryRun() void { hgatp_execution_dry_run.printFieldsCommand(); }
pub fn requestHgatpExecutionDryRun() void { hgatp_execution_dry_run.printRequestCommand(); }
pub fn stepsHgatpExecutionDryRun() void { hgatp_execution_dry_run.printStepsCommand(); }
pub fn resultHgatpExecutionDryRun() void { hgatp_execution_dry_run.printResultCommand(); }
pub fn trapSlotHgatpExecutionDryRun() void { hgatp_execution_dry_run.printTrapSlotCommand(); }
pub fn readbackHgatpExecutionDryRun() void { hgatp_execution_dry_run.printReadbackCommand(); }
pub fn decisionHgatpExecutionDryRun() void { hgatp_execution_dry_run.printDecisionCommand(); }
pub fn requireOperationTestHgatpExecutionDryRun() void { hgatp_execution_dry_run.printRequireOperationTestCommand(); }
pub fn invalidOperationTestHgatpExecutionDryRun() void { hgatp_execution_dry_run.printInvalidOperationTestCommand(); }
pub fn sourceIntegrityTestHgatpExecutionDryRun() void { hgatp_execution_dry_run.printSourceIntegrityTestCommand(); }
pub fn requestValueTestHgatpExecutionDryRun() void { hgatp_execution_dry_run.printRequestValueTestCommand(); }
pub fn optInTestHgatpExecutionDryRun() void { hgatp_execution_dry_run.printOptInTestCommand(); }
pub fn policyAllowsTestHgatpExecutionDryRun() void { hgatp_execution_dry_run.printPolicyAllowsTestCommand(); }
pub fn operationCallReachableTestHgatpExecutionDryRun() void { hgatp_execution_dry_run.printOperationCallReachableTestCommand(); }
pub fn operationCallCalledTestHgatpExecutionDryRun() void { hgatp_execution_dry_run.printOperationCallCalledTestCommand(); }
pub fn rawWriteCalledTestHgatpExecutionDryRun() void { hgatp_execution_dry_run.printRawWriteCalledTestCommand(); }
pub fn executionReachedRawWriteTestHgatpExecutionDryRun() void { hgatp_execution_dry_run.printExecutionReachedRawWriteTestCommand(); }
pub fn executionCalledRawWriteTestHgatpExecutionDryRun() void { hgatp_execution_dry_run.printExecutionCalledRawWriteTestCommand(); }
pub fn fakeTrapTestHgatpExecutionDryRun() void { hgatp_execution_dry_run.printFakeTrapTestCommand(); }
pub fn fakeReadbackTestHgatpExecutionDryRun() void { hgatp_execution_dry_run.printFakeReadbackTestCommand(); }
pub fn writeAttemptedTestHgatpExecutionDryRun() void { hgatp_execution_dry_run.printWriteAttemptedTestCommand(); }
pub fn writePerformedTestHgatpExecutionDryRun() void { hgatp_execution_dry_run.printWritePerformedTestCommand(); }
pub fn activeStage2TestHgatpExecutionDryRun() void { hgatp_execution_dry_run.printActiveStage2TestCommand(); }
pub fn guestEnteredTestHgatpExecutionDryRun() void { hgatp_execution_dry_run.printGuestEnteredTestCommand(); }
pub fn firstInstructionTestHgatpExecutionDryRun() void { hgatp_execution_dry_run.printFirstInstructionTestCommand(); }
pub fn invariantConsumptionTestHgatpExecutionDryRun() void { hgatp_execution_dry_run.printInvariantConsumptionCommand(); }
pub fn invariantCorruptionTestHgatpExecutionDryRun() void { hgatp_execution_dry_run.printInvariantCorruptionCommand(); }
pub fn printHgatpHardwareWriteOperation() void { hgatp_hardware_write_operation.printStatusCommand(); }
pub fn buildHgatpHardwareWriteOperation() void { hgatp_hardware_write_operation.printBuildCommand(); }
pub fn validateHgatpHardwareWriteOperation() void { hgatp_hardware_write_operation.printValidateCommand(); }
pub fn blockersHgatpHardwareWriteOperation() void { hgatp_hardware_write_operation.printBlockersCommand(); }
pub fn nextHgatpHardwareWriteOperation() void { hgatp_hardware_write_operation.printNextCommand(); }
pub fn checksumHgatpHardwareWriteOperation() void { hgatp_hardware_write_operation.printChecksumCommand(); }
pub fn resetHgatpHardwareWriteOperation() void { hgatp_hardware_write_operation.printResetCommand(); }
pub fn fieldsHgatpHardwareWriteOperation() void { hgatp_hardware_write_operation.printFieldsCommand(); }
pub fn requestHgatpHardwareWriteOperation() void { hgatp_hardware_write_operation.printRequestCommand(); }
pub fn preflightHgatpHardwareWriteOperation() void { hgatp_hardware_write_operation.printPreflightCommand(); }
pub fn resultHgatpHardwareWriteOperation() void { hgatp_hardware_write_operation.printOperationResultCommand(); }
pub fn trapSlotHgatpHardwareWriteOperation() void { hgatp_hardware_write_operation.printTrapSlotCommand(); }
pub fn readbackHgatpHardwareWriteOperation() void { hgatp_hardware_write_operation.printReadbackCommand(); }
pub fn decisionHgatpHardwareWriteOperation() void { hgatp_hardware_write_operation.printDecisionCommand(); }
pub fn requirePrepTestHgatpHardwareWriteOperation() void { hgatp_hardware_write_operation.printRequirePrepTestCommand(); }
pub fn invalidPrepTestHgatpHardwareWriteOperation() void { hgatp_hardware_write_operation.printInvalidPrepTestCommand(); }
pub fn sourceIntegrityTestHgatpHardwareWriteOperation() void { hgatp_hardware_write_operation.printSourceIntegrityTestCommand(); }
pub fn requestValueTestHgatpHardwareWriteOperation() void { hgatp_hardware_write_operation.printRequestValueTestCommand(); }
pub fn optInTestHgatpHardwareWriteOperation() void { hgatp_hardware_write_operation.printOptInTestCommand(); }
pub fn policyAllowsTestHgatpHardwareWriteOperation() void { hgatp_hardware_write_operation.printPolicyAllowsTestCommand(); }
pub fn callReachableTestHgatpHardwareWriteOperation() void { hgatp_hardware_write_operation.printCallReachableTestCommand(); }
pub fn callCalledTestHgatpHardwareWriteOperation() void { hgatp_hardware_write_operation.printCallCalledTestCommand(); }
pub fn rawWriteCalledTestHgatpHardwareWriteOperation() void { hgatp_hardware_write_operation.printRawWriteCalledTestCommand(); }
pub fn fakeTrapTestHgatpHardwareWriteOperation() void { hgatp_hardware_write_operation.printFakeTrapTestCommand(); }
pub fn fakeReadbackTestHgatpHardwareWriteOperation() void { hgatp_hardware_write_operation.printFakeReadbackTestCommand(); }
pub fn writeAttemptedTestHgatpHardwareWriteOperation() void { hgatp_hardware_write_operation.printWriteAttemptedTestCommand(); }
pub fn writePerformedTestHgatpHardwareWriteOperation() void { hgatp_hardware_write_operation.printWritePerformedTestCommand(); }
pub fn activeStage2TestHgatpHardwareWriteOperation() void { hgatp_hardware_write_operation.printActiveStage2TestCommand(); }
pub fn guestEnteredTestHgatpHardwareWriteOperation() void { hgatp_hardware_write_operation.printGuestEnteredTestCommand(); }
pub fn firstInstructionTestHgatpHardwareWriteOperation() void { hgatp_hardware_write_operation.printFirstInstructionTestCommand(); }
pub fn invariantConsumptionTestHgatpHardwareWriteOperation() void { hgatp_hardware_write_operation.printInvariantConsumptionCommand(); }
pub fn invariantCorruptionTestHgatpHardwareWriteOperation() void { hgatp_hardware_write_operation.printInvariantCorruptionCommand(); }

pub fn printHgatpHardwareWritePrep() void { hgatp_hardware_write_prep.printStatusCommand(); }
pub fn buildHgatpHardwareWritePrep() void { hgatp_hardware_write_prep.printBuildCommand(); }
pub fn validateHgatpHardwareWritePrep() void { hgatp_hardware_write_prep.printValidateCommand(); }
pub fn blockersHgatpHardwareWritePrep() void { hgatp_hardware_write_prep.printBlockersCommand(); }
pub fn nextHgatpHardwareWritePrep() void { hgatp_hardware_write_prep.printNextCommand(); }
pub fn checksumHgatpHardwareWritePrep() void { hgatp_hardware_write_prep.printChecksumCommand(); }
pub fn resetHgatpHardwareWritePrep() void { hgatp_hardware_write_prep.printResetCommand(); }
pub fn fieldsHgatpHardwareWritePrep() void { hgatp_hardware_write_prep.printFieldsCommand(); }
pub fn envelopeHgatpHardwareWritePrep() void { hgatp_hardware_write_prep.printFieldsCommand(); }
pub fn trapEnvelopeHgatpHardwareWritePrep() void { hgatp_hardware_write_prep.printTrapSlotCommand(); }
pub fn readbackEnvelopeHgatpHardwareWritePrep() void { hgatp_hardware_write_prep.printReadbackCommand(); }
pub fn decisionHgatpHardwareWritePrep() void { hgatp_hardware_write_prep.printDecisionCommand(); }
pub fn requireResultTestHgatpHardwareWritePrep() void { hgatp_hardware_write_prep.printRequireInterfaceTestCommand(); }
pub fn invalidResultTestHgatpHardwareWritePrep() void { hgatp_hardware_write_prep.printInvalidInterfaceTestCommand(); }
pub fn sourceIntegrityTestHgatpHardwareWritePrep() void { hgatp_hardware_write_prep.printSourceIntegrityTestCommand(); }
pub fn requestValueTestHgatpHardwareWritePrep() void { hgatp_hardware_write_prep.printRequestValueTestCommand(); }
pub fn policyAllowsTestHgatpHardwareWritePrep() void { hgatp_hardware_write_prep.printPolicyAllowsTestCommand(); }
pub fn callReachableTestHgatpHardwareWritePrep() void { hgatp_hardware_write_prep.printCallReachableTestCommand(); }
pub fn callCalledTestHgatpHardwareWritePrep() void { hgatp_hardware_write_prep.printCsrCalledTestCommand(); }
pub fn rawWriteCalledTestHgatpHardwareWritePrep() void { hgatp_hardware_write_prep.printRawAsmCalledTestCommand(); }
pub fn fakeTrapTestHgatpHardwareWritePrep() void { hgatp_hardware_write_prep.printFakeFaultTestCommand(); }
pub fn fakeReadbackTestHgatpHardwareWritePrep() void { hgatp_hardware_write_prep.printFakeReadbackTestCommand(); }
pub fn writeAttemptedTestHgatpHardwareWritePrep() void { hgatp_hardware_write_prep.printWriteAttemptedTestCommand(); }
pub fn writePerformedTestHgatpHardwareWritePrep() void { hgatp_hardware_write_prep.printWritePerformedTestCommand(); }
pub fn activeStage2TestHgatpHardwareWritePrep() void { hgatp_hardware_write_prep.printActiveStage2TestCommand(); }
pub fn guestEnteredTestHgatpHardwareWritePrep() void { hgatp_hardware_write_prep.printGuestEnteredTestCommand(); }
pub fn firstInstructionTestHgatpHardwareWritePrep() void { hgatp_hardware_write_prep.printFirstInstructionTestCommand(); }
pub fn invariantConsumptionTestHgatpHardwareWritePrep() void { hgatp_hardware_write_prep.printInvariantConsumptionCommand(); }
pub fn invariantCorruptionTestHgatpHardwareWritePrep() void { hgatp_hardware_write_prep.printInvariantCorruptionCommand(); }

pub fn printHgatpCsrResult() void { hgatp_csr_result.printStatusCommand(); }
pub fn buildHgatpCsrResult() void { hgatp_csr_result.printBuildCommand(); }
pub fn validateHgatpCsrResult() void { hgatp_csr_result.printValidateCommand(); }
pub fn blockersHgatpCsrResult() void { hgatp_csr_result.printBlockersCommand(); }
pub fn nextHgatpCsrResult() void { hgatp_csr_result.printNextCommand(); }
pub fn checksumHgatpCsrResult() void { hgatp_csr_result.printChecksumCommand(); }
pub fn resetHgatpCsrResult() void { hgatp_csr_result.printResetCommand(); }
pub fn fieldsHgatpCsrResult() void { hgatp_csr_result.printFieldsCommand(); }
pub fn observationHgatpCsrResult() void { hgatp_csr_result.printObservationCommand(); }
pub fn trapSlotHgatpCsrResult() void { hgatp_csr_result.printTrapSlotCommand(); }
pub fn readbackHgatpCsrResult() void { hgatp_csr_result.printReadbackCommand(); }
pub fn decisionHgatpCsrResult() void { hgatp_csr_result.printDecisionCommand(); }
pub fn requireInterfaceTestHgatpCsrResult() void { hgatp_csr_result.printRequireInterfaceTestCommand(); }
pub fn invalidInterfaceTestHgatpCsrResult() void { hgatp_csr_result.printInvalidInterfaceTestCommand(); }
pub fn sourceIntegrityTestHgatpCsrResult() void { hgatp_csr_result.printSourceIntegrityTestCommand(); }
pub fn requestValueTestHgatpCsrResult() void { hgatp_csr_result.printRequestValueTestCommand(); }
pub fn csrCalledTestHgatpCsrResult() void { hgatp_csr_result.printCsrCalledTestCommand(); }
pub fn rawAsmCalledTestHgatpCsrResult() void { hgatp_csr_result.printRawAsmCalledTestCommand(); }
pub fn writeAttemptedTestHgatpCsrResult() void { hgatp_csr_result.printWriteAttemptedTestCommand(); }
pub fn writePerformedTestHgatpCsrResult() void { hgatp_csr_result.printWritePerformedTestCommand(); }
pub fn fakeFaultTestHgatpCsrResult() void { hgatp_csr_result.printFakeFaultTestCommand(); }
pub fn fakeReadbackTestHgatpCsrResult() void { hgatp_csr_result.printFakeReadbackTestCommand(); }
pub fn activeStage2TestHgatpCsrResult() void { hgatp_csr_result.printActiveStage2TestCommand(); }
pub fn guestEnteredTestHgatpCsrResult() void { hgatp_csr_result.printGuestEnteredTestCommand(); }
pub fn firstInstructionTestHgatpCsrResult() void { hgatp_csr_result.printFirstInstructionTestCommand(); }
pub fn invariantConsumptionTestHgatpCsrResult() void { hgatp_csr_result.printInvariantConsumptionCommand(); }
pub fn invariantCorruptionTestHgatpCsrResult() void { hgatp_csr_result.printInvariantCorruptionCommand(); }

pub fn printHgatpCsrInterface() void { hgatp_csr_interface.printStatusCommand(); }
pub fn buildHgatpCsrInterface() void { hgatp_csr_interface.printBuildCommand(); }
pub fn validateHgatpCsrInterface() void { hgatp_csr_interface.printValidateCommand(); }
pub fn blockersHgatpCsrInterface() void { hgatp_csr_interface.printBlockersCommand(); }
pub fn nextHgatpCsrInterface() void { hgatp_csr_interface.printNextCommand(); }
pub fn checksumHgatpCsrInterface() void { hgatp_csr_interface.printChecksumCommand(); }
pub fn resetHgatpCsrInterface() void { hgatp_csr_interface.printResetCommand(); }
pub fn fieldsHgatpCsrInterface() void { hgatp_csr_interface.printFieldsCommand(); }
pub fn requestHgatpCsrInterface() void { hgatp_csr_interface.printRequestCommand(); }
pub fn resultHgatpCsrInterface() void { hgatp_csr_interface.printResultCommand(); }
pub fn decisionHgatpCsrInterface() void { hgatp_csr_interface.printDecisionCommand(); }
pub fn requireAttemptTestHgatpCsrInterface() void { hgatp_csr_interface.printRequireAttemptTestCommand(); }
pub fn invalidAttemptTestHgatpCsrInterface() void { hgatp_csr_interface.printInvalidAttemptTestCommand(); }
pub fn sourceIntegrityTestHgatpCsrInterface() void { hgatp_csr_interface.printSourceIntegrityTestCommand(); }
pub fn requestValueTestHgatpCsrInterface() void { hgatp_csr_interface.printRequestValueTestCommand(); }
pub fn csrCalledTestHgatpCsrInterface() void { hgatp_csr_interface.printCsrCalledTestCommand(); }
pub fn rawAsmCalledTestHgatpCsrInterface() void { hgatp_csr_interface.printRawAsmCalledTestCommand(); }
pub fn writeAttemptedTestHgatpCsrInterface() void { hgatp_csr_interface.printWriteAttemptedTestCommand(); }
pub fn writePerformedTestHgatpCsrInterface() void { hgatp_csr_interface.printWritePerformedTestCommand(); }
pub fn activeStage2TestHgatpCsrInterface() void { hgatp_csr_interface.printActiveStage2TestCommand(); }
pub fn invariantConsumptionTestHgatpCsrInterface() void { hgatp_csr_interface.printInvariantConsumptionCommand(); }
pub fn invariantCorruptionTestHgatpCsrInterface() void { hgatp_csr_interface.printInvariantCorruptionCommand(); }

pub fn printHgatpWriteAttempt() void { hgatp_write_attempt.printStatusCommand(); }
pub fn buildHgatpWriteAttempt() void { hgatp_write_attempt.printBuildCommand(); }
pub fn validateHgatpWriteAttempt() void { hgatp_write_attempt.printValidateCommand(); }
pub fn blockersHgatpWriteAttempt() void { hgatp_write_attempt.printBlockersCommand(); }
pub fn nextHgatpWriteAttempt() void { hgatp_write_attempt.printNextCommand(); }
pub fn checksumHgatpWriteAttempt() void { hgatp_write_attempt.printChecksumCommand(); }
pub fn resetHgatpWriteAttempt() void { hgatp_write_attempt.printResetCommand(); }
pub fn fieldsHgatpWriteAttempt() void { hgatp_write_attempt.printFieldsCommand(); }
pub fn requestHgatpWriteAttempt() void { hgatp_write_attempt.printRequestCommand(); }
pub fn decisionHgatpWriteAttempt() void { hgatp_write_attempt.printDecisionCommand(); }
pub fn requireBoundaryTestHgatpWriteAttempt() void { hgatp_write_attempt.printRequireBoundaryTestCommand(); }
pub fn sourceIntegrityTestHgatpWriteAttempt() void { hgatp_write_attempt.printSourceIntegrityTestCommand(); }
pub fn requestValueTestHgatpWriteAttempt() void { hgatp_write_attempt.printRequestValueTestCommand(); }
pub fn invariantConsumptionTestHgatpWriteAttempt() void { hgatp_write_attempt.printInvariantConsumptionCommand(); }
pub fn invariantCorruptionTestHgatpWriteAttempt() void { hgatp_write_attempt.printInvariantCorruptionCommand(); }

pub fn printHgatpWriteBoundary() void { hgatp_write_boundary.printStatusCommand(); }
pub fn buildHgatpWriteBoundary() void { hgatp_write_boundary.printBuildCommand(); }
pub fn validateHgatpWriteBoundary() void { hgatp_write_boundary.printValidateCommand(); }
pub fn blockersHgatpWriteBoundary() void { hgatp_write_boundary.printBlockersCommand(); }
pub fn nextHgatpWriteBoundary() void { hgatp_write_boundary.printNextCommand(); }
pub fn checksumHgatpWriteBoundary() void { hgatp_write_boundary.printChecksumCommand(); }
pub fn resetHgatpWriteBoundary() void { hgatp_write_boundary.printResetCommand(); }
pub fn fieldsHgatpWriteBoundary() void { hgatp_write_boundary.printFieldsCommand(); }
pub fn requestHgatpWriteBoundary() void { hgatp_write_boundary.printRequestCommand(); }
pub fn decisionHgatpWriteBoundary() void { hgatp_write_boundary.printDecisionCommand(); }
pub fn invariantLifecycleTestHgatpWriteBoundary() void { hgatp_write_boundary.printInvariantLifecycleCommand(); }
pub fn invariantConsumptionTestHgatpWriteBoundary() void { hgatp_write_boundary.printInvariantConsumptionCommand(); }
pub fn invariantCorruptionTestHgatpWriteBoundary() void { hgatp_write_boundary.printInvariantCorruptionCommand(); }
pub fn requireGateTestHgatpWriteBoundary() void { hgatp_write_boundary.printRequireGateTestCommand(); }
pub fn invalidGateTestHgatpWriteBoundary() void { hgatp_write_boundary.printInvalidGateTestCommand(); }
pub fn gateAllowsBoundaryTestHgatpWriteBoundary() void { hgatp_write_boundary.printGateAllowsBoundaryTestCommand(); }
pub fn sourceIntegrityTestHgatpWriteBoundary() void { hgatp_write_boundary.printSourceIntegrityTestCommand(); }
pub fn requestValueTestHgatpWriteBoundary() void { hgatp_write_boundary.printRequestValueTestCommand(); }
pub fn boundaryAllowedTestHgatpWriteBoundary() void { hgatp_write_boundary.printBoundaryAllowedTestCommand(); }
pub fn boundaryReachedTestHgatpWriteBoundary() void { hgatp_write_boundary.printBoundaryReachedTestCommand(); }
pub fn writeAttemptTestHgatpWriteBoundary() void { hgatp_write_boundary.printWriteAttemptTestCommand(); }
pub fn writePerformedTestHgatpWriteBoundary() void { hgatp_write_boundary.printWritePerformedTestCommand(); }
pub fn activeStage2TestHgatpWriteBoundary() void { hgatp_write_boundary.printActiveStage2TestCommand(); }

pub fn printHgatpWriteGate() void { hgatp_write_gate.printStatusCommand(); }
pub fn buildHgatpWriteGate() void { hgatp_write_gate.printBuildCommand(); }
pub fn validateHgatpWriteGate() void { hgatp_write_gate.printValidateCommand(); }
pub fn blockersHgatpWriteGate() void { hgatp_write_gate.printBlockersCommand(); }
pub fn nextHgatpWriteGate() void { hgatp_write_gate.printNextCommand(); }
pub fn checksumHgatpWriteGate() void { hgatp_write_gate.printChecksumCommand(); }
pub fn resetHgatpWriteGate() void { hgatp_write_gate.printResetCommand(); }
pub fn fieldsHgatpWriteGate() void { hgatp_write_gate.printFieldsCommand(); }
pub fn decisionHgatpWriteGate() void { hgatp_write_gate.printDecisionCommand(); }
pub fn invariantLifecycleTestHgatpWriteGate() void { hgatp_write_gate.printInvariantLifecycleCommand(); }
pub fn invariantConsumptionTestHgatpWriteGate() void { hgatp_write_gate.printInvariantConsumptionCommand(); }
pub fn invariantCorruptionTestHgatpWriteGate() void { hgatp_write_gate.printInvariantCorruptionCommand(); }
pub fn requirePlanTestHgatpWriteGate() void { hgatp_write_gate.printRequirePlanTestCommand(); }
pub fn invalidPlanTestHgatpWriteGate() void { hgatp_write_gate.printInvalidPlanTestCommand(); }
pub fn requireHextTestHgatpWriteGate() void { hgatp_write_gate.printRequireHextTestCommand(); }
pub fn requireCsrSafetyTestHgatpWriteGate() void { hgatp_write_gate.printRequireCsrSafetyTestCommand(); }
pub fn sourceIntegrityTestHgatpWriteGate() void { hgatp_write_gate.printSourceIntegrityTestCommand(); }
pub fn boundaryAttemptTestHgatpWriteGate() void { hgatp_write_gate.printBoundaryAttemptTestCommand(); }
pub fn writeAttemptTestHgatpWriteGate() void { hgatp_write_gate.printWriteAttemptTestCommand(); }
pub fn writePerformedTestHgatpWriteGate() void { hgatp_write_gate.printWritePerformedTestCommand(); }
pub fn activeStage2TestHgatpWriteGate() void { hgatp_write_gate.printActiveStage2TestCommand(); }

pub fn printHgatpWritePlan() void { hgatp_write_plan.printStatusCommand(); }
pub fn buildHgatpWritePlan() void { hgatp_write_plan.printBuildCommand(); }
pub fn validateHgatpWritePlan() void { hgatp_write_plan.printValidateCommand(); }
pub fn blockersHgatpWritePlan() void { hgatp_write_plan.printBlockersCommand(); }
pub fn nextHgatpWritePlan() void { hgatp_write_plan.printNextCommand(); }
pub fn checksumHgatpWritePlan() void { hgatp_write_plan.printChecksumCommand(); }
pub fn resetHgatpWritePlan() void { hgatp_write_plan.printResetCommand(); }
pub fn fieldsHgatpWritePlan() void { hgatp_write_plan.printFieldsCommand(); }
pub fn invariantLifecycleTestHgatpWritePlan() void { hgatp_write_plan.printInvariantLifecycleCommand(); }
pub fn invariantConsumptionTestHgatpWritePlan() void { hgatp_write_plan.printInvariantConsumptionCommand(); }
pub fn invariantCorruptionTestHgatpWritePlan() void { hgatp_write_plan.printInvariantCorruptionCommand(); }
pub fn requireCandidateTestHgatpWritePlan() void { hgatp_write_plan.printRequireCandidateTestCommand(); }
pub fn invalidCandidateTestHgatpWritePlan() void { hgatp_write_plan.printInvalidCandidateTestCommand(); }
pub fn requireReadinessTestHgatpWritePlan() void { hgatp_write_plan.printRequireReadinessTestCommand(); }
pub fn invalidReadinessTestHgatpWritePlan() void { hgatp_write_plan.printInvalidReadinessTestCommand(); }
pub fn readinessNotReadyTestHgatpWritePlan() void { hgatp_write_plan.printReadinessNotReadyTestCommand(); }
pub fn requireHextTestHgatpWritePlan() void { hgatp_write_plan.printRequireHextTestCommand(); }
pub fn requireCsrSafetyTestHgatpWritePlan() void { hgatp_write_plan.printRequireCsrSafetyTestCommand(); }
pub fn requireStage2MetadataTestHgatpWritePlan() void { hgatp_write_plan.printRequireStage2MetadataTestCommand(); }
pub fn requireStage2TableTestHgatpWritePlan() void { hgatp_write_plan.printRequireStage2TableTestCommand(); }
pub fn sourceIntegrityTestHgatpWritePlan() void { hgatp_write_plan.printSourceIntegrityTestCommand(); }
pub fn writeAllowedTestHgatpWritePlan() void { hgatp_write_plan.printWriteAllowedTestCommand(); }
pub fn writeAttemptTestHgatpWritePlan() void { hgatp_write_plan.printWriteAttemptTestCommand(); }
pub fn activeStage2TestHgatpWritePlan() void { hgatp_write_plan.printActiveStage2TestCommand(); }

pub fn printHgatpReadiness() void { hgatp_readiness.printStatusCommand(); }
pub fn buildHgatpReadiness() void { hgatp_readiness.printBuildCommand(); }
pub fn validateHgatpReadiness() void { hgatp_readiness.printValidateCommand(); }
pub fn blockersHgatpReadiness() void { hgatp_readiness.printBlockersCommand(); }
pub fn nextHgatpReadiness() void { hgatp_readiness.printNextCommand(); }
pub fn checksumHgatpReadiness() void { hgatp_readiness.printChecksumCommand(); }
pub fn resetHgatpReadiness() void { hgatp_readiness.printResetCommand(); }
pub fn invariantLifecycleTestHgatpReadiness() void { hgatp_readiness.printInvariantLifecycleCommand(); }
pub fn invariantConsumptionTestHgatpReadiness() void { hgatp_readiness.printInvariantConsumptionCommand(); }
pub fn invariantCorruptionTestHgatpReadiness() void { hgatp_readiness.printInvariantCorruptionCommand(); }
pub fn requireCandidateTestHgatpReadiness() void { hgatp_readiness.printRequireCandidateTestCommand(); }
pub fn invalidCandidateTestHgatpReadiness() void { hgatp_readiness.printInvalidCandidateTestCommand(); }
pub fn requireStage2TestHgatpReadiness() void { hgatp_readiness.printRequireStage2TestCommand(); }
pub fn requireTableTestHgatpReadiness() void { hgatp_readiness.printRequireTableTestCommand(); }
pub fn requireHextTestHgatpReadiness() void { hgatp_readiness.printRequireHextTestCommand(); }
pub fn requireCsrSafetyTestHgatpReadiness() void { hgatp_readiness.printRequireCsrSafetyTestCommand(); }
pub fn writeAttemptTestHgatpReadiness() void { hgatp_readiness.printWriteAttemptTestCommand(); }
pub fn activeStage2TestHgatpReadiness() void { hgatp_readiness.printActiveStage2TestCommand(); }
pub fn sourceIntegrityTestHgatpReadiness() void { hgatp_readiness.printSourceIntegrityTestCommand(); }

pub fn printHgatpCandidate() void { hgatp_candidate.printStatusCommand(); }
pub fn buildHgatpCandidate() void { hgatp_candidate.printBuildCommand(); }
pub fn validateHgatpCandidate() void { hgatp_candidate.printValidateCommand(); }
pub fn blockersHgatpCandidate() void { hgatp_candidate.printBlockersCommand(); }
pub fn fieldsHgatpCandidate() void { hgatp_candidate.printFieldsCommand(); }
pub fn checksumHgatpCandidate() void { hgatp_candidate.printChecksumCommand(); }
pub fn resetHgatpCandidate() void { hgatp_candidate.printResetCommand(); }
pub fn invariantLifecycleTestHgatpCandidate() void { hgatp_candidate.printInvariantLifecycleCommand(); }
pub fn invariantDerivationTestHgatpCandidate() void { hgatp_candidate.printInvariantDerivationCommand(); }
pub fn invariantCorruptionTestHgatpCandidate() void { hgatp_candidate.printInvariantCorruptionCommand(); }
pub fn modeTestHgatpCandidate() void { hgatp_candidate.printModeTestCommand(); }
pub fn ppnAlignmentTestHgatpCandidate() void { hgatp_candidate.printPpnAlignmentTestCommand(); }
pub fn vmidBoundsTestHgatpCandidate() void { hgatp_candidate.printVmidBoundsTestCommand(); }
pub fn requireHextTestHgatpCandidate() void { hgatp_candidate.printRequireHextTestCommand(); }
pub fn writeAttemptTestHgatpCandidate() void { hgatp_candidate.printWriteAttemptTestCommand(); }
pub fn activeStage2TestHgatpCandidate() void { hgatp_candidate.printActiveStage2TestCommand(); }

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

