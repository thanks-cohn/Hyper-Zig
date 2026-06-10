# Hyper-Zig Command Reference

This reference documents the current user-facing shell commands by inspecting `kernel/console/shell.zig`. Commands report the current educational kernel state; not-implemented output is intentional proof of a boundary.



## Hyper-Zig validation commands

Hyper-Zig is the hypervisor-first repository; this repository is the active target for hypervisor validation. Use **Zig 0.14.x only** when producing compatibility, build, or smoke evidence. Do not treat Zig 0.15, Zig 0.16, or newer builds as project proof.

Canonical validator:

```sh
./scripts/validate-hyperzig.sh
```

Build-system validation entry point:

```sh
zig build validate-hyperzig
```

Normal build path, which must continue to build without running the full validator:

```sh
zig build
```

The validator runs the Zig version check, the build script, required HV0/HV1 smoke tests, discovered smoke tests under `smoke/`, and ends with a Minimus-Log summary. To inspect the project state from the bottom of the latest validation output, run:

```sh
tail -n 200 logs/latest/validate-hyperzig.log
tail -n 500 logs/latest/validate-hyperzig.log
```

The summary must report branch, commit, Zig path/version, build status, smoke statuses, transcript paths, log paths, completed and missing milestones, blockers, next milestone, readiness, and the PASS/FAIL/BLOCKED reason. Hyper-Zig does not claim Linux guest support or guest execution yet.

## Zig toolchain target

ZIGN01D currently targets **Zig 0.14.x**. Zig 0.16 is not the target for build, smoke, or command-reference validation. Any Zig 0.16-only source, build API, script, or generated command must be labeled and backported to Zig 0.14.x instead of accepted silently.

Run `./scripts/check-zig-version.sh` before using shell-command transcripts as compatibility evidence.

