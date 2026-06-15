# HV09

## Controlled Guest Run Attempts

```text
Section: 9A
Module: Controlled Guest Run Attempts
Type: Concept
Source: guest_run_attempt.zig
```

### In Plain English

By now, Hyper-Zig has assembled many of the pieces needed for a guest.

The hypervisor has:

* a VM
* a vCPU
* guest memory
* a guest image
* an entry point
* an address space
* guest exit tracking

A beginner might now ask:

```text
Why not just run it?
```

Because hypervisors do not trust assumptions.

Before execution begins, the hypervisor must verify that all required pieces are present.

Think of an aircraft.

Before takeoff, the pilot does not simply push the throttle forward.

A checklist exists.

Fuel.

Controls.

Navigation.

Communication.

Engine status.

Only after verification does takeoff occur.

HV09 introduces the same idea.

A controlled guest run attempt is not guest execution.

It is a decision process.

The hypervisor asks:

* Is the VM valid?
* Does memory exist?
* Does an image exist?
* Does an entry point exist?
* Is the vCPU ready?

If the answer is no, execution is denied.

If the answer is yes, the request may proceed to the next stage.

The important lesson is that execution is a privilege.

Not a default.

Hypervisors earn safety by refusing unsafe operations.

### Key Idea

HV08 answered:

```text
Why did execution stop?
```

HV09 answers:

```text
Should execution begin at all?
```

Those are different decisions.

---

```text
Section: 9B
Module: Controlled Guest Run Attempts
Type: Implementation
Source: guest_run_attempt.zig
```

## The Real Hyper-Zig Module

File:

```text
kernel/hypervisor/guest_run_attempt.zig
```

