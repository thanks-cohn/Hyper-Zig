# ZIGN01D vs Diosix Engineering Gap Analysis

This document is an evidence-based comparison of the local ZIGN01D checkout at
`/home/big-bro/dev/zign01d` and the local Diosix checkout at
`/home/big-bro/research/diosix`. It does not treat filenames, roadmap entries,
or diagnostic strings as proof of implementation. A subsystem is marked
`IMPLEMENTED` only when executable code performs the claimed work, `PARTIAL`
when a real but incomplete mechanism exists, `STUB` when a named boundary exists
without the mechanism, and `MISSING` when no subsystem exists.

# 1. Executive Summary

ZIGN01D is currently a small, bootable RV64 supervisor-mode kernel foundation
for QEMU `virt`. Its real working core is narrow but useful: assembly entry,
BSS clearing, a linker-defined stack and image layout, a Zig `kmain`, polling
16550 UART I/O, an interactive diagnostic shell, live `rdtime` reads, a
supervisor trap vector that reports and halts on unhandled traps, structured
serial diagnostics, QEMU reset/shutdown, a static device/status registry, and
marker-driven QEMU smoke tests. Those mechanisms are visible in
`boot/entry.S::_start`, `boot/linker.ld`, `kernel/main.zig::kmain`,
`kernel/console/uart.zig`, `kernel/console/shell.zig::start`,
`kernel/arch/riscv64/trap.zig::init`, and `smoke/smoke-v0.sh` through
`smoke/smoke-v4.sh`.

ZIGN01D is not yet a general-purpose operating system kernel. Its physical
memory manager only prints linker and hardcoded QEMU addresses
(`kernel/memory/pmm.zig`); its heap and VMM are explicit TODO stubs
(`kernel/memory/allocator.zig`, `kernel/memory/vmm.zig`); timer interrupts and
PLIC support are stubs (`kernel/interrupt/timer.zig::init`,
`kernel/interrupt/plic.zig::init`); the scheduler has no runnable contexts
(`kernel/scheduler/scheduler.zig`); tasks and syscalls are descriptive tables
(`kernel/task/task.zig`, `kernel/syscall/syscall.zig`); userspace is not entered
(`kernel/main.zig::userspace_init_stub`); and no filesystem exists.

Diosix is a substantially larger machine-mode RISC-V hypervisor. It brings up
multiple physical cores, parses and edits a DTB, discovers RAM and devices,
manages pages with a buddy allocator and reference counts, provides per-core
heaps, creates guests and virtual CPUs, loads an ELF root VM, supports H-extension
stage-2 translation with an Sv39x4 implementation and a PMP fallback, saves and
restores guest architecture state, dispatches exceptions and interrupts,
implements an SBI-facing guest interface, and schedules vCPUs across local and
global run queues. The principal evidence is in
`hypervisor/hw/qemu/entry.s::_start`, `hypervisor/core/boot.zig::bootCpuInit`,
`hypervisor/core/dt.zig::DeviceTreeBlob`,
`hypervisor/core/physmem.zig::init`, `hypervisor/core/alloc.zig::HeapAllocator`,
`hypervisor/core/guest.zig::Guest`, `hypervisor/core/vcore.zig::VirtualCore`,
`hypervisor/core/vm_space.zig::GuestSpace`,
`hypervisor/core/sv39x4.zig::PageTable`,
`hypervisor/core/xint.zig::xint_handler`,
`hypervisor/core/sbi.zig::handle`, and
`hypervisor/core/scheduler.zig::schedule`.

Both projects are kernel-level because both execute freestanding RISC-V code,
own trap/interrupt boundaries, directly access CSRs and MMIO, define their own
link-time memory layout, and run without a host operating system. The difference
is not whether they are low-level; it is the amount of complete resource and
execution machinery behind their entry points.

Diosix is more mature because its named subsystems are connected into a real
boot-to-guest execution path and backed by unit tests. ZIGN01D is still mostly a
diagnostic kernel with honest subsystem boundaries. ZIGN01D becomes serious by
building the dependencies in order: trustworthy CSR and trap context, real timer
interrupts, DTB discovery, a page allocator, a heap, page tables, user entry and
syscalls, then scheduling and drivers. The immediate next action is to implement
Milestone 1, the CSR introspection layer and `csr` shell command.

# 2. Evidence Map

## Table A: ZIGN01D Evidence

| Subsystem | Status | Evidence path | Important functions/modules | Notes |
| --- | --- | --- | --- | --- |
| Boot entry | IMPLEMENTED | `boot/entry.S` | `_start`, `zign01d_boot_hart_id` | Sets stack, clears BSS, saves `a0`, calls `kmain`. |
| Linker layout | IMPLEMENTED | `boot/linker.ld` | `ENTRY(_start)`, `__kernel_start`, `__kernel_end`, stack symbols | Fixed QEMU load address `0x80200000`; one 64 KiB stack. |
| Kernel main | IMPLEMENTED | `kernel/main.zig` | `kmain`, `panic`, `userspace_init_stub` | Initializes current boundaries then enters shell. |
| UART/console | IMPLEMENTED | `kernel/console/uart.zig` | `init`, `putByte`, `write`, `readByteBlocking` | Polling 16550-compatible MMIO at hardcoded `0x10000000`. |
| Shell/commands | IMPLEMENTED | `kernel/console/shell.zig` | `start`, `handle`, command functions | Real polling shell; many commands intentionally report missing features. |
| Panic/logging | PARTIAL | `kernel/panic/panic.zig`, `kernel/log.zig`, `kernel/diag/breadcrumb.zig` | `panicWithCause`, `report`, `log.write` | Structured serial output and halt; no trap-frame dump, unwinder, or retained ring buffer. |
| Physical memory manager | STUB | `kernel/memory/pmm.zig` | `init`, `report` | Reports hardcoded DRAM and linker symbols; allocates no pages. |
| Heap allocator | STUB | `kernel/memory/allocator.zig` | `init` | Explicit TODO; no allocation API. |
| Trap handling | PARTIAL | `boot/entry.S`, `kernel/arch/riscv64/trap.zig` | `zign01d_trap_vector`, `init`, `causeName`, `zign01d_handle_trap` | Reads three CSRs and halts on live traps; no saved register frame or recovery. |
| Interrupt/timer | STUB | `kernel/interrupt/timer.zig` | `init`, `ticks`, diagnostic functions | `rdtime` polling is real; interrupts are explicitly not enabled. |
| Syscall layer | STUB | `kernel/syscall/syscall.zig` | `syscalls`, `init`, `printStatus` | Table only; no `ecall` dispatch or user ABI. |
| VFS/RAMFS/TARFS | MISSING | none | none | Shell status explicitly says filesystem not implemented. |
| Board/platform | PARTIAL | `kernel/console/uart.zig`, `kernel/device/mmio_probe.zig`, `kernel/console/shell.zig` | hardcoded QEMU MMIO constants | QEMU `virt` assumptions are distributed, not represented by a platform object or DTB. |
| CPU/CSR layer | PARTIAL | `kernel/arch/riscv64/cpu.zig` | `hartId`, `readTime`, `readStvec`, `readSie`, `readSip`, `readSstatus` | Safe S-mode reads exist, but no coherent CSR module or complete trap CSR set. |
| External interrupts | STUB | `kernel/interrupt/plic.zig` | `init` | No priority, enable, threshold, claim, or complete operations. |
| VMM/page tables | STUB | `kernel/memory/vmm.zig` | `init` | Explicit TODO; kernel currently relies on firmware-established execution state. |
| Scheduler | STUB | `kernel/scheduler/scheduler.zig` | `init`, `idle` | Logs startup and exposes `wfi`; no queue, context switch, or timeslice. |
| Task model | STUB | `kernel/task/task.zig` | `TaskRecord`, static `tasks`, `printStatus` | Two static records; no saved context, stack ownership, or lifecycle. |
| Userspace/init | STUB | `kernel/main.zig`, `userspace/init/init.zig` | `userspace_init_stub`, `start` | Never transitions to U-mode. |
| Device model | PARTIAL | `kernel/device/device.zig`, `kernel/device/mmio_probe.zig` | `DeviceRecord`, `status`, `probe32` | Honest registry and fixed allowlist; live optional MMIO probing disabled. |
| Tests/smoke | PARTIAL | `smoke/smoke-v0.sh` ... `smoke/smoke-v4.sh`, `tests/*/README.md` | controlled QEMU transcript checks | Strong integration markers; no Zig unit-test suite for core algorithms because those algorithms mostly do not exist yet. |
| Build scripts | IMPLEMENTED | `build.zig`, `scripts/build.sh`, `scripts/run-qemu.sh` | `build`, wrapper scripts | Reproducible single-target kernel build for RV64 freestanding QEMU. |
| Documentation | PARTIAL | `README.md`, `ROADMAP.md`, `docs/*.md` | milestone audits and plans | Extensive and unusually honest in newer audits, but README contains stale claims that userspace and interrupts work. |

