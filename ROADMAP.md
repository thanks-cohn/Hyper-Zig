# ZIGN01D Roadmap

ZIGN01D is a RISC-V-first operating system stack built for total inspectability.

The goal is not merely to be open source. The goal is to be open-understandable.

Every layer should answer:

- What happened?
- Where did it happen?
- What owns this state?
- What owns this memory?
- What test proves this works?
- What file should be inspected next?

ZIGN01D must not become an empty carton facsimile of an operating system. No fake green checkmarks. No hollow victories. No decorative commands. Every milestone must leave living proof.

---

## Core Doctrine

ZIGN01D is built around five rules:

1. No silent failure.
2. No fake success.
3. No undocumented magic.
4. No unowned state.
5. No milestone without proof.

Every subsystem must eventually provide:

- Init path
- Status path
- Failure path
- Inspect hint
- Smoke proof
- Documentation
- Ownership model

Every test should answer a real question. Every log should tell a story. Every breadcrumb should lead us home.

---

## Phase 0: V0 Boot Proof

Status: achieved locally.

Purpose: prove that the kernel is not theoretical.

Proven capabilities:

- RISC-V 64 freestanding Zig kernel builds.
- QEMU virt boots through OpenSBI.
- Kernel reaches `_start` and `kmain`.
- UART works at QEMU virt MMIO `0x10000000`.
- Interactive shell works.
- Manual commands work: `help`, `mem`, `uptime`, `shutdown`.
- QEMU shutdown works through virt finisher.
- Build output exists at `zig-out/bin/zign01d-v0`, not `zig-out/bin/zign01d-v0.elf`.

V0 required proof:

- `./scripts/build.sh`
- `./scripts/run-qemu.sh`
- Manual shell transcript proving `help`, `mem`, `uptime`, and `shutdown`.

V0 exit criteria:

- Kernel boots.
- UART logs appear.
- Shell prompt appears.
- Manual commands work.
- Shutdown returns to host.
- Commit is pushed.
- Tag exists: `v0-booting-shell`.

---

## Phase 1: V1 Diagnostic Foundation

Purpose: make the kernel diagnosable before making it ambitious.

V1 is not a phone OS yet. V1 is not a real networked OS yet. V1 is not a userspace platform yet. V1 is the first load-bearing slab.

Core V1 goal:

Build a small kernel foundation where every subsystem has:

- Real state
- Init function
- Status function
- Shell-visible status
- Log marker
- Failure marker
- Inspect hint
- Smoke proof

Required modules:

- `kernel/diag/breadcrumb.zig`
- `kernel/task/task.zig`
- `kernel/device/device.zig`
- `kernel/syscall/syscall.zig`
- `kernel/net/net.zig`
- `kernel/phone/phone.zig`

Required documentation:

- `docs/V0_PROOF.md`
- `docs/V1_PLAN.md`
- `docs/LOGGING_AND_BREADCRUMBS.md`
- `docs/V1_FOUNDATION_AUDIT.md`

Required shell commands:

Existing commands must remain:

- `help`
- `mem`
- `uptime`
- `reboot`
- `shutdown`
- `log`
- `status`

New commands:

- `version`
- `build`
- `breadcrumbs`
- `logs`
- `tasks`
- `devices`
- `syscalls`
- `net`
- `ping`
- `phone`
- `call`
- `sms`

Required state models:

Task state:

- `pid=0 name=kernel state=running`
- `pid=1 name=init state=ready`

No fake preemption. No fake multitasking.

Device registry:

- `uart0`
- `timer0`
- `plic0`
- `ram0`
- `virtio-mmio-net0 placeholder`
- `virtio-mmio-blk0 placeholder`
- `modem0 placeholder`

Each device must include `name`, `subsystem`, `status`, and `inspect_hint`.

Syscall table:

- `write`
- `read`
- `uptime`
- `device_list`
- `net_status`
- `phone_status`

V1 does not need full userspace trap handling. It must say honestly: `table present, trap boundary not implemented`.

Network state:

- `down`
- `driver_missing`
- `link_unknown`

`ping` must not fake success.

Expected network failure:

`[ZIGN01D][WARN][NET][NET002] network driver not implemented; inspect kernel/net/net.zig and virtio-mmio device registry`

