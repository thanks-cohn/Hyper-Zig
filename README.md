# ZIGn01d

A phone should be a machine.

Modern phones are increasingly difficult to understand, modify, repair, or own. Most software assumes permanent dependence on large vendors, proprietary ecosystems, and continuously changing platforms.

ZIGN01D is an attempt to build a phone operating system from first principles.

Goals:

- User ownership.
- Long-term maintainability.
- Portable architecture.
- Open runtime hosting.
- Native RISC-V support.
- Clear and inspectable design.

ZIGN01D is not tied to a single language ecosystem.

The system should eventually be capable of hosting:

- Zig
- C
- C++
- Java
- Kotlin
- C#

and any future runtime that can be supported through stable system interfaces.

Milestones:

V0
- Boot on RISC-V under QEMU.
- Memory management.
- Interrupts.
- Scheduler.
- Shell.

V1
- Calls.
- SMS.
- Internet access.
- Local storage.

If V1 can call, text, and access the internet, it is a phone.

Everything else can be built on top.

Long term:

The objective is not merely to create another phone operating system.

The objective is to create a durable foundation for personal computing, one capable of scaling from phones to workstations, clusters, and future hardware while remaining understandable by the people who use it.

A machine should outlive its manufacturer.

We intend to find out how far that idea can be taken.

```
---
V0 Repo Outline
Status: BOOTS
Target: Prove the machine exists
Hardware: RISC-V (QEMU)
Scope: Kernel foundation only

What works:
    - Boot
    - UART console
    - Memory initialization
    - Interrupt initialization
    - Scheduler startup
    - Userspace init
    - Interactive shell
    - Reboot
    - Shutdown

What does NOT exist yet:
    - Filesystem
    - Networking
    - Internet
    - Modem
    - SMS
    - Calls
    - GUI
    - Touchscreen
    - Audio
    - Applications

Success Definition:

    qemu-system-riscv64
            ↓
        kernel boots
            ↓
     userspace starts
            ↓
      shell appears
            ↓
     commands execute
            ↓
      reboot/shutdown

Repository:

zign01d/

├── README.md
├── LICENSE
│
├── docs/
│   ├── vision.md
│   ├── roadmap.md
│   ├── boot-process.md
│   └── smoke-test.md
│
├── kernel/
│   ├── arch/
│   │   └── riscv64/
│   │       ├── boot.zig
│   │       ├── trap.zig
│   │       └── cpu.zig
│   │
│   ├── memory/
│   │   ├── pmm.zig
│   │   ├── vmm.zig
│   │   └── allocator.zig
│   │
│   ├── interrupt/
│   │   ├── plic.zig
│   │   └── timer.zig
│   │
│   ├── scheduler/
│   │   └── scheduler.zig
│   │
│   ├── console/
│   │   ├── uart.zig
│   │   └── shell.zig
│   │
│   ├── panic/
│   │   └── panic.zig
│   │
│   └── main.zig
│
├── boot/
│   ├── linker.ld
│   └── entry.S
│
├── userspace/
│   └── init/
│       └── init.zig
│
├── smoke/
│   ├── README.md
│   ├── smoke-v0.sh
│   ├── expected-boot.txt
│   └── transcripts/
│       └── .gitkeep
│
├── scripts/
│   ├── build.sh
│   ├── run-qemu.sh
│   └── debug.sh
│
├── tests/
│   ├── boot/
│   ├── memory/
│   └── scheduler/
│
└── tools/
    └── qemu/


V0 Smoke Test

Required boot sequence:

    power on
        ↓
    kernel entry
        ↓
    memory online
        ↓
    interrupts online
        ↓
    scheduler online
        ↓
    userspace init
        ↓
    shell

Required commands:

    help
    mem
    uptime
    reboot
    shutdown

Pass Criteria:

    ✓ boots every run
    ✓ shell appears
    ✓ commands respond
    ✓ reboot works
    ✓ shutdown works

V0 Completion Statement:

    ZIGN01D has successfully established a bootable
    RISC-V kernel capable of initializing memory,
    handling interrupts, launching userspace, and
    presenting an interactive command environment.

    The machine exists.
```

