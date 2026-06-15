# HV01

## The Virtual Machine Object

PAGE C
THE EXERCISE
============

In the previous pages we learned what a VM Object is and examined the
actual Hyper-Zig implementation.

Now it is your turn.

The goal is not to recreate Hyper-Zig line-for-line.

The goal is to recreate the ideas.

If you can build a tiny VM Object in C, then you understand the
concept regardless of language.

For this exercise, ignore virtualization.

Ignore Linux.

Ignore page tables.

Ignore hypervisors.

Pretend you have been asked to keep track of a machine that does not
exist yet.

What information would you store?

How would you identify it?

How would you know whether it has memory attached?

These are the same questions Hyper-Zig is answering.

The concepts required for this exercise are:

* Structures
* Enumerations
* Variables
* Functions
* State
* Ownership

You do not need advanced C knowledge.

You only need enough C to describe an object and store information
inside it.

---

Starting Point

Complete the implementation below.

Do not immediately search for the answer.

Think about what each field means.

Think about why it exists.

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

---

Questions

1.

What information is the VM actually storing?

Write your answer without using the words
"struct" or "variable".

---

2.

Why does the VM have an id field?

Hyper-Zig currently creates only one VM.

Why might the id still be useful?

---

3.

Why is guest_memory separate from state?

What information does guest_memory tell us that state does not?

---

4.

Add a second VM state.

Examples:

* VM_INITIALIZING
* VM_RUNNING
* VM_STOPPED

Choose your own.

What new information does your state provide?

---

5.

Create a function:

```c
void vm_set_memory_configured(int configured);
```

What should happen when configured is:

```text
0
```

?

What should happen when configured is:

```text
1
```

?

---

6.

Modify vm_print() so that the output becomes:

```text
vm.id=0
vm.state=defined
vm.guest_memory=not-configured
```

---

7.

Suppose Hyper-Zig wanted to manage:

```text
VM 0
VM 1
VM 2
VM 3
```

Would a single global variable still be enough?

What would need to change?

---

Challenge Question

At HV01 the VM Object does not contain:

* a CPU
* memory pages
* a guest image
* an operating system

Why create the VM first?

Why not create those things immediately?

Think carefully before continuing to the next milestone.

The answer will appear repeatedly throughout the rest of Hyper-Zig.

===============================================================

Completion Check

Before moving to HV02, make sure you can explain:

* What a VM Object is
* Why a VM needs an identity
* Why state exists
* Why ownership matters
* Why the VM is created before other subsystems

If you can explain those concepts in your own words, you have
completed HV01.

===============================================================
