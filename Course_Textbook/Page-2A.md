# HV02

## Capability Detection

PAGE A
IN PLAIN ENGLISH
================

Before Hyper-Zig can do anything dangerous, it needs to ask a simple
question:

What is this machine actually capable of?

That question matters.

A hypervisor cannot assume that the hardware supports everything it
wants to do. It cannot assume guest execution is available. It cannot
assume Linux can run as a guest. It cannot assume the RISC-V
H-extension is present.

In systems programming, guessing is expensive.

A bad guess can crash the machine.

So HV02 introduces capability detection.

At this stage, Hyper-Zig is not trying to activate virtualization.

It is not trying to run a guest.

It is not trying to boot Linux.

It is doing something smaller and more careful:

It is creating a place where the hypervisor can report what it knows,
what it does not know, and why.

That last part matters.

A weak system says:

"Not supported."

A better system says:

"Not supported yet, and here is why."

HV02 chooses the better path.

The capability module reports that detection exists, but that safe
hardware detection is not available yet. So the H-extension status is
reported as unknown.

This is honest.

Unknown does not mean absent.

Unknown does not mean present.

Unknown means Hyper-Zig does not yet have a safe way to prove the
answer.

That distinction is important.

A careful hypervisor must separate:

what it knows

from

what it wants to be true.

In HV01, Hyper-Zig created the VM Object.

In HV02, Hyper-Zig begins describing the environment around that VM.

The VM exists.

Now the hypervisor begins asking:

What can this machine safely support?

===============================================================

TECHNICAL TRANSLATION

Machine capability
→ Hardware or software feature Hyper-Zig may use

Capability detection
→ Code that reports whether a feature is available

H-extension
→ RISC-V hypervisor extension

Unknown
→ Hyper-Zig cannot safely prove present or absent yet

Reason
→ Human-readable explanation for the reported status

Static policy
→ A conservative answer chosen without unsafe hardware probing

Guest execution
→ Running instructions from a virtual machine

Linux guest
→ Linux running inside Hyper-Zig as a guest operating system

===============================================================

The Key Idea

Capability detection prevents the hypervisor from pretending.

HV02 does not claim guest execution.

HV02 does not claim Linux support.

HV02 only reports what Hyper-Zig can safely say at this point in the
build.

If you understand the difference between absent, present, and unknown,
you understand HV02.
