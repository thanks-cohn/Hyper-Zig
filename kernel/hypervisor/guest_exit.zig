const uart = @import("../console/uart.zig");
const vm_model = @import("vm.zig");
const vcpu_model = @import("vcpu.zig");
const guest_entry = @import("guest_entry.zig");

pub const GuestExitState = enum {
    no_exit,
    recorded,
};

pub const GuestExitKind = enum {
    none,
    instruction_trap,
    memory_fault,
    timer_interrupt,
    external_interrupt,
    illegal_instruction,
    explicit_halt,
    unknown,
};

pub const GuestExitReason = enum {
    none,
    simulated_instruction_trap,
    simulated_memory_fault,
    simulated_timer_interrupt,
    simulated_external_interrupt,
    simulated_illegal_instruction,
    simulated_explicit_halt,
    simulated_unknown,
};

pub const GuestExitError = enum {
    none,
    guest_entry_not_prepared,
    guest_entry_frame_invalid,
    owner_mismatch,
    unsupported_kind,
};

pub const GuestExitFrame = struct {
    pc: usize,
    sp: usize,
    cause: usize,
    trap_value: usize,
    instruction_bits: usize,
    owner_vm_id: vm_model.VmId,
    owner_vcpu_id: vcpu_model.VcpuId,
};

pub const GuestExitStats = struct {
    record_count: usize,
    reset_count: usize,
    failed_record_count: usize,
    instruction_trap_count: usize,
    memory_fault_count: usize,
    timer_interrupt_count: usize,
    external_interrupt_count: usize,
    illegal_instruction_count: usize,
    explicit_halt_count: usize,
    unknown_count: usize,
};

pub const GuestExitRecordResult = struct {
    result: CommandResult,
    state: GuestExitState,
    kind: GuestExitKind,
    reason: GuestExitReason,
    frame: GuestExitFrame,
    exit_error: GuestExitError,
};

pub const GuestExitResetResult = struct {
    result: CommandResult,
    state: GuestExitState,
    reset_count: usize,
    exit_error: GuestExitError,
};

pub const CommandResult = enum {
    ok,
    rejected,
};

pub const GuestExit = struct {
    owner_vm_id: vm_model.VmId,
    owner_vcpu_id: vcpu_model.VcpuId,
    state: GuestExitState,
    last_kind: GuestExitKind,
    last_reason: GuestExitReason,
    last_frame: GuestExitFrame,
    record_count: usize,
    reset_count: usize,
    failed_record_count: usize,
    instruction_trap_count: usize,
    memory_fault_count: usize,
    timer_interrupt_count: usize,
    external_interrupt_count: usize,
    illegal_instruction_count: usize,
    explicit_halt_count: usize,
    unknown_count: usize,
    last_error: GuestExitError,
};

const Cause = struct {
    const instruction_trap: usize = 2;
    const memory_fault: usize = 13;
    const timer_interrupt: usize = 0x8000_0000_0000_0005;
    const external_interrupt: usize = 0x8000_0000_0000_0009;
    const explicit_halt: usize = 0x100;
    const illegal_instruction: usize = 2;
    const unknown: usize = 0xff;
};

const TrapValue = struct {
    const instruction_trap: usize = 0;
    const memory_fault_offset: usize = 8;
    const timer_interrupt: usize = 0;
    const external_interrupt: usize = 0;
    const explicit_halt: usize = 0;
    const illegal_instruction: usize = 0x0000_0013;
    const unknown: usize = 0;
};

const InstructionBits = struct {
    const tiny_nop: usize = 0x0000_0013;
    const tiny_addi_ra: usize = 0x0010_0093;
    const explicit_halt_marker: usize = 0x0000_006f;
};

var boot_guest_exit: GuestExit = undefined;
var initialized: bool = false;

pub fn init(owner_vm_id: vm_model.VmId, owner_vcpu_id: vcpu_model.VcpuId) void {
    boot_guest_exit = emptyObject(owner_vm_id, owner_vcpu_id, 0, 0, 0, emptyStats());
    initialized = true;
    vcpu_model.clearGuestExitAttachment();
}

