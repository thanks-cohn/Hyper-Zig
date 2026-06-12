const uart = @import("../console/uart.zig");
const vm_model = @import("vm.zig");

pub const VcpuId = u32;

pub const State = enum {
    created,
    initialized,
    runnable,
    halted,
};

pub const HartBinding = enum {
    boot_hart,
};

pub const TransitionResult = enum {
    never_run,
    ok,
    invalid_state,
};

pub const LifecycleStats = struct {
    reset_generation: u64,
    initialize_count: u64,
    prepare_count: u64,
    halt_count: u64,
    reset_count: u64,
    failed_transition_count: u64,
    last_transition_result: TransitionResult,
};

pub const GuestEntryAttachment = struct {
    prepared: bool,
    pc: usize,
    sp: usize,
    status_flags: usize,
    owner_vm_id: vm_model.VmId,
    owner_vcpu_id: VcpuId,
    attach_count: u64,
    clear_count: u64,
};

pub const Vcpu = struct {
    id: VcpuId,
    vm_id: vm_model.VmId,
    state: State,
    hart_binding: HartBinding,
    run_count: u64,
    stats: LifecycleStats,
    guest_entry: GuestEntryAttachment,
};

var boot_vcpu: Vcpu = undefined;
var initialized: bool = false;

pub fn init(vm_id: vm_model.VmId) void {
    boot_vcpu = Vcpu{
        .id = 0,
        .vm_id = vm_id,
        .state = .created,
        .hart_binding = .boot_hart,
        .run_count = 0,
        .stats = LifecycleStats{
            .reset_generation = 0,
            .initialize_count = 0,
            .prepare_count = 0,
            .halt_count = 0,
            .reset_count = 0,
            .failed_transition_count = 0,
            .last_transition_result = .never_run,
        },
        .guest_entry = emptyGuestEntryAttachment(vm_id, 0, 0),
    };
    initialized = true;
}

pub fn object() *const Vcpu {
    if (!initialized) init(vm_model.object().id);
    return &boot_vcpu;
}

fn mutableObject() *Vcpu {
    if (!initialized) init(vm_model.object().id);
    return &boot_vcpu;
}

fn emptyGuestEntryAttachment(owner_vm_id: vm_model.VmId, owner_vcpu_id: VcpuId, clear_count: u64) GuestEntryAttachment {
    return .{
        .prepared = false,
        .pc = 0,
        .sp = 0,
        .status_flags = 0,
        .owner_vm_id = owner_vm_id,
        .owner_vcpu_id = owner_vcpu_id,
        .attach_count = 0,
        .clear_count = clear_count,
    };
}

pub fn attachGuestEntryFrame(frame: anytype) void {
    const vcpu = mutableObject();
    vcpu.guest_entry.prepared = true;
    vcpu.guest_entry.pc = frame.pc;
    vcpu.guest_entry.sp = frame.sp;
    vcpu.guest_entry.status_flags = frame.status_flags;
    vcpu.guest_entry.owner_vm_id = frame.owner_vm_id;
    vcpu.guest_entry.owner_vcpu_id = frame.owner_vcpu_id;
    vcpu.guest_entry.attach_count += 1;
}

pub fn clearGuestEntryFrame() void {
    const vcpu = mutableObject();
    const attach_count = vcpu.guest_entry.attach_count;
    const clear_count = vcpu.guest_entry.clear_count + 1;
    vcpu.guest_entry = emptyGuestEntryAttachment(vcpu.vm_id, vcpu.id, clear_count);
    vcpu.guest_entry.attach_count = attach_count;
}

pub fn initializeLifecycle() TransitionResult {
    const vcpu = mutableObject();
    if (vcpu.state != .created) return reject(vcpu);
    vcpu.state = .initialized;
    vcpu.stats.initialize_count += 1;
    vcpu.stats.last_transition_result = .ok;
    return .ok;
}

pub fn prepareRunnable() TransitionResult {
    const vcpu = mutableObject();
    switch (vcpu.state) {
        .initialized, .halted => {
            vcpu.state = .runnable;
            vcpu.stats.prepare_count += 1;
            vcpu.stats.last_transition_result = .ok;
            return .ok;
        },
        .created, .runnable => return reject(vcpu),
    }
}

pub fn halt() TransitionResult {
    const vcpu = mutableObject();
    if (vcpu.state != .runnable) return reject(vcpu);
    vcpu.state = .halted;
    vcpu.stats.halt_count += 1;
    vcpu.stats.last_transition_result = .ok;
    return .ok;
}

pub fn reset() TransitionResult {
    const vcpu = mutableObject();
    vcpu.state = .created;
    vcpu.stats.reset_generation += 1;
    vcpu.stats.reset_count += 1;
    vcpu.stats.last_transition_result = .ok;
    return .ok;
}

fn reject(vcpu: *Vcpu) TransitionResult {
    vcpu.stats.failed_transition_count += 1;
    vcpu.stats.last_transition_result = .invalid_state;
    return .invalid_state;
}

pub fn canInitialize() bool {
    return object().state == .created;
}

pub fn canPrepareRunnable() bool {
    const state = object().state;
    return state == .initialized or state == .halted;
}

pub fn canHalt() bool {
    return object().state == .runnable;
}

