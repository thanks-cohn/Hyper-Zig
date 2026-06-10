const uart = @import("../console/uart.zig");
const vm_model = @import("vm.zig");

pub const VcpuId = u32;

pub const State = enum {
    defined,
};

pub const HartBinding = enum {
    unbound,
};

pub const Vcpu = struct {
    id: VcpuId,
    vm_id: vm_model.VmId,
    state: State,
    hart_binding: HartBinding,
    run_count: u64,
};

var boot_vcpu: Vcpu = undefined;
var initialized: bool = false;

pub fn init(vm_id: vm_model.VmId) void {
    boot_vcpu = Vcpu{
        .id = 0,
        .vm_id = vm_id,
        .state = .defined,
        .hart_binding = .unbound,
        .run_count = 0,
    };
    initialized = true;
}

pub fn object() *const Vcpu {
    if (!initialized) init(vm_model.object().id);
    return &boot_vcpu;
}

pub fn stateName(state: State) []const u8 {
    return switch (state) {
        .defined => "defined",
    };
}

pub fn hartBindingName(binding: HartBinding) []const u8 {
    return switch (binding) {
        .unbound => "unbound",
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
}