```zig
const uart = @import("../console/uart.zig");
const vm_model = @import("vm.zig");
const vcpu_model = @import("vcpu.zig");
const guest_memory = @import("guest_memory.zig");
const guest_address_space = @import("guest_address_space.zig");
const guest_image = @import("guest_image.zig");
const guest_entry = @import("guest_entry.zig");
const guest_exit = @import("guest_exit.zig");

pub const GuestRunAttemptState = enum {
    idle,
    checked,
    blocked,
    armed_no_execute,
};

pub const GuestRunAttemptDecision = enum {
    not_checked,
    blocked_missing_entry,
    blocked_missing_exit_model,
    blocked_missing_second_stage_translation,
    blocked_h_extension_unknown,
    blocked_guest_execution_disabled,
    armed_no_execute,
};

pub const GuestRunAttemptBlocker = enum {
    none,
    guest_entry_not_prepared,
    guest_exit_model_missing,
    second_stage_translation_missing,
    h_extension_unknown,
    guest_execution_disabled,
};

pub const GuestRunAttemptError = enum {
    none,
    missing_vm,
    missing_vcpu,
    missing_guest_memory,
    missing_address_space,
    missing_guest_image,
    missing_guest_entry,
    missing_guest_exit_model,
    blocked_by_safety_gate,
};

pub const GuestRunAttemptCommandResult = enum {
    ok,
    blocked,
    rejected,
    armed_no_execute,
};

pub const GuestRunAttemptPrereqs = struct {
    vm_present: bool,
    vcpu_present: bool,
    guest_memory_configured: bool,
    address_space_configured: bool,
    guest_image_loaded: bool,
    guest_entry_prepared: bool,
    guest_exit_model_ready: bool,
    second_stage_translation_present: bool,
    h_extension_present: bool,
    guest_execution_enabled: bool,
};

pub const GuestRunAttemptFrame = struct {
    pc: usize,
    sp: usize,
    entry_owner_vm_id: vm_model.VmId,
    entry_owner_vcpu_id: vcpu_model.VcpuId,
    last_exit_kind_tag: usize,
    vcpu_run_count_before: u64,
    vcpu_run_count_after: u64,
};

pub const GuestRunAttemptStats = struct {
    check_count: usize,
    arm_count: usize,
    blocked_count: usize,
    reset_count: usize,
    failed_check_count: usize,
    last_error: GuestRunAttemptError,
};

pub const GuestRunAttemptResult = struct {
    result: GuestRunAttemptCommandResult,
    state: GuestRunAttemptState,
    decision: GuestRunAttemptDecision,
    primary_blocker: GuestRunAttemptBlocker,
    prereqs: GuestRunAttemptPrereqs,
    frame: GuestRunAttemptFrame,
    attempt_error: GuestRunAttemptError,
};

pub const GuestRunAttemptResetResult = struct {
    result: GuestRunAttemptCommandResult,
    state: GuestRunAttemptState,
    reset_count: usize,
    attempt_error: GuestRunAttemptError,
};

pub const GuestRunAttempt = struct {
    owner_vm_id: vm_model.VmId,
    owner_vcpu_id: vcpu_model.VcpuId,
    state: GuestRunAttemptState,
    decision: GuestRunAttemptDecision,
    primary_blocker: GuestRunAttemptBlocker,
    blocker_guest_entry_not_prepared: bool,
    blocker_guest_exit_model_missing: bool,
    blocker_second_stage_translation_missing: bool,
    blocker_h_extension_unknown: bool,
    blocker_guest_execution_disabled: bool,
    prereqs: GuestRunAttemptPrereqs,
    frame: GuestRunAttemptFrame,
    stats: GuestRunAttemptStats,
};

var boot_guest_run_attempt: GuestRunAttempt = undefined;
var initialized: bool = false;

pub fn init(owner_vm_id: vm_model.VmId, owner_vcpu_id: vcpu_model.VcpuId) void {
    boot_guest_run_attempt = emptyObject(owner_vm_id, owner_vcpu_id, emptyStats());
    initialized = true;
}

pub fn object() *const GuestRunAttempt {
    return mutableObject();
}

fn mutableObject() *GuestRunAttempt {
    if (!initialized) init(vm_model.object().id, vcpu_model.object().id);
    return &boot_guest_run_attempt;
}

fn emptyPrereqs() GuestRunAttemptPrereqs {
    return .{
        .vm_present = false,
        .vcpu_present = false,
        .guest_memory_configured = false,
        .address_space_configured = false,
        .guest_image_loaded = false,
        .guest_entry_prepared = false,
        .guest_exit_model_ready = false,
        .second_stage_translation_present = false,
        .h_extension_present = false,
        .guest_execution_enabled = false,
    };
}

fn emptyFrame(owner_vm_id: vm_model.VmId, owner_vcpu_id: vcpu_model.VcpuId) GuestRunAttemptFrame {
    return .{
        .pc = 0,
        .sp = 0,
        .entry_owner_vm_id = owner_vm_id,
        .entry_owner_vcpu_id = owner_vcpu_id,
        .last_exit_kind_tag = 0,
        .vcpu_run_count_before = 0,
        .vcpu_run_count_after = 0,
    };
}

fn emptyStats() GuestRunAttemptStats {
    return .{
        .check_count = 0,
        .arm_count = 0,
        .blocked_count = 0,
        .reset_count = 0,
        .failed_check_count = 0,
        .last_error = .none,
    };
}

fn emptyObject(owner_vm_id: vm_model.VmId, owner_vcpu_id: vcpu_model.VcpuId, stats: GuestRunAttemptStats) GuestRunAttempt {
    return .{
        .owner_vm_id = owner_vm_id,
        .owner_vcpu_id = owner_vcpu_id,
        .state = .idle,
        .decision = .not_checked,
        .primary_blocker = .none,
        .blocker_guest_entry_not_prepared = false,
        .blocker_guest_exit_model_missing = false,
        .blocker_second_stage_translation_missing = false,
        .blocker_h_extension_unknown = false,
        .blocker_guest_execution_disabled = false,
        .prereqs = emptyPrereqs(),
        .frame = emptyFrame(owner_vm_id, owner_vcpu_id),
        .stats = stats,
    };
}

pub fn check() GuestRunAttemptResult {
    const attempt = mutableObject();
    attempt.stats.check_count += 1;
    evaluate(attempt, false);
    if (attempt.primary_blocker == .none) {
        attempt.state = .checked;
        attempt.decision = .not_checked;
        attempt.stats.last_error = .none;
        return makeResult(.ok, attempt);
    }
    attempt.state = .blocked;
    attempt.stats.blocked_count += 1;
    attempt.stats.failed_check_count += 1;
    attempt.stats.last_error = errorFromBlocker(attempt.primary_blocker);
    return makeResult(.blocked, attempt);
}

pub fn armNoExecute() GuestRunAttemptResult {
    const attempt = mutableObject();
    attempt.stats.arm_count += 1;
    evaluate(attempt, true);
    if (attempt.blocker_guest_entry_not_prepared or attempt.blocker_guest_exit_model_missing) {
        attempt.state = .blocked;
        attempt.stats.blocked_count += 1;
        attempt.stats.failed_check_count += 1;
        attempt.stats.last_error = errorFromBlocker(attempt.primary_blocker);
        return makeResult(.blocked, attempt);
    }
    if (attempt.blocker_second_stage_translation_missing or attempt.blocker_h_extension_unknown or attempt.blocker_guest_execution_disabled) {
        attempt.state = .armed_no_execute;
        attempt.decision = .armed_no_execute;
        attempt.stats.blocked_count += 1;
        attempt.stats.last_error = .blocked_by_safety_gate;
        return makeResult(.armed_no_execute, attempt);
    }
    attempt.state = .checked;
    attempt.decision = .not_checked;
    attempt.stats.last_error = .none;
    return makeResult(.ok, attempt);
}

pub fn reset() GuestRunAttemptResetResult {
    const attempt = mutableObject();
    const owner_vm_id = attempt.owner_vm_id;
    const owner_vcpu_id = attempt.owner_vcpu_id;
    var stats = attempt.stats;
    stats.reset_count += 1;
    stats.last_error = .none;
    boot_guest_run_attempt = emptyObject(owner_vm_id, owner_vcpu_id, stats);
    initialized = true;
    return .{
        .result = .ok,
        .state = .idle,
        .reset_count = stats.reset_count,
        .attempt_error = .none,
    };
}

pub fn requireEntryTest() GuestRunAttemptCommandResult {
    _ = guest_entry.reset();
    _ = reset();
    const result = check();
    return if (result.result == .blocked and result.primary_blocker == .guest_entry_not_prepared) .rejected else .ok;
}

pub fn requireExitTest() GuestRunAttemptCommandResult {
    _ = guest_exit.reset();
    _ = reset();
    const result = armNoExecute();
    return if (result.result == .blocked and result.primary_blocker == .guest_exit_model_missing) .rejected else .ok;
}

fn evaluate(attempt: *GuestRunAttempt, for_arm: bool) void {
    const vm_obj = vm_model.object();
    const vcpu_obj = vcpu_model.object();
    const gm = guest_memory.object();
    const as = guest_address_space.object();
    const image = guest_image.object();
    const entry = guest_entry.object();
    const exit = guest_exit.object();

    attempt.owner_vm_id = vm_obj.id;
    attempt.owner_vcpu_id = vcpu_obj.id;
    attempt.prereqs = .{
        .vm_present = vm_obj.state == .defined,
        .vcpu_present = vcpu_obj.vm_id == vm_obj.id,
        .guest_memory_configured = gm.state == .configured and gm.owner_vm_id == vm_obj.id and gm.size_bytes > 0,
        .address_space_configured = as.state == .configured and as.owner_vm_id == vm_obj.id and as.translated_page_count > 0,
        .guest_image_loaded = image.state == .loaded and image.owner_vm_id == vm_obj.id and image.loaded_byte_count > 0,
        .guest_entry_prepared = entry.state == .prepared and entry.frame_valid and entry.owner_vm_id == vm_obj.id and entry.owner_vcpu_id == vcpu_obj.id,
        .guest_exit_model_ready = exit.state == .recorded and exit.owner_vm_id == vm_obj.id and exit.owner_vcpu_id == vcpu_obj.id,
        .second_stage_translation_present = false,
        .h_extension_present = false,
        .guest_execution_enabled = false,
    };
    attempt.frame = .{
        .pc = if (attempt.prereqs.guest_entry_prepared) entry.frame.pc else 0,
        .sp = if (attempt.prereqs.guest_entry_prepared) entry.frame.sp else 0,
        .entry_owner_vm_id = if (attempt.prereqs.guest_entry_prepared) entry.frame.owner_vm_id else vm_obj.id,
        .entry_owner_vcpu_id = if (attempt.prereqs.guest_entry_prepared) entry.frame.owner_vcpu_id else vcpu_obj.id,
        .last_exit_kind_tag = if (attempt.prereqs.guest_exit_model_ready) @intFromEnum(exit.last_kind) else 0,
        .vcpu_run_count_before = vcpu_obj.run_count,
        .vcpu_run_count_after = vcpu_obj.run_count,
    };

    attempt.blocker_guest_entry_not_prepared = !attempt.prereqs.guest_entry_prepared;
    attempt.blocker_guest_exit_model_missing = !attempt.prereqs.guest_exit_model_ready;
    attempt.blocker_second_stage_translation_missing = !attempt.prereqs.second_stage_translation_present;
    attempt.blocker_h_extension_unknown = !attempt.prereqs.h_extension_present;
    attempt.blocker_guest_execution_disabled = !attempt.prereqs.guest_execution_enabled;

    const decision = chooseDecision(attempt, for_arm);
    attempt.decision = decision;
    attempt.primary_blocker = if (decision == .armed_no_execute) firstExecutionBlocker(attempt) else blockerFromDecision(decision);
}

fn chooseDecision(attempt: *const GuestRunAttempt, for_arm: bool) GuestRunAttemptDecision {
    if (attempt.blocker_guest_entry_not_prepared) return .blocked_missing_entry;
    if (attempt.blocker_guest_exit_model_missing) return .blocked_missing_exit_model;
    if (for_arm and (attempt.blocker_second_stage_translation_missing or attempt.blocker_h_extension_unknown or attempt.blocker_guest_execution_disabled)) return .armed_no_execute;
    if (attempt.blocker_second_stage_translation_missing) return .blocked_missing_second_stage_translation;
    if (attempt.blocker_h_extension_unknown) return .blocked_h_extension_unknown;
    if (attempt.blocker_guest_execution_disabled) return .blocked_guest_execution_disabled;
    return .not_checked;
}

fn firstExecutionBlocker(attempt: *const GuestRunAttempt) GuestRunAttemptBlocker {
    if (attempt.blocker_second_stage_translation_missing) return .second_stage_translation_missing;
    if (attempt.blocker_h_extension_unknown) return .h_extension_unknown;
    if (attempt.blocker_guest_execution_disabled) return .guest_execution_disabled;
    return .none;
}

fn blockerFromDecision(decision: GuestRunAttemptDecision) GuestRunAttemptBlocker {
    return switch (decision) {
        .not_checked, .armed_no_execute => .none,
        .blocked_missing_entry => .guest_entry_not_prepared,
        .blocked_missing_exit_model => .guest_exit_model_missing,
        .blocked_missing_second_stage_translation => .second_stage_translation_missing,
        .blocked_h_extension_unknown => .h_extension_unknown,
        .blocked_guest_execution_disabled => .guest_execution_disabled,
    };
}

fn errorFromBlocker(blocker: GuestRunAttemptBlocker) GuestRunAttemptError {
    return switch (blocker) {
        .none => .none,
        .guest_entry_not_prepared => .missing_guest_entry,
        .guest_exit_model_missing => .missing_guest_exit_model,
        .second_stage_translation_missing, .h_extension_unknown, .guest_execution_disabled => .blocked_by_safety_gate,
    };
}

fn makeResult(result: GuestRunAttemptCommandResult, attempt: *const GuestRunAttempt) GuestRunAttemptResult {
    return .{
        .result = result,
        .state = attempt.state,
        .decision = attempt.decision,
        .primary_blocker = attempt.primary_blocker,
        .prereqs = attempt.prereqs,
        .frame = attempt.frame,
        .attempt_error = attempt.stats.last_error,
    };
}

pub fn printState() void {
    printImplementedMarker();
    printFields();
    printPrereqs();
    printBlockers();
    printFrame();
    printStats();
    printNonClaims();
}

pub fn printCheckCommand() void {
    const result = check();
    uart.write("hv: guest_run.check_result=");
    uart.write(commandResultName(result.result));
    uart.write("\r\n");
    printState();
}

pub fn printArmNoExecuteCommand() void {
    const result = armNoExecute();
    uart.write("hv: guest_run.arm_result=");
    uart.write(commandResultName(result.result));
    uart.write("\r\n");
    printState();
}

pub fn printResetCommand() void {
    const result = reset();
    uart.write("hv: guest_run.reset_result=");
    uart.write(commandResultName(result.result));
    uart.write("\r\n");
    uart.write("hv: guest_run.reset_result.attempt_error=");
    uart.write(errorName(result.attempt_error));
    uart.write("\r\n");
    printState();
}

pub fn printRequireEntryTestCommand() void {
    const result = requireEntryTest();
    uart.write("hv: guest_run.require_entry_test=");
    uart.write(if (result == .rejected) "rejected" else "failed-to-reject");
    uart.write("\r\n");
    printState();
}

pub fn printRequireExitTestCommand() void {
    const result = requireExitTest();
    uart.write("hv: guest_run.require_exit_test=");
    uart.write(if (result == .rejected) "rejected" else "failed-to-reject");
    uart.write("\r\n");
    printState();
}

pub fn printImplementedMarker() void {
    uart.write("hv: guest_run=implemented\r\n");
}

fn printFields() void {
    const attempt = object();
    uart.write("hv: guest_run.owner_vm_id=");
    uart.writeDec(attempt.owner_vm_id);
    uart.write("\r\n");
    uart.write("hv: guest_run.owner_vcpu_id=");
    uart.writeDec(attempt.owner_vcpu_id);
    uart.write("\r\n");
    uart.write("hv: guest_run.state=");
    uart.write(stateName(attempt.state));
    uart.write("\r\n");
    uart.write("hv: guest_run.decision=");
    uart.write(decisionName(attempt.decision));
    uart.write("\r\n");
    uart.write("hv: guest_run.blocker=");
    uart.write(blockerName(attempt.primary_blocker));
    uart.write("\r\n");
}

fn printPrereqs() void {
    const prereqs = object().prereqs;
    printBool("hv: guest_run.prereq.vm_present=", prereqs.vm_present);
    printBool("hv: guest_run.prereq.vcpu_present=", prereqs.vcpu_present);
    printBool("hv: guest_run.prereq.guest_memory_configured=", prereqs.guest_memory_configured);
    printBool("hv: guest_run.prereq.address_space_configured=", prereqs.address_space_configured);
    printBool("hv: guest_run.prereq.guest_image_loaded=", prereqs.guest_image_loaded);
    printBool("hv: guest_run.prereq.guest_entry_prepared=", prereqs.guest_entry_prepared);
    printBool("hv: guest_run.prereq.guest_exit_model_ready=", prereqs.guest_exit_model_ready);
    printBool("hv: guest_run.prereq.second_stage_translation_present=", prereqs.second_stage_translation_present);
    printBool("hv: guest_run.prereq.h_extension_present=", prereqs.h_extension_present);
    printBool("hv: guest_run.prereq.guest_execution_enabled=", prereqs.guest_execution_enabled);
}

fn printBlockers() void {
    const attempt = object();
    printBool("hv: guest_run.blocker.guest_entry_not_prepared=", attempt.blocker_guest_entry_not_prepared);
    printBool("hv: guest_run.blocker.guest_exit_model_missing=", attempt.blocker_guest_exit_model_missing);
    printBool("hv: guest_run.blocker.second_stage_translation_missing=", attempt.blocker_second_stage_translation_missing);
    printBool("hv: guest_run.blocker.h_extension_unknown=", attempt.blocker_h_extension_unknown);
    printBool("hv: guest_run.blocker.guest_execution_disabled=", attempt.blocker_guest_execution_disabled);
}

fn printFrame() void {
    const frame = object().frame;
    uart.write("hv: guest_run.frame.pc=");
    uart.writeHex(frame.pc);
    uart.write("\r\n");
    uart.write("hv: guest_run.frame.sp=");
    uart.writeHex(frame.sp);
    uart.write("\r\n");
    uart.write("hv: guest_run.frame.entry_owner_vm_id=");
    uart.writeDec(frame.entry_owner_vm_id);
    uart.write("\r\n");
    uart.write("hv: guest_run.frame.entry_owner_vcpu_id=");
    uart.writeDec(frame.entry_owner_vcpu_id);
    uart.write("\r\n");
    uart.write("hv: guest_run.frame.last_exit_kind_tag=");
    uart.writeDec(frame.last_exit_kind_tag);
    uart.write("\r\n");
    uart.write("hv: guest_run.frame.vcpu_run_count_before=");
    uart.writeDec(frame.vcpu_run_count_before);
    uart.write("\r\n");
    uart.write("hv: guest_run.frame.vcpu_run_count_after=");
    uart.writeDec(frame.vcpu_run_count_after);
    uart.write("\r\n");
}

fn printStats() void {
    const stats = object().stats;
    uart.write("hv: guest_run.check_count=");
    uart.writeDec(stats.check_count);
    uart.write("\r\n");
    uart.write("hv: guest_run.arm_count=");
    uart.writeDec(stats.arm_count);
    uart.write("\r\n");
    uart.write("hv: guest_run.blocked_count=");
    uart.writeDec(stats.blocked_count);
    uart.write("\r\n");
    uart.write("hv: guest_run.reset_count=");
    uart.writeDec(stats.reset_count);
    uart.write("\r\n");
    uart.write("hv: guest_run.failed_check_count=");
    uart.writeDec(stats.failed_check_count);
    uart.write("\r\n");
    uart.write("hv: guest_run.last_error=");
    uart.write(errorName(stats.last_error));
    uart.write("\r\n");
}

fn printBool(prefix: []const u8, value: bool) void {
    uart.write(prefix);
    uart.write(if (value) "true" else "false");
    uart.write("\r\n");
}

fn stateName(state: GuestRunAttemptState) []const u8 {
    return switch (state) {
        .idle => "idle",
        .checked => "checked",
        .blocked => "blocked",
        .armed_no_execute => "armed-no-execute",
    };
}

fn decisionName(decision: GuestRunAttemptDecision) []const u8 {
    return switch (decision) {
        .not_checked => "not-checked",
        .blocked_missing_entry => "blocked-missing-entry",
        .blocked_missing_exit_model => "blocked-missing-exit-model",
        .blocked_missing_second_stage_translation => "blocked-missing-second-stage-translation",
        .blocked_h_extension_unknown => "blocked-h-extension-unknown",
        .blocked_guest_execution_disabled => "blocked-guest-execution-disabled",
        .armed_no_execute => "armed-no-execute",
    };
}

fn blockerName(blocker: GuestRunAttemptBlocker) []const u8 {
    return switch (blocker) {
        .none => "none",
        .guest_entry_not_prepared => "guest-entry-not-prepared",
        .guest_exit_model_missing => "guest-exit-model-missing",
        .second_stage_translation_missing => "second-stage-translation-missing",
        .h_extension_unknown => "h-extension-unknown",
        .guest_execution_disabled => "guest-execution-disabled",
    };
}

fn commandResultName(result: GuestRunAttemptCommandResult) []const u8 {
    return switch (result) {
        .ok => "ok",
        .blocked => "blocked",
        .rejected => "rejected",
        .armed_no_execute => "armed-no-execute",
    };
}

fn errorName(err: GuestRunAttemptError) []const u8 {
    return switch (err) {
        .none => "none",
        .missing_vm => "missing-vm",
        .missing_vcpu => "missing-vcpu",
        .missing_guest_memory => "missing-guest-memory",
        .missing_address_space => "missing-address-space",
        .missing_guest_image => "missing-guest-image",
        .missing_guest_entry => "missing-guest-entry",
        .missing_guest_exit_model => "missing-guest-exit-model",
        .blocked_by_safety_gate => "blocked-by-safety-gate",
    };
}

fn printNonClaims() void {
    uart.write("hv: guest_execution=not-supported-yet\r\n");
    uart.write("hv: linux_guest=not-supported-yet\r\n");
    uart.write("hv: second_stage_translation=MISSING\r\n");
    uart.write("hv: h_extension=unknown reason=no-safe-detection-yet\r\n");
}
```