## Table B: Diosix Evidence

| Subsystem | Status | Evidence path | Important functions/modules | Notes |
| --- | --- | --- | --- | --- |
| Boot entry | IMPLEMENTED | `hypervisor/hw/qemu/entry.s` | `_start` | Multi-core slab assignment, BSS coordination, stack/mscratch setup, DTB forwarding. |
| Architecture layer | IMPLEMENTED | `hypervisor/core/riscv.zig`, `hypervisor/interface/riscv.zig`, `hypervisor/hw/qemu/*.s` | CSR helpers, `CpuContext`, `ThreadContext`, hardware functions | Broad M/HS/VS CSR and context machinery with test mocks. |
| Hypervisor entry | IMPLEMENTED | `hypervisor/core/main.zig` | `main` | Per-core setup, boot-core serialization, scheduling and guest entry loop. |
| Physical memory manager | IMPLEMENTED | `hypervisor/core/physmem.zig` | `discoverRegions`, `init`, `allocPageSelection`, `freePage`, `findContiguousRegion` | DTB-aware buddy allocation, descriptors, free lists, reference counts, tests. |
| Allocator | IMPLEMENTED | `hypervisor/core/alloc.zig`, `hypervisor/core/riscv.zig` | `HeapAllocator`, `initCPUHeapAllocator`, `getCPUHeapAllocator` | Per-core heap with split/merge, alignment, resize, OOM, and tests. |
| Device tree parsing | IMPLEMENTED | `hypervisor/core/dt.zig` | `DeviceTreeBlob.init`, `parse`, `DeviceTree`, iterators, editing/serialization | Parses, queries, edits, serializes, and tests DTBs and reserved memory. |
| PMP/isolation | IMPLEMENTED | `hypervisor/core/pmp.zig`, `hypervisor/core/vm_space.zig` | `PMPConfig`, `GuestSpace` | PMP fallback plus H-extension paging mode. |
| Trap/interrupt handling | IMPLEMENTED | `hypervisor/hw/qemu/xint.s`, `hypervisor/core/xint.zig` | `hw_xint_init`, `xint_handler`, `dispatch`, handlers | Full context boundary, exception reflection, timer/software/external routing, loop detection. |
| Scheduler | IMPLEMENTED | `hypervisor/core/scheduler.zig` | `init`, `initCpu`, `queue`, `pickNext`, `schedule`, `yield` | Weighted virtual-runtime scheduling with local/global queues and tests. |
| Virtual CPU model | IMPLEMENTED | `hypervisor/core/vcore.zig` | `VirtualCore`, `init`, `fork` | Saved GPR, machine, hypervisor, and guest-supervisor state. |
| Guest model | IMPLEMENTED | `hypervisor/core/guest.zig` | `Guest`, `createGuest`, `terminate`, `fork`, quota methods | Guest lineage, quotas, VMIDs, vCPU lists, trust state, tests. |
| VM memory model | IMPLEMENTED | `hypervisor/core/vm_space.zig`, `hypervisor/core/sv39x4.zig` | `GuestSpace`, `PageTable`, mapping/fault/COW functions | Stage-2 paging and PMP alternatives; mapping protection and COW tests. |
| SBI/hypervisor interface | IMPLEMENTED | `hypervisor/core/sbi.zig`, `hypervisor/interface/sbi.zig` | `handle`, base/timer/reset/HSM/debug-console handlers | Guest ABI boundary with typed extension and error constants. |
| Platform/device model | PARTIAL | `hypervisor/hw/ports/*.yaml`, `scripts/yaml_parser.zig`, `hypervisor/core/boot.zig` | port configuration, DTB device discovery | Real QEMU ports and discovery; not a broad driver ecosystem. |
| Root VM loader | IMPLEMENTED | `hypervisor/core/loader.zig`, `hypervisor/core/boot.zig` | `Loader.load`, `bootCpuInit` | Loads embedded ELF, prepares guest DTB, creates and queues root vCPU. |
| Tests | IMPLEMENTED | inline `test` blocks across `hypervisor/core/*.zig`, `build.zig` | `zig build test` graph | Tests allocators, DT, scheduler, guest, paging, data structures, boot, and more. |
| Documentation/build | IMPLEMENTED | `build.zig`, `scripts/build.sh`, `docs/*.md`, `hypervisor/hw/ports/*.yaml` | dynamic port selection and documented build/run/test flow | Coherent build, architecture, interface, security, and development docs. |

# 3. Subsystem-by-Subsystem Comparison

## 1. Boot path

- **ZIGN01D current state:** `boot/entry.S::_start` installs one linker-defined
  stack, clears BSS, saves the boot hart ID, and calls `kernel/main.zig::kmain`.
  It does not consume the DTB pointer in `a1` and has no secondary-hart path.
- **Diosix current state:** `hypervisor/hw/qemu/entry.s::_start` atomically assigns
  linear CPU IDs, allocates per-CPU slabs, coordinates BSS clearing, initializes
  `mscratch`, preserves the DTB, and calls `hypervisor/core/main.zig::main` on
  every physical core.
