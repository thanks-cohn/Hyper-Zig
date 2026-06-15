# HV10

## Guest Execution Gates

```text
Section: 10A
Module: Guest Execution Gates
Type: Concept
Source: guest_execution.zig
```

### In Plain English

Everything built so far has been preparation.

The hypervisor created:

* a VM
* a vCPU
* guest memory
* a guest image
* an entry point
* an address space
* guest exit tracking
* run-attempt validation

Now we arrive at the edge of execution.

Not execution itself.

The edge of execution.

That distinction matters.

Many students imagine execution as a switch:

```text
Off
↓
On
```

Real systems are rarely that simple.

Between:

```text
Ready
```

and

```text
Running
```

there is usually a gate.

A final checkpoint.

A final verification.

A final opportunity to refuse.

That is the purpose of Guest Execution Gates.

The execution gate exists to answer one question:

```text
Should the hypervisor allow execution to proceed?
```

Notice the wording.

Not:

```text
Can execution happen?
```

But:

```text
Should execution happen?
```

A hypervisor is not a passenger.

A hypervisor is the authority.

Execution occurs only because the hypervisor permits it.

HV10 introduces the policy layer.

The guest may be prepared.

The guest may be valid.

The guest may be ready.

The hypervisor still decides.

At this stage:

* no Linux boots
* no BusyBox boots
* no Alpine boots
* no guest instructions execute

The gate exists.

The permission exists.

The final decision exists.

Actual execution comes later.

### Key Idea

HV09 answers:

```text
Is the guest ready?
```

HV10 answers:

```text
Will the hypervisor allow it?
```

Those are different questions.

---

```text
Section: 10B
Module: Guest Execution Gates
Type: Implementation
Source: guest_execution.zig
```

## The Real Hyper-Zig Module

File:

```text
kernel/hypervisor/guest_execution.zig
```