### Things To Notice

1. Run attempts are evaluated.

2. Execution is not automatic.

3. Readiness checks exist.

4. Failure reasons exist.

5. Ownership is tracked.

6. State validation exists.

7. Successful attempts are recorded.

8. Rejected attempts are recorded.

9. Evidence is preserved.

10. Hypervisor control remains absolute.

---

```text
Section: 9C
Module: Controlled Guest Run Attempts
Type: Exercise
Source: guest_run_attempt.zig
```

## Build It Yourself

In HV08, you recorded reasons why execution stopped.

Now create a system that decides whether execution should begin.

The goal is not to execute guest code.

The goal is to build a readiness gate.

### Concepts Required

* Structures
* Validation
* State Checks
* Ownership
* Decision Making

### C Skeleton

```c
#include <stdio.h>

typedef enum
{
    RUN_ATTEMPT_ALLOWED,
    RUN_ATTEMPT_REJECTED
}
RunAttemptResult;

typedef struct
{
    int vm_ready;

    int memory_ready;

    int image_ready;

    int entry_ready;

    int vcpu_ready;

    unsigned long attempt_count;

    unsigned long success_count;

    unsigned long reject_count;
}
GuestRunAttempt;

static GuestRunAttempt run_attempt;

void run_attempt_init(void)
{
    /*
        TODO
    */
}

RunAttemptResult evaluate_run_attempt(void)
{
    /*
        TODO

        Verify:

        - VM exists
        - Memory exists
        - Image exists
        - Entry exists
        - vCPU is ready

        Return success or rejection.
    */

    return RUN_ATTEMPT_REJECTED;
}

void run_attempt_print(void)
{
    /*
        TODO
    */
}

int main(void)
{
    run_attempt_init();

    /*
        TODO

        Attempt execution.

        Enable missing requirements.

        Attempt execution again.

        Print results.
    */

    return 0;
}
```