- **ZIGN01D is missing:** DTB preservation, explicit privilege assumptions,
  secondary-hart parking/bring-up, and per-hart stacks.
- **Why it matters:** Boot arguments and per-hart state are prerequisites for
  hardware discovery and multicore correctness.
- **Minimum serious implementation:** Preserve `a0`/`a1`, allocate a distinct
  boot stack per supported hart, designate one boot hart, and park others safely.
- **Immediate next task:** Store the incoming DTB pointer beside the boot hart ID
  and expose both through architecture helpers.
- **Acceptance test:** Boot with `-smp 2`, print one boot-hart record and one
  parked-secondary record, and reach the shell without stack corruption.

## 2. Linker and memory layout

- **ZIGN01D current state:** `boot/linker.ld` defines text, rodata, data, BSS, one
  stack, and kernel bounds at a fixed `0x80200000` load address.
- **Diosix current state:** `hypervisor/hw/qemu/linker.ld` defines the hypervisor
  image at `0x80000000`, embedded root VM, BSS, host interface symbols, and a
  page-aligned end used by per-CPU slabs.
- **ZIGN01D is missing:** explicit guard regions, per-CPU stack layout, page-table
  sections, init/reclaimable sections, and assertions against overlap.
- **Why it matters:** Memory allocators and page tables need precise reserved
  ranges; one silent overlap can corrupt the kernel.
- **Minimum serious implementation:** Page-align all regions, export section
  bounds, reserve per-hart stacks, and add linker assertions.
- **Immediate next task:** Add exported rodata/data/stack bounds and document the
  complete physical layout.
- **Acceptance test:** `readelf -S` and runtime diagnostics agree on every bound,
  with no overlap and a page-aligned `__kernel_end`.

## 3. CPU/hart model

- **ZIGN01D current state:** `kernel/arch/riscv64/cpu.zig::hartId` returns the
  boot-time `a0`; all execution is effectively single-hart.
- **Diosix current state:** `hypervisor/core/riscv.zig::CpuContext`,
  `hypervisor/core/pcore.zig::this`, and the assembly CPU slab provide per-core
  identity, allocator, active-vCPU, run queue, and trap accounting.
- **ZIGN01D is missing:** per-hart state, hart-to-CPU mapping, local scheduler
  state, interrupt stacks, and interprocessor coordination.
- **Why it matters:** Global mutable state and one stack cannot safely scale
  beyond one hart.
- **Minimum serious implementation:** A bounded `CpuLocal` array keyed by a
  validated hart index, with per-hart stack and state.
- **Immediate next task:** Define a read-only CPU-local identity record populated
  at boot before adding multicore execution.
- **Acceptance test:** Two harts report distinct IDs and stack ranges while only
  the boot hart initializes global subsystems.

## 4. RISC-V CSR layer

- **ZIGN01D current state:** `kernel/arch/riscv64/cpu.zig` has isolated helpers for
  `rdtime`, `stvec`, `sie`, `sip`, and `sstatus`; trap code reads `scause`, `sepc`,
  and `stval` directly in assembly.
- **Diosix current state:** `hypervisor/interface/riscv.zig::CSR` names the ABI,
  while `hypervisor/core/riscv.zig` provides broad typed helpers and hardware
  state structures.
- **ZIGN01D is missing:** one authoritative CSR module, `sepc`, `scause`, `stval`,
  `satp`, bit definitions, privilege-safe policy, and testable formatting.
- **Why it matters:** Trap, timer, paging, and user-entry work otherwise duplicate
  unsafe inline assembly and privilege assumptions.
- **Minimum serious implementation:** S-mode-safe read/write helpers with named
  constants and a shell diagnostic that never reads M-mode-only CSRs.
- **Immediate next task:** Implement M1 in `kernel/arch/riscv64/csr.zig` and add the
  `csr` command.
- **Acceptance test:** QEMU boots and `csr` prints hart ID, `sstatus`, `sie`, `sip`,
  `stvec`, `sepc`, `scause`, `stval`, and `satp` without trapping.

## 5. Trap frame and exception decoding

- **ZIGN01D current state:** `boot/entry.S::zign01d_trap_vector` reads only
  `scause`, `sepc`, and `stval`, then tail-calls a noreturn panic handler.
  `kernel/arch/riscv64/trap.zig::causeName` decodes a subset of synchronous causes.
- **Diosix current state:** `hypervisor/hw/qemu/xint.s` and
  `hypervisor/core/xint.zig::xint_handler` save complete execution context,
  classify privilege/cause, route interrupts, reflect guest exceptions, and
  restore context.
- **ZIGN01D is missing:** a register-complete trap frame, `sscratch` stack policy,
  interrupt-bit decoding, return path, nested-trap policy, and recoverable handlers.
- **Why it matters:** Syscalls, page faults, timer preemption, and guarded MMIO all
  require returning from traps safely.
- **Minimum serious implementation:** Save all GPRs plus `sepc`, `sstatus`,
  `scause`, and `stval`; pass a frame pointer to Zig; permit an explicit `sret`.
- **Immediate next task:** Implement M2 with a real `TrapFrame` and exhaustive
  supervisor cause decoder.
- **Acceptance test:** A controlled `ecall` and breakpoint reach Zig, preserve
  registers, advance `sepc` only when authorized, and return safely.

## 6. Timer interrupts

- **ZIGN01D current state:** `kernel/interrupt/timer.zig::ticks` reads `rdtime`;
  `init` explicitly says interrupts are not enabled.
- **Diosix current state:** `hypervisor/core/riscv.zig::setTimer`,
  `hypervisor/core/sbi.zig::handleTimer`, and
  `hypervisor/core/xint.zig::handle_interrupt` program and route physical and
  virtual timer events.
- **ZIGN01D is missing:** timer programming through SBI or Sstc, `sie.STIE`, trap
  dispatch, acknowledgement/rearm, and tick accounting.
- **Why it matters:** Preemption, sleeping, deadlines, and scheduler fairness need
  asynchronous time.
- **Minimum serious implementation:** Program a one-shot supervisor timer via the
  available firmware interface, count interrupts, and rearm at a fixed interval.
- **Immediate next task:** Implement M3 only after M2 can return from interrupts.
- **Acceptance test:** At least ten timer interrupts occur while the shell remains
  responsive, and the counter increases without polling commands.

## 7. External interrupt controller support

- **ZIGN01D current state:** `kernel/interrupt/plic.zig::init` is a logging stub.
- **Diosix current state:** `hypervisor/core/boot.zig::bootCpuInit` discovers PLIC
  base addresses from DTB, while `hypervisor/core/xint.zig::handle_interrupt`
  routes external interrupt state toward guests. Diosix does not present a broad
  host driver framework, so its platform interrupt support is real but focused.
- **ZIGN01D is missing:** PLIC context selection, priority, enable, threshold,
  claim, completion, source ownership, and spurious IRQ handling.