| Command | Milestone where it appeared if known | What it does | Example usage | Expected honest output | What it does not imply |
| --- | --- | --- | --- | --- | --- |
| `help` | V1 diagnostic foundation | Lists shell commands. | `help` | `commands: help mem uptime...` | Does not prove every listed subsystem is implemented. |
| `mem` | V0/V1 foundation | Prints physical memory status. | `mem` | Memory report from `kernel/memory/pmm.zig`. | Does not imply virtual memory or userspace isolation. |
| `uptime` | V1/V3 | Reads `rdtime` twice and reports ticks and delta. | `uptime` | `uptime ticks=... source=rdtime` | Does not imply timer interrupts. |
| `time` | V3 timer readiness | Prints polling time diagnostic. | `time` | `timer: source=rdtime-polling value=...` | Does not imply wall-clock time. |
| `ticks` | V3 timer readiness | Prints raw polling tick diagnostic. | `ticks` | `ticks: source=rdtime-polling value=...` | Does not imply preemption. |
| `heartbeat` | V3 timer readiness | Checks two `rdtime` reads for monotonic diagnostic output. | `heartbeat` | `heartbeat: source=rdtime-polling ... monotonic=yes` | Does not imply an interrupt heartbeat. |
| `reboot` | V0/V1 foundation | Requests QEMU virt finisher reset. | `reboot` | Reset request marker before halt/reset. | Does not imply board-generic reboot support. |
| `shutdown` | V0/V1 foundation | Requests QEMU virt finisher pass/shutdown. | `shutdown` | Shutdown request marker and QEMU exit. | Does not imply ACPI or hardware power management. |
| `log` | V1 diagnostic foundation | Emits a log command marker. | `log` | `log command reached...` | Does not imply a persistent log store. |
| `logs` | V1 diagnostic foundation | Explains that no ring buffer exists. | `logs` | `logs: no ring buffer yet...` | Does not imply kernel log retrieval. |
| `status` | V1-V4 plus COMM/ZBUS summaries | Prints overall kernel status and subsystem summaries. | `status` | Kernel version, UART, timer, trap, MMIO, task/device/syscall/net/phone/comm/zbus lines. | Does not imply missing subsystems are implemented. |
| `machine` | V2 machine boundary | Prints hart, privilege, QEMU assumptions, timer, trap, and interrupt-controller boundary. | `machine` | `machine: hart_id=... privilege=supervisor...` | Does not imply machine-mode CSR access or real hardware proof. |
| `cpu` | V2 machine boundary | Alias for `machine`. | `cpu` | Same as `machine`. | Does not imply CPU feature discovery. |
| `panic-test` | V3 trap/panic readiness | Emits a controlled smoke-safe panic report without halting through the live panic path. | `panic-test` | `panic-test controlled report...` | Does not imply arbitrary panic recovery. |
| `trap-test` | V3 trap readiness | Prints synthetic trap cause names. | `trap-test` | `trap-test: illegal-instruction name=...` and `recovery=not-implemented`. | Does not inject a live fault. |
| `version` | V1 diagnostic foundation | Prints kernel version string. | `version` | `version: ZIGN01D V4 guarded MMIO probe foundation` | Does not imply all future docs are implemented as features. |
| `build` | V1 diagnostic foundation | Prints build mode, target, and output path. | `build` | `build: mode=ReleaseSmall target=riscv64-freestanding-none...` | Does not rebuild the kernel from inside QEMU. |
| `breadcrumbs` | V1 diagnostic foundation | Prints breadcrumb format doctrine. | `breadcrumbs` | `breadcrumbs: format=[ZIGN01D][LEVEL][SUBSYSTEM][CODE] message` | Does not imply persistent breadcrumb storage. |
| `tasks` | V1 diagnostic foundation | Prints cooperative task table/status. | `tasks` | Task status records from `kernel/task/task.zig`. | Does not imply preemptive multitasking. |
| `devices` | V1/V4 device boundary | Prints device registry and boundary statuses. | `devices` | UART/timer active, PLIC placeholder, virtio deferred/missing. | Does not imply virtio drivers. |
| `mmio` | V4 guarded MMIO / BOARD V0 / VIRTIO DISCOVERY V0 | Prints guarded MMIO probe policy, deferred fixed-window results, and the computed virtio discovery table relationship. | `mmio` | `mmio: board=qemu-virt source=board-profile`, `mmio: virtio_discovery=present`, `mmio: virtio_slots=8`, `mmio: virtio_slot_table=computed`. | Does not imply live MMIO scanning, magic reads, or driver negotiation. |
| `virtio` | VIRTIO DISCOVERY V0 | Reports the virtio discovery interface and board-profile source constants. | `virtio` | `virtio: interface=present`, `virtio: base=0x10001000`, `virtio: stride=0x1000`, `virtio: slot_count=8`. | Does not imply live probing, magic reads, driver negotiation, queues, interrupts, virtio-block, or virtio-net. |
| `virtio summary` / `virtio-summary` | VIRTIO DISCOVERY V0 | Summarizes the computed MMIO transport table. | `virtio summary` | `virtio-summary: transport=mmio`, `virtio-summary: slots=8`, `virtio-summary: computed_from=board-profile`. | Does not imply a bound driver or active device. |
| `virtio slots` / `virtio-slots` | VIRTIO DISCOVERY V0 | Prints exactly eight slot addresses computed as `base + index * stride` from BOARD V0 constants. | `virtio slots` | `virtio-slot: index=0 addr=0x10001000 status=expected-by-board-profile` through `index=7 addr=0x10008000`. | Does not imply the slots were read, detected, negotiated, or activated. |
| `heap` | HEAP V0 | Prints live kernel heap state from the bump-reset allocator. | `heap` | `heap: interface=present`, `heap: kind=bump-reset`, total/used/free/count fields, and honest missing-feature lines. | Does not imply individual free, thread safety, userspace allocation, paging, or production allocator maturity. |
| `heap stats` / `heap-stats` | HEAP V0 | Prints compact heap totals and counters. | `heap stats` | `heap-stats: total_bytes=16384`, `heap-stats: used_bytes=...`, `heap-stats: overflow_count=...`. | Does not allocate or reset by itself. |
| `heap alloc-test` / `heap-alloc-test` | HEAP V0 | Resets the heap, allocates 64 bytes at 8-byte alignment, verifies stats changed, and reports pass/fail. | `heap alloc-test` | `heap_used_before=0`, `heap_alloc_size=64`, `heap_alloc_ok=yes`, `heap_used_after_alloc=64`, `heap-alloc-test: result=pass`. | Does not prove general-purpose allocation or free-list behavior. |
| `heap reset-test` / `heap-reset-test` | HEAP V0 | Creates heap usage, resets the heap, verifies used bytes returned to zero, and reports pass/fail. | `heap reset-test` | `heap_reset=ok`, `heap_used_after_reset=0`, `heap-reset-test: result=pass`. | Does not free individual allocations. |
| `heap overflow-test` / `heap-overflow-test` | HEAP V0 | Requests more than the heap total, verifies rejection, verifies used bytes remain zero, and reports pass/fail. | `heap overflow-test` | `heap_overflow_rejected=yes`, `heap_used_after_overflow=0`, `heap_last_error=out-of-memory`, `heap-overflow-test: result=pass`. | Does not imply recovery beyond returning allocation failure. |
| `syscalls` | V1 diagnostic foundation | Prints syscall table entries. | `syscalls` | Entries marked table-only and trap boundary not implemented. | Does not imply userspace syscall ABI. |
| `net` | V1 placeholder | Prints legacy network placeholder status. | `net` | `network driver not implemented...` status. | Does not imply internet access. |
| `ping <target>` | V1 placeholder | Reports ping/network unavailable. | `ping example.com` | Network driver not implemented warning. | Does not send packets. |
| `phone` | V1 placeholder | Prints phone component placeholders. | `phone` | Modem/cellular/audio/SMS missing lines. | Does not imply a phone stack. |
| `call <number>` | V1 placeholder | Reports calls unavailable. | `call 5551234` | Call unavailable warning. | Does not place a call. |
| `sms <number> <message>` | V1 placeholder | Legacy phone SMS placeholder; reports SMS unavailable. | `sms 5551234 hello` | SMS unavailable warning. | Does not send SMS. |
| `comm` | COMM V0 | Prints communication scaffold status. | `comm` | `comm: interface=present`, backends `none`, real services `not-implemented`. | Does not imply host bridge connection. |
| `bridge status` / `bridge-status` | COMM V0 | Prints host bridge scaffold status. | `bridge status` | `bridge: connected=no`, transport/target `none`. | Does not imply a host bridge exists. |
| `net status` / `net-status` | COMM V0 | Prints COMM network scaffold status. | `net status` | Backend `none`, provider `zbus`, internet `not-implemented`. | Does not imply internet. |
| `net get <url>` / `net-get <url>` | COMM V0 | Echoes requested URL and reports GET not implemented. | `net get https://example.com` | `net: get=not-implemented`, `safety=no network request sent`. | Does not send a network request. |
| `sms inbox` / `sms-inbox` | COMM V0 | Prints unavailable SMS inbox scaffold. | `sms inbox` | `sms: inbox=unavailable`. | Does not receive SMS. |
| `sms send <number>` / `sms-send <number>` | COMM V0 | Echoes number and reports send not implemented. | `sms send 5551234 hello` | `sms: send=not-implemented`, `safety=not-sent`. | Does not send SMS. |
| `sms wait` / `sms-wait` | COMM V0 | Reports incoming SMS wait not implemented. | `sms wait` | `sms: wait=not-implemented`. | Does not block for real messages. |
| `modem status` / `modem-status` | COMM V0 | Prints modem scaffold status. | `modem status` | `modem: backend=none`, `real_modem=not-attached`. | Does not imply attached modem hardware. |
| `zbus` | ZBUS scaffold present in current repo | Prints host capability bus scaffold status. | `zbus` | `zbus: interface=present`, transport `none`, providers `none`. | Does not imply a connected host transport. |
| `zbus status` / `zbus-status` | ZBUS scaffold present in current repo | Alias for ZBUS status. | `zbus status` | Same status fields as `zbus`. | Does not imply provider discovery. |
| `zbus ping` / `zbus-ping` | ZBUS scaffold present in current repo | Reports ping not implemented because no transport is connected. | `zbus ping` | `zbus: ping=not-implemented`, `safety=no host request sent`. | Does not contact host services. |
| `zbus providers` / `zbus-providers` | ZBUS scaffold present in current repo | Lists provider scaffold states. | `zbus providers` | Providers `none`; net/sms/modem/files/time not implemented. | Does not imply provider backends. |
| `hv` | HV0 Hypervisor Status Scaffold | Reports hypervisor research scaffold status. Does not imply guest execution or Linux support. | `hv` | `hv: status=research-scaffold`, guest features marked `not-supported-yet` or `MISSING`. | Does not imply VM support, vCPU support, guest execution, second-stage translation, SBI emulation, virtual console, or Linux support. |
| `hv status` / `hv-status` | HV0 Hypervisor Status Scaffold | Reports hypervisor research scaffold status. Does not imply guest execution or Linux support. | `hv status` | Same output as `hv`. | Does not imply guest execution or Linux support. |
| `hv capability` / `hv-capability` | HV1 Capability Detection | Reports the HV1 safe capability surface and the current H-extension status without unsafe probing. | `hv capability` | `hv: capability_detection=implemented`, `hv: capability_source=supervisor-mode-safe-static-policy`, `hv: h_extension=unknown reason=no-safe-detection-yet`, and guest/Linux/VM/vCPU non-claim markers. | Does not imply H-extension presence, VM support, vCPU support, guest memory, guest entry, guest execution, second-stage translation, SBI emulation, virtual console, virtio for Linux, or Linux support. |

