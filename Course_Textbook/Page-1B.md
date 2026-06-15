# HV01

## The Virtual Machine Object

PAGE B
THE IMPLEMENTATION
==================

File:

kernel/hypervisor/vm.zig

The real Hyper-Zig implementation is shown below.

Read the explanation page first.

Then read the code.

The goal is not to memorize Zig syntax.

The goal is to identify the structures that make the VM Object possible.

---

```zig
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

    boot_vm.guest_memory =
        if (configured) .configured
        else .not_configured;
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
```

---

What To Notice

1. There is only one VM.

   Hyper-Zig starts small.

2. No guest memory exists yet.

   The VM can exist before memory exists.

3. No virtual CPU exists yet.

   The VM can exist before CPUs exist.

4. The VM Object is a container.

   Future milestones will attach more virtualization state to this structure.

5. The proof is visible.

   Hyper-Zig prints observable state so both humans and validation scripts can confirm what the hypervisor is actually doing.

Key Structures

* Vm
* State
* GuestMemory

Key Functions

* init()
* object()
* setGuestMemoryConfigured()
* printObject()

If you can explain the purpose of those four functions, you understand the implementation.
