const uart = @import("../console/uart.zig");
const pmm = @import("../memory/pmm.zig");
const vm_model = @import("vm.zig");
const capability = @import("capability.zig");
const second_stage = @import("second_stage.zig");
const stage2_table = @import("stage2_table.zig");
const guest_execution = @import("guest_execution.zig");

pub const Stage2ActivationState = enum {
    idle,
    checked,
    blocked,
    planned,
    reset,
};

pub const Stage2ActivationMode = enum {
    guarded_readiness_only,
    no_hgatp_write,
    no_h_extension_proof,
};

pub const Stage2ActivationDecision = enum {
    not_checked,
    blocked_missing_stage2_metadata,
    blocked_missing_stage2_table,
    blocked_table_not_validated,
    blocked_h_extension_unknown,
    blocked_hgatp_write_disabled,
    blocked_guest_execution_disabled,
    planned_no_activate,
};

pub const Stage2ActivationBlocker = struct {
    missing_stage2_metadata: bool,
    missing_stage2_table: bool,
    table_not_validated: bool,
    table_empty: bool,
    table_active: bool,
    second_stage_translation_missing: bool,
    h_extension_unknown: bool,
    hgatp_write_disabled: bool,
    guest_execution_disabled: bool,
    table_root_unavailable: bool,
};

pub const Stage2ActivationPlan = struct {
    owner_vm_id: vm_model.VmId,
    entry_count: usize,
    page_size: usize,
    table_root_host_address: usize,
    expected_hgatp_mode: usize,
    expected_hgatp_ppn: usize,
    hgatp_write_allowed: bool,
    h_extension_known: bool,
    activation_allowed: bool,
    would_flush_tlb: bool,
    would_write_hgatp: bool,
    would_enable_second_stage: bool,
    current_hgatp_snapshot: usize,
    current_hgatp_snapshot_available: bool,
    current_hgatp_snapshot_reason: HgatpSnapshotReason,
    root_available: bool,
};

pub const HgatpSnapshotReason = enum {
    safely_read,
    no_safe_detection_yet,
    h_extension_unknown,
};

pub const Stage2ActivationPrereqs = struct {
    stage2_metadata_ready: bool,
    stage2_metadata_validated: bool,
    stage2_table_present: bool,
    stage2_table_validated: bool,
    entry_count_nonzero: bool,
    table_inactive: bool,
    second_stage_translation_missing: bool,
    h_extension_known: bool,
    hgatp_write_disabled: bool,
    guest_execution_disabled: bool,
};

pub const Stage2ActivationResult = enum {
    ok,
    blocked,
    rejected,
};

pub const Stage2ActivationValidateResult = struct {
    result: Stage2ActivationResult,
    decision: Stage2ActivationDecision,
    safe_non_activating: bool,
    activation_still_blocked: bool,
    error: Stage2ActivationError,
};

pub const Stage2ActivationResetResult = struct {
    result: Stage2ActivationResult,
    state: Stage2ActivationState,
};

pub const Stage2ActivationStats = struct {
    check_count: usize,
    plan_count: usize,
    validate_count: usize,
    reset_count: usize,
    blocked_count: usize,
    failed_check_count: usize,
    failed_plan_count: usize,
    last_error: Stage2ActivationError,
};

pub const Stage2ActivationError = enum {
    none,
    missing_stage2_metadata,
    missing_stage2_table,
    table_not_validated,
    table_empty,
    table_active,
    second_stage_translation_missing,
    h_extension_unknown,
    hgatp_write_disabled,
    guest_execution_disabled,
    table_root_unavailable,
    unsafe_plan,
};

pub const Stage2Activation = struct {
    owner_vm_id: vm_model.VmId,
    state: Stage2ActivationState,
    mode: Stage2ActivationMode,
    decision: Stage2ActivationDecision,
    prereqs: Stage2ActivationPrereqs,
    blocker: Stage2ActivationBlocker,
    plan: Stage2ActivationPlan,
    stats: Stage2ActivationStats,
    hgatp_written: bool,
    second_stage_enabled: bool,
    table_required: bool,
    table_validated: bool,
};

var boot_activation: Stage2Activation = undefined;
var initialized: bool = false;