```zig
const uart = @import("../console/uart.zig");
const vm_model = @import("vm.zig");
const vcpu_model = @import("vcpu.zig");
const capability = @import("capability.zig");
const guest_memory = @import("guest_memory.zig");
const guest_address_space = @import("guest_address_space.zig");
const guest_image = @import("guest_image.zig");
const guest_entry = @import("guest_entry.zig");
const guest_exit = @import("guest_exit.zig");
const guest_run_attempt = @import("guest_run_attempt.zig");

pub const ExecutionState = enum {
    cold,
    collecting,
    validated,
    blocked,
    armed_blocked,
};

pub const GateDecision = enum {
    not_evaluated,
    validated_ready_for_hardware_gate,
    blocked_missing_prerequisite,
    blocked_by_hardware_gate,
    armed_but_execution_blocked,
};

pub const ExecutionBlocker = enum {
    none,
    vm_missing,
    vcpu_missing,
    guest_memory_missing,
    address_space_missing,
    guest_image_missing,
    guest_entry_missing,
    guest_exit_missing,
    run_attempt_not_armed,
    second_stage_translation_missing,
    h_extension_unknown,
    guest_execution_disabled,
};

pub const ExecutionError = enum {
    none,
    missing_prerequisite,
    hardware_gate_blocked,
};

pub const ExecutionCommandResult = enum {
    ok,
    rejected,
    blocked,
    armed_blocked,
};

pub const ExecutionPrereqs = struct {
    vm_present: bool,
    vcpu_present: bool,
    guest_memory_configured: bool,
    address_space_configured: bool,
    guest_image_loaded: bool,
    guest_entry_prepared: bool,
    guest_exit_model_ready: bool,
    run_attempt_armed: bool,
    second_stage_translation_present: bool,
    h_extension_present: bool,
    guest_execution_enabled: bool,
};

pub const ExecutionFrame = struct {
    pc: usize,
    sp: usize,
    guest_base: usize,
    guest_size_bytes: usize,
    translated_page_count: usize,
    loaded_byte_count: usize,
    entry_owner_vm_id: vm_model.VmId,
    entry_owner_vcpu_id: vcpu_model.VcpuId,
    exit_kind_tag: usize,
    run_count_snapshot: u64,
};

pub const ExecutionStats = struct {
    status_count: usize,
    validate_count: usize,
    arm_count: usize,
    blocker_count: usize,
    reset_count: usize,
    transition_count: usize,
    rejected_count: usize,
    hardware_block_count: usize,
    readiness_score: usize,
    last_error: ExecutionError,
};

pub const ExecutionResult = struct {
    result: ExecutionCommandResult,
    state: ExecutionState,
    decision: GateDecision,
    primary_blocker: ExecutionBlocker,
    prereqs: ExecutionPrereqs,
    frame: ExecutionFrame,
    stats: ExecutionStats,
};

pub const GuestExecutionGate = struct {
    owner_vm_id: vm_model.VmId,
    owner_vcpu_id: vcpu_model.VcpuId,
    state: ExecutionState,
    decision: GateDecision,
    primary_blocker: ExecutionBlocker,
    prereqs: ExecutionPrereqs,
    frame: ExecutionFrame,
    blocker_vm_missing: bool,
    blocker_vcpu_missing: bool,
    blocker_guest_memory_missing: bool,
    blocker_address_space_missing: bool,
    blocker_guest_image_missing: bool,
    blocker_guest_entry_missing: bool,
    blocker_guest_exit_missing: bool,
    blocker_run_attempt_not_armed: bool,
    blocker_second_stage_translation_missing: bool,
    blocker_h_extension_unknown: bool,
    blocker_guest_execution_disabled: bool,
    stats: ExecutionStats,
};

var boot_execution_gate: GuestExecutionGate = undefined;
var initialized: bool = false;

pub fn init(owner_vm_id: vm_model.VmId, owner_vcpu_id: vcpu_model.VcpuId) void {
    boot_execution_gate = emptyObject(owner_vm_id, owner_vcpu_id, emptyStats());
    initialized = true;
}

pub fn object() *const GuestExecutionGate {
    return mutableObject();
}

fn mutableObject() *GuestExecutionGate {
    if (!initialized) init(vm_model.object().id, vcpu_model.object().id);
    return &boot_execution_gate;
}

fn emptyPrereqs() ExecutionPrereqs {
    return .{
        .vm_present = false,
        .vcpu_present = false,
        .guest_memory_configured = false,
        .address_space_configured = false,
        .guest_image_loaded = false,
        .guest_entry_prepared = false,
        .guest_exit_model_ready = false,
        .run_attempt_armed = false,
        .second_stage_translation_present = false,
        .h_extension_present = false,
        .guest_execution_enabled = false,
    };
}

fn emptyFrame(owner_vm_id: vm_model.VmId, owner_vcpu_id: vcpu_model.VcpuId) ExecutionFrame {
    return .{
        .pc = 0,
        .sp = 0,
        .guest_base = 0,
        .guest_size_bytes = 0,
        .translated_page_count = 0,
        .loaded_byte_count = 0,
        .entry_owner_vm_id = owner_vm_id,
        .entry_owner_vcpu_id = owner_vcpu_id,
        .exit_kind_tag = 0,
        .run_count_snapshot = 0,
    };
}

fn emptyStats() ExecutionStats {
    return .{
        .status_count = 0,
        .validate_count = 0,
        .arm_count = 0,
        .blocker_count = 0,
        .reset_count = 0,
        .transition_count = 0,
        .rejected_count = 0,
        .hardware_block_count = 0,
        .readiness_score = 0,
        .last_error = .none,
    };
}

fn emptyObject(owner_vm_id: vm_model.VmId, owner_vcpu_id: vcpu_model.VcpuId, stats: ExecutionStats) GuestExecutionGate {
    return .{
        .owner_vm_id = owner_vm_id,
        .owner_vcpu_id = owner_vcpu_id,
        .state = .cold,
        .decision = .not_evaluated,
        .primary_blocker = .none,
        .prereqs = emptyPrereqs(),
        .frame = emptyFrame(owner_vm_id, owner_vcpu_id),
        .blocker_vm_missing = false,
        .blocker_vcpu_missing = false,
        .blocker_guest_memory_missing = false,
        .blocker_address_space_missing = false,
        .blocker_guest_image_missing = false,
        .blocker_guest_entry_missing = false,
        .blocker_guest_exit_missing = false,
        .blocker_run_attempt_not_armed = false,
        .blocker_second_stage_translation_missing = false,
        .blocker_h_extension_unknown = false,
        .blocker_guest_execution_disabled = false,
        .stats = stats,
    };
}

pub fn status() ExecutionResult {
    const gate = mutableObject();
    gate.stats.status_count += 1;
    collect(gate);
    return makeResult(.ok, gate);
}

pub fn validate() ExecutionResult {
    const gate = mutableObject();
    gate.stats.validate_count += 1;
    collect(gate);
    gate.state = .collecting;
    gate.stats.transition_count += 1;
    decide(gate, false);
    if (hasRequiredPrereqBlocker(gate)) {
        gate.state = .blocked;
        gate.stats.transition_count += 1;
        gate.stats.rejected_count += 1;
        gate.stats.last_error = .missing_prerequisite;
        return makeResult(.rejected, gate);
    }
    gate.state = .validated;
    gate.stats.transition_count += 1;
    gate.stats.last_error = .none;
    return makeResult(.ok, gate);
}

pub fn arm() ExecutionResult {
    const gate = mutableObject();
    gate.stats.arm_count += 1;
    collect(gate);
    gate.state = .collecting;
    gate.stats.transition_count += 1;
    decide(gate, true);
    if (hasRequiredPrereqBlocker(gate)) {
        gate.state = .blocked;
        gate.stats.transition_count += 1;
        gate.stats.rejected_count += 1;
        gate.stats.last_error = .missing_prerequisite;
        return makeResult(.rejected, gate);
    }
    if (hasHardwareBlocker(gate)) {
        gate.state = .armed_blocked;
        gate.decision = .armed_but_execution_blocked;
        gate.primary_blocker = firstHardwareBlocker(gate);
        gate.stats.transition_count += 1;
        gate.stats.hardware_block_count += 1;
        gate.stats.last_error = .hardware_gate_blocked;
        return makeResult(.armed_blocked, gate);
    }
    gate.state = .validated;
    gate.decision = .validated_ready_for_hardware_gate;
    gate.primary_blocker = .none;
    gate.stats.transition_count += 1;
    gate.stats.last_error = .none;
    return makeResult(.ok, gate);
}

pub fn blockers() ExecutionResult {
    const gate = mutableObject();
    gate.stats.blocker_count += 1;
    collect(gate);
    decide(gate, false);
    return makeResult(if (gate.primary_blocker == .none) .ok else .blocked, gate);
}

pub fn reset() ExecutionResult {
    const gate = mutableObject();
    const owner_vm_id = gate.owner_vm_id;
    const owner_vcpu_id = gate.owner_vcpu_id;
    var stats = gate.stats;
    stats.reset_count += 1;
    stats.last_error = .none;
    boot_execution_gate = emptyObject(owner_vm_id, owner_vcpu_id, stats);
    initialized = true;
    return makeResult(.ok, &boot_execution_gate);
}

pub fn requirePrereqTest() ExecutionCommandResult {
    _ = guest_entry.reset();
    _ = reset();
    const result = arm();
    return if (result.result == .rejected and result.primary_blocker == .guest_entry_missing) .rejected else .ok;
}

fn collect(gate: *GuestExecutionGate) void {
    const vm_obj = vm_model.object();
    const vcpu_obj = vcpu_model.object();
    const gm = guest_memory.object();
    const as = guest_address_space.object();
    const image = guest_image.object();
    const entry = guest_entry.object();
    const exit = guest_exit.object();
    const run_attempt = guest_run_attempt.object();
    const caps = capability.detect();

    gate.owner_vm_id = vm_obj.id;
    gate.owner_vcpu_id = vcpu_obj.id;
    gate.prereqs = .{
        .vm_present = vm_obj.state == .defined,
        .vcpu_present = vcpu_obj.vm_id == vm_obj.id,
        .guest_memory_configured = gm.state == .configured and gm.owner_vm_id == vm_obj.id and gm.size_bytes > 0,
        .address_space_configured = as.state == .configured and as.owner_vm_id == vm_obj.id and as.translated_page_count > 0,
        .guest_image_loaded = image.state == .loaded and image.owner_vm_id == vm_obj.id and image.loaded_byte_count > 0,
        .guest_entry_prepared = entry.state == .prepared and entry.frame_valid and entry.owner_vm_id == vm_obj.id and entry.owner_vcpu_id == vcpu_obj.id,
        .guest_exit_model_ready = exit.state == .recorded and exit.owner_vm_id == vm_obj.id and exit.owner_vcpu_id == vcpu_obj.id,
        .run_attempt_armed = run_attempt.state == .armed_no_execute and run_attempt.owner_vm_id == vm_obj.id and run_attempt.owner_vcpu_id == vcpu_obj.id,
        .second_stage_translation_present = false,
        .h_extension_present = caps.h_extension == .present,
        .guest_execution_enabled = false,
    };
    gate.frame = .{
        .pc = if (gate.prereqs.guest_entry_prepared) entry.frame.pc else 0,
        .sp = if (gate.prereqs.guest_entry_prepared) entry.frame.sp else 0,
        .guest_base = if (gate.prereqs.guest_memory_configured) gm.base else 0,
        .guest_size_bytes = if (gate.prereqs.guest_memory_configured) gm.size_bytes else 0,
        .translated_page_count = if (gate.prereqs.address_space_configured) as.translated_page_count else 0,
        .loaded_byte_count = if (gate.prereqs.guest_image_loaded) image.loaded_byte_count else 0,
        .entry_owner_vm_id = if (gate.prereqs.guest_entry_prepared) entry.frame.owner_vm_id else vm_obj.id,
        .entry_owner_vcpu_id = if (gate.prereqs.guest_entry_prepared) entry.frame.owner_vcpu_id else vcpu_obj.id,
        .exit_kind_tag = if (gate.prereqs.guest_exit_model_ready) @intFromEnum(exit.last_kind) else 0,
        .run_count_snapshot = vcpu_obj.run_count,
    };
    refreshBlockers(gate);
    gate.stats.readiness_score = readinessScore(gate.prereqs);
}

fn refreshBlockers(gate: *GuestExecutionGate) void {
    gate.blocker_vm_missing = !gate.prereqs.vm_present;
    gate.blocker_vcpu_missing = !gate.prereqs.vcpu_present;
    gate.blocker_guest_memory_missing = !gate.prereqs.guest_memory_configured;
    gate.blocker_address_space_missing = !gate.prereqs.address_space_configured;
    gate.blocker_guest_image_missing = !gate.prereqs.guest_image_loaded;
    gate.blocker_guest_entry_missing = !gate.prereqs.guest_entry_prepared;
    gate.blocker_guest_exit_missing = !gate.prereqs.guest_exit_model_ready;
    gate.blocker_run_attempt_not_armed = !gate.prereqs.run_attempt_armed;
    gate.blocker_second_stage_translation_missing = !gate.prereqs.second_stage_translation_present;
    gate.blocker_h_extension_unknown = !gate.prereqs.h_extension_present;
    gate.blocker_guest_execution_disabled = !gate.prereqs.guest_execution_enabled;
}

fn decide(gate: *GuestExecutionGate, for_arm: bool) void {
    if (firstRequiredPrereqBlocker(gate)) |blocker| {
        gate.decision = .blocked_missing_prerequisite;
        gate.primary_blocker = blocker;
        return;
    }
    if (firstHardwareBlocker(gate) != .none) {
        gate.decision = if (for_arm) .armed_but_execution_blocked else .blocked_by_hardware_gate;
        gate.primary_blocker = firstHardwareBlocker(gate);
        return;
    }
    gate.decision = .validated_ready_for_hardware_gate;
    gate.primary_blocker = .none;
}

fn readinessScore(prereqs: ExecutionPrereqs) usize {
    var score: usize = 0;
    if (prereqs.vm_present) score += 1;
    if (prereqs.vcpu_present) score += 1;
    if (prereqs.guest_memory_configured) score += 1;
    if (prereqs.address_space_configured) score += 1;
    if (prereqs.guest_image_loaded) score += 1;
    if (prereqs.guest_entry_prepared) score += 1;
    if (prereqs.guest_exit_model_ready) score += 1;
    if (prereqs.run_attempt_armed) score += 1;
    if (prereqs.second_stage_translation_present) score += 1;
    if (prereqs.h_extension_present) score += 1;
    if (prereqs.guest_execution_enabled) score += 1;
    return score;
}

fn hasRequiredPrereqBlocker(gate: *const GuestExecutionGate) bool {
    return firstRequiredPrereqBlocker(gate) != null;
}

fn firstRequiredPrereqBlocker(gate: *const GuestExecutionGate) ?ExecutionBlocker {
    if (gate.blocker_vm_missing) return .vm_missing;
    if (gate.blocker_vcpu_missing) return .vcpu_missing;
    if (gate.blocker_guest_memory_missing) return .guest_memory_missing;
    if (gate.blocker_address_space_missing) return .address_space_missing;
    if (gate.blocker_guest_image_missing) return .guest_image_missing;
    if (gate.blocker_guest_entry_missing) return .guest_entry_missing;
    if (gate.blocker_guest_exit_missing) return .guest_exit_missing;
    if (gate.blocker_run_attempt_not_armed) return .run_attempt_not_armed;
    return null;
}

fn hasHardwareBlocker(gate: *const GuestExecutionGate) bool {
    return firstHardwareBlocker(gate) != .none;
}

fn firstHardwareBlocker(gate: *const GuestExecutionGate) ExecutionBlocker {
    if (gate.blocker_second_stage_translation_missing) return .second_stage_translation_missing;
    if (gate.blocker_h_extension_unknown) return .h_extension_unknown;
    if (gate.blocker_guest_execution_disabled) return .guest_execution_disabled;
    return .none;
}

fn makeResult(result: ExecutionCommandResult, gate: *const GuestExecutionGate) ExecutionResult {
    return .{
        .result = result,
        .state = gate.state,
        .decision = gate.decision,
        .primary_blocker = gate.primary_blocker,
        .prereqs = gate.prereqs,
        .frame = gate.frame,
        .stats = gate.stats,
    };
}

pub fn printState() void {
    _ = status();
    printImplementedMarker();
    printFields();
    printPrereqs();
    printBlockers();
    printFrame();
    printStats();
    printNonClaims();
}

pub fn printStatusCommand() void {
    printState();
}

pub fn printValidateCommand() void {
    const result = validate();
    uart.write("hv: guest_exec.validate_result=");
    uart.write(commandResultName(result.result));
    uart.write("\r\n");
    printStateWithoutStatusMutation();
}

pub fn printArmCommand() void {
    const result = arm();
    uart.write("hv: guest_exec.arm_result=");
    uart.write(commandResultName(result.result));
    uart.write("\r\n");
    printStateWithoutStatusMutation();
}

pub fn printBlockersCommand() void {
    const result = blockers();
    uart.write("hv: guest_exec.blockers_result=");
    uart.write(commandResultName(result.result));
    uart.write("\r\n");
    printStateWithoutStatusMutation();
}

pub fn printResetCommand() void {
    const result = reset();
    uart.write("hv: guest_exec.reset_result=");
    uart.write(commandResultName(result.result));
    uart.write("\r\n");
    printStateWithoutStatusMutation();
}

pub fn printRequirePrereqTestCommand() void {
    const result = requirePrereqTest();
    uart.write("hv: guest_exec.require_prereq_test_result=");
    uart.write(commandResultName(result));
    uart.write("\r\n");
    printStateWithoutStatusMutation();
}

fn printStateWithoutStatusMutation() void {
    printImplementedMarker();
    printFields();
    printPrereqs();
    printBlockers();
    printFrame();
    printStats();
    printNonClaims();
}

pub fn printImplementedMarker() void {
    uart.write("hv: guest_execution_gate=implemented\r\n");
}

fn printFields() void {
    const gate = object();
    uart.write("hv: guest_exec.owner_vm_id=");
    uart.writeDec(gate.owner_vm_id);
    uart.write("\r\n");
    uart.write("hv: guest_exec.owner_vcpu_id=");
    uart.writeDec(gate.owner_vcpu_id);
    uart.write("\r\n");
    uart.write("hv: guest_exec.state=");
    uart.write(stateName(gate.state));
    uart.write("\r\n");
    uart.write("hv: guest_exec.decision=");
    uart.write(decisionName(gate.decision));
    uart.write("\r\n");
    uart.write("hv: guest_exec.primary_blocker=");
    uart.write(blockerName(gate.primary_blocker));
    uart.write("\r\n");
}

fn printPrereqs() void {
    const prereqs = object().prereqs;
    printBool("hv: guest_exec.prereq.vm_present=", prereqs.vm_present);
    printBool("hv: guest_exec.prereq.vcpu_present=", prereqs.vcpu_present);
    printBool("hv: guest_exec.prereq.guest_memory_configured=", prereqs.guest_memory_configured);
    printBool("hv: guest_exec.prereq.address_space_configured=", prereqs.address_space_configured);
    printBool("hv: guest_exec.prereq.guest_image_loaded=", prereqs.guest_image_loaded);
    printBool("hv: guest_exec.prereq.guest_entry_prepared=", prereqs.guest_entry_prepared);
    printBool("hv: guest_exec.prereq.guest_exit_model_ready=", prereqs.guest_exit_model_ready);
    printBool("hv: guest_exec.prereq.run_attempt_armed=", prereqs.run_attempt_armed);
    printBool("hv: guest_exec.prereq.second_stage_translation_present=", prereqs.second_stage_translation_present);
    printBool("hv: guest_exec.prereq.h_extension_present=", prereqs.h_extension_present);
    printBool("hv: guest_exec.prereq.guest_execution_enabled=", prereqs.guest_execution_enabled);
}

fn printBlockers() void {
    const gate = object();
    printBool("hv: guest_exec.blocker.vm_missing=", gate.blocker_vm_missing);
    printBool("hv: guest_exec.blocker.vcpu_missing=", gate.blocker_vcpu_missing);
    printBool("hv: guest_exec.blocker.guest_memory_missing=", gate.blocker_guest_memory_missing);
    printBool("hv: guest_exec.blocker.address_space_missing=", gate.blocker_address_space_missing);
    printBool("hv: guest_exec.blocker.guest_image_missing=", gate.blocker_guest_image_missing);
    printBool("hv: guest_exec.blocker.guest_entry_missing=", gate.blocker_guest_entry_missing);
    printBool("hv: guest_exec.blocker.guest_exit_missing=", gate.blocker_guest_exit_missing);
    printBool("hv: guest_exec.blocker.run_attempt_not_armed=", gate.blocker_run_attempt_not_armed);
    printBool("hv: guest_exec.blocker.second_stage_translation_missing=", gate.blocker_second_stage_translation_missing);
    printBool("hv: guest_exec.blocker.h_extension_unknown=", gate.blocker_h_extension_unknown);
    printBool("hv: guest_exec.blocker.guest_execution_disabled=", gate.blocker_guest_execution_disabled);
}

fn printFrame() void {
    const frame = object().frame;
    uart.write("hv: guest_exec.frame.pc=");
    uart.writeHex(frame.pc);
    uart.write("\r\n");
    uart.write("hv: guest_exec.frame.sp=");
    uart.writeHex(frame.sp);
    uart.write("\r\n");
    uart.write("hv: guest_exec.frame.guest_base=");
    uart.writeHex(frame.guest_base);
    uart.write("\r\n");
    uart.write("hv: guest_exec.frame.guest_size_bytes=");
    uart.writeDec(frame.guest_size_bytes);
    uart.write("\r\n");
    uart.write("hv: guest_exec.frame.translated_page_count=");
    uart.writeDec(frame.translated_page_count);
    uart.write("\r\n");
    uart.write("hv: guest_exec.frame.loaded_byte_count=");
    uart.writeDec(frame.loaded_byte_count);
    uart.write("\r\n");
    uart.write("hv: guest_exec.frame.entry_owner_vm_id=");
    uart.writeDec(frame.entry_owner_vm_id);
    uart.write("\r\n");
    uart.write("hv: guest_exec.frame.entry_owner_vcpu_id=");
    uart.writeDec(frame.entry_owner_vcpu_id);
    uart.write("\r\n");
    uart.write("hv: guest_exec.frame.exit_kind_tag=");
    uart.writeDec(frame.exit_kind_tag);
    uart.write("\r\n");
    uart.write("hv: guest_exec.frame.run_count_snapshot=");
    uart.writeDec(frame.run_count_snapshot);
    uart.write("\r\n");
}

fn printStats() void {
    const stats = object().stats;
    uart.write("hv: guest_exec.stats.status_count=");
    uart.writeDec(stats.status_count);
    uart.write("\r\n");
    uart.write("hv: guest_exec.stats.validate_count=");
    uart.writeDec(stats.validate_count);
    uart.write("\r\n");
    uart.write("hv: guest_exec.stats.arm_count=");
    uart.writeDec(stats.arm_count);
    uart.write("\r\n");
    uart.write("hv: guest_exec.stats.blocker_count=");
    uart.writeDec(stats.blocker_count);
    uart.write("\r\n");
    uart.write("hv: guest_exec.stats.reset_count=");
    uart.writeDec(stats.reset_count);
    uart.write("\r\n");
    uart.write("hv: guest_exec.stats.transition_count=");
    uart.writeDec(stats.transition_count);
    uart.write("\r\n");
    uart.write("hv: guest_exec.stats.rejected_count=");
    uart.writeDec(stats.rejected_count);
    uart.write("\r\n");
    uart.write("hv: guest_exec.stats.hardware_block_count=");
    uart.writeDec(stats.hardware_block_count);
    uart.write("\r\n");
    uart.write("hv: guest_exec.stats.readiness_score=");
    uart.writeDec(stats.readiness_score);
    uart.write("\r\n");
    uart.write("hv: guest_exec.stats.last_error=");
    uart.write(errorName(stats.last_error));
    uart.write("\r\n");
}

fn printNonClaims() void {
    uart.write("hv: guest_exec.non_claim.guest_instruction_execution=false\r\n");
    uart.write("hv: guest_exec.non_claim.linux_guest=false\r\n");
    uart.write("hv: guest_exec.non_claim.h_extension_proven=false\r\n");
    uart.write("hv: guest_exec.non_claim.second_stage_translation=false\r\n");
}

fn printBool(prefix: []const u8, value: bool) void {
    uart.write(prefix);
    uart.write(if (value) "true" else "false");
    uart.write("\r\n");
}

fn stateName(state: ExecutionState) []const u8 {
    return switch (state) {
        .cold => "cold",
        .collecting => "collecting",
        .validated => "validated",
        .blocked => "blocked",
        .armed_blocked => "armed-blocked",
    };
}

fn decisionName(decision: GateDecision) []const u8 {
    return switch (decision) {
        .not_evaluated => "not-evaluated",
        .validated_ready_for_hardware_gate => "validated-ready-for-hardware-gate",
        .blocked_missing_prerequisite => "blocked-missing-prerequisite",
        .blocked_by_hardware_gate => "blocked-by-hardware-gate",
        .armed_but_execution_blocked => "armed-but-execution-blocked",
    };
}

fn blockerName(blocker: ExecutionBlocker) []const u8 {
    return switch (blocker) {
        .none => "none",
        .vm_missing => "vm-missing",
        .vcpu_missing => "vcpu-missing",
        .guest_memory_missing => "guest-memory-missing",
        .address_space_missing => "address-space-missing",
        .guest_image_missing => "guest-image-missing",
        .guest_entry_missing => "guest-entry-missing",
        .guest_exit_missing => "guest-exit-missing",
        .run_attempt_not_armed => "run-attempt-not-armed",
        .second_stage_translation_missing => "second-stage-translation-missing",
        .h_extension_unknown => "h-extension-unknown",
        .guest_execution_disabled => "guest-execution-disabled",
    };
}

fn commandResultName(result: ExecutionCommandResult) []const u8 {
    return switch (result) {
        .ok => "ok",
        .rejected => "rejected",
        .blocked => "blocked",
        .armed_blocked => "armed-blocked",
    };
}

fn errorName(err: ExecutionError) []const u8 {
    return switch (err) {
        .none => "none",
        .missing_prerequisite => "missing-prerequisite",
        .hardware_gate_blocked => "hardware-gate-blocked",
    };
}

```

