# HV01

## The Virtual Machine Object

```text
Section: 1A
Module: The Virtual Machine Object
Type: Concept
Source: vm.zig
```

### In Plain English

Before Hyper-Zig can create memory, CPUs, devices, operating systems, or guest execution, it needs a place to store information about the machine it intends to build.

That place is the Virtual Machine Object.

Think of it as a folder.

Not a physical folder.

A folder that answers questions like:

* Which VM is this?
* What state is it in?
* Does it have memory?
* What belongs to it?

The VM Object is not the virtual machine itself.

It is the structure that stores information about the virtual machine.

A useful comparison is a character sheet in a role-playing game.

The character sheet is not the character.

It simply stores information about the character.

The VM Object serves the same purpose.

At HV01:

* No Linux exists.
* No guest is running.
* No virtual CPU exists.
* No guest memory exists.

We are only creating the first container.

Future modules will eventually attach:

* Guest Memory
* Virtual CPUs
* Guest Images
* Address Spaces
* Translation Structures
* Device State

to this object.

Every later Hyper-Zig subsystem eventually begins here.

```text
Section: 1B
Module: The Virtual Machine Object
Type: Implementation
Source: vm.zig
```

### The Real Hyper-Zig Module

File:

```text
kernel/hypervisor/vm.zig
```

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

### Things To Notice

1. There is only one VM.

2. The VM exists before memory exists.

3. The VM exists before CPUs exist.

4. The VM Object is a container.

5. The implementation exposes observable state.

6. Future modules will attach themselves here.

### Key Structures

```text
Vm
State
GuestMemory
```

### Key Functions

```text
init()
object()
setGuestMemoryConfigured()
printObject()
```

If you can explain the purpose of those functions, you understand the implementation.

```text
Section: 1C
Module: The Virtual Machine Object
Type: Exercise
Source: vm.zig
```

### Build It Yourself

Your goal is not to copy Hyper-Zig.

Your goal is to recreate the idea.

Using C, build a tiny VM Object.

Start with:

```c
#include <stdio.h>

typedef unsigned int VmId;

typedef enum
{
    VM_DEFINED
} VmState;

typedef enum
{
    MEMORY_NOT_CONFIGURED,
    MEMORY_CONFIGURED
} GuestMemoryState;

typedef struct
{
    VmId id;
    VmState state;
    GuestMemoryState guest_memory;
} Vm;

Vm boot_vm;

void vm_init(void)
{
    boot_vm.id = 0;

    /* What state should the VM begin in? */

    /* Should memory already be configured? */
}

void vm_print(void)
{
    printf("vm.id=%u\n", boot_vm.id);

    /* Print the VM state */

    /* Print the guest memory state */
}

int main(void)
{
    vm_init();

    vm_print();

    return 0;
}
```

### Questions

1.

Why does the VM need an ID if only one VM exists?

2.

Why is guest memory tracked separately from VM state?

3.

What information is the VM actually storing?

4.

Why create the VM before memory or CPUs exist?

5.

What would need to change if Hyper-Zig managed:

```text
VM0
VM1
VM2
VM3
```

instead of a single VM?

### Challenge

Add:

```c
void vm_set_memory_configured(int configured);
```

and make the VM report:

```text
vm.id=0
vm.state=defined
vm.guest_memory=not-configured
```

```text
Section: 1D
Module: The Virtual Machine Object
Type: Instructor Notes
Source: vm.zig
```

### Instructor Notes

The purpose of HV01 is not to teach virtualization.

The purpose of HV01 is to teach state.

Students should leave this module understanding:

```text
Description comes before execution.
```

The VM Object is the first box.

Future modules will fill that box with:

* Memory
* CPUs
* Images
* Address Spaces
* Translation Structures
* Device State

A student has successfully completed HV01 if they can answer:

```text
What is a VM Object?
```

without answering:

```text
It is a struct.
```

The desired answer focuses on purpose.

Not implementation.

### Key Idea

A VM Object does not run a virtual machine.

A VM Object stores information about a virtual machine.

If you understand that, you understand HV01.
