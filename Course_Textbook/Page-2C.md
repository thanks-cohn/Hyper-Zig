# HV02

## Capability Detection

PAGE C
THE EXERCISE
============

In HV01, you created a VM Object.

The VM existed.

However, the VM knew nothing about the machine it was running on.

HV02 introduces a new idea:

Before a system uses a feature, it should know whether that feature is
available.

This sounds obvious.

Yet many software failures begin when a program assumes something
exists without verifying it.

Hyper-Zig avoids that mistake.

For this exercise, you will build a tiny capability detection system
in C.

Do not worry about real hardware detection.

The goal is to understand how capability information is represented,
stored, and reported.

The concepts required for this exercise are:

* Structures
* Enumerations
* Functions
* State Reporting
* Diagnostic Output

---

Starting Point

Complete the implementation below.

Think carefully about what each field represents.

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

---

Questions

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

---

2.

Suppose the hypervisor cannot safely determine whether a feature
exists.

Which answer is safer?

```text
present
```

or

```text
unknown
```

Why?

---

3.

Why store a reason string?

Why not simply print:

```text
h_extension=unknown
```

and stop there?

---

4.

Create a helper function:

```c
const char *capability_name(
    CapabilityState state
);
```

that converts capability states into text.

---

5.

Add a second capability.

Examples:

```text
guest_execution
```

```text
linux_guest
```

```text
virtualization
```

Store and print it.

---

6.

Modify your output so it resembles:

```text
capability_detection=implemented
h_extension=unknown
reason=no-safe-detection-yet
```

---

7.

Suppose a future version of Hyper-Zig discovers that the H-extension
is definitely present.

What information should change?

What information should remain the same?

---

Challenge Question

A careless engineer writes:

```text
h_extension=present
```

without verifying the hardware.

What problems could this cause later?

Think beyond compilation.

Think about execution.

Think about trust.

===============================================================

Completion Check

Before moving to HV03, make sure you can explain:

* What a capability is
* Why unknown is a valid answer
* Why reasons matter
* Why diagnostics exist
* Why assumptions are dangerous

If you can explain those ideas in your own words, you have completed
HV02.

===============================================================