### Things To Notice

1. Execution permission is explicit.

2. Execution permission is observable.

3. Denials are recorded.

4. Approvals are recorded.

5. Policy exists separately from readiness.

6. Ownership information is preserved.

7. Validation remains visible.

8. Hypervisor authority remains absolute.

9. The gate does not execute instructions.

10. The gate controls access to execution.

---

```text
Section: 10C
Module: Guest Execution Gates
Type: Exercise
Source: guest_execution.zig
```

## Build It Yourself

In HV09, you built a readiness check.

Now build an execution gate.

The goal is not to run guest code.

The goal is to separate:

```text
Ready
```

from

```text
Permitted
```

### Concepts Required

* Structures
* Policy
* Validation
* Ownership
* Decision Gates

### C Skeleton

```c
#include <stdio.h>

typedef enum
{
    EXECUTION_DENIED,
    EXECUTION_ALLOWED
}
ExecutionDecision;

typedef struct
{
    int guest_ready;

    int policy_enabled;

    unsigned long request_count;

    unsigned long approval_count;

    unsigned long denial_count;
}
ExecutionGate;

static ExecutionGate execution_gate;

void execution_gate_init(void)
{
    /*
        TODO
    */
}

ExecutionDecision execution_gate_check(void)
{
    /*
        TODO

        Verify readiness.

        Verify policy.

        Record result.

        Return approval or denial.
    */

    return EXECUTION_DENIED;
}

void execution_gate_print(void)
{
    /*
        TODO
    */
}

int main(void)
{
    execution_gate_init();

    /*
        TODO

        Attempt execution.

        Enable readiness.

        Enable policy.

        Attempt execution again.

        Print final state.
    */

    return 0;
}
```

