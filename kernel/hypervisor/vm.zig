const uart = @import("../console/uart.zig");

pub const VmId = u32;

pub const State = enum {
    defined,
};

pub const GuestMemory = enum {
    not_configured,
    configured,
};

pub const Vm = struct {
    id: VmId,
    state: State,
    guest_memory: GuestMemory,
};

var boot_vm: Vm = undefined;
var initialized: bool = false;

pub fn init() void {
    boot_vm = Vm{
        .id = 0,
        .state = .defined,
        .guest_memory = .not_configured,
    };
    initialized = true;
}

pub fn object() *const Vm {
    if (!initialized) init();
    return &boot_vm;
}

pub fn stateName(state: State) []const u8 {
    return switch (state) {
        .defined => "defined",
    };
}

pub fn guestMemoryName(memory: GuestMemory) []const u8 {
    return switch (memory) {
        .not_configured => "not-configured",
        .configured => "configured",
    };
}

pub fn setGuestMemoryConfigured(configured: bool) void {
    if (!initialized) init();
    boot_vm.guest_memory = if (configured) .configured else .not_configured;
}

pub fn printImplementedMarker() void {
    uart.write("hv: vm_object=implemented\r\n");
}

pub fn printObject() void {
    const vm = object();
    printImplementedMarker();
    uart.write("hv: vm.id=");
    uart.writeDec(vm.id);
    uart.write("\r\n");
    uart.write("hv: vm.state=");
    uart.write(stateName(vm.state));
    uart.write("\r\n");
    uart.write("hv: vm.guest_memory=");
    uart.write(guestMemoryName(vm.guest_memory));
    uart.write("\r\n");
}