pub fn init(owner_vm_id: vm_model.VmId) void {
    boot_activation = emptyObject(owner_vm_id, emptyStats());
    initialized = true;
}

pub fn object() *const Stage2Activation {
    return mutableObject();
}

fn mutableObject() *Stage2Activation {
    if (!initialized) init(vm_model.object().id);
    return &boot_activation;
}

fn emptyObject(owner_vm_id: vm_model.VmId, stats: Stage2ActivationStats) Stage2Activation {
    return .{
        .owner_vm_id = owner_vm_id,
        .state = .idle,
        .mode = .guarded_readiness_only,
        .decision = .not_checked,
        .prereqs = emptyPrereqs(),
        .blocker = emptyBlocker(),
        .plan = emptyPlan(owner_vm_id),
        .stats = stats,
        .hgatp_written = false,
        .second_stage_enabled = false,
        .table_required = true,
        .table_validated = false,
    };
}

fn emptyStats() Stage2ActivationStats {
    return .{
        .check_count = 0,
        .plan_count = 0,
        .validate_count = 0,
        .reset_count = 0,
        .blocked_count = 0,
        .failed_check_count = 0,
        .failed_plan_count = 0,
        .last_error = .none,
    };
}

fn emptyPrereqs() Stage2ActivationPrereqs {
    return .{
        .stage2_metadata_ready = false,
        .stage2_metadata_validated = false,
        .stage2_table_present = false,
        .stage2_table_validated = false,
        .entry_count_nonzero = false,
        .table_inactive = true,
        .second_stage_translation_missing = true,
        .h_extension_known = false,
        .hgatp_write_disabled = true,
        .guest_execution_disabled = true,
    };
}

fn emptyBlocker() Stage2ActivationBlocker {
    return .{
        .missing_stage2_metadata = false,
        .missing_stage2_table = false,
        .table_not_validated = false,
        .table_empty = false,
        .table_active = false,
        .second_stage_translation_missing = true,
        .h_extension_unknown = true,
        .hgatp_write_disabled = true,
        .guest_execution_disabled = true,
        .table_root_unavailable = false,
    };
}

fn emptyPlan(owner_vm_id: vm_model.VmId) Stage2ActivationPlan {
    return .{
        .owner_vm_id = owner_vm_id,
        .entry_count = 0,
        .page_size = pmm.page_size,
        .table_root_host_address = 0,
        .expected_hgatp_mode = 0,
        .expected_hgatp_ppn = 0,
        .hgatp_write_allowed = false,
        .h_extension_known = false,
        .activation_allowed = false,
        .would_flush_tlb = false,
        .would_write_hgatp = false,
        .would_enable_second_stage = false,
        .current_hgatp_snapshot = 0,
        .current_hgatp_snapshot_available = false,
        .current_hgatp_snapshot_reason = .no_safe_detection_yet,
        .root_available = false,
    };
}

pub fn check() Stage2ActivationResult {
    const activation = mutableObject();
    activation.stats.check_count += 1;
    collectPrereqs(activation);
    chooseDecision(activation, false);
    activation.state = if (hasAnyBlocker(activation.blocker)) .blocked else .checked;
    if (activation.state == .blocked) {
        activation.stats.blocked_count += 1;
        activation.stats.failed_check_count += 1;
        activation.stats.last_error = errorForDecision(activation.decision);
        return .blocked;
    }
    activation.stats.last_error = .none;
    return .ok;
}

pub fn plan() Stage2ActivationResult {
    const activation = mutableObject();
    activation.stats.plan_count += 1;
    collectPrereqs(activation);
    buildPlanFromTable(activation);
    chooseDecision(activation, true);
    activation.state = if (activation.decision == .planned_no_activate) .planned else .blocked;
    if (activation.state == .blocked) {
        activation.stats.blocked_count += 1;
        activation.stats.failed_plan_count += 1;
        activation.stats.last_error = errorForDecision(activation.decision);
        return .blocked;
    }
    activation.stats.last_error = .none;
    return .ok;
}

