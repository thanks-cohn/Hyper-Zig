```
===============================================================
HYPER-ZIG
The Rosetta Stone of Virtualization

HV01
The Virtual Machine Object

PAGE 1
IN PLAIN ENGLISH
===============================================================

Before you can build a house, you need a folder.

Not a physical folder.

A folder that says:

"This house belongs here."
"These are its parts."
"This is where we keep information about it."

The Virtual Machine Object is that folder.

A Virtual Machine, often called a VM, is a computer that exists
inside another computer.

Before the VM can have memory, a CPU, devices, or an operating
system, Hyper-Zig needs a place to store information about it.

That place is the VM Object.

Think of it like a character sheet in a role-playing game.

The character sheet is not the character.

The sheet simply keeps track of information about the character.

Likewise:

The VM Object is not the virtual machine.

The VM Object is the structure that stores information about the
virtual machine.

At HV01, nothing is running.

No guest operating system exists.

No Linux system exists.

No instructions are executing.

No virtual CPU exists.

No guest memory exists.

The VM Object is simply the first box.

It is the container that future Hyper-Zig milestones will use to
attach everything else.

Future milestones will eventually connect:

- Guest Memory
- Virtual CPUs
- Guest Images
- Address Spaces
- Translation Structures
- Device State

All of those things need somewhere to belong.

The VM Object answers the question:

"Which virtual machine does this belong to?"

Without a VM Object, Hyper-Zig would have nowhere to store the
state of a virtual machine.

Without state, there can be no virtualization.

Without virtualization, there can be no guest.

Without a guest, there can be no operating system running under
Hyper-Zig.

So while HV01 may appear simple, it is the first foundation stone
upon which every later virtualization feature is built.

---------------------------------------------------------------

TECHNICAL TRANSLATION

Folder
→ VM Object

Character Sheet
→ VM State Structure

Information About A VM
→ Metadata

Container For Future Components
→ Root Virtual Machine Structure

Belongs To This VM
→ Ownership

Stored Information
→ State

---------------------------------------------------------------

Key Idea

A VM Object does not run a virtual machine.

A VM Object stores information about a virtual machine.

Every future virtualization feature in Hyper-Zig begins by
attaching itself to a VM Object.

If you understand that, you understand HV01.
===============================================================

```