### Questions

1.

Why is readiness different from permission?

2.

Can a guest be ready but still denied?

Why?

3.

Why should execution decisions be recorded?

4.

Why should denials be observable?

5.

Why should policy exist separately from execution?

6.

Why should the hypervisor remain the final authority?

### Challenge Question

Suppose:

```text
Guest Ready      = Yes
Policy Enabled   = No
```

Should execution proceed?

Why?

Now suppose:

```text
Guest Ready      = No
Policy Enabled   = Yes
```

Should execution proceed?

Why?

### Completion Check

Before moving to HV11, make sure you can explain:

* what an execution gate is
* why permission exists
* why denials are useful
* why readiness and permission are separate
* why the hypervisor remains in control

---

```text
Section: 10D
Module: Guest Execution Gates
Type: Instructor Notes
Source: guest_execution.zig
```

## Instructor Notes

### Audience

Students should have completed:

* HV01 VM Object
* HV02 Capability Detection
* HV03 vCPU Lifecycle
* HV04 Guest Memory
* HV05 Guest Images
* HV06 Guest Entry
* HV07 Guest Address Spaces
* HV08 Guest Exit Metadata
* HV09 Controlled Guest Run Attempts

### Learning Objective

Students should understand that readiness does not automatically imply permission.

This is one of the most important ideas in systems software.