pub fn object() *const GuestExit {
    return mutableObject();
}

fn mutableObject() *GuestExit {
    if (!initialized) init(vm_model.object().id, vcpu_model.object().id);
    return &boot_guest_exit;
}

fn emptyStats() GuestExitStats {
    return .{
        .record_count = 0,
        .reset_count = 0,
        .failed_record_count = 0,
        .instruction_trap_count = 0,
        .memory_fault_count = 0,
        .timer_interrupt_count = 0,
        .external_interrupt_count = 0,
        .illegal_instruction_count = 0,
        .explicit_halt_count = 0,
        .unknown_count = 0,
    };
}

fn currentStats(exit: *const GuestExit) GuestExitStats {
    return .{
        .record_count = exit.record_count,
        .reset_count = exit.reset_count,
        .failed_record_count = exit.failed_record_count,
        .instruction_trap_count = exit.instruction_trap_count,
        .memory_fault_count = exit.memory_fault_count,
        .timer_interrupt_count = exit.timer_interrupt_count,
        .external_interrupt_count = exit.external_interrupt_count,
        .illegal_instruction_count = exit.illegal_instruction_count,
        .explicit_halt_count = exit.explicit_halt_count,
        .unknown_count = exit.unknown_count,
    };
}

fn emptyFrame(owner_vm_id: vm_model.VmId, owner_vcpu_id: vcpu_model.VcpuId) GuestExitFrame {
    return .{
        .pc = 0,
        .sp = 0,
        .cause = 0,
        .trap_value = 0,
        .instruction_bits = 0,
        .owner_vm_id = owner_vm_id,
        .owner_vcpu_id = owner_vcpu_id,
    };
}

fn emptyObject(
    owner_vm_id: vm_model.VmId,
    owner_vcpu_id: vcpu_model.VcpuId,
    reset_count: usize,
    record_count: usize,
    failed_record_count: usize,
    stats: GuestExitStats,
) GuestExit {
    return .{
        .owner_vm_id = owner_vm_id,
        .owner_vcpu_id = owner_vcpu_id,
        .state = .no_exit,
        .last_kind = .none,
        .last_reason = .none,
        .last_frame = emptyFrame(owner_vm_id, owner_vcpu_id),
        .record_count = record_count,
        .reset_count = reset_count,
        .failed_record_count = failed_record_count,
        .instruction_trap_count = stats.instruction_trap_count,
        .memory_fault_count = stats.memory_fault_count,
        .timer_interrupt_count = stats.timer_interrupt_count,
        .external_interrupt_count = stats.external_interrupt_count,
        .illegal_instruction_count = stats.illegal_instruction_count,
        .explicit_halt_count = stats.explicit_halt_count,
        .unknown_count = stats.unknown_count,
        .last_error = .none,
    };
}

pub fn recordInstructionTrap() GuestExitRecordResult {
    return record(.instruction_trap);
}

pub fn recordMemoryFault() GuestExitRecordResult {
    return record(.memory_fault);
}

pub fn recordTimerInterrupt() GuestExitRecordResult {
    return record(.timer_interrupt);
}

pub fn recordExplicitHalt() GuestExitRecordResult {
    return record(.explicit_halt);
}