```
v1 Repo Outline

zign01d/

├── README.md
├── LICENSE
├── build.zig
├── build.zig.zon
│
├── docs/
│   ├── vision.md
│   ├── v1-definition.md
│   ├── architecture.md
│   ├── boot-process.md
│   ├── modem.md
│   ├── networking.md
│   ├── storage.md
│   ├── hardware-targets.md
│   └── smoke-test.md
│
├── kernel/
│   ├── main.zig
│   ├── arch/
│   │   └── riscv64/
│   │       ├── entry.S
│   │       ├── linker.ld
│   │       ├── boot.zig
│   │       ├── cpu.zig
│   │       ├── trap.zig
│   │       ├── context.zig
│   │       └── mmu.zig
│   ├── memory/
│   │   ├── pmm.zig
│   │   ├── vmm.zig
│   │   ├── heap.zig
│   │   └── map.zig
│   ├── interrupt/
│   │   ├── plic.zig
│   │   ├── timer.zig
│   │   └── irq.zig
│   ├── process/
│   │   ├── process.zig
│   │   ├── thread.zig
│   │   ├── scheduler.zig
│   │   └── exec.zig
│   ├── syscall/
│   │   ├── syscall.zig
│   │   ├── table.zig
│   │   └── numbers.zig
│   ├── ipc/
│   │   ├── pipe.zig
│   │   ├── message.zig
│   │   └── event.zig
│   └── panic/
│       └── panic.zig
│
├── drivers/
│   ├── uart/
│   │   └── uart.zig
│   ├── gpio/
│   │   └── gpio.zig
│   ├── storage/
│   │   ├── virtio_blk.zig
│   │   └── block_device.zig
│   ├── net/
│   │   ├── virtio_net.zig
│   │   └── net_device.zig
│   ├── display/
│   │   ├── framebuffer.zig
│   │   └── console_fb.zig
│   ├── input/
│   │   ├── keyboard.zig
│   │   └── touchscreen.zig
│   ├── audio/
│   │   └── audio_device.zig
│   ├── battery/
│   │   └── power.zig
│   └── modem/
│       ├── modem.zig
│       ├── at.zig
│       ├── call.zig
│       └── sms.zig
│
├── storage/
│   ├── vfs/
│   │   ├── vfs.zig
│   │   ├── inode.zig
│   │   └── mount.zig
│   ├── ramfs/
│   │   └── ramfs.zig
│   └── devfs/
│       └── devfs.zig
│
├── networking/
│   ├── net.zig
│   ├── packet.zig
│   ├── ethernet.zig
│   ├── arp.zig
│   ├── ipv4.zig
│   ├── icmp.zig
│   ├── udp.zig
│   ├── tcp.zig
│   ├── dns.zig
│   └── dhcp.zig
│
├── phone/
│   ├── phone.zig
│   ├── dialer.zig
│   ├── call_state.zig
│   ├── sms_store.zig
│   ├── contacts.zig
│   └── modem_manager.zig
│
├── userspace/
│   ├── init/
│   │   └── init.zig
│   ├── shell/
│   │   └── shell.zig
│   ├── commands/
│   │   ├── help.zig
│   │   ├── mem.zig
│   │   ├── ps.zig
│   │   ├── ls.zig
│   │   ├── cat.zig
│   │   ├── mount.zig
│   │   ├── ping.zig
│   │   ├── curl.zig
│   │   ├── dial.zig
│   │   ├── answer.zig
│   │   ├── hangup.zig
│   │   ├── sms-send.zig
│   │   ├── sms-read.zig
│   │   ├── net-status.zig
│   │   └── shutdown.zig
│   └── lib/
│       ├── libc_min.zig
│       ├── sys.zig
│       └── phone_api.zig
│
├── runtime/
│   ├── abi/
│   │   ├── syscall_abi.md
│   │   └── process_abi.md
│   ├── c/
│   │   └── README.md
│   └── future/
│       ├── cpp.md
│       ├── jvm.md
│       └── dotnet.md
│
├── configs/
│   ├── qemu-riscv64.toml
│   ├── devboard-riscv64.toml
│   └── modem.toml
│
├── scripts/
│   ├── build.sh
│   ├── run-qemu.sh
│   ├── debug-qemu.sh
│   ├── flash-device.sh
│   ├── clean.sh
│   └── smoke/
│       ├── smoke-all.sh
│       ├── smoke-boot.sh
│       ├── smoke-memory.sh
│       ├── smoke-scheduler.sh
│       ├── smoke-storage.sh
│       ├── smoke-network.sh
│       ├── smoke-modem.sh
│       ├── smoke-phone.sh
│       └── smoke-userspace.sh
│
├── tests/
│   ├── boot/
│   │   ├── boots_to_shell.test
│   │   └── panic_prints_reason.test
│   ├── memory/
│   │   ├── pmm_alloc_free.test
│   │   ├── heap_alloc_free.test
│   │   └── vmm_maps_pages.test
│   ├── process/
│   │   ├── init_starts.test
│   │   ├── process_spawn.test
│   │   └── scheduler_ticks.test
│   ├── syscall/
│   │   ├── write_console.test
│   │   ├── read_console.test
│   │   └── exit_process.test
│   ├── storage/
│   │   ├── ramfs_create_read_write.test
│   │   ├── devfs_exposes_devices.test
│   │   └── virtio_blk_mount.test
│   ├── networking/
│   │   ├── net_device_detected.test
│   │   ├── dhcp_gets_address.test
│   │   ├── ping_gateway.test
│   │   └── dns_resolves_name.test
│   ├── modem/
│   │   ├── modem_detected.test
│   │   ├── at_command_roundtrip.test
│   │   └── sim_status.test
│   ├── phone/
│   │   ├── dial_command.test
│   │   ├── answer_command.test
│   │   ├── hangup_command.test
│   │   ├── sms_send_command.test
│   │   └── sms_read_command.test
│   └── userspace/
│       ├── shell_accepts_commands.test
│       ├── help_lists_commands.test
│       ├── curl_fetches_url.test
│       └── shutdown_exits_cleanly.test
│
├── smoke/
│   ├── README.md
│   ├── v1-smoke-plan.md
│   ├── expected-output/
│   │   ├── boot.txt
│   │   ├── memory.txt
│   │   ├── network.txt
│   │   ├── modem.txt
│   │   ├── phone.txt
│   │   └── shutdown.txt
│   ├── transcripts/
│   │   └── .gitkeep
│   └── scenarios/
│       ├── 00_boot_to_shell.scn
│       ├── 01_memory_status.scn
│       ├── 02_mount_storage.scn
│       ├── 03_network_online.scn
│       ├── 04_ping_gateway.scn
│       ├── 05_curl_example.scn
│       ├── 06_modem_status.scn
│       ├── 07_send_sms.scn
│       ├── 08_read_sms.scn
│       ├── 09_make_call.scn
│       ├── 10_answer_call.scn
│       ├── 11_hangup_call.scn
│       └── 12_shutdown_clean.scn
│
└── tools/
    ├── image-builder/
    ├── qemu/
    ├── serial-console/
    ├── modem-sim/
    ├── net-sim/
    └── log-parser/
```
Target: V1

V1 is the first release intended to operate as a functional phone.

Required capabilities:

- Boot on supported RISC-V hardware.
- Local shell access.
- Persistent storage.
- Network connectivity.
- Cellular modem integration.
- Voice calls.
- SMS messaging.

Non-goals:

- Graphical environment.
- Application ecosystem.
- Media framework.
- Mobile app compatibility.

The purpose of V1 is to establish a complete vertical slice of the system.

A successful V1 proves that the kernel, driver model, userspace, storage,
networking stack, and modem integration are sufficient to support the
fundamental responsibilities of a phone.

Future releases may add graphical interfaces, runtime hosting,
application compatibility layers, and distributed capabilities.
These are intentionally deferred until the platform itself is proven.



 
