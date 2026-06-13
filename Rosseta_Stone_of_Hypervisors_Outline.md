```

Hyper-Zig/
├── README.md
│   The front door:
│   "The Rosetta Stone of Virtualization"
│   5-minute quickstart
│   current proven status
│   no false claims
│
├── kernel/
│   The real hypervisor code.
│   VM model, vCPU model, traps, SBI, timers, memory,
│   stage-2 translation, guest execution, device model.
│
├── arch/riscv64/
│   RISC-V-specific truth:
│   CSRs, privilege modes, hgatp, traps, page tables,
│   SBI, interrupt/timer machinery.
│
├── guests/
│   Tiny guest
│   BusyBox guest
│   Buildroot guest
│   Linux guest
│   test kernels
│
├── smoke/
│   Every milestone proof.
│   HV0 through HV50+.
│   No grep-only fake wins.
│
├── transcripts/
│   The museum.
│   Every run captured.
│   "Here is exactly what happened."
│
├── labs/
│   The classroom.
│   lab-00-what-is-a-trap/
│   lab-01-what-is-a-vcpu/
│   lab-02-guest-memory/
│   lab-03-stage2-translation/
│   lab-04-first-linux-boot/
│
├── docs/
│   The book.
│   Rosetta narrative.
│   Architecture diagrams.
│   RISC-V virtualization glossary.
│   Compare: Hyper-Zig vs KVM vs Xen vs QEMU.
│
├── scripts/
│   Build, run, validate, reset, replay.
│
├── tools/
│   Visualizers.
│   ASCII trace viewer.
│   page-table explorer.
│   trap timeline viewer.
│   guest boot recorder.
│
├── proofs/
│   Machine-readable evidence.
│   JSON summaries.
│   release audits.
│   milestone manifests.
│
├── examples/
│   "Run this and learn one concept."
│
└── COMMANDS.md
    All Commands.
```