Being able to perform an action and being allowed to perform an action are separate concepts.

HV10 introduces that distinction.

### Key Concepts

* Permission
* Policy
* Validation
* Approval
* Denial
* Hypervisor Authority

### Common Misconceptions

Misconception:

```text
Ready means run.
```

Correction:

Ready means the prerequisites exist.

Permission is still required.

---

Misconception:

```text
Policy is unnecessary.
```

Correction:

Policy provides control.

Control provides safety.

---

Misconception:

```text
Execution gates perform execution.
```

Correction:

Execution gates control execution.

They do not perform execution.

### Discussion Questions

Ask students:

```text
Should every valid request be approved?
```

Why?

---

Ask students:

```text
Who should make the final decision:
the guest or the hypervisor?
```

Why?

### Expected Outcomes

Students should be able to explain:

* what an execution gate is
* why permission exists
* why denials are recorded
* why policy matters
* why hypervisors retain authority

### Connection To Future Modules

HV01 through HV10 have built the software model of a hypervisor.

The next stage begins addressing translation structures.

The chain now becomes:

```text
VM
↓
vCPU
↓
Memory
↓
Image
↓
Entry
↓
Address Space
↓
Exit Metadata
↓
Run Attempt
↓
Execution Gate
↓
Translation
```

### Key Idea

A hypervisor is not defined by its ability to start execution.

A hypervisor is defined by its ability to control execution.
