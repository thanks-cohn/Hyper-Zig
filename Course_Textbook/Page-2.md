# HV02

## Capability Detection

```text
Section: 2A
Module: Capability Detection
Type: Concept
Source: capability.zig
```

### In Plain English

Before Hyper-Zig can do anything dangerous, it needs to ask a simple question:

What is this machine actually capable of?

That question matters.

A hypervisor cannot assume that the hardware supports everything it wants to do.

It cannot assume guest execution is available.

It cannot assume Linux can run as a guest.

It cannot assume the RISC-V H-extension is present.

In systems programming, guessing is expensive.

A bad guess can crash the machine.

So HV02 introduces Capability Detection.

At this stage, Hyper-Zig is not trying to activate virtualization.

It is not trying to run a guest.

It is not trying to boot Linux.

It is doing something smaller and more careful:

It is creating a place where the hypervisor can report:

* what it knows
* what it does not know
* why

That last part matters.

A weak system says:

```text
Not supported.
```

A better system says:

```text
Not supported yet, and here is why.
```

HV02 chooses the better path.

The capability module reports that detection exists, but safe hardware detection is not available yet.

So the H-extension status is reported as:

```text
unknown
```

This is honest.

Unknown does not mean absent.

Unknown does not mean present.

Unknown means Hyper-Zig does not yet have a safe way to prove the answer.

A careful hypervisor must separate:

```text
What I know.
```

from

```text
What I hope is true.
```

In HV01, Hyper-Zig created the VM Object.

In HV02, Hyper-Zig begins describing the environment around that VM.

```text
Section: 2B
Module: Capability Detection
Type: Implementation
Source: capability.zig
```

### The Real Hyper-Zig Module

File:

```text
kernel/hypervisor/capability.zig
```

```zig
const uart = @import("../console/uart.zig");

pub const HExtensionStatus = enum {
    present,
    absent,
    unknown,
};

pub const CapabilityStatus = struct {
    source: []const u8,
    h_extension: HExtensionStatus,
    reason: []const u8,
};

pub fn detect() CapabilityStatus {
    return CapabilityStatus{
        .source = "supervisor-mode-safe-static-policy",
        .h_extension = .unknown,
        .reason = "no-safe-detection-yet",
    };
}

pub fn print() void {
    const status = detect();

    uart.write("hv: branch=hypervisor-v0\r\n");
    uart.write("hv: target=zig-0.14.x\r\n");
    uart.write("hv: capability_detection=implemented\r\n");
    uart.write("hv: capability_source=");
    uart.write(status.source);
    uart.write("\r\n");
    uart.write("hv: h_extension=");
    switch (status.h_extension) {
        .present => uart.write("present"),
        .absent => uart.write("absent"),
        .unknown => uart.write("unknown"),
    }
    uart.write(" reason=");
    uart.write(status.reason);
    uart.write("\r\n");
    uart.write("hv: guest_execution=not-supported-yet\r\n");
    uart.write("hv: linux_guest=not-supported-yet\r\n");
    uart.write("hv: vm_object=implemented\r\n");
    uart.write("hv: vcpu_object=implemented\r\n");
}
```

### Things To Notice

1. Capability detection has three states.

```text
present
absent
unknown
```

2. Unknown is a real answer.

Hyper-Zig does not guess when it cannot safely prove something.

3. The reason is stored with the status.

A status without a reason is much less useful.

4. The module prints negative claims.

Hyper-Zig explicitly says guest execution and Linux guests are not supported yet.

5. The proof is observable.

The capability state is printed through UART so validation scripts can verify what the hypervisor actually reported.

### Key Structures

```text
HExtensionStatus
CapabilityStatus
```

### Key Functions

```text
detect()
print()
```

If you can explain why unknown is safer than pretending, you understand the implementation.

```text
Section: 2C
Module: Capability Detection
Type: Exercise
Source: capability.zig
```

### Build It Yourself

In HV01, you created a VM Object.

The VM existed.

However, the VM knew nothing about the machine it was running on.

HV02 introduces a new idea:

Before a system uses a feature, it should know whether that feature is available.

For this exercise, build a tiny capability detection system in C.

Do not worry about real hardware detection.

The goal is to understand how capability information is represented, stored, and reported.

### C Skeleton

```c
#include <stdio.h>

typedef enum
{
    CAPABILITY_PRESENT,
    CAPABILITY_ABSENT,

    /* Add the third state used by Hyper-Zig */
}
CapabilityState;

typedef struct
{
    const char *source;
    CapabilityState h_extension;
    const char *reason;
}
CapabilityStatus;

CapabilityStatus detect(void)
{
    CapabilityStatus status;

    status.source = "student-policy";

    /* What should the capability state be? */

    /* Why? */

    status.reason = "replace-me";

    return status;
}

void print_status(CapabilityStatus status)
{
    printf("source=%s\n", status.source);

    /* Print capability state */

    /* Print reason */
}

int main(void)
{
    CapabilityStatus status = detect();

    print_status(status);

    return 0;
}
```

### Questions

1.

Why does Hyper-Zig use:

```text
present
absent
unknown
```

instead of:

```text
present
absent
```

alone?

2.

Suppose the hypervisor cannot safely determine whether a feature exists.

Which answer is safer?

```text
present
```

or

```text
unknown
```

Why?

3.

Why store a reason string?

Why not simply print:

```text
h_extension=unknown
```

and stop there?

4.

Create a helper function:

```c
const char *capability_name(
    CapabilityState state
);
```

that converts capability states into text.

5.

Add a second capability.

Examples:

```text
guest_execution
linux_guest
virtualization
```

Store and print it.

### Challenge Question

A careless engineer writes:

```text
h_extension=present
```

without verifying the hardware.

What problems could this cause later?

Think beyond compilation.

Think about execution.

Think about trust.

```text
Section: 2D
Module: Capability Detection
Type: Instructor Notes
Source: capability.zig
```

### Instructor Notes

### Audience

Students should have completed HV01.

Students should already understand:

* VM Objects
* Identity
* State
* Initialization

This module introduces a new concept:

Evidence.

The central lesson is simple:

A system should report what it knows.

A system should not pretend to know more than it does.

### Learning Objective

By the end of HV02, students should understand that capability detection is not about enabling features.

It is about understanding the environment in which those features might eventually run.

Students should understand that:

```text
unknown
```

is often a more correct answer than:

```text
present
```

or

```text
absent
```

when evidence does not exist.

### Key Concepts

* Capability Detection
* Evidence
* Unknown State
* Reporting
* Diagnostic Output

### Common Misconceptions

Unknown means failure.

Correction:

Unknown means insufficient evidence.

Unknown and absent are the same.

Correction:

Absent means the feature is known not to exist.

Unknown means the feature has not yet been proven one way or the other.

Diagnostics are only for debugging.

Correction:

Diagnostics are also evidence.

### Discussion Questions

What is more dangerous:

```text
A missing feature
```

or

```text
A feature incorrectly reported as present
```

Why?

Why should software explain its reasoning?

### Key Idea

HV01 taught students how to describe a machine.

HV02 teaches students how to describe certainty.

A trustworthy hypervisor reports what it knows.

A trustworthy hypervisor also reports what it does not know.