- **Why it matters:** Interrupt-driven UART and virtio cannot work without a real
  external interrupt path.
- **Minimum serious implementation:** QEMU PLIC driver for one S-mode hart with
  explicit source registration and claim/complete loop.
- **Immediate next task:** Create a PLIC register model from DTB-discovered base
  and wire one test IRQ source after timer/trap completion.
- **Acceptance test:** A known external IRQ is claimed exactly once, dispatched,
  completed, and does not livelock.

## 8. Device tree parsing

- **ZIGN01D current state:** MISSING; QEMU addresses are hardcoded across UART,
  shell, PMM, and MMIO probe files.
- **Diosix current state:** `hypervisor/core/dt.zig::DeviceTreeBlob` validates and
  parses FDT data; `DeviceTree` supports property lookup, iteration, editing,
  serialization, address cells, and reserved-memory entries.
- **ZIGN01D is missing:** FDT header validation, token walking, string/property
  lookup, cell decoding, reserved-memory parsing, and boot DTB preservation.
- **Why it matters:** Hardcoded maps prevent portability and can cause unsafe MMIO
  or RAM use.
- **Minimum serious implementation:** Read-only, allocation-free parser sufficient
  for `/memory`, `/cpus`, `/chosen`, UART, PLIC, and timebase frequency.
- **Immediate next task:** Implement M4 against the QEMU `virt` DTB with strict
  bounds checking.
- **Acceptance test:** Print discovered memory, UART, PLIC, CPU count, and
  timebase; reject malformed magic and truncated blobs.

## 9. Physical memory map discovery

- **ZIGN01D current state:** `kernel/memory/pmm.zig::report` prints hardcoded DRAM
  base and linker bounds; no size or reserved regions are discovered.
- **Diosix current state:** `hypervisor/core/physmem.zig::discoverRegions` consumes
  DT memory and reservations and classifies RAM, hypervisor memory, and MMIO.
- **ZIGN01D is missing:** RAM ranges, reserved ranges, kernel subtraction,
  overflow validation, and a normalized map.
- **Why it matters:** A page allocator cannot safely own memory it has not
  discovered and excluded.
- **Minimum serious implementation:** Build a bounded normalized region table from
  DTB memory nodes, reservations, kernel image, DTB, and stacks.
- **Immediate next task:** Implement M5 and make `mem` print discovered rather than
  assumed ranges.
- **Acceptance test:** With QEMU `-m 128M` and `-m 256M`, the reported usable end
  changes correctly and never overlaps kernel or DTB ranges.

## 10. Physical memory manager

- **ZIGN01D current state:** STUB in `kernel/memory/pmm.zig`; no page allocation.
- **Diosix current state:** `hypervisor/core/physmem.zig` implements page metadata,
  buddy free lists, contiguous-order allocation, reference counts, and tests.
- **ZIGN01D is missing:** page ownership metadata, free structure, allocation,
  free, double-free detection, and accounting.
- **Why it matters:** Every later dynamic kernel resource depends on reliable
  physical pages.
- **Minimum serious implementation:** A deterministic 4 KiB bitmap allocator is
  sufficient initially; reserve all non-usable regions and expose alloc/free.
- **Immediate next task:** Implement M6 as a bitmap PMM before attempting a buddy
  allocator.
- **Acceptance test:** Allocate every usable page once, detect exhaustion, free in
  shuffled order, reallocate, and preserve reserved pages.

## 11. Heap allocator

- **ZIGN01D current state:** `kernel/memory/allocator.zig::init` is an explicit TODO.
- **Diosix current state:** `hypervisor/core/alloc.zig::HeapAllocator` supports
  aligned allocation, resize, freeing, coalescing, OOM behavior, and tests.
- **ZIGN01D is missing:** an allocator interface, heap region, metadata integrity,
  alignment, free, and OOM policy.
- **Why it matters:** Dynamic task, filesystem, device, and VM structures are not
  practical with only static storage.
- **Minimum serious implementation:** A page-backed kernel allocator with checked
  headers, alignment, free/coalescing, and deterministic OOM failure.
- **Immediate next task:** Implement M7 on top of PMM pages and expose a Zig
  `std.mem.Allocator`.
- **Acceptance test:** Alignment, fragmentation, coalescing, resize, OOM, and
  repeated allocation/free tests pass without corrupting PMM accounting.

## 12. Virtual memory and page tables

- **ZIGN01D current state:** `kernel/memory/vmm.zig` is an explicit TODO.
- **Diosix current state:** `hypervisor/core/sv39x4.zig::PageTable` implements
  stage-2 mappings and COW; `hypervisor/core/vm_space.zig::GuestSpace` selects
  H-extension paging or PMP isolation.
- **ZIGN01D is missing:** Sv39 tables, mapping API, TLB fences, permission model,
  kernel mapping ownership, and fault handling.
- **Why it matters:** Isolation, userspace, guarded mappings, and scalable memory
  management require controlled translation.
- **Minimum serious implementation:** Sv39 kernel page tables with map/unmap/query,
  identity/direct map policy, W^X permissions, and `sfence.vma`.
- **Immediate next task:** Implement M8 after PMM and heap are proven.
- **Acceptance test:** Enable a new `satp`, preserve console execution, map a test
  page, enforce read-only behavior, unmap it, and observe a decoded page fault.

## 13. Kernel/user address split

- **ZIGN01D current state:** MISSING; no U-mode mappings or address-space policy.
- **Diosix current state:** Diosix isolates guest physical spaces rather than a
  conventional monolithic kernel/user split; `GuestSpace` and Sv39x4/PMP enforce
  host/guest boundaries.
- **ZIGN01D is missing:** canonical virtual layout, user range, kernel range,
  trampoline/trap mapping, guard pages, and validation helpers.
- **Why it matters:** Every user pointer and syscall must be constrained by one
  stable address policy.
- **Minimum serious implementation:** Document and enforce a fixed Sv39 lower-half
  user / upper-half kernel layout with unmapped guards.
- **Immediate next task:** Define the layout in code and docs as part of M9 before
  loading init.
- **Acceptance test:** User mappings cannot overlap kernel mappings, and invalid
  user pointers fail validation without kernel faults.

## 14. Userspace/init process

- **ZIGN01D current state:** `kernel/main.zig::userspace_init_stub` prints that
  userspace is not implemented; `userspace/init/init.zig::start` is never entered.
- **Diosix current state:** Diosix loads an ELF root VM through
  `hypervisor/core/loader.zig::Loader.load`, creates a guest/vCPU, prepares a guest
  DTB, and schedules it in `bootCpuInit`.
- **ZIGN01D is missing:** user ELF or embedded image loading, user stack, U-mode
  CSR setup, address space, first context, and exit policy.
- **Why it matters:** A kernel-only shell does not prove an operating-system
  process boundary.
- **Minimum serious implementation:** One embedded init image mapped into one user
  address space and entered with `sret`.
