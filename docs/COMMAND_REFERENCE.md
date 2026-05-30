# ZIGN01D Command Reference

This reference documents the current user-facing shell commands by inspecting `kernel/console/shell.zig`. Commands report the current educational kernel state; not-implemented output is intentional proof of a boundary.

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
| `mmio` | V4 guarded MMIO | Prints guarded MMIO probe policy and deferred fixed-window results. | `mmio` | `mmio: live_probe=disabled`, `result=deferred`. | Does not imply live MMIO scanning or driver negotiation. |
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
