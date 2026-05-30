# ZIGN01D Educational Mission

## Mission

ZIGN01D is a proof-driven RISC-V Zig teaching kernel. Its mission is to make early kernel construction understandable, inspectable, and reproducible.

The project values clarity over fake completeness. A documented limitation is better than an undocumented lie. A smoke-tested scaffold is better than an unproven feature claim.

## Audience

ZIGN01D is intended for:

- OS students;
- RISC-V students;
- Zig programmers;
- systems programmers;
- educators;
- self-learners;
- researchers comparing small kernels.

## What students should learn

Students should learn how to:

- build a freestanding Zig kernel;
- boot a RISC-V kernel in QEMU;
- follow early boot output;
- read UART polling code;
- trace a shell command from input to output;
- distinguish implemented behavior from scaffolding;
- read trap and timer diagnostics;
- use smoke tests as evidence;
- document both changes and limitations.

## What educators can assign

Educators can assign small, bounded exercises:

- identify boot markers in a transcript;
- explain one shell command path;
- add a harmless diagnostic command;
- extend a smoke test by one expected marker;
- write a limitation note for an intentionally missing feature;
- compare two milestone outputs;
- design a future milestone without implementing it.

## What researchers can inspect

Researchers can inspect how a small kernel project records proof discipline, names subsystem boundaries, and avoids misleading claims while still building toward larger operating-system ideas.

## What contributors must preserve

Contributors must preserve:

- readable source;
- small milestone scope;
- honest command output;
- documented limitations;
- smoke-test proof;
- no generated transcript commits unless explicitly intended;
- no claims of internet, SMS, modem, hardware, or production support without proof.

## Proof over claims

A claim must have a command. A command must have expected output. A milestone must have smoke proof. If a subsystem is only a scaffold, the output must say so.

## Documentation as part of the kernel

Documentation is not an afterthought. It is the map that turns the repository into a kernel laboratory. New commands, smoke tests, milestones, and subsystems are not complete until students can read what changed, how to run it, what PASS means, and what remains unimplemented.