- **Immediate next task:** Implement the user-entry half of M9 after the syscall
  return path exists.
- **Acceptance test:** Init executes in U-mode, issues `write` and `exit`, and a
  deliberate supervisor-memory access is rejected.

## 15. Syscall ABI

- **ZIGN01D current state:** `kernel/syscall/syscall.zig` defines six descriptive
  records but no ABI or dispatch; trap cause 8 is only named.
- **Diosix current state:** `hypervisor/core/sbi.zig::handle` dispatches guest
  environment calls across base, timer, reset, HSM, debug console, and Diosix
  extensions with typed results.
- **ZIGN01D is missing:** register convention, syscall numbers, `ecall` dispatch,
  user-copy validation, return values, errors, and compatibility versioning.
- **Why it matters:** Userspace cannot request kernel services without a stable,
  validated boundary.
- **Minimum serious implementation:** RV64 ABI using `a7` number, `a0..a5`
  arguments, `a0` result, with `write`, `yield`, and `exit` first.
- **Immediate next task:** Implement syscall dispatch in M9 against a real trap
  frame and user address validator.
- **Acceptance test:** User init performs valid and invalid syscalls; unknown
  numbers return a defined error and invalid pointers do not crash the kernel.

## 16. Scheduler

- **ZIGN01D current state:** `kernel/scheduler/scheduler.zig` logs a stub and offers
  only `idle()`.
- **Diosix current state:** `hypervisor/core/scheduler.zig` maintains weighted
  virtual-runtime queues, per-core and global queues, context selection, yielding,
  and unit tests.
- **ZIGN01D is missing:** run queue, scheduling policy, timer integration, blocked
  state, context switch, and synchronization.
- **Why it matters:** Multiple independent execution contexts require a
  deterministic owner of CPU time.
- **Minimum serious implementation:** Single-hart round-robin scheduler with a
  bounded intrusive ready queue and timer-driven preemption.
- **Immediate next task:** Implement M10 only after timer interrupts and saved task
  contexts exist.
- **Acceptance test:** Three kernel tasks increment independent counters under
  forced preemption, then one blocks and later resumes without starvation.

## 17. Task/thread model

- **ZIGN01D current state:** `kernel/task/task.zig` contains two static status
  records and no executable task context.
- **Diosix current state:** `hypervisor/core/vcore.zig::VirtualCore` owns GPRs,
  machine/guest CSR state, scheduling state, timer state, and guest association.
- **ZIGN01D is missing:** saved registers, kernel stack, state transitions,
  ownership, task ID allocation, blocking/wakeup, and teardown.
- **Why it matters:** A scheduler cannot switch descriptive table rows.
- **Minimum serious implementation:** `Task` with trap/context frame, kernel stack,
  state enum, queue links, and lifecycle invariants.
- **Immediate next task:** Define and test the task context structure in M10 before
  writing the context-switch assembly.
- **Acceptance test:** Context switching preserves all callee/caller-visible
  registers and task-local stack contents over thousands of switches.

## 18. Process/address-space model

- **ZIGN01D current state:** MISSING; tasks do not own address spaces or resources.
- **Diosix current state:** `hypervisor/core/guest.zig::Guest` owns a `GuestSpace`,
  VMID, vCPUs, lineage, quotas, trust, and lifecycle.
- **ZIGN01D is missing:** process identity, address-space ownership, handles,
  parent/child policy, resource cleanup, and fault termination.
- **Why it matters:** Userspace isolation and cleanup need an ownership root above
  threads.
- **Minimum serious implementation:** One `Process` containing an Sv39 root,
  user-memory map, thread list, exit state, and kernel-owned handles.
- **Immediate next task:** Add the minimal one-process model in M9, then generalize
  it only after init works.
- **Acceptance test:** Destroying a process reclaims all user pages and tasks while
  leaving kernel mappings and other processes intact.

## 19. VFS/filesystem model

- **ZIGN01D current state:** MISSING; no VFS, RAMFS, TARFS, inode, file, or mount
  implementation exists.
- **Diosix current state:** Diosix is a hypervisor and delegates normal filesystems
  to its root VM; no host VFS is claimed in the inspected hypervisor sources.
- **ZIGN01D is missing:** object model, path walk, file descriptors, read/write,
  mount policy, and an initial filesystem image.
- **Why it matters:** Userspace needs named persistent or packaged objects beyond
  raw syscalls.
- **Minimum serious implementation:** Read-only initramfs/TARFS behind a tiny VFS
  with root, lookup, open, read, close, and stat.
- **Immediate next task:** Implement M11 only after user pointers and process-owned
  descriptor tables exist.
- **Acceptance test:** Init opens and reads two files from an embedded archive;
  missing paths return a defined error and malformed archives are rejected.

## 20. Virtio or device driver model

- **ZIGN01D current state:** `kernel/device/device.zig` is a status registry;
  `kernel/device/mmio_probe.zig` has a fixed allowlist with live reads disabled;
  no virtqueue or device protocol exists.
- **Diosix current state:** Platform discovery and guest interrupt routing exist,
  but the hypervisor is not itself a broad virtio device stack; guest Linux owns
  most device drivers.
- **ZIGN01D is missing:** bus/transport abstraction, feature negotiation, DMA-safe
  memory, virtqueues, IRQ routing, driver binding, and device lifecycle.
- **Why it matters:** Storage and networking require real asynchronous devices,
  not registry entries.
- **Minimum serious implementation:** DTB-enumerated virtio-mmio transport plus one
  driver, preferably entropy or block before networking.
- **Immediate next task:** Implement M12 with transport reset, status negotiation,
  one queue, and interrupt/poll fallback.
- **Acceptance test:** The driver negotiates a real QEMU device, submits a request,
  validates completion, and survives device absence without a trap.

## 21. Security/isolation model

- **ZIGN01D current state:** MISSING beyond Rust-like Zig bounds where applicable
  and honest privilege avoidance; there is no page-based kernel/user isolation.
- **Diosix current state:** `hypervisor/core/pmp.zig::PMPConfig`,
  `hypervisor/core/vm_space.zig::GuestSpace`, stage-2 paging, trust flags, quotas,
  and guest lineage establish real isolation mechanisms.
- **ZIGN01D is missing:** threat model, memory permissions, user-copy boundary,
  capability/handle policy, W^X, and fault containment.
- **Why it matters:** One malformed user pointer or driver DMA request can corrupt
  the entire system.
- **Minimum serious implementation:** Sv39 isolation, W^X, validated user copies,
  kernel stack guards, and process termination on user faults.
- **Immediate next task:** Write and enforce the first threat model during M8/M9,
  beginning with memory isolation invariants.
- **Acceptance test:** Automated negative tests prove user code cannot read/write
  kernel text/data or another process and cannot map executable writable pages.

## 22. Hypervisor/guest model

- **ZIGN01D current state:** MISSING; it is currently an S-mode kernel, not a
  machine-mode hypervisor.