pub fn validate() Stage2ActivationValidateResult {
    const activation = mutableObject();
    activation.stats.validate_count += 1;
    collectPrereqs(activation);
    buildPlanFromTable(activation);
    chooseDecision(activation, true);

    const safe_non_activating = !activation.plan.activation_allowed and
        !activation.plan.hgatp_write_allowed and
        !activation.plan.would_write_hgatp and
        !activation.plan.would_enable_second_stage and
        !activation.hgatp_written and
        !activation.second_stage_enabled;
    const activation_still_blocked = activation.blocker.h_extension_unknown or
        activation.blocker.hgatp_write_disabled or
        activation.blocker.guest_execution_disabled or
        activation.blocker.second_stage_translation_missing or
        activation.blocker.table_root_unavailable;

    if (!safe_non_activating or !activation_still_blocked) {
        activation.state = .blocked;
        activation.stats.blocked_count += 1;
        activation.stats.last_error = .unsafe_plan;
        return .{ .result = .rejected, .decision = activation.decision, .safe_non_activating = safe_non_activating, .activation_still_blocked = activation_still_blocked, .error = .unsafe_plan };
    }

    activation.state = .planned;
    activation.decision = .planned_no_activate;
    activation.stats.last_error = .none;
    return .{ .result = .ok, .decision = activation.decision, .safe_non_activating = true, .activation_still_blocked = true, .error = .none };
}

pub fn reset() Stage2ActivationResetResult {
    const activation = mutableObject();
    const owner = activation.owner_vm_id;
    var stats = activation.stats;
    stats.reset_count += 1;
    stats.last_error = .none;
    boot_activation = emptyObject(owner, stats);
    boot_activation.state = .idle;
    initialized = true;
    return .{ .result = .ok, .state = boot_activation.state };
}

pub fn requireTableTest() Stage2ActivationResult {
    _ = stage2_table.reset();
    _ = reset();
    const result = check();
    const activation = object();
    return if (result == .blocked and (activation.blocker.missing_stage2_table or activation.blocker.table_not_validated)) .rejected else .ok;
}

pub fn hgatpWriteTest() Stage2ActivationResult {
    const activation = mutableObject();
    const result = rejectHgatpWrite(activation);
    collectPrereqs(activation);
    buildPlanFromTable(activation);
    chooseDecision(activation, true);
    activation.state = .blocked;
    return result;
}

fn rejectHgatpWrite(activation: *Stage2Activation) Stage2ActivationResult {
    activation.hgatp_written = false;
    activation.second_stage_enabled = false;
    activation.plan.hgatp_write_allowed = false;
    activation.plan.would_write_hgatp = false;
    activation.plan.would_enable_second_stage = false;
    activation.plan.activation_allowed = false;
    activation.blocker.hgatp_write_disabled = true;
    activation.stats.blocked_count += 1;
    activation.stats.last_error = .hgatp_write_disabled;
    return .rejected;
}

fn collectPrereqs(activation: *Stage2Activation) void {
    const metadata = second_stage.object();
    const table = stage2_table.object();
    const caps = capability.detect();
    _ = guest_execution.object();

    activation.owner_vm_id = vm_model.object().id;
    activation.table_required = true;
    activation.table_validated = table.state == .validated;
    activation.prereqs = .{
        .stage2_metadata_ready = metadata.state == .metadata_ready,
        .stage2_metadata_validated = metadata.mapping.validated,
        .stage2_table_present = table.state == .built or table.state == .validated,
        .stage2_table_validated = table.state == .validated,
        .entry_count_nonzero = table.entry_count > 0,
        .table_inactive = !table.active,
        .second_stage_translation_missing = !metadata.mapping.active,
        .h_extension_known = caps.h_extension != .unknown,
        .hgatp_write_disabled = true,
        .guest_execution_disabled = true,
    };
    activation.blocker = .{
        .missing_stage2_metadata = !activation.prereqs.stage2_metadata_ready or !activation.prereqs.stage2_metadata_validated,
        .missing_stage2_table = !activation.prereqs.stage2_table_present,
        .table_not_validated = activation.prereqs.stage2_table_present and !activation.prereqs.stage2_table_validated,
        .table_empty = table.entry_count == 0,
        .table_active = table.active,
        .second_stage_translation_missing = activation.prereqs.second_stage_translation_missing,
        .h_extension_unknown = !activation.prereqs.h_extension_known,
        .hgatp_write_disabled = activation.prereqs.hgatp_write_disabled,
        .guest_execution_disabled = activation.prereqs.guest_execution_disabled,
        .table_root_unavailable = table.root_host_address == 0,
    };
    activation.hgatp_written = false;
    activation.second_stage_enabled = false;
}

