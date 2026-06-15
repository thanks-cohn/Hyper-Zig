# Hyper-Zig Textbook

## Table of Contents

### Part I — The Foundations

Page 1 — HV01 — The Virtual Machine Object
Source: vm.zig

Page 2 — HV02 — Capability Detection
Source: capability.zig

Page 3 — HV03 — The Virtual CPU Object
Source: vcpu.zig

Page 4 — HV04 — Guest Memory
Source: guest_memory.zig

---

### Part II — Preparing a Guest

Page 5 — HV05 — Guest Images
Source: guest_image.zig

Page 6 — HV06 — Guest Entry
Source: guest_entry.zig

Page 7 — HV07 — Guest Address Space
Source: guest_address_space.zig

Page 8 — HV08 — Guest Exit Metadata
Source: guest_exit.zig

Page 9 — HV09 — Controlled Guest Run Attempts
Source: guest_run_attempt.zig

Page 10 — HV10 — Guest Execution Gates
Source: guest_execution.zig

---

### Part III — Memory Translation

Page 11 — HV11 — Second Stage Translation
Source: second_stage.zig

Page 12 — HV12 — Stage-2 Translation Tables
Source: stage2_table.zig

Page 13 — HV13 — Guest Boot Packages
Source: boot_package.zig

---

### Part IV — Talking To The Guest

Page 14 — HV14 — Device Tree Concepts
Source: guest_dtb.zig

Page 15 — HV15 — Supervisor Binary Interface (SBI)
Source: sbi.zig

Page 16 — HV16 — Virtual Timers
Source: virtual_timer.zig

Page 17 — HV17 — Binary Device Tree Generation
Source: binary_fdt.zig

Page 18 — HV18 — Linux Handoff Validation
Source: linux_handoff.zig

Page 19 — HV19 — SBI Console Mediation
Source: sbi_console.zig

Page 20 — HV20 — SBI Dispatch Integration
Source: sbi_dispatch.zig

---

### Part V — Guest Context And Return Paths

Page 21 — HV21 — Guest Context Preparation
Source: guest_context.zig

Page 22 — HV22 — Trap Return Planning
Source: trap_plan.zig

Page 23 — HV23 — Guest Entry Assembly Stubs
Source: entry_stub.zig

---

### Part VI — Hardware Virtualization

Page 24 — HV24 — The RISC-V H Extension
Source: h_extension.zig

Page 25 — HV25 — HGATP Candidate Construction
Source: hgatp_candidate.zig

Page 26 — HV26 — HGATP Activation Readiness
Source: hgatp_activation_readiness.zig

Page 27 — HV27 — HGATP Write Planning
Source: hgatp_write_plan.zig

Page 28 — HV28 — HGATP Write Gates
Source: hgatp_write_gate.zig

Page 29 — HV29 — HGATP Write Boundaries
Source: hgatp_write_boundary.zig

Page 30 — HV30 — HGATP Write Attempts
Source: hgatp_write_attempt.zig

Page 31 — HV31 — HGATP CSR Interface
Source: hgatp_csr_interface.zig

Page 32 — HV32 — HGATP CSR Result Accounting
Source: hgatp_csr_result.zig

---

### Future Milestones

Page 33 — Guest Translation Activation

Page 34 — Guest Instruction Execution

Page 35 — Guest Trap Handling

Page 36 — Multi-vCPU Guests

Page 37 — Linux Early Boot

Page 38 — BusyBox Guest Boot

Page 39 — Alpine Guest Boot

Page 40 — Multi-Guest Hypervisor Operation

---

## Learning Flow
```
VM
↓
Capabilities
↓
vCPU
↓
Memory
↓
Images
↓
Entry
↓
Address Space
↓
Execution Preparation
↓
Translation
↓
Boot Packaging
↓
SBI
↓
Guest Context
↓
Trap Return
↓
Hardware Virtualization
↓
HGATP
↓
Guest Execution
↓
Linux
↓
BusyBox
↓
Alpine
```