- **Diosix current state:** `Guest`, `VirtualCore`, `GuestSpace`, SBI emulation,
  H-extension state, PMP fallback, root VM loading, and scheduling form a real
  guest execution model.
- **ZIGN01D is missing:** all guest, vCPU, stage-2, virtual interrupt, VMID, SBI,
  and machine-mode ownership machinery.
- **Why it matters:** It matters only if ZIGN01D chooses virtualization as a product
  requirement; it is not required for a serious conventional kernel.
- **Minimum serious implementation:** Do not start this until the kernel has PMM,
  VMM, traps, scheduler, and userspace; then prototype H-extension discovery and
  one isolated guest.
- **Immediate next task:** Keep hypervisor work at P4 and explicitly defer it while
  completing M1 through M12.
- **Acceptance test:** Future work must boot one guest with isolated stage-2 memory,
  virtual timer/SBI console, and host survival after guest failure.

## 23. Testing/smoke system

- **ZIGN01D current state:** `smoke/smoke-v0.sh` through `smoke/smoke-v4.sh` build,
  boot QEMU, issue commands, capture transcripts, require real markers, and reject
  selected fake-success claims. Algorithmic unit tests are effectively absent.
- **Diosix current state:** Inline Zig tests cover DT parsing, allocator behavior,
  buddy allocation, scheduling, guest lifecycle, paging/COW, data structures, and
  boot; `build.zig` exposes test and run steps.
- **ZIGN01D is missing:** unit tests for pure logic, malformed-input tests, fault
  injection, repeatability/stress tests, and CI architecture.
- **Why it matters:** QEMU marker tests prove integration but are poor at isolating
  allocator and parser invariants.
- **Minimum serious implementation:** Keep smoke tests and add host-runnable Zig
  tests for every pure parser/allocator/scheduler component.
- **Immediate next task:** Add unit tests with M4 and M6 rather than postponing all
  testing until integration.
- **Acceptance test:** One command runs unit tests plus all smoke versions, reports
  exact failures, and leaves reproducible transcripts.

## 24. Documentation/proof system

- **ZIGN01D current state:** Milestone audits and smoke transcripts are a strong
  practice, but `README.md` still says interrupts, scheduler, and userspace work in
  sections contradicted by current source and newer audits.
- **Diosix current state:** `docs/architecture.md`, `docs/build.md`,
  `docs/interface.md`, `docs/security.md`, and `docs/run.md` align with substantial
  code and tests, though implementation must remain the authority.
- **ZIGN01D is missing:** one authoritative status index, command reference,
  subsystem ownership map, and release checklist that rejects stale claims.
- **Why it matters:** In kernel work, inaccurate documentation causes unsafe design
  assumptions and fake maturity.
- **Minimum serious implementation:** Maintain a milestone index, command reference,
  audit per milestone, and evidence links to exact smoke transcripts.
- **Immediate next task:** Add `docs/COMMAND_REFERENCE.md` and
  `docs/MILESTONE_INDEX.md` in M1 and reconcile stale README claims incrementally.
- **Acceptance test:** Every claimed implemented subsystem links to code and a test;
  every stub is labeled, and a documentation grep finds no known false success
  statement.

# 4. Ranking of Gaps

| Priority | Gap | Current evidence | Required outcome | Concrete next action |
| --- | --- | --- | --- | --- |
| P0 | Coherent CSR layer | scattered helpers in `kernel/arch/riscv64/cpu.zig` | safe, named S-mode CSR access | Implement M1 `csr.zig` and smoke it. |
| P0 | Returnable full trap frame | three CSR arguments in `boot/entry.S` | complete saved context and `sret` path | Implement M2 trap entry/exit assembly. |
| P0 | DTB parser and boot DTB preservation | MISSING | validated QEMU hardware description | Implement M4 parser with malformed-input tests. |
| P0 | Discovered physical memory map | hardcoded report in `pmm.zig` | normalized usable/reserved ranges | Implement M5 from DTB plus linker exclusions. |
| P0 | Physical page allocator | STUB | reliable 4 KiB allocation/free/accounting | Implement M6 bitmap PMM. |
| P0 | Kernel heap | STUB | checked dynamic allocation | Implement M7 page-backed allocator. |
| P0 | Kernel page tables | STUB | owned Sv39 mappings and permissions | Implement M8 VMM. |
| P1 | Kernel/user split | MISSING | enforced address policy | Define and enforce layout in M9. |
| P1 | U-mode init | explicit stub | first isolated user execution | Load and enter embedded init in M9. |
| P1 | Syscall ABI | table-only stub | real `ecall` dispatch and safe user copy | Implement `write`, `yield`, `exit` in M9. |
| P1 | Security baseline | MISSING | W^X, user-copy checks, fault containment | Add negative isolation tests in M9. |
| P2 | Timer interrupts | polling only | periodic asynchronous tick | Implement M3 after returnable traps. |
| P2 | Task contexts | static table | executable stack/register ownership | Define `Task` and context switch in M10. |
| P2 | Scheduler | STUB | preemptive ready/blocked task execution | Implement M10 round robin. |
| P2 | Process lifecycle | MISSING | address-space and resource ownership | Add minimal `Process` in M9/M10. |
| P3 | PLIC | STUB | external IRQ claim/complete routing | Add QEMU PLIC after M4 and M3. |
| P3 | VFS/initramfs | MISSING | user-visible files and descriptors | Implement M11 TARFS-backed VFS. |
| P3 | Virtio transport/driver | deferred registry only | negotiated queue and completed I/O | Implement M12 one virtio-mmio device. |
| P3 | Platform abstraction | hardcoded constants | DTB-backed board/device descriptions | Move UART/PLIC/virtio bases behind platform data. |
| P4 | Multicore scheduling | single hart | per-hart stacks, CPU-local state, IPIs | Start only after M10 single-hart correctness. |
| P4 | Hypervisor/guest model | MISSING | optional H-extension guest isolation | Defer until kernel roadmap is complete. |

# 5. No-Bullshit Roadmap

Exactly twelve milestones follow. M1 through M5 are intentionally narrow and
independently finishable.

## M1: CSR introspection command

- **Goal:** Centralize privilege-safe supervisor CSR reads and expose live values
  through a `csr` shell command.
- **Files likely to change:** `kernel/console/shell.zig`, `README.md`.
- **Files likely to be created:** `kernel/arch/riscv64/csr.zig`,
  `smoke/smoke-csr-v0.sh`, `docs/V5_CSR_V0_AUDIT.md`,
  `docs/COMMAND_REFERENCE.md`, `docs/MILESTONE_INDEX.md`.
- **What not to do:** Do not read M-mode-only CSRs from S-mode, infer privilege
  from inaccessible CSRs, add trap recovery, or claim timer/paging support.
- **Implementation steps:** Add inline read helpers; source hart ID from saved boot
  state; print stable names and hex values; route `csr` in shell; add smoke markers;
  document the privilege policy.
- **Acceptance test:** Build, boot, run `csr`, print hart ID, trap vector, cause, and
  all requested readable S-mode values, then shut down without panic.