## PMM V0 commands

| Command | Milestone where it appeared if known | What it does | Example usage | Expected honest output | What it does not imply |
| --- | --- | --- | --- | --- | --- |
| `pmm` | PMM V0 | Prints PMM interface markers, page size, live counters, managed range, reserved kernel boundary, and non-claims. | `pmm` | `pmm_interface=present`, `pmm_kind=bitmap-v0`, `pmm_page_size=4096`, page counters including invalid/double-free/exhaustion counters, `pmm_managed_region_start=...`, `pmm_managed_region_end=...`, and `production_pmm=not-implemented`. | Does not imply paging, virtual memory, userspace memory, swap, NUMA, or production PMM policy. |
| `pmm stats` / `pmm-stats` | PMM V0 | Prints compact PMM page counters and last error. | `pmm stats` | `pmm_total_pages=...`, `pmm_free_pages=...`, `pmm_used_pages=...`, `pmm_reserved_pages=...`, `pmm_invalid_free_count=...`, `pmm_double_free_count=...`, `pmm_exhaustion_count=...`, `pmm_last_error=...`. | Does not allocate or free by itself. |
| `pmm alloc-test` / `pmm-alloc-test` | PMM V0 | Resets PMM accounting, allocates one physical page, and verifies free/used/allocation counters changed. | `pmm alloc-test` | `pmm_alloc_page_ok=yes`, `pmm_alloc_test=pass`. | Does not map the page into a virtual address space. |
| `pmm free-test` / `pmm-free-test` | PMM V0 | Allocates one page, frees it, and verifies free/used/free counters changed back. | `pmm free-test` | `pmm_free_page_ok=yes`, `pmm_free_test=pass`. | Does not imply arbitrary memory reclamation outside PMM-managed pages. |
| `pmm invalid-free-test` / `pmm-invalid-free-test` | PMM V0 | Attempts to free an address outside the managed range and proves it is rejected. | `pmm invalid-free-test` | `pmm_invalid_free_rejected=yes`, `pmm_last_error=invalid-free`, `pmm-invalid-free-test: result=pass`. | Does not accept invalid physical addresses. |
| `pmm double-free-test` / `pmm-double-free-test` | PMM V0 | Frees an allocated page, tries to free it again, and proves the second free is rejected. | `pmm double-free-test` | `pmm_double_free_rejected=yes`, `pmm_last_error=double-free`, `pmm-double-free-test: result=pass`. | Does not permit double-free success. |
| `pmm exhaustion-test` / `pmm-exhaustion-test` | PMM V0 | Allocates all currently free managed pages, verifies the next allocation is rejected, and prints breadcrumbs. | `pmm exhaustion-test` | `pmm_exhaustion_free_after_fill=0`, `pmm_exhaustion_rejected=yes`, `pmm_last_error=out-of-pages`, `pmm-exhaustion-test: result=pass`. | Does not imply overcommit, swap, or recovery beyond allocation failure. |