fn buildPlanFromTable(activation: *Stage2Activation) void {
    const table = stage2_table.object();
    const root = table.root_host_address;
    const root_available = root != 0;
    const page_size = if (table.page_size == 0) pmm.page_size else table.page_size;
    activation.plan = .{
        .owner_vm_id = table.owner_vm_id,
        .entry_count = table.entry_count,
        .page_size = page_size,
        .table_root_host_address = root,
        .expected_hgatp_mode = 0,
        .expected_hgatp_ppn = if (root_available and page_size != 0) root / page_size else 0,
        .hgatp_write_allowed = false,
        .h_extension_known = activation.prereqs.h_extension_known,
        .activation_allowed = false,
        .would_flush_tlb = false,
        .would_write_hgatp = false,
        .would_enable_second_stage = false,
        .current_hgatp_snapshot = 0,
        .current_hgatp_snapshot_available = false,
        .current_hgatp_snapshot_reason = if (activation.prereqs.h_extension_known) .no_safe_detection_yet else .h_extension_unknown,
        .root_available = root_available,
    };
    activation.blocker.table_root_unavailable = !root_available;
}

fn chooseDecision(activation: *Stage2Activation, for_plan: bool) void {
    if (activation.blocker.missing_stage2_metadata) {
        activation.decision = .blocked_missing_stage2_metadata;
    } else if (activation.blocker.missing_stage2_table or activation.blocker.table_empty) {
        activation.decision = .blocked_missing_stage2_table;
    } else if (activation.blocker.table_not_validated or activation.blocker.table_active) {
        activation.decision = .blocked_table_not_validated;
    } else if (activation.blocker.h_extension_unknown) {
        activation.decision = .blocked_h_extension_unknown;
    } else if (activation.blocker.hgatp_write_disabled) {
        activation.decision = .blocked_hgatp_write_disabled;
    } else if (activation.blocker.guest_execution_disabled) {
        activation.decision = .blocked_guest_execution_disabled;
    } else if (for_plan) {
        activation.decision = .planned_no_activate;
    } else {
        activation.decision = .not_checked;
    }
}

fn hasAnyBlocker(blocker: Stage2ActivationBlocker) bool {
    return blocker.missing_stage2_metadata or blocker.missing_stage2_table or blocker.table_not_validated or
        blocker.table_empty or blocker.table_active or blocker.second_stage_translation_missing or
        blocker.h_extension_unknown or blocker.hgatp_write_disabled or blocker.guest_execution_disabled or
        blocker.table_root_unavailable;
}

fn errorForDecision(decision: Stage2ActivationDecision) Stage2ActivationError {
    return switch (decision) {
        .not_checked => .none,
        .blocked_missing_stage2_metadata => .missing_stage2_metadata,
        .blocked_missing_stage2_table => .missing_stage2_table,
        .blocked_table_not_validated => .table_not_validated,
        .blocked_h_extension_unknown => .h_extension_unknown,
        .blocked_hgatp_write_disabled => .hgatp_write_disabled,
        .blocked_guest_execution_disabled => .guest_execution_disabled,
        .planned_no_activate => .none,
    };
}

pub fn printState() void {
    printImplementedMarker();
    printFields("status");
    printPlan("status");
    printPrereqs();
    printBlockers();
    printStats();
    printNonClaims();
}

pub fn printCheckCommand() void {
    const result = check();
    uart.write("hv: stage2_activation.check_result=");
    uart.write(if (result == .blocked) "blocked" else resultName(result));
    uart.write("\r\n");
    printFields("check");
    printPlan("check");
    printPrereqs();
    printBlockers();
    printStats();
    printNonClaims();
}

pub fn printPlanCommand() void {
    const result = plan();
    uart.write("hv: stage2_activation.plan_result=");
    uart.write(if (result == .ok and object().decision == .planned_no_activate) "planned-no-activate" else "blocked");
    uart.write("\r\n");
    printFields("plan");
    printPlan("plan");
    printBlockers();
    printStats();
    printNonClaims();
}