- **Smoke command:** `./smoke/smoke-csr-v0.sh`
- **Expected output pattern:** `csr: hart_id=0`, `csr: stvec=0x...`,
  `csr: scause=0x...`, and no `[ZIGN01D][PANIC]`.
- **Rollback plan:** Remove the new command/module/docs/smoke file and restore the
  shell import/dispatch/help lines; existing CPU helpers remain untouched.

## M2: Real trap frame and cause decoder

- **Goal:** Save complete integer context and return safely from selected traps.
- **Files likely to change:** `boot/entry.S`, `kernel/arch/riscv64/trap.zig`,
  `kernel/panic/panic.zig`.
- **Files likely to be created:** `docs/V6_TRAP_FRAME_AUDIT.md`,
  `smoke/smoke-trap-frame-v0.sh`.
- **What not to do:** Do not skip arbitrary faulting instructions or call every
  trap recoverable.
- **Implementation steps:** Define aligned `TrapFrame`; swap stack via `sscratch`;
  save/restore all GPRs and CSRs; decode interrupt bit and causes; implement
  explicit resume decisions; add diagnostics.
- **Acceptance test:** Controlled breakpoint and S-mode ecall preserve registers,
  report decoded causes, and return; illegal load still panics honestly.
- **Smoke command:** `./smoke/smoke-trap-frame-v0.sh`
- **Expected output pattern:** `trap-frame: saved=yes`, `trap-return: ok`, no register
  mismatch marker.
- **Rollback plan:** Restore the prior noreturn vector and remove only M2-specific
  recovery commands/tests.

## M3: Machine/supervisor timer interrupt proof

- **Goal:** Deliver and rearm real timer interrupts without losing shell input.
- **Files likely to change:** `kernel/interrupt/timer.zig`,
  `kernel/arch/riscv64/trap.zig`, `kernel/arch/riscv64/csr.zig`.
- **Files likely to be created:** `kernel/arch/riscv64/sbi.zig`,
  `smoke/smoke-timer-irq-v0.sh`, `docs/V7_TIMER_IRQ_AUDIT.md`.
- **What not to do:** Do not call polling ticks interrupts or introduce a scheduler.
- **Implementation steps:** Detect supported timer programming path; program first
  deadline; set SIE/STIE; dispatch supervisor timer cause; increment and rearm;
  expose counter command.
- **Acceptance test:** Counter increases asynchronously to at least ten while shell
  commands still execute and shutdown succeeds.
- **Smoke command:** `./smoke/smoke-timer-irq-v0.sh`
- **Expected output pattern:** `timer-irq: enabled=yes count=` with increasing
  nonzero counts.
- **Rollback plan:** Clear STIE/SIE, restore polling-only `timer.zig`, and retain M2
  trap-frame functionality.

## M4: DTB parser for QEMU virt

- **Goal:** Parse the boot FDT safely without heap allocation.
- **Files likely to change:** `boot/entry.S`, `kernel/main.zig`,
  `kernel/arch/riscv64/boot.zig`.
- **Files likely to be created:** `kernel/platform/fdt.zig`,
  `kernel/platform/qemu_virt.zig`, `smoke/smoke-dtb-v0.sh`,
  `docs/V8_DTB_AUDIT.md`.
- **What not to do:** Do not copy Diosix parsing code, mutate the DTB, or support the
  entire FDT specification initially.
- **Implementation steps:** Preserve `a1`; validate header and block bounds; walk
  structure tokens; decode strings and cells; expose read-only queries; discover
  memory, UART, PLIC, CPUs, and timebase.
- **Acceptance test:** Host unit tests reject malformed/truncated blobs and QEMU
  smoke prints correct discovered nodes.
- **Smoke command:** `./smoke/smoke-dtb-v0.sh`
- **Expected output pattern:** `dtb: valid=yes`, `uart=0x10000000`,
  `memory_base=0x80000000`.
- **Rollback plan:** Keep hardcoded platform constants active behind one switch,
  remove DTB selection, and retain parser tests for repair.

## M5: RAM map from DTB instead of hardcoded memory

- **Goal:** Produce an authoritative usable/reserved physical map.
- **Files likely to change:** `kernel/memory/pmm.zig`, `kernel/main.zig`,
  `kernel/console/shell.zig`, `boot/linker.ld`.
- **Files likely to be created:** `kernel/memory/map.zig`,
  `smoke/smoke-memory-map-v0.sh`, `docs/V9_MEMORY_MAP_AUDIT.md`.
- **What not to do:** Do not allocate pages yet or assume one contiguous range after
  exclusions.
- **Implementation steps:** Read all DT memory ranges/reservations; subtract kernel,
  DTB, stacks, and firmware reservations; normalize and print regions; reject
  overflow/overlap.
- **Acceptance test:** QEMU memory sizes produce matching usable totals with no
  reserved overlap.
- **Smoke command:** `./smoke/smoke-memory-map-v0.sh`
- **Expected output pattern:** `memory-map: source=dtb`, `usable_bytes=`,
  `overlap_errors=0`.
- **Rollback plan:** Revert `mem` to the linker-only report while leaving DTB parser
  available for diagnosis.

## M6: Physical page allocator

- **Goal:** Allocate and free discovered 4 KiB physical pages correctly.
- **Files likely to change:** `kernel/memory/pmm.zig`, `kernel/main.zig`.
- **Files likely to be created:** `kernel/memory/bitmap.zig`,
  `smoke/smoke-pmm-v0.sh`, `docs/V10_PMM_AUDIT.md`.
- **What not to do:** Do not begin with a buddy allocator or allocate MMIO/reserved
  pages.
- **Implementation steps:** Place bounded bitmap metadata; mark exclusions; add
  alloc/free; validate alignment/range/state; expose counters; add host tests.
- **Acceptance test:** Exhaustion, free/reuse, double-free, and reserved-page tests
  pass; runtime self-test leaves counters unchanged.
- **Smoke command:** `./smoke/smoke-pmm-v0.sh`
- **Expected output pattern:** `pmm: selftest=pass free_before=` and equal
  `free_after=`.
- **Rollback plan:** Disable PMM consumers, retain discovered map, and restore
  report-only behavior.

## M7: Page-backed kernel heap

- **Goal:** Provide a tested Zig allocator for kernel dynamic objects.
- **Files likely to change:** `kernel/memory/allocator.zig`, `kernel/main.zig`.
- **Files likely to be created:** `kernel/memory/heap.zig`,
  `smoke/smoke-heap-v0.sh`, `docs/V11_HEAP_AUDIT.md`.
- **What not to do:** Do not silently leak, panic on normal OOM, or expose heap
  pointers to userspace.
- **Implementation steps:** Reserve PMM pages; define blocks; implement aligned
  alloc/free/resize/coalescing; add corruption checks and stats; wrap as
  `std.mem.Allocator`.
- **Acceptance test:** Unit and QEMU self-tests cover alignment, fragmentation,
  coalescing, resize, OOM, and full reclamation.