## BOARD V0 commands

| Command | Milestone where it appeared if known | What it does | Example usage | Expected honest output | What it does not imply |
| --- | --- | --- | --- | --- | --- |
| `board` | BOARD V0 | Prints the active fixed board identity and explicitly states detection/device-tree parsing are not implemented. | `board` | `board: name=qemu-virt`, `board: arch=riscv64`, `board: source=fixed-assumption`, `board: detection=not-implemented`, `board: device_tree_parse=not-implemented`. | Does not imply live board discovery or real hardware support. |
| `board profile` / `board-profile` | BOARD V0 | Prints fixed QEMU `virt` profile constants for RAM, UART0, virtio-mmio, PLIC, and CLINT. | `board profile` | `board-profile: ram_base=0x80000000`, `ram_size_mib=128`, `uart0_base=0x10000000`, `virtio_mmio_base=0x10001000`, `virtio_mmio_count=8`. | Does not imply those devices have drivers or were probed live. |
| `board devices` / `board-devices` | BOARD V0 / VIRTIO DISCOVERY V0 | Prints assumed board device presence, virtio discovery linkage, and explicitly marks live probing and driver binding as not implemented. | `board devices` | `board-devices: uart0=present-assumed`, `virtio_mmio=present-assumed`, `virtio_discovery=present`, `virtio_slots=8`, `live_probe=not-implemented`. | Does not imply virtio, PLIC, or CLINT driver support. |