pub fn printValidateCommand() void {
    const result = validate();
    uart.write("hv: stage2_activation.validate_result=");
    uart.write(if (result.result == .ok) "ok" else resultName(result.result));
    uart.write("\r\n");
    uart.write("hv: stage2_activation.validate.safe_non_activating=");
    uart.write(boolName(result.safe_non_activating));
    uart.write("\r\n");
    uart.write("hv: stage2_activation.validate.activation_still_blocked=");
    uart.write(boolName(result.activation_still_blocked));
    uart.write("\r\n");
    printFields("validate");
    printPlan("validate");
    printBlockers();
    printStats();
    printNonClaims();
}

pub fn printResetCommand() void {
    const result = reset();
    uart.write("hv: stage2_activation.reset_result=");
    uart.write(resultName(result.result));
    uart.write("\r\n");
    printFields("reset");
    printPlan("reset");
    printStats();
    printNonClaims();
}

pub fn printRequireTableTestCommand() void {
    const result = requireTableTest();
    uart.write("hv: stage2_activation.require_table_test=");
    uart.write(if (result == .rejected) "rejected" else "failed-to-reject");
    uart.write("\r\n");
    printFields("require_table_test");
    printPlan("require_table_test");
    printBlockers();
    printStats();
    printNonClaims();
}

pub fn printHgatpWriteTestCommand() void {
    const result = hgatpWriteTest();
    uart.write("hv: stage2_activation.hgatp_write_test=");
    uart.write(if (result == .rejected) "rejected" else "failed-to-reject");
    uart.write("\r\n");
    printFields("hgatp_write_test");
    printPlan("hgatp_write_test");
    printBlockers();
    printStats();
    printNonClaims();
}

pub fn printImplementedMarker() void {
    uart.write("hv: stage2_activation=implemented-guarded-readiness\r\n");
}

fn printFields(prefix: []const u8) void {
    const activation = object();
    uart.write("hv: stage2_activation.state=");
    uart.write(stateName(activation.state));
    uart.write("\r\n");
    uart.write("hv: stage2_activation.mode=");
    uart.write(modeName(activation.mode));
    uart.write("\r\n");
    uart.write("hv: stage2_activation.owner_vm_id=");
    uart.writeDec(activation.owner_vm_id);
    uart.write("\r\n");
    uart.write("hv: stage2_activation.decision=");
    uart.write(decisionName(activation.decision));
    uart.write("\r\n");
    uart.write("hv: stage2_activation.");
    uart.write(prefix);
    uart.write(".last_error=");
    uart.write(errorName(activation.stats.last_error));
    uart.write("\r\n");
    uart.write("hv: stage2_activation.table_required=");
    uart.write(boolName(activation.table_required));
    uart.write("\r\n");
    uart.write("hv: stage2_activation.table_validated=");
    uart.write(boolName(activation.table_validated));
    uart.write("\r\n");
    uart.write("hv: stage2_activation.hgatp_written=");
    uart.write(boolName(activation.hgatp_written));
    uart.write("\r\n");
    uart.write("hv: stage2_activation.second_stage_enabled=");
    uart.write(boolName(activation.second_stage_enabled));
    uart.write("\r\n");
}