Phone state:

- `modem driver missing`
- `cellular stack missing`
- `audio path missing for calls`
- `sms stack missing`

`call` and `sms` must not fake success.

Expected phone failures:

`[ZIGN01D][WARN][PHONE][PHONE002] call unavailable; inspect kernel/phone/phone.zig, modem driver, cellular stack, audio route`

`[ZIGN01D][WARN][PHONE][PHONE003] sms unavailable; inspect kernel/phone/phone.zig, modem driver, cellular stack`

V1 smoke tests:

Required:

- `smoke/smoke-v0.sh`
- `smoke/smoke-v1.sh`

V0 smoke must keep passing.

V1 smoke must:

- Build the kernel.
- Boot QEMU.
- Capture real serial output.
- Send commands to the shell.
- Verify command responses.
- Prove `uptime` is live, not canned text.
- Fail if QEMU never reaches the shell.
- Fail if commands are not processed.
- Fail if placeholders pretend to be real features.

V1 smoke should send:

- `help`
- `status`
- `version`
- `build`
- `breadcrumbs`
- `devices`
- `tasks`
- `syscalls`
- `net`
- `ping 1.1.1.1`
- `phone`
- `call 5551234`
- `sms 5551234 hello`
- `uptime`
- `shutdown`

V1 acceptance criteria:

- `./scripts/build.sh`
- `./scripts/run-qemu.sh`
- `./smoke/smoke-v0.sh`
- `./smoke/smoke-v1.sh`

Every new subsystem must answer in `docs/V1_FOUNDATION_AUDIT.md`:

- What real state does this subsystem own?
- Where is that state stored?
- Which init path creates or validates it?
- Which shell command exposes it?
- Which smoke test proves it?
- What is still placeholder?
- What exact file should be inspected next to make it real?

V1 non-goals:

- Real phone calls
- Real SMS
- LTE/5G modem support
- Full userspace
- Filesystem
- Real networking
- Memory allocator
- Preemptive scheduler
- C/C++ runtime
- Python or Java
- GUI
- Real phone hardware

---

## Phase 2: V2 Machine Boundary

Purpose: move from "kernel that boots" to "kernel with real machine-facing structure."

Core goal: introduce real interrupt, trap, and device boundaries without pretending the system is complete.

Target capabilities:

- Trap vector cleanup
- Basic exception reporting
- Panic path with full breadcrumb dump
- Timer interrupt groundwork
- PLIC/interrupt-controller status
- Virtio MMIO discovery
- Real device probing for QEMU virt devices
- Better memory map reporting
- Early physical page allocator design document
- Stronger smoke tests

Required work:

- `kernel/trap/trap.zig`
- `kernel/panic/panic.zig`

Panic output must include:

- panic code
- subsystem
- last boot stage
- last breadcrumb
- likely inspect file

V2 acceptance criteria:

- V1 tests still pass.
- Trap/panic path can be triggered by a deliberate shell command: `panic-test`.
- Panic output is useful.
- Device command reports discovered QEMU virtio devices if available.
- No fake driver success.

---

## Phase 3: V3 Memory and Allocation Discipline

Purpose: build memory ownership discipline before the system grows.

Target capabilities:

- Physical memory region model
- Kernel image reservation
- Boot memory accounting
- Page frame bitmap or simple region allocator
- Allocation failure diagnostics
- Ownership documentation
- Leak doctrine

Required documentation:

- `docs/MEMORY_OWNERSHIP.md`
- `docs/ALLOCATOR_PLAN.md`

Required commands:

- `mem`
- `mem-regions`
- `alloc-status`
- `alloc-test`

Acceptance criteria:

- Kernel still boots.
- V1 and V2 smoke tests still pass.
- Memory regions are real, not decorative.
- Allocator test proves allocation and release if allocator exists.
- Failure paths are logged.

---

## Phase 4: V4 Syscall and Userspace Boundary

Purpose: create the first honest userspace boundary.

Target capabilities:

- Trap-based syscall entry
- Syscall dispatcher
- User/kernel ABI document
- Minimal init task model
- Controlled user pointer policy document
- First tiny userspace payload, if safe

Minimum syscalls:

- `write`
- `read`
- `uptime`
- `exit`
- `device_list`

Required documentation:

- `docs/SYSCALL_ABI.md`
- `docs/USERSPACE_PLAN.md`

Acceptance criteria:

- Existing kernel shell still works.
- Syscall table is real.
- Syscall dispatcher is tested.
- Invalid syscall produces useful error.
- User/kernel boundary does not pretend to be secure if it is not.

---

## Phase 5: V5 Storage Foundation

Purpose: add real persistent or block-device groundwork.

Core goal: start with QEMU virtio-blk or a simple ramdisk, but do not fake a filesystem.

Target capabilities:

- virtio-blk investigation
- block device registry
- read-only block probe
- sector read test
- block status shell command
- storage smoke proof

Possible commands:

- `blk`
- `blk-read-test`
- `storage-status`

Acceptance criteria:

- Device is discovered.
- Reads are real if implemented.
- Failures are specific.
- No fake filesystem.

---

## Phase 6: V6 Network Foundation

Purpose: move from honest network placeholder to real QEMU networking.

Core goal: implement enough virtio-net or hosted networking to prove packets can move.

Target capabilities:

- virtio-net driver research
- MAC address reporting
- TX/RX queue initialization
- Link status
- Packet send test
- Packet receive test
- Basic ARP or raw packet smoke test

Required commands:

- `net`
- `net-dev`
- `net-send-test`
- `net-rx-status`

Acceptance criteria:

- Network state is real.
- Driver init either succeeds with proof or fails with inspectable cause.
- No fake ping.
- First real packet movement is captured in transcript.

---

## Phase 7: V7 C ABI and Tiny libc Direction

Purpose: prepare the system for portable software.

Target capabilities:

- Stable syscall numbers
- C header generation or manual headers
- Minimal freestanding C program support
- Tiny libc plan
- Build example C payload

Required documentation:

- `docs/C_ABI.md`
- `docs/LIBC_PLAN.md`

Possible syscalls:

- `write`
- `read`
- `exit`
- `uptime`
- `open placeholder`
- `close placeholder`

Acceptance criteria:

- C code can call into known ABI or documented stubs.
- Example builds reproducibly.
- Missing POSIX features are documented.
- No claim of POSIX compatibility until real.

---

## Phase 8: V8 Filesystem or Object Store Foundation

Purpose: introduce persistent naming and data model.

Options:

- tiny read-only initramfs
- simple educational filesystem
- object store / manifest-based early storage

Required capabilities:

- File/object listing
- Read test
- Metadata inspection
- Failure breadcrumbs
- Storage docs

Required commands:

- `ls`
- `cat`
- `fs-status`
- `fs-check`

Acceptance criteria:

- Reads are real.
- Names are real.
- Metadata is inspectable.
- No fake persistence.

---

## Phase 9: V9 C++ Runtime Groundwork

Purpose: prepare for higher-level compiled languages.

Required work:

- Constructors/destructors plan
- New/delete ownership model
- Exception policy
- RTTI policy
- TLS policy
- Static initialization policy

Acceptance criteria:

- A small C++ freestanding example builds only if honest.
- Unsupported features fail clearly.
- No fake "C++ support" claim.

---

## Phase 10: V10 Hosted Runtime Experiments

Purpose: test whether higher-level runtimes can eventually sit on ZIGN01D.

Suggested order:

1. Lua or tiny scripting runtime
2. MicroPython
3. Small WASM runtime
4. Larger Python subset
5. Java VM research

Acceptance criteria:

- Runtime limitations documented.
- Memory ownership documented.
- Syscall needs documented.
- No fake compatibility claims.

---

## Phase 11: Real Hardware Tier 1

Purpose: move beyond QEMU onto one real RISC-V board.

Board selection criteria:

- Public documentation
- UART access
- Boot process documentation
- Available toolchain support
- Minimal closed blobs
- Active community
- Affordable replacement cost

Acceptance criteria:

- Kernel prints boot logs on real UART.
- Board-specific memory map is documented.
- QEMU path still works.
- Hardware differences are isolated.

---

## Phase 12: Real Hardware Tier 2

Purpose: support a second board to prove architecture discipline.

Acceptance criteria:

- Board abstraction improves.
- Two hardware targets share common kernel core.
- Per-board code is isolated.
- Docs explain what differs.

---