pub fn record(kind: GuestExitKind) GuestExitRecordResult {
    const exit = mutableObject();
    exit.owner_vm_id = vm_model.object().id;
    exit.owner_vcpu_id = vcpu_model.object().id;

    const entry = guest_entry.object();
    if (entry.state != .prepared) return failRecord(.guest_entry_not_prepared, kind);
    if (!entry.frame_valid) return failRecord(.guest_entry_frame_invalid, kind);
    if (entry.frame.owner_vm_id != exit.owner_vm_id or entry.frame.owner_vcpu_id != exit.owner_vcpu_id) return failRecord(.owner_mismatch, kind);

    const spec = eventSpec(kind) orelse return failRecord(.unsupported_kind, kind);
    const frame = GuestExitFrame{
        .pc = entry.frame.pc,
        .sp = entry.frame.sp,
        .cause = spec.cause,
        .trap_value = computeTrapValue(kind, entry.frame.pc),
        .instruction_bits = spec.instruction_bits,
        .owner_vm_id = exit.owner_vm_id,
        .owner_vcpu_id = exit.owner_vcpu_id,
    };

    exit.state = .recorded;
    exit.last_kind = kind;
    exit.last_reason = spec.reason;
    exit.last_frame = frame;
    exit.record_count += 1;
    incrementKindCounter(exit, kind);
    exit.last_error = .none;
    vcpu_model.attachGuestExitRecord(frame, @as(usize, @intFromEnum(kind)), exit.record_count);

    return .{
        .result = .ok,
        .state = exit.state,
        .kind = exit.last_kind,
        .reason = exit.last_reason,
        .frame = exit.last_frame,
        .exit_error = .none,
    };
}

pub fn reset() GuestExitResetResult {
    const exit = mutableObject();
    const owner_vm_id = exit.owner_vm_id;
    const owner_vcpu_id = exit.owner_vcpu_id;
    const stats = currentStats(exit);
    const next_reset_count = exit.reset_count + 1;
    boot_guest_exit = emptyObject(owner_vm_id, owner_vcpu_id, next_reset_count, stats.record_count, stats.failed_record_count, stats);
    initialized = true;
    vcpu_model.clearGuestExitAttachment();
    return .{
        .result = .ok,
        .state = .no_exit,
        .reset_count = next_reset_count,
        .exit_error = .none,
    };
}

pub fn requireEntryTest() CommandResult {
    _ = guest_entry.reset();
    _ = reset();
    const result = recordInstructionTrap();
    return if (result.result == .rejected and result.exit_error == .guest_entry_not_prepared) .rejected else .ok;
}

fn failRecord(err: GuestExitError, attempted_kind: GuestExitKind) GuestExitRecordResult {
    const exit = mutableObject();
    exit.failed_record_count += 1;
    exit.last_error = err;
    return .{
        .result = .rejected,
        .state = exit.state,
        .kind = attempted_kind,
        .reason = exit.last_reason,
        .frame = exit.last_frame,
        .exit_error = err,
    };
}

const EventSpec = struct {
    reason: GuestExitReason,
    cause: usize,
    instruction_bits: usize,
};

fn eventSpec(kind: GuestExitKind) ?EventSpec {
    return switch (kind) {
        .instruction_trap => .{ .reason = .simulated_instruction_trap, .cause = Cause.instruction_trap, .instruction_bits = InstructionBits.tiny_nop },
        .memory_fault => .{ .reason = .simulated_memory_fault, .cause = Cause.memory_fault, .instruction_bits = InstructionBits.tiny_addi_ra },
        .timer_interrupt => .{ .reason = .simulated_timer_interrupt, .cause = Cause.timer_interrupt, .instruction_bits = InstructionBits.tiny_nop },
        .external_interrupt => .{ .reason = .simulated_external_interrupt, .cause = Cause.external_interrupt, .instruction_bits = InstructionBits.tiny_nop },
        .illegal_instruction => .{ .reason = .simulated_illegal_instruction, .cause = Cause.illegal_instruction, .instruction_bits = InstructionBits.tiny_nop },
        .explicit_halt => .{ .reason = .simulated_explicit_halt, .cause = Cause.explicit_halt, .instruction_bits = InstructionBits.explicit_halt_marker },
        .unknown => .{ .reason = .simulated_unknown, .cause = Cause.unknown, .instruction_bits = 0 },
        .none => null,
    };
}