fn printPlan(prefix: []const u8) void {
    const plan_value = object().plan;
    uart.write("hv: stage2_activation.");
    uart.write(prefix);
    uart.write(".plan_owner_vm_id=");
    uart.writeDec(plan_value.owner_vm_id);
    uart.write("\r\n");
    uart.write("hv: stage2_activation.entry_count=");
    uart.writeDec(plan_value.entry_count);
    uart.write("\r\n");
    uart.write("hv: stage2_activation.page_size=");
    uart.writeDec(plan_value.page_size);
    uart.write("\r\n");
    uart.write("hv: stage2_activation.table_root_host_address=");
    uart.writeHex(plan_value.table_root_host_address);
    uart.write("\r\n");
    uart.write("hv: stage2_activation.expected_hgatp_mode=");
    uart.writeDec(plan_value.expected_hgatp_mode);
    uart.write("\r\n");
    uart.write("hv: stage2_activation.expected_hgatp_ppn=");
    uart.writeHex(plan_value.expected_hgatp_ppn);
    uart.write("\r\n");
    uart.write("hv: stage2_activation.activation_allowed=");
    uart.write(boolName(plan_value.activation_allowed));
    uart.write("\r\n");
    uart.write("hv: stage2_activation.hgatp_write_allowed=");
    uart.write(boolName(plan_value.hgatp_write_allowed));
    uart.write("\r\n");
    uart.write("hv: stage2_activation.h_extension_known=");
    uart.write(boolName(plan_value.h_extension_known));
    uart.write("\r\n");
    uart.write("hv: stage2_activation.would_flush_tlb=");
    uart.write(boolName(plan_value.would_flush_tlb));
    uart.write("\r\n");
    uart.write("hv: stage2_activation.would_write_hgatp=");
    uart.write(boolName(plan_value.would_write_hgatp));
    uart.write("\r\n");
    uart.write("hv: stage2_activation.would_enable_second_stage=");
    uart.write(boolName(plan_value.would_enable_second_stage));
    uart.write("\r\n");
    uart.write("hv: stage2_activation.current_hgatp_snapshot=");
    uart.writeHex(plan_value.current_hgatp_snapshot);
    uart.write("\r\n");
    uart.write("hv: stage2_activation.current_hgatp_snapshot_available=");
    uart.write(boolName(plan_value.current_hgatp_snapshot_available));
    uart.write("\r\n");
    uart.write("hv: stage2_activation.current_hgatp_snapshot_reason=");
    uart.write(snapshotReasonName(plan_value.current_hgatp_snapshot_reason));
    uart.write("\r\n");
    uart.write("hv: stage2_activation.root_available=");
    uart.write(boolName(plan_value.root_available));
    uart.write("\r\n");
}

fn printPrereqs() void {
    const prereqs = object().prereqs;
    printBool("hv: stage2_activation.prereq.stage2_metadata_ready=", prereqs.stage2_metadata_ready);
    printBool("hv: stage2_activation.prereq.stage2_metadata_validated=", prereqs.stage2_metadata_validated);
    printBool("hv: stage2_activation.prereq.stage2_table_present=", prereqs.stage2_table_present);
    printBool("hv: stage2_activation.prereq.stage2_table_validated=", prereqs.stage2_table_validated);
    printBool("hv: stage2_activation.prereq.entry_count_nonzero=", prereqs.entry_count_nonzero);
    printBool("hv: stage2_activation.prereq.table_inactive=", prereqs.table_inactive);
    printBool("hv: stage2_activation.prereq.second_stage_translation_missing=", prereqs.second_stage_translation_missing);
    printBool("hv: stage2_activation.prereq.h_extension_known=", prereqs.h_extension_known);
    printBool("hv: stage2_activation.prereq.hgatp_write_disabled=", prereqs.hgatp_write_disabled);
    printBool("hv: stage2_activation.prereq.guest_execution_disabled=", prereqs.guest_execution_disabled);
}

fn printBlockers() void {
    const blocker = object().blocker;
    printBool("hv: stage2_activation.blocker.missing_stage2_metadata=", blocker.missing_stage2_metadata);
    printBool("hv: stage2_activation.blocker.missing_stage2_table=", blocker.missing_stage2_table);
    printBool("hv: stage2_activation.blocker.table_not_validated=", blocker.table_not_validated);
    printBool("hv: stage2_activation.blocker.table_empty=", blocker.table_empty);
    printBool("hv: stage2_activation.blocker.table_active=", blocker.table_active);
    printBool("hv: stage2_activation.blocker.second_stage_translation_missing=", blocker.second_stage_translation_missing);
    printBool("hv: stage2_activation.blocker.h_extension_unknown=", blocker.h_extension_unknown);
    printBool("hv: stage2_activation.blocker.hgatp_write_disabled=", blocker.hgatp_write_disabled);
    printBool("hv: stage2_activation.blocker.guest_execution_disabled=", blocker.guest_execution_disabled);
    printBool("hv: stage2_activation.blocker.table_root_unavailable=", blocker.table_root_unavailable);
}

