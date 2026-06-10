# Linux Guest Fast Path

Linux guest support is not present yet. The fastest honest route is a proof ladder that makes every missing layer visible before claiming a guest boot.

## Ordered path

1. **HV0 status scaffold**: expose `hv status`; print research state and missing guest pieces.
2. **HV1 capability detection**: safely detect whether hypervisor capability is available, without unsafe supervisor-mode CSR reads.
3. **HV2 VM/vCPU structs**: define honest VM and vCPU data models without entering a guest.
4. **HV3 vCPU lifecycle**: prove created, initialized, runnable, halted, and reset state management without guest execution.
5. **HV4 guest memory object**: allocate and track guest memory ranges before any payload loader.
6. **HV5 guest entry attempt**: attempt controlled guest entry only after data structures and memory are real.
7. **HV6 trap return**: handle a guest trap and return or fail honestly.
8. **HV7 virtual console**: define a guest-visible console path.
9. **HV8 SBI mediation**: mediate necessary SBI calls instead of pretending firmware is present.
10. **HV9 Linux Image + DTB loading**: load Linux `Image` and a guest DTB into guest memory.
11. **HV10 early Linux boot text**: prove earliest Linux boot text from the guest.
12. **HV11 Linux shell**: reach an interactive Linux shell.
13. **HV12 compile C inside Linux guest**: prove a C compiler can run inside the guest.
14. **HV13 Rust toolchain inside Linux guest**: prove Rust tooling can run inside the guest.

## Why this order

Linux needs a real guest execution substrate. ZIGN01D must first prove capability detection, VM/vCPU state, guest memory, guest entry, trap handling, virtual console, SBI mediation, and virtio or equivalent device support. HV0 deliberately implements none of those pieces.