fn computeTrapValue(kind: GuestExitKind, pc: usize) usize {
    return switch (kind) {
        .instruction_trap => TrapValue.instruction_trap,
        .memory_fault => pc + TrapValue.memory_fault_offset,
        .timer_interrupt => TrapValue.timer_interrupt,
        .external_interrupt => TrapValue.external_interrupt,
        .illegal_instruction => TrapValue.illegal_instruction,
        .explicit_halt => TrapValue.explicit_halt,
        .unknown => TrapValue.unknown,
        .none => 0,
    };
}

fn incrementKindCounter(exit: *GuestExit, kind: GuestExitKind) void {
    switch (kind) {
        .instruction_trap => exit.instruction_trap_count += 1,
        .memory_fault => exit.memory_fault_count += 1,
        .timer_interrupt => exit.timer_interrupt_count += 1,
        .external_interrupt => exit.external_interrupt_count += 1,
        .illegal_instruction => exit.illegal_instruction_count += 1,
        .explicit_halt => exit.explicit_halt_count += 1,
        .unknown => exit.unknown_count += 1,
        .none => {},
    }
}

pub fn printState() void {
    printImplementedMarker();
    printFields();
    printFrameFields();
    printNonClaims();
}

pub fn printRecordInstructionCommand() void {
    printRecordCommand(recordInstructionTrap());
}

pub fn printRecordMemoryFaultCommand() void {
    printRecordCommand(recordMemoryFault());
}

pub fn printRecordTimerCommand() void {
    printRecordCommand(recordTimerInterrupt());
}

pub fn printRecordHaltCommand() void {
    printRecordCommand(recordExplicitHalt());
}

fn printRecordCommand(result: GuestExitRecordResult) void {
    uart.write("hv: guest_exit.record_result=");
    uart.write(resultName(result.result));
    uart.write("\r\n");
    uart.write("hv: guest_exit.record_result.error=");
    uart.write(errorName(result.exit_error));
    uart.write("\r\n");
    printFields();
    printFrameFields();
    printNonClaims();
}

pub fn printResetCommand() void {
    const result = reset();
    uart.write("hv: guest_exit.reset_result=");
    uart.write(resultName(result.result));
    uart.write("\r\n");
    uart.write("hv: guest_exit.reset_result.error=");
    uart.write(errorName(result.exit_error));
    uart.write("\r\n");
    printFields();
    printFrameFields();
    printNonClaims();
}

pub fn printRequireEntryTestCommand() void {
    const result = requireEntryTest();
    uart.write("hv: guest_exit.require_entry_test=");
    uart.write(if (result == .rejected) "rejected" else "failed-to-reject");
    uart.write("\r\n");
    printFields();
    printFrameFields();
    printNonClaims();
}

pub fn printImplementedMarker() void {
    uart.write("hv: guest_exit=implemented\r\n");
}

fn printFields() void {
    const exit = object();
    uart.write("hv: guest_exit.owner_vm_id=");
    uart.writeDec(exit.owner_vm_id);
    uart.write("\r\n");
    uart.write("hv: guest_exit.owner_vcpu_id=");
    uart.writeDec(exit.owner_vcpu_id);
    uart.write("\r\n");
    uart.write("hv: guest_exit.state=");
    uart.write(stateName(exit.state));
    uart.write("\r\n");
    uart.write("hv: guest_exit.last_kind=");
    uart.write(kindName(exit.last_kind));
    uart.write("\r\n");
    uart.write("hv: guest_exit.last_reason=");
    uart.write(reasonName(exit.last_reason));
    uart.write("\r\n");
    uart.write("hv: guest_exit.record_count=");
    uart.writeDec(exit.record_count);
    uart.write("\r\n");
    uart.write("hv: guest_exit.reset_count=");
    uart.writeDec(exit.reset_count);
    uart.write("\r\n");
    uart.write("hv: guest_exit.failed_record_count=");
    uart.writeDec(exit.failed_record_count);
    uart.write("\r\n");
    uart.write("hv: guest_exit.instruction_trap_count=");
    uart.writeDec(exit.instruction_trap_count);
    uart.write("\r\n");
    uart.write("hv: guest_exit.memory_fault_count=");
    uart.writeDec(exit.memory_fault_count);
    uart.write("\r\n");
    uart.write("hv: guest_exit.timer_interrupt_count=");
    uart.writeDec(exit.timer_interrupt_count);
    uart.write("\r\n");
    uart.write("hv: guest_exit.external_interrupt_count=");
    uart.writeDec(exit.external_interrupt_count);
    uart.write("\r\n");
    uart.write("hv: guest_exit.illegal_instruction_count=");
    uart.writeDec(exit.illegal_instruction_count);
    uart.write("\r\n");
    uart.write("hv: guest_exit.explicit_halt_count=");
    uart.writeDec(exit.explicit_halt_count);
    uart.write("\r\n");
    uart.write("hv: guest_exit.unknown_count=");
    uart.writeDec(exit.unknown_count);
    uart.write("\r\n");
    uart.write("hv: guest_exit.last_error=");
    uart.write(errorName(exit.last_error));
    uart.write("\r\n");
}