- **Smoke command:** `./smoke/smoke-heap-v0.sh`
- **Expected output pattern:** `heap: selftest=pass in_use=0 corruption=0`.
- **Rollback plan:** Remove all heap consumers and return to static allocations while
  preserving PMM.

## M8: Sv39 kernel virtual memory

- **Goal:** Make ZIGN01D own its page tables and memory permissions.
- **Files likely to change:** `kernel/memory/vmm.zig`, `kernel/main.zig`,
  `boot/linker.ld`, trap fault handling.
- **Files likely to be created:** `kernel/arch/riscv64/page_table.zig`,
  `smoke/smoke-vmm-v0.sh`, `docs/V12_VMM_AUDIT.md`.
- **What not to do:** Do not map everything RWX or enable `satp` before validating
  the complete execution path.
- **Implementation steps:** Define PTE flags; allocate tables; map kernel sections
  with W^X; map UART; install `satp`; fence; add map/unmap/query and fault proof.
- **Acceptance test:** Kernel and shell survive table switch; permissions are
  correct; deliberate unmapped access produces a decoded fault.
- **Smoke command:** `./smoke/smoke-vmm-v0.sh`
- **Expected output pattern:** `vmm: mode=sv39 active=yes wx_pages=0`.
- **Rollback plan:** Boot with paging disabled via a compile-time switch and retain
  table construction tests.

## M9: First U-mode init and syscall ABI

- **Goal:** Run one isolated init program with `write`, `yield`, and `exit` syscalls.
- **Files likely to change:** `kernel/syscall/syscall.zig`,
  `kernel/arch/riscv64/trap.zig`, `kernel/task/task.zig`, `userspace/init/init.zig`,
  `kernel/main.zig`.
- **Files likely to be created:** `kernel/process/process.zig`,
  `kernel/memory/user_copy.zig`, `kernel/arch/riscv64/user_entry.S`,
  `smoke/smoke-userspace-v0.sh`, `docs/V13_USERSPACE_AUDIT.md`.
- **What not to do:** Do not run init in S-mode, trust raw user pointers, or expose
  kernel addresses.
- **Implementation steps:** Define address split and process; map init text/data/
  stack; build user trap context; `sret` to U-mode; dispatch ecall ABI; validate
  copies; terminate cleanly.
- **Acceptance test:** U-mode init prints through syscall, yields, exits, and is
  killed rather than crashing kernel on forbidden access.
- **Smoke command:** `./smoke/smoke-userspace-v0.sh`
- **Expected output pattern:** `init: privilege=user`, `hello from init`,
  `process-exit: code=0`.
- **Rollback plan:** Disable user launch and return to kernel shell while retaining
  VMM and syscall unit tests.

## M10: Preemptive task scheduler

- **Goal:** Schedule multiple saved contexts with timer preemption and blocking.
- **Files likely to change:** `kernel/scheduler/scheduler.zig`,
  `kernel/task/task.zig`, timer/trap code.
- **Files likely to be created:** `kernel/arch/riscv64/context_switch.S`,
  `smoke/smoke-scheduler-v0.sh`, `docs/V14_SCHEDULER_AUDIT.md`.
- **What not to do:** Do not add multicore work stealing, priorities, or CFS before
  single-hart invariants pass.
- **Implementation steps:** Implement task states and stacks; bounded ready queue;
  context switch; timer timeslice; block/wake; idle task; lifecycle accounting.
- **Acceptance test:** Three tasks make progress, one sleeps/wakes, register canaries
  survive, and no task starves over a fixed run.
- **Smoke command:** `./smoke/smoke-scheduler-v0.sh`
- **Expected output pattern:** `scheduler: preemptive=yes switches=` and per-task
  counters greater than zero.
- **Rollback plan:** Disable preemption and run one task cooperatively while keeping
  context structures testable.

## M11: Read-only initramfs and minimal VFS

- **Goal:** Give userspace a real file-descriptor and pathname boundary.
- **Files likely to change:** syscall, process, build, and init files.
- **Files likely to be created:** `kernel/fs/vfs.zig`, `kernel/fs/tarfs.zig`,
  `kernel/fs/fd_table.zig`, `smoke/smoke-vfs-v0.sh`,
  `docs/V15_VFS_AUDIT.md`.
- **What not to do:** Do not implement writes, caching, permissions, or a disk
  filesystem before read-only semantics are proven.
- **Implementation steps:** Embed archive; validate TAR bounds/checksums; construct
  read-only nodes; implement lookup/open/read/close/stat; add process FD ownership.
- **Acceptance test:** Init reads known files, EOF and missing paths behave correctly,
  and malformed archive tests fail closed.
- **Smoke command:** `./smoke/smoke-vfs-v0.sh`
- **Expected output pattern:** `vfs: root=tarfs`, `read:/etc/banner bytes=`.
- **Rollback plan:** Remove filesystem syscalls and boot the same embedded init
  directly.

## M12: DTB-backed PLIC and one virtio-mmio driver

- **Goal:** Complete one real interrupt-capable device I/O path.
- **Files likely to change:** `kernel/interrupt/plic.zig`,
  `kernel/device/mmio_probe.zig`, `kernel/device/device.zig`, DTB platform data.
- **Files likely to be created:** `kernel/device/virtio/mmio.zig`,
  `kernel/device/virtio/queue.zig`, one device driver,
  `smoke/smoke-virtio-v0.sh`, `docs/V16_VIRTIO_AUDIT.md`.
- **What not to do:** Do not claim virtio from magic detection, assume queue sizes,
  or enable DMA without physical/virtual translation checks.
- **Implementation steps:** Discover transport and IRQ; reset; negotiate features;
  allocate DMA-safe queue; submit one request; claim/complete IRQ; validate used
  ring; handle absent device.
- **Acceptance test:** A real QEMU device completes one request with verified data,
  IRQ accounting, and clean absence/error behavior.
- **Smoke command:** `./smoke/smoke-virtio-v0.sh`
- **Expected output pattern:** `virtio-mmio: negotiated=yes queue_ready=yes`,
  `request: complete status=ok`.
- **Rollback plan:** Disable driver binding and return device status to `deferred`
  without removing DTB, PMM, or PLIC foundations.

# 6. First Implementable Task

The first implementable task is M1 only: create a real RISC-V supervisor CSR
introspection layer, route a `csr` shell command, add a dedicated QEMU smoke test,
and document exactly which CSRs are safe to read in the current execution mode.

The implementation must use the saved boot `a0` value for hart ID because
`mhartid` is a machine-mode CSR and ZIGN01D runs in supervisor mode under OpenSBI
or compatible firmware. It may read supervisor CSRs `sstatus`, `sie`, `sip`,
`stvec`, `sepc`, `scause`, `stval`, and `satp`. It must not probe machine CSRs and
hope to recover from illegal instructions, because the current trap path is
noreturn and cannot safely resume. The immediate next action is to implement M1
and stop before M2.