## Phase 13: Phone-Like Hardware Research

Purpose: prepare for phone ambitions without lying.

Real calls and SMS require:

- Modem driver
- AT/QMI/MBIM or equivalent modem protocol
- SIM handling
- APN handling
- Cellular registration
- SMS PDU or modem SMS path
- Audio routing
- Microphone/speaker path
- Power management
- Permissions/security model
- Emergency-call policy
- Regulatory reality

Acceptance criteria:

- Hardware candidate list exists.
- Modem path is documented.
- No claim of phone support until calls/SMS actually work.

---

## Phase 14: Minimal Graphical or Text UI Layer

Purpose: make the system usable without compromising inspectability.

Possible paths:

- Serial shell first
- Framebuffer text console
- Simple graphical console
- Later compositor research

Acceptance criteria:

- UI does not hide system state.
- Logs remain accessible.
- Panic output remains visible.
- Serial remains first-class.

---

## Phase 15: Language Ecosystem Expansion

Purpose: make ZIGN01D useful to more developers.

Long-term targets:

- C
- Zig
- C++
- Lua
- MicroPython
- Python subset
- Java research
- WASM research

Rule:

No language is "supported" until:

- It builds reproducibly.
- It runs a real program.
- Its syscall/runtime needs are documented.
- Its memory behavior is understood.
- Its failure modes are logged.

---

## Phase 16: Security and Permissions

Purpose: no serious OS can grow without boundaries.

Target capabilities:

- Capability model research
- Device permission model
- Process isolation plan
- User/kernel memory policy
- Fault containment
- Audit logs

Acceptance criteria:

- Security claims are conservative.
- Unsupported protections are admitted.
- Dangerous commands are marked.
- Failure does not become silent corruption.

---

## Phase 17: Distribution and Developer Experience

Purpose: make the system easy to clone, build, run, test, and understand.

Required commands:

- `./scripts/doctor.sh`
- `./scripts/build.sh`
- `./scripts/run-qemu.sh`
- `./smoke/smoke-all.sh`

Acceptance criteria:

A new developer can run `git clone <repo>`, `cd zign01d`, `./scripts/doctor.sh`, `./scripts/build.sh`, and `./smoke/smoke-all.sh` and get useful output.

If something fails, the output must say what to inspect next.

---

## Phase 18: Public Credibility

Purpose: earn trust before asking for adoption.

Required public proof:

- Clean README
- Milestone table
- Boot transcript
- Smoke transcript
- Architecture docs
- "What is real / what is placeholder" section
- Contribution guide
- Known failures
- Roadmap

Rule:

Never market ahead of proof.

The repo should always make clear:

- This works.
- This is partial.
- This is placeholder.
- This is planned.
- This is unknown.

---

## Phase 19: Long-Term System Vision

Purpose: move from kernel project to operating system stack.

Long-term stack:

- Open hardware target
- Boot firmware expectations
- ZIGN01D kernel
- Diagnostic driver model
- Syscall ABI
- Tiny libc
- Userspace init
- Shell
- Storage model
- Network stack
- Language runtimes
- Developer tools
- Graphical or text UI
- Application model

Long-term promise:

ZIGN01D should become the system where nothing is allowed to be magic.

Every layer, from reset to runtime, should be inspectable, documented, smoke-tested, and honest about its own state.

---

## Version Philosophy

A version number is not a trophy.

A version number is a proof boundary.

Do not tag a version because the code looks impressive.

Tag a version because the proof is repeatable.

Each version must answer:

- What works?
- How do we know?
- What does not work?
- Where is the proof?
- Where is the next fault line?

---

## Near-Term Priority Order

- V0: pushed and tagged boot proof
- V1: diagnostic foundation
- V2: trap/panic/device boundary
- V3: memory ownership foundation
- V4: syscall/userspace boundary
- V5: storage foundation
- V6: network foundation
- V7: C ABI and tiny libc
- V8: filesystem/object store
- V9: C++ groundwork
- V10: hosted runtime experiments
- V11: first real RISC-V board

Phone features come after real driver, device, syscall, storage, network, audio, and permissions foundations exist.

---

## Final Rule

Could a critic call this an empty carton facsimile?

If yes, fix it.

Do not answer criticism with more words.

Answer it with proof.