## MEMORY V0 commands

| Command | Milestone where it appeared if known | What it does | Example usage | Expected honest output | What it does not imply |
| --- | --- | --- | --- | --- | --- |
| `memory` | MEMORY V0 / HEAP V0 / PMM V0 integration | Prints the fixed QEMU virt model plus current heap allocator stats, PMM presence, and missing memory powers. | `memory` | `memory: heap=implemented-v0`, `memory: pmm=implemented-v0`, `memory: allocator=kernel-bump-reset-v0`, heap counters, and `paging=not-implemented`. | Does not imply dynamic RAM discovery, paging, virtual memory, userspace memory, swap, NUMA, individual heap free, or production PMM behavior. |
| `memmap` | MEMORY V0 | Prints the fixed QEMU virt RAM region and its source. | `memmap` | `memmap: region=ram base=0x80000000 size_bytes=134217728 size_mib=128 source=qemu-virt-assumption`, with live discovery and device-tree parsing marked `not-implemented`. | Does not imply device-tree parsing or live memory probing. |
| `kernel-bounds` | MEMORY V0 | Prints linker-symbol kernel image start, end, and size. | `kernel-bounds` | `kernel-bounds: start=0x...`, `kernel-bounds: end=0x...`, `kernel-bounds: size_bytes=...`. | Does not imply relocation, modules, or userspace address spaces. |

## Hypervisor command details

HV0 and HV1 hypervisor commands are grouped in `docs/hypervisor/HV1_commands.md` so the status-only commands and capability-only commands remain easy to audit together.