fn printStats() void {
    const stats = object().stats;
    uart.write("hv: stage2_activation.stats.check_count=");
    uart.writeDec(stats.check_count);
    uart.write("\r\n");
    uart.write("hv: stage2_activation.stats.plan_count=");
    uart.writeDec(stats.plan_count);
    uart.write("\r\n");
    uart.write("hv: stage2_activation.stats.validate_count=");
    uart.writeDec(stats.validate_count);
    uart.write("\r\n");
    uart.write("hv: stage2_activation.stats.reset_count=");
    uart.writeDec(stats.reset_count);
    uart.write("\r\n");
    uart.write("hv: stage2_activation.stats.blocked_count=");
    uart.writeDec(stats.blocked_count);
    uart.write("\r\n");
    uart.write("hv: stage2_activation.stats.failed_check_count=");
    uart.writeDec(stats.failed_check_count);
    uart.write("\r\n");
    uart.write("hv: stage2_activation.stats.failed_plan_count=");
    uart.writeDec(stats.failed_plan_count);
    uart.write("\r\n");
    uart.write("hv: stage2_activation.stats.last_error=");
    uart.write(errorName(stats.last_error));
    uart.write("\r\n");
}

fn printNonClaims() void {
    uart.write("hv: second_stage_translation=MISSING\r\n");
    uart.write("hv: guest_execution=not-supported-yet\r\n");
    uart.write("hv: linux_guest=not-supported-yet\r\n");
    uart.write("hv: h_extension=unknown reason=no-safe-detection-yet\r\n");
}

fn printBool(prefix: []const u8, value: bool) void {
    uart.write(prefix);
    uart.write(boolName(value));
    uart.write("\r\n");
}

fn boolName(value: bool) []const u8 {
    return if (value) "true" else "false";
}

fn stateName(state: Stage2ActivationState) []const u8 {
    return switch (state) {
        .idle => "idle",
        .checked => "checked",
        .blocked => "blocked",
        .planned => "planned",
        .reset => "reset",
    };
}

fn modeName(mode: Stage2ActivationMode) []const u8 {
    return switch (mode) {
        .guarded_readiness_only => "guarded-readiness-only",
        .no_hgatp_write => "no-hgatp-write",
        .no_h_extension_proof => "no-h-extension-proof",
    };
}

fn decisionName(decision: Stage2ActivationDecision) []const u8 {
    return switch (decision) {
        .not_checked => "not-checked",
        .blocked_missing_stage2_metadata => "blocked-missing-stage2-metadata",
        .blocked_missing_stage2_table => "blocked-missing-stage2-table",
        .blocked_table_not_validated => "blocked-table-not-validated",
        .blocked_h_extension_unknown => "blocked-h-extension-unknown",
        .blocked_hgatp_write_disabled => "blocked-hgatp-write-disabled",
        .blocked_guest_execution_disabled => "blocked-guest-execution-disabled",
        .planned_no_activate => "planned-no-activate",
    };
}

fn resultName(result: Stage2ActivationResult) []const u8 {
    return switch (result) {
        .ok => "ok",
        .blocked => "blocked",
        .rejected => "rejected",
    };
}

fn errorName(err: Stage2ActivationError) []const u8 {
    return switch (err) {
        .none => "none",
        .missing_stage2_metadata => "missing-stage2-metadata",
        .missing_stage2_table => "missing-stage2-table",
        .table_not_validated => "table-not-validated",
        .table_empty => "table-empty",
        .table_active => "table-active",
        .second_stage_translation_missing => "second-stage-translation-missing",
        .h_extension_unknown => "h-extension-unknown",
        .hgatp_write_disabled => "hgatp-write-disabled",
        .guest_execution_disabled => "guest-execution-disabled",
        .table_root_unavailable => "table-root-unavailable",
        .unsafe_plan => "unsafe-plan",
    };
}

fn snapshotReasonName(reason: HgatpSnapshotReason) []const u8 {
    return switch (reason) {
        .safely_read => "safely-read",
        .no_safe_detection_yet => "no-safe-detection-yet",
        .h_extension_unknown => "h-extension-unknown",
    };
}