fn printFrameFields() void {
    const frame = object().last_frame;
    uart.write("hv: guest_exit.frame.pc=");
    uart.writeHex(frame.pc);
    uart.write("\r\n");
    uart.write("hv: guest_exit.frame.sp=");
    uart.writeHex(frame.sp);
    uart.write("\r\n");
    uart.write("hv: guest_exit.frame.cause=");
    uart.writeHex(frame.cause);
    uart.write("\r\n");
    uart.write("hv: guest_exit.frame.trap_value=");
    uart.writeHex(frame.trap_value);
    uart.write("\r\n");
    uart.write("hv: guest_exit.frame.instruction_bits=");
    uart.writeHex(frame.instruction_bits);
    uart.write("\r\n");
    uart.write("hv: guest_exit.frame.owner_vm_id=");
    uart.writeDec(frame.owner_vm_id);
    uart.write("\r\n");
    uart.write("hv: guest_exit.frame.owner_vcpu_id=");
    uart.writeDec(frame.owner_vcpu_id);
    uart.write("\r\n");
}

fn stateName(state: GuestExitState) []const u8 {
    return switch (state) {
        .no_exit => "no-exit",
        .recorded => "recorded",
    };
}

fn kindName(kind: GuestExitKind) []const u8 {
    return switch (kind) {
        .none => "none",
        .instruction_trap => "instruction-trap",
        .memory_fault => "memory-fault",
        .timer_interrupt => "timer-interrupt",
        .external_interrupt => "external-interrupt",
        .illegal_instruction => "illegal-instruction",
        .explicit_halt => "explicit-halt",
        .unknown => "unknown",
    };
}

fn reasonName(reason: GuestExitReason) []const u8 {
    return switch (reason) {
        .none => "none",
        .simulated_instruction_trap => "simulated-instruction-trap",
        .simulated_memory_fault => "simulated-memory-fault",
        .simulated_timer_interrupt => "simulated-timer-interrupt",
        .simulated_external_interrupt => "simulated-external-interrupt",
        .simulated_illegal_instruction => "simulated-illegal-instruction",
        .simulated_explicit_halt => "simulated-explicit-halt",
        .simulated_unknown => "simulated-unknown",
    };
}

fn resultName(result: CommandResult) []const u8 {
    return switch (result) {
        .ok => "ok",
        .rejected => "rejected",
    };
}

fn errorName(err: GuestExitError) []const u8 {
    return switch (err) {
        .none => "none",
        .guest_entry_not_prepared => "guest-entry-not-prepared",
        .guest_entry_frame_invalid => "guest-entry-frame-invalid",
        .owner_mismatch => "owner-mismatch",
        .unsupported_kind => "unsupported-kind",
    };
}

fn printNonClaims() void {
    uart.write("hv: guest_execution=not-supported-yet\r\n");
    uart.write("hv: linux_guest=not-supported-yet\r\n");
    uart.write("hv: second_stage_translation=MISSING\r\n");
    uart.write("hv: h_extension=unknown reason=no-safe-detection-yet\r\n");
}
