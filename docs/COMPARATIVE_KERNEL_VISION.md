# Comparative Kernel Vision

ZIGN01D is the RISC-V Zig teaching kernel.

Future sibling kernels may include:

- a RISC-V C teaching kernel;
- a RISC-V Rust teaching kernel;
- an x86_64 C teaching kernel.

These sibling kernels are future/planned unless an actual repository exists with its own proof contract and smoke evidence.

## Point of controlled comparison

The educational value is controlled comparison:

- same architecture, different language;
- same language, different architecture;
- same milestone, different implementation;
- same proof contract across kernels.

A student could compare boot setup in Zig and C on RISC-V, or compare interrupt setup across RISC-V and x86_64, while keeping milestone names, expected behavior, and smoke proof parallel.

## What ZIGN01D should not become

ZIGN01D does not need to become a language zoo. Its job is to stay readable as the RISC-V Zig kernel lab. Other languages should live in sibling repositories or in explicit ABI experiments with clear boundaries and documentation.

## Shared proof standard

Any sibling kernel should follow the same educational rules:

- no claim without proof;
- no proof without command;
- no milestone without smoke test;
- every limitation documented;
- generated transcripts not committed unless explicitly intended.