### Questions

1.

Why should a hypervisor verify readiness before execution?

2.

Why is execution treated as a privileged operation?

3.

What could happen if a guest runs without memory?

4.

What could happen if a guest runs without an entry point?

5.

Why record rejected run attempts?

6.

Why should readiness checks be observable?

### Challenge Question

Suppose:

```text
VM          = Ready
Memory      = Ready
Image       = Ready
AddressSpace= Ready
vCPU        = Ready
Entry       = Missing
```

Should execution begin?

Why?

### Completion Check

Before moving to HV10, make sure you can explain:

* what a controlled run attempt is
* why readiness checks exist
* why execution can be denied
* why rejection reasons matter
* why validation comes before execution

---

```text
Section: 9D
Module: Controlled Guest Run Attempts
Type: Instructor Notes
Source: guest_run_attempt.zig
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

### Learning Objective

Students should understand that a hypervisor does not execute guests blindly.

Execution requires evidence.

Execution requires preparation.

Execution requires validation.

HV09 introduces the concept of a readiness gate.

The guest may request execution.

The hypervisor decides whether execution is permitted.

### Key Concepts

* Readiness
* Validation
* Decision Gates
* Execution Permission
* Observable Evidence

### Common Misconceptions

Misconception:

```text
If all the code compiles,
the guest should run.
```

Correction:

Execution requires far more than compilation.

---

Misconception:

```text
A run request means execution must occur.
```

Correction:

The hypervisor may reject unsafe requests.

---

Misconception:

```text
Validation is wasted work.
```

Correction:

Validation prevents failures that are much harder to diagnose later.

### Discussion Questions

Ask students:

```text
Why do aircraft use preflight checklists?
```

Relate the answer to guest readiness checks.

---

Ask students:

```text
What is more dangerous:

A failed execution?

or

An execution that should never have started?
```

Why?

### Expected Outcomes

Students should be able to explain:

* what a run attempt is
* why execution is gated
* why readiness matters
* why rejections are recorded
* why validation exists

### Connection To Future Modules

HV09 is the final checkpoint before execution concepts become more serious.

The chain now becomes:

```text
VM
↓
Memory
↓
Image
↓
Entry
↓
Address Space
↓
Run Attempt
↓
Execution
```

HV10 will begin focusing on execution preparation itself.

### Key Idea

A trustworthy hypervisor does not merely know how to run a guest.

A trustworthy hypervisor knows when not to.