pub fn stateName(state: State) []const u8 {
    return switch (state) {
        .created => "created",
        .initialized => "initialized",
        .runnable => "runnable",
        .halted => "halted",
    };
}

pub fn hartBindingName(binding: HartBinding) []const u8 {
    return switch (binding) {
        .boot_hart => "boot-hart",
    };
}

pub fn transitionResultName(result: TransitionResult) []const u8 {
    return switch (result) {
        .never_run => "never-run",
        .ok => "ok",
        .invalid_state => "invalid-state",
    };
}

pub fn printImplementedMarker() void {
    uart.write("hv: vcpu_object=implemented\r\n");
}

pub fn printObject() void {
    const vcpu = object();
    printImplementedMarker();
    uart.write("hv: vcpu.id=");
    uart.writeDec(vcpu.id);
    uart.write("\r\n");
    uart.write("hv: vcpu.vm_id=");
    uart.writeDec(vcpu.vm_id);
    uart.write("\r\n");
    uart.write("hv: vcpu.state=");
    uart.write(stateName(vcpu.state));
    uart.write("\r\n");
    uart.write("hv: vcpu.hart_binding=");
    uart.write(hartBindingName(vcpu.hart_binding));
    uart.write("\r\n");
    uart.write("hv: vcpu.run_count=");
    uart.writeDec(vcpu.run_count);
    uart.write("\r\n");
    printGuestEntryAttachment();
}

pub fn printLifecycle() void {
    const vcpu = object();
    uart.write("hv: vcpu.lifecycle.state=");
    uart.write(stateName(vcpu.state));
    uart.write("\r\n");
    uart.write("hv: vcpu.lifecycle.can_initialize=");
    uart.write(boolName(canInitialize()));
    uart.write("\r\n");
    uart.write("hv: vcpu.lifecycle.can_prepare_runnable=");
    uart.write(boolName(canPrepareRunnable()));
    uart.write("\r\n");
    uart.write("hv: vcpu.lifecycle.can_halt=");
    uart.write(boolName(canHalt()));
    uart.write("\r\n");
    uart.write("hv: vcpu.reset_generation=");
    uart.writeDec(vcpu.stats.reset_generation);
    uart.write("\r\n");
    printStats();
}

pub fn printTransition(command_name: []const u8, result: TransitionResult) void {
    const vcpu = object();
    uart.write("hv: vcpu.transition=");
    uart.write(command_name);
    uart.write(" result=");
    uart.write(transitionResultName(result));
    uart.write("\r\n");
    uart.write("hv: vcpu.state=");
    uart.write(stateName(vcpu.state));
    uart.write("\r\n");
    uart.write("hv: vcpu.hart_binding=");
    uart.write(hartBindingName(vcpu.hart_binding));
    uart.write("\r\n");
    uart.write("hv: vcpu.run_count=");
    uart.writeDec(vcpu.run_count);
    uart.write("\r\n");
    uart.write("hv: vcpu.reset_generation=");
    uart.writeDec(vcpu.stats.reset_generation);
    uart.write("\r\n");
    printStats();
}

fn printGuestEntryAttachment() void {
    const attachment = object().guest_entry;
    uart.write("hv: vcpu.guest_entry.prepared=");
    uart.write(if (attachment.prepared) "true" else "false");
    uart.write("\r\n");
    uart.write("hv: vcpu.guest_entry.pc=");
    uart.writeHex(attachment.pc);
    uart.write("\r\n");
    uart.write("hv: vcpu.guest_entry.sp=");
    uart.writeHex(attachment.sp);
    uart.write("\r\n");
    uart.write("hv: vcpu.guest_entry.status_flags=");
    uart.writeHex(attachment.status_flags);
    uart.write("\r\n");
    uart.write("hv: vcpu.guest_entry.owner_vm_id=");
    uart.writeDec(attachment.owner_vm_id);
    uart.write("\r\n");
    uart.write("hv: vcpu.guest_entry.owner_vcpu_id=");
    uart.writeDec(attachment.owner_vcpu_id);
    uart.write("\r\n");
    uart.write("hv: vcpu.guest_entry.attach_count=");
    uart.writeDec(attachment.attach_count);
    uart.write("\r\n");
    uart.write("hv: vcpu.guest_entry.clear_count=");
    uart.writeDec(attachment.clear_count);
    uart.write("\r\n");
}

fn printStats() void {
    const stats = object().stats;
    uart.write("hv: vcpu.stats.initialize_count=");
    uart.writeDec(stats.initialize_count);
    uart.write("\r\n");
    uart.write("hv: vcpu.stats.prepare_count=");
    uart.writeDec(stats.prepare_count);
    uart.write("\r\n");
    uart.write("hv: vcpu.stats.halt_count=");
    uart.writeDec(stats.halt_count);
    uart.write("\r\n");
    uart.write("hv: vcpu.stats.reset_count=");
    uart.writeDec(stats.reset_count);
    uart.write("\r\n");
    uart.write("hv: vcpu.stats.failed_transition_count=");
    uart.writeDec(stats.failed_transition_count);
    uart.write("\r\n");
    uart.write("hv: vcpu.stats.last_transition_result=");
    uart.write(transitionResultName(stats.last_transition_result));
    uart.write("\r\n");
}

fn boolName(value: bool) []const u8 {
    return if (value) "true" else "false";
}
