const uart = @import("uart.zig");
const log = @import("../log.zig");
const diag = @import("../diag/breadcrumb.zig");
const mem = @import("../memory/pmm.zig");
const memory_v0 = @import("../memory/memory.zig");
const timer = @import("../interrupt/timer.zig");
const cpu = @import("../arch/riscv64/cpu.zig");
const csr = @import("../arch/riscv64/csr.zig");
const task = @import("../task/task.zig");
const device = @import("../device/device.zig");
const syscall = @import("../syscall/syscall.zig");
const net = @import("../net/net.zig");
const phone = @import("../phone/phone.zig");
const comm = @import("../comm/comm.zig");
const trap = @import("../arch/riscv64/trap.zig");
const mmio_probe = @import("../device/mmio_probe.zig");
const zbus = @import("../comm/zbus.zig");
const board = @import("../board/board.zig");
const virtio_discovery = @import("../virtio/discovery.zig");
const heap = @import("../memory/heap.zig");
const tarfs = @import("../fs/tarfs.zig");
const ramfs = @import("../fs/ramfs.zig");
const vfs = @import("../fs/vfs.zig");
const hv = @import("../hypervisor/hv.zig");

const RESET_BASE: usize = 0x0010_0000;
const FINISHER_PASS: u32 = 0x5555;
const FINISHER_RESET: u32 = 0x7777;
const VERSION = "ZIGN01D V4 guarded MMIO probe foundation";
const BUILD_MODE = "ReleaseSmall";
const TARGET = "riscv64-freestanding-none";

fn finisher() *volatile u32 {
    return @ptrFromInt(RESET_BASE);
}

pub fn start() noreturn {
    log.info("SHELL", "SHELL001", "shell ready");
    uart.write("ZIGN01D V1 interactive diagnostic shell\r\n");
    uart.write("ZIGN01D V3 timer and trap recovery readiness\r\n");
    uart.write("ZIGN01D V4 guarded MMIO probe foundation\r\n");
    uart.write("Type 'help' for commands. Missing drivers report honestly.\r\n");

    var line: [128]u8 = undefined;
    while (true) {
        uart.write("zign01d> ");
        const len = readLine(&line);
        handle(line[0..len]);
    }
}

fn readLine(buf: []u8) usize {
    var len: usize = 0;
    while (true) {
        const byte = uart.readByteBlocking();
        switch (byte) {
            '\r', '\n' => {
                uart.write("\r\n");
                return len;
            },
            0x08, 0x7f => {
                if (len > 0) {
                    len -= 1;
                    uart.write("\x08 \x08");
                }
            },
            else => {
                if (byte >= 0x20 and byte <= 0x7e and len < buf.len) {
                    buf[len] = byte;
                    len += 1;
                    uart.putByte(byte);
                }
            },
        }
    }
}

fn handle(cmd: []const u8) void {
    if (cmd.len == 0) return;
    if (equals(cmd, "help")) return help();
    if (equals(cmd, "mem")) return mem.report();
    if (equals(cmd, "pmm")) return mem.printPmm();
    if (equals(cmd, "pmm stats") or equals(cmd, "pmm-stats")) return mem.printStats();
    if (equals(cmd, "pmm alloc-test") or equals(cmd, "pmm-alloc-test")) return mem.printAllocTest();
    if (equals(cmd, "pmm free-test") or equals(cmd, "pmm-free-test")) return mem.printFreeTest();
    if (equals(cmd, "pmm invalid-free-test") or equals(cmd, "pmm-invalid-free-test")) return mem.printInvalidFreeTest();
    if (equals(cmd, "pmm double-free-test") or equals(cmd, "pmm-double-free-test")) return mem.printDoubleFreeTest();
    if (equals(cmd, "pmm exhaustion-test") or equals(cmd, "pmm-exhaustion-test")) return mem.printExhaustionTest();
    if (equals(cmd, "memory")) return memory_v0.printMemory();
    if (equals(cmd, "memmap")) return memory_v0.printMemmap();
    if (equals(cmd, "kernel-bounds")) return memory_v0.printKernelBounds();
    if (equals(cmd, "heap")) return heap.printHeap();
    if (equals(cmd, "heap stats") or equals(cmd, "heap-stats")) return heap.printStats();
    if (equals(cmd, "heap alloc-test") or equals(cmd, "heap-alloc-test")) return heap.printAllocTest();
    if (equals(cmd, "heap reset-test") or equals(cmd, "heap-reset-test")) return heap.printResetTest();
    if (equals(cmd, "heap overflow-test") or equals(cmd, "heap-overflow-test")) return heap.printOverflowTest();
    if (equals(cmd, "board")) return board.printBoard();
    if (equals(cmd, "board profile") or equals(cmd, "board-profile")) return board.printProfile();
    if (equals(cmd, "board devices") or equals(cmd, "board-devices")) return board.printDevices();
    if (equals(cmd, "virtio")) return virtio_discovery.printInfo();
    if (equals(cmd, "virtio summary") or equals(cmd, "virtio-summary")) return virtio_discovery.printSummary();
    if (equals(cmd, "virtio slots") or equals(cmd, "virtio-slots")) return virtio_discovery.printSlots();
    if (equals(cmd, "fs")) return tarfs.printOverview();
    if (equals(cmd, "fs list")) return tarfs.printList();
    if (startsWith(cmd, "fs stat ")) return tarfs.printStat(cmd["fs stat ".len..]);
    if (equals(cmd, "fs stat")) return tarfs.printStat("");
    if (startsWith(cmd, "fs cat ")) return tarfs.printCat(cmd["fs cat ".len..]);
    if (equals(cmd, "fs cat")) return tarfs.printCat("");
    if (startsWith(cmd, "fs checksum ")) return tarfs.printChecksum(cmd["fs checksum ".len..]);
    if (equals(cmd, "fs checksum")) return tarfs.printChecksum("");
    if (equals(cmd, "fs write-test")) return tarfs.printWriteTest();
    if (equals(cmd, "ramfs")) return ramfs.printOverview();
    if (equals(cmd, "ramfs stats")) return ramfs.printStats();
    if (equals(cmd, "ramfs list")) return ramfs.printList();
    if (startsWith(cmd, "ramfs create ")) return ramfs.printCreate(cmd["ramfs create ".len..]);
    if (equals(cmd, "ramfs create")) return ramfs.printCreate("");
    if (startsWith(cmd, "ramfs write ")) return ramfsWriteCommand(cmd["ramfs write ".len..]);
    if (equals(cmd, "ramfs write")) return ramfs.printWrite("", "");
    if (startsWith(cmd, "ramfs append ")) return ramfsAppendCommand(cmd["ramfs append ".len..]);
    if (equals(cmd, "ramfs append")) return ramfs.printAppend("", "");
    if (startsWith(cmd, "ramfs cat ")) return ramfs.printCat(cmd["ramfs cat ".len..]);
    if (equals(cmd, "ramfs cat")) return ramfs.printCat("");
    if (startsWith(cmd, "ramfs stat ")) return ramfs.printStat(cmd["ramfs stat ".len..]);
    if (equals(cmd, "ramfs stat")) return ramfs.printStat("");
    if (startsWith(cmd, "ramfs checksum ")) return ramfs.printChecksum(cmd["ramfs checksum ".len..]);
    if (equals(cmd, "ramfs checksum")) return ramfs.printChecksum("");
    if (startsWith(cmd, "ramfs delete ")) return ramfs.printDelete(cmd["ramfs delete ".len..]);
    if (equals(cmd, "ramfs delete")) return ramfs.printDelete("");
    if (equals(cmd, "ramfs missing-test")) return ramfs.printMissingTest();
    if (equals(cmd, "ramfs capacity-test")) return ramfs.printCapacityTest();
    if (equals(cmd, "ramfs overflow-test")) return ramfs.printOverflowTest();
    if (equals(cmd, "vfs")) return vfs.printOverview();
    if (equals(cmd, "vfs mounts")) return vfs.printMounts();
    if (startsWith(cmd, "vfs route ")) return vfs.printRoute(cmd["vfs route ".len..]);
    if (equals(cmd, "vfs route")) return vfs.printRoute("");
    if (startsWith(cmd, "vfs list ")) return vfs.printList(cmd["vfs list ".len..]);
    if (equals(cmd, "vfs list")) return vfs.printList("");
    if (startsWith(cmd, "vfs stat ")) return vfs.printStat(cmd["vfs stat ".len..]);
    if (equals(cmd, "vfs stat")) return vfs.printStat("");
    if (startsWith(cmd, "vfs cat ")) return vfs.printCat(cmd["vfs cat ".len..]);
    if (equals(cmd, "vfs cat")) return vfs.printCat("");
    if (startsWith(cmd, "vfs checksum ")) return vfs.printChecksum(cmd["vfs checksum ".len..]);
    if (equals(cmd, "vfs checksum")) return vfs.printChecksum("");
    if (startsWith(cmd, "vfs create ")) return vfs.printCreate(cmd["vfs create ".len..]);
    if (equals(cmd, "vfs create")) return vfs.printCreate("");
    if (startsWith(cmd, "vfs write ")) return vfsWriteCommand(cmd["vfs write ".len..]);
    if (equals(cmd, "vfs write")) return vfs.printWrite("", "");
    if (startsWith(cmd, "vfs append ")) return vfsAppendCommand(cmd["vfs append ".len..]);
    if (equals(cmd, "vfs append")) return vfs.printAppend("", "");
    if (startsWith(cmd, "vfs delete ")) return vfs.printDelete(cmd["vfs delete ".len..]);
    if (equals(cmd, "vfs delete")) return vfs.printDelete("");
    if (equals(cmd, "uptime")) return uptime();
    if (equals(cmd, "time")) return timeCommand();
    if (equals(cmd, "ticks")) return ticksCommand();
    if (equals(cmd, "heartbeat")) return heartbeatCommand();
    if (equals(cmd, "reboot")) return reboot();
    if (equals(cmd, "shutdown")) return shutdown();
    if (equals(cmd, "log")) return logCommand();
    if (equals(cmd, "logs")) return logsCommand();
    if (equals(cmd, "status")) return statusCommand();
    if (equals(cmd, "machine") or equals(cmd, "cpu")) return machineCommand();
    if (equals(cmd, "csr")) return csr.printStatus();
    if (equals(cmd, "hv") or equals(cmd, "hv status") or equals(cmd, "hv-status")) return hv.printStatus();
    if (equals(cmd, "hv capability") or equals(cmd, "hv-capability")) return hv.printCapability();
    if (equals(cmd, "hv guest-memory") or equals(cmd, "hv guest memory") or equals(cmd, "hv-guest-memory")) return hv.printGuestMemory();
    if (equals(cmd, "hv guest-memory alloc")) return hv.allocGuestMemory();
    if (equals(cmd, "hv guest-memory free")) return hv.freeGuestMemory();
    if (equals(cmd, "hv guest-memory reset")) return hv.resetGuestMemory();
    if (equals(cmd, "hv guest-memory bounds-test")) return hv.boundsTestGuestMemory();
    if (equals(cmd, "hv guest-memory double-free-test")) return hv.doubleFreeTestGuestMemory();
    if (equals(cmd, "hv guest-memory overflow-test")) return hv.overflowTestGuestMemory();
    if (equals(cmd, "hv address-space") or equals(cmd, "hv-address-space")) return hv.printAddressSpace();
    if (equals(cmd, "hv address-space create")) return hv.createAddressSpace();
    if (equals(cmd, "hv address-space reset")) return hv.resetAddressSpace();
    if (equals(cmd, "hv address-space lookup-zero")) return hv.lookupZeroAddressSpace();
    if (equals(cmd, "hv address-space lookup-page")) return hv.lookupPageAddressSpace();
    if (equals(cmd, "hv address-space bounds-test")) return hv.boundsTestAddressSpace();
    if (equals(cmd, "hv address-space alignment-test")) return hv.alignmentTestAddressSpace();
    if (equals(cmd, "hv guest-image") or equals(cmd, "hv-image")) return hv.printGuestImage();
    if (equals(cmd, "hv guest-image load-tiny")) return hv.loadTinyGuestImage();
    if (equals(cmd, "hv guest-image verify")) return hv.verifyGuestImage();
    if (equals(cmd, "hv guest-image reset")) return hv.resetGuestImage();
    if (equals(cmd, "hv guest-image bounds-test")) return hv.boundsTestGuestImage();
    if (equals(cmd, "hv guest-entry") or equals(cmd, "hv-entry")) return hv.printGuestEntry();
    if (equals(cmd, "hv guest-entry prepare")) return hv.prepareGuestEntry();
    if (equals(cmd, "hv guest-entry reset")) return hv.resetGuestEntry();
    if (equals(cmd, "hv guest-entry bounds-test")) return hv.boundsTestGuestEntry();
    if (equals(cmd, "hv guest-entry require-image-test")) return hv.requireImageTestGuestEntry();
    if (equals(cmd, "hv guest-exit") or equals(cmd, "hv-exit")) return hv.printGuestExit();
    if (equals(cmd, "hv guest-exit record-instruction")) return hv.recordInstructionGuestExit();
    if (equals(cmd, "hv guest-exit record-memory-fault")) return hv.recordMemoryFaultGuestExit();
    if (equals(cmd, "hv guest-exit record-timer")) return hv.recordTimerGuestExit();
    if (equals(cmd, "hv guest-exit record-halt")) return hv.recordHaltGuestExit();
    if (equals(cmd, "hv guest-exit reset")) return hv.resetGuestExit();
    if (equals(cmd, "hv guest-exit require-entry-test")) return hv.requireEntryTestGuestExit();
    if (equals(cmd, "hv guest-run") or equals(cmd, "hv-run")) return hv.printGuestRunAttempt();
    if (equals(cmd, "hv guest-run check")) return hv.checkGuestRunAttempt();
    if (equals(cmd, "hv guest-run arm-no-execute")) return hv.armNoExecuteGuestRunAttempt();
    if (equals(cmd, "hv guest-run reset")) return hv.resetGuestRunAttempt();
    if (equals(cmd, "hv guest-run require-entry-test")) return hv.requireEntryTestGuestRunAttempt();
    if (equals(cmd, "hv guest-run require-exit-test")) return hv.requireExitTestGuestRunAttempt();
    if (equals(cmd, "hv exec") or equals(cmd, "hv-exec") or equals(cmd, "hv execution")) return hv.printGuestExecution();
    if (equals(cmd, "hv exec-status") or equals(cmd, "hv exec status")) return hv.printGuestExecution();
    if (equals(cmd, "hv exec-check") or equals(cmd, "hv exec check")) return hv.validateGuestExecution();
    if (equals(cmd, "hv exec-arm") or equals(cmd, "hv exec arm")) return hv.armGuestExecution();
    if (equals(cmd, "hv exec-blockers") or equals(cmd, "hv exec blockers")) return hv.blockersGuestExecution();
    if (equals(cmd, "hv exec-reset") or equals(cmd, "hv exec reset")) return hv.resetGuestExecution();
    if (equals(cmd, "hv exec-require-prereq-test") or equals(cmd, "hv exec require-prereq-test")) return hv.requirePrereqTestGuestExecution();
    if (equals(cmd, "hv second-stage") or equals(cmd, "hv-stage2")) return hv.printSecondStage();
    if (equals(cmd, "hv second-stage configure")) return hv.configureSecondStage();
    if (equals(cmd, "hv second-stage validate")) return hv.validateSecondStage();
    if (equals(cmd, "hv second-stage lookup-zero")) return hv.lookupZeroSecondStage();
    if (equals(cmd, "hv second-stage lookup-page")) return hv.lookupPageSecondStage();
    if (equals(cmd, "hv second-stage bounds-test")) return hv.boundsTestSecondStage();
    if (equals(cmd, "hv second-stage alignment-test")) return hv.alignmentTestSecondStage();
    if (equals(cmd, "hv second-stage execute-permission-test")) return hv.executePermissionTestSecondStage();
    if (equals(cmd, "hv second-stage reset")) return hv.resetSecondStage();
    if (equals(cmd, "hv stage2-table") or equals(cmd, "hv-stage2-table")) return hv.printStage2Table();
    if (equals(cmd, "hv stage2-table build")) return hv.buildStage2Table();
    if (equals(cmd, "hv stage2-table validate")) return hv.validateStage2Table();
    if (equals(cmd, "hv stage2-table walk-zero")) return hv.walkZeroStage2Table();
    if (equals(cmd, "hv stage2-table walk-page")) return hv.walkPageStage2Table();
    if (equals(cmd, "hv stage2-table bounds-test")) return hv.boundsTestStage2Table();
    if (equals(cmd, "hv stage2-table alignment-test")) return hv.alignmentTestStage2Table();
    if (equals(cmd, "hv stage2-table execute-permission-test")) return hv.executePermissionTestStage2Table();
    if (equals(cmd, "hv stage2-table reset")) return hv.resetStage2Table();
    if (equals(cmd, "hv bootpkg") or equals(cmd, "hv-bootpkg")) return hv.printBootPackage();
    if (equals(cmd, "hv bootpkg status")) return hv.printBootPackage();
    if (equals(cmd, "hv bootpkg attach-kernel")) return hv.attachKernelBootPackage();
    if (equals(cmd, "hv bootpkg set-entry")) return hv.setEntryBootPackage();
    if (startsWith(cmd, "hv bootpkg set-cmdline ")) return hv.setCmdlineBootPackage(cmd["hv bootpkg set-cmdline ".len..]);
    if (equals(cmd, "hv bootpkg set-cmdline")) return hv.setCmdlineBootPackage("");
    if (equals(cmd, "hv bootpkg attach-initrd")) return hv.attachInitrdBootPackage();
    if (equals(cmd, "hv bootpkg attach-dtb")) return hv.attachDtbBootPackage();
    if (equals(cmd, "hv bootpkg validate")) return hv.validateBootPackage();
    if (equals(cmd, "hv bootpkg blockers")) return hv.blockersBootPackage();
    if (equals(cmd, "hv bootpkg overlap-test")) return hv.overlapTestBootPackage();
    if (equals(cmd, "hv bootpkg bounds-test")) return hv.boundsTestBootPackage();
    if (equals(cmd, "hv bootpkg reset")) return hv.resetBootPackage();
    if (equals(cmd, "hv dtb") or equals(cmd, "hv-dtb") or equals(cmd, "hv dtb status")) return hv.printDtbContract();
    if (equals(cmd, "hv dtb build")) return hv.buildDtbContract();
    if (equals(cmd, "hv dtb validate")) return hv.validateDtbContract();
    if (equals(cmd, "hv dtb blockers")) return hv.blockersDtbContract();
    if (equals(cmd, "hv dtb nodes")) return hv.nodesDtbContract();
    if (equals(cmd, "hv dtb bounds-test")) return hv.boundsTestDtbContract();
    if (equals(cmd, "hv dtb overlap-test")) return hv.overlapTestDtbContract();
    if (equals(cmd, "hv dtb reset")) return hv.resetDtbContract();
    if (equals(cmd, "hv fdt") or equals(cmd, "hv-fdt") or equals(cmd, "hv fdt status")) return hv.printBinaryFdt();
    if (equals(cmd, "hv fdt build")) return hv.buildBinaryFdt();
    if (equals(cmd, "hv fdt validate")) return hv.validateBinaryFdt();
    if (equals(cmd, "hv fdt header")) return hv.headerBinaryFdt();
    if (equals(cmd, "hv fdt nodes")) return hv.nodesBinaryFdt();
    if (equals(cmd, "hv fdt strings")) return hv.stringsBinaryFdt();
    if (equals(cmd, "hv fdt checksum")) return hv.checksumBinaryFdt();
    if (equals(cmd, "hv fdt bounds-test")) return hv.boundsTestBinaryFdt();
    if (equals(cmd, "hv fdt missing-contract-test")) return hv.missingContractTestBinaryFdt();
    if (equals(cmd, "hv fdt reset")) return hv.resetBinaryFdt();
    if (equals(cmd, "hv handoff") or equals(cmd, "hv-handoff") or equals(cmd, "hv handoff status")) return hv.printLinuxHandoff();
    if (equals(cmd, "hv handoff prepare")) return hv.prepareLinuxHandoff();
    if (equals(cmd, "hv handoff validate")) return hv.validateLinuxHandoff();
    if (equals(cmd, "hv handoff blockers")) return hv.blockersLinuxHandoff();
    if (equals(cmd, "hv handoff ranges")) return hv.rangesLinuxHandoff();
    if (equals(cmd, "hv handoff summary")) return hv.summaryLinuxHandoff();
    if (equals(cmd, "hv handoff overlap-test")) return hv.overlapTestLinuxHandoff();
    if (equals(cmd, "hv handoff bounds-test")) return hv.boundsTestLinuxHandoff();
    if (equals(cmd, "hv handoff missing-fdt-test")) return hv.missingFdtTestLinuxHandoff();
    if (equals(cmd, "hv handoff missing-bootpkg-test")) return hv.missingBootpkgTestLinuxHandoff();
    if (equals(cmd, "hv handoff reset")) return hv.resetLinuxHandoff();
    if (equals(cmd, "hv console") or equals(cmd, "hv-console") or equals(cmd, "hv console status")) return hv.printSbiConsole();
    if (equals(cmd, "hv console putchar-test")) return hv.putcharTestSbiConsole();
    if (equals(cmd, "hv console putstring-test")) return hv.putstringTestSbiConsole();
    if (equals(cmd, "hv console getchar-test")) return hv.getcharTestSbiConsole();
    if (equals(cmd, "hv console invalid-test")) return hv.invalidTestSbiConsole();
    if (equals(cmd, "hv console overflow-test")) return hv.overflowTestSbiConsole();
    if (equals(cmd, "hv console validate")) return hv.validateSbiConsole();
    if (equals(cmd, "hv console blockers")) return hv.blockersSbiConsole();
    if (equals(cmd, "hv console buffer")) return hv.bufferSbiConsole();
    if (equals(cmd, "hv console reset")) return hv.resetSbiConsole();
    if (equals(cmd, "hv sbi-dispatch") or equals(cmd, "hv-dispatch") or equals(cmd, "hv sbi-dispatch status")) return hv.printSbiDispatch();
    if (equals(cmd, "hv sbi-dispatch validate")) return hv.validateSbiDispatch();
    if (equals(cmd, "hv sbi-dispatch blockers")) return hv.blockersSbiDispatch();
    if (equals(cmd, "hv sbi-dispatch reset")) return hv.resetSbiDispatch();
    if (equals(cmd, "hv sbi-dispatch base-test")) return hv.baseTestSbiDispatch();
    if (equals(cmd, "hv sbi-dispatch timer-test")) return hv.timerTestSbiDispatch();
    if (equals(cmd, "hv sbi-dispatch console-putchar-test")) return hv.consolePutcharTestSbiDispatch();
    if (equals(cmd, "hv sbi-dispatch console-getchar-test")) return hv.consoleGetcharTestSbiDispatch();
    if (equals(cmd, "hv sbi-dispatch unknown-test")) return hv.unknownTestSbiDispatch();
    if (equals(cmd, "hv sbi-dispatch unsupported-function-test")) return hv.unsupportedFunctionTestSbiDispatch();
    if (equals(cmd, "hv context") or equals(cmd, "hv-context") or equals(cmd, "hv context status")) return hv.printGuestContext();
    if (equals(cmd, "hv context prepare")) return hv.prepareGuestContext();
    if (equals(cmd, "hv context validate")) return hv.validateGuestContext();
    if (equals(cmd, "hv context blockers")) return hv.blockersGuestContext();
    if (equals(cmd, "hv context registers")) return hv.registersGuestContext();
    if (equals(cmd, "hv context ranges")) return hv.rangesGuestContext();
    if (equals(cmd, "hv context require-handoff-test")) return hv.requireHandoffTestGuestContext();
    if (equals(cmd, "hv context require-fdt-test")) return hv.requireFdtTestGuestContext();
    if (equals(cmd, "hv context bounds-test")) return hv.boundsTestGuestContext();
    if (equals(cmd, "hv context reset")) return hv.resetGuestContext();

    if (equals(cmd, "hv hgatp-csr-interface") or equals(cmd, "hv-hgatp-csr-interface") or equals(cmd, "hv hgatp-csr-interface status")) return hv.printHgatpCsrInterface();
    if (equals(cmd, "hv hgatp-csr-interface build")) return hv.buildHgatpCsrInterface();
    if (equals(cmd, "hv hgatp-csr-interface validate")) return hv.validateHgatpCsrInterface();
    if (equals(cmd, "hv hgatp-csr-interface blockers")) return hv.blockersHgatpCsrInterface();
    if (equals(cmd, "hv hgatp-csr-interface next")) return hv.nextHgatpCsrInterface();
    if (equals(cmd, "hv hgatp-csr-interface checksum")) return hv.checksumHgatpCsrInterface();
    if (equals(cmd, "hv hgatp-csr-interface reset")) return hv.resetHgatpCsrInterface();
    if (equals(cmd, "hv hgatp-csr-interface fields")) return hv.fieldsHgatpCsrInterface();
    if (equals(cmd, "hv hgatp-csr-interface request")) return hv.requestHgatpCsrInterface();
    if (equals(cmd, "hv hgatp-csr-interface result")) return hv.resultHgatpCsrInterface();
    if (equals(cmd, "hv hgatp-csr-interface decision")) return hv.decisionHgatpCsrInterface();
    if (equals(cmd, "hv hgatp-csr-interface require-attempt-test")) return hv.requireAttemptTestHgatpCsrInterface();
    if (equals(cmd, "hv hgatp-csr-interface invalid-attempt-test")) return hv.invalidAttemptTestHgatpCsrInterface();
    if (equals(cmd, "hv hgatp-csr-interface source-integrity-test")) return hv.sourceIntegrityTestHgatpCsrInterface();
    if (equals(cmd, "hv hgatp-csr-interface request-value-test")) return hv.requestValueTestHgatpCsrInterface();
    if (equals(cmd, "hv hgatp-csr-interface csr-called-test")) return hv.csrCalledTestHgatpCsrInterface();
    if (equals(cmd, "hv hgatp-csr-interface raw-asm-called-test")) return hv.rawAsmCalledTestHgatpCsrInterface();
    if (equals(cmd, "hv hgatp-csr-interface write-attempted-test")) return hv.writeAttemptedTestHgatpCsrInterface();
    if (equals(cmd, "hv hgatp-csr-interface write-performed-test")) return hv.writePerformedTestHgatpCsrInterface();
    if (equals(cmd, "hv hgatp-csr-interface active-stage2-test")) return hv.activeStage2TestHgatpCsrInterface();
    if (equals(cmd, "hv hgatp-csr-interface invariant-consumption-test")) return hv.invariantConsumptionTestHgatpCsrInterface();
    if (equals(cmd, "hv hgatp-csr-interface invariant-corruption-test")) return hv.invariantCorruptionTestHgatpCsrInterface();
    if (equals(cmd, "hv hgatp-write-attempt") or equals(cmd, "hv-hgatp-write-attempt") or equals(cmd, "hv hgatp-write-attempt status")) return hv.printHgatpWriteAttempt();
    if (equals(cmd, "hv hgatp-write-attempt build")) return hv.buildHgatpWriteAttempt();
    if (equals(cmd, "hv hgatp-write-attempt validate")) return hv.validateHgatpWriteAttempt();
    if (equals(cmd, "hv hgatp-write-attempt blockers")) return hv.blockersHgatpWriteAttempt();
    if (equals(cmd, "hv hgatp-write-attempt next")) return hv.nextHgatpWriteAttempt();
    if (equals(cmd, "hv hgatp-write-attempt checksum")) return hv.checksumHgatpWriteAttempt();
    if (equals(cmd, "hv hgatp-write-attempt reset")) return hv.resetHgatpWriteAttempt();
    if (equals(cmd, "hv hgatp-write-attempt fields")) return hv.fieldsHgatpWriteAttempt();
    if (equals(cmd, "hv hgatp-write-attempt request")) return hv.requestHgatpWriteAttempt();
    if (equals(cmd, "hv hgatp-write-attempt decision")) return hv.decisionHgatpWriteAttempt();
    if (equals(cmd, "hv hgatp-write-attempt require-boundary-test")) return hv.requireBoundaryTestHgatpWriteAttempt();
    if (equals(cmd, "hv hgatp-write-attempt source-integrity-test")) return hv.sourceIntegrityTestHgatpWriteAttempt();
    if (equals(cmd, "hv hgatp-write-attempt request-value-test")) return hv.requestValueTestHgatpWriteAttempt();
    if (equals(cmd, "hv hgatp-write-attempt invariant-consumption-test")) return hv.invariantConsumptionTestHgatpWriteAttempt();
    if (equals(cmd, "hv hgatp-write-attempt invariant-corruption-test")) return hv.invariantCorruptionTestHgatpWriteAttempt();
    if (equals(cmd, "hv hgatp-write-boundary") or equals(cmd, "hv-hgatp-write-boundary") or equals(cmd, "hv hgatp-write-boundary status")) return hv.printHgatpWriteBoundary();
    if (equals(cmd, "hv hgatp-write-boundary build")) return hv.buildHgatpWriteBoundary();
    if (equals(cmd, "hv hgatp-write-boundary validate")) return hv.validateHgatpWriteBoundary();
    if (equals(cmd, "hv hgatp-write-boundary blockers")) return hv.blockersHgatpWriteBoundary();
    if (equals(cmd, "hv hgatp-write-boundary next")) return hv.nextHgatpWriteBoundary();
    if (equals(cmd, "hv hgatp-write-boundary checksum")) return hv.checksumHgatpWriteBoundary();
    if (equals(cmd, "hv hgatp-write-boundary reset")) return hv.resetHgatpWriteBoundary();
    if (equals(cmd, "hv hgatp-write-boundary fields")) return hv.fieldsHgatpWriteBoundary();
    if (equals(cmd, "hv hgatp-write-boundary request")) return hv.requestHgatpWriteBoundary();
    if (equals(cmd, "hv hgatp-write-boundary decision")) return hv.decisionHgatpWriteBoundary();
    if (equals(cmd, "hv hgatp-write-boundary invariant-lifecycle-test")) return hv.invariantLifecycleTestHgatpWriteBoundary();
    if (equals(cmd, "hv hgatp-write-boundary invariant-consumption-test")) return hv.invariantConsumptionTestHgatpWriteBoundary();
    if (equals(cmd, "hv hgatp-write-boundary invariant-corruption-test")) return hv.invariantCorruptionTestHgatpWriteBoundary();
    if (equals(cmd, "hv hgatp-write-boundary require-gate-test")) return hv.requireGateTestHgatpWriteBoundary();
    if (equals(cmd, "hv hgatp-write-boundary invalid-gate-test")) return hv.invalidGateTestHgatpWriteBoundary();
    if (equals(cmd, "hv hgatp-write-boundary gate-allows-boundary-test")) return hv.gateAllowsBoundaryTestHgatpWriteBoundary();
    if (equals(cmd, "hv hgatp-write-boundary source-integrity-test")) return hv.sourceIntegrityTestHgatpWriteBoundary();
    if (equals(cmd, "hv hgatp-write-boundary request-value-test")) return hv.requestValueTestHgatpWriteBoundary();
    if (equals(cmd, "hv hgatp-write-boundary boundary-allowed-test")) return hv.boundaryAllowedTestHgatpWriteBoundary();
    if (equals(cmd, "hv hgatp-write-boundary boundary-reached-test")) return hv.boundaryReachedTestHgatpWriteBoundary();
    if (equals(cmd, "hv hgatp-write-boundary write-attempt-test")) return hv.writeAttemptTestHgatpWriteBoundary();
    if (equals(cmd, "hv hgatp-write-boundary write-performed-test")) return hv.writePerformedTestHgatpWriteBoundary();
    if (equals(cmd, "hv hgatp-write-boundary active-stage2-test")) return hv.activeStage2TestHgatpWriteBoundary();
    if (equals(cmd, "hv hgatp-write-gate") or equals(cmd, "hv-hgatp-write-gate") or equals(cmd, "hv hgatp-write-gate status")) return hv.printHgatpWriteGate();
    if (equals(cmd, "hv hgatp-write-gate build")) return hv.buildHgatpWriteGate();
    if (equals(cmd, "hv hgatp-write-gate validate")) return hv.validateHgatpWriteGate();
    if (equals(cmd, "hv hgatp-write-gate blockers")) return hv.blockersHgatpWriteGate();
    if (equals(cmd, "hv hgatp-write-gate next")) return hv.nextHgatpWriteGate();
    if (equals(cmd, "hv hgatp-write-gate checksum")) return hv.checksumHgatpWriteGate();
    if (equals(cmd, "hv hgatp-write-gate reset")) return hv.resetHgatpWriteGate();
    if (equals(cmd, "hv hgatp-write-gate fields")) return hv.fieldsHgatpWriteGate();
    if (equals(cmd, "hv hgatp-write-gate decision")) return hv.decisionHgatpWriteGate();
    if (equals(cmd, "hv hgatp-write-gate invariant-lifecycle-test")) return hv.invariantLifecycleTestHgatpWriteGate();
    if (equals(cmd, "hv hgatp-write-gate invariant-consumption-test")) return hv.invariantConsumptionTestHgatpWriteGate();
    if (equals(cmd, "hv hgatp-write-gate invariant-corruption-test")) return hv.invariantCorruptionTestHgatpWriteGate();
    if (equals(cmd, "hv hgatp-write-gate require-plan-test")) return hv.requirePlanTestHgatpWriteGate();
    if (equals(cmd, "hv hgatp-write-gate invalid-plan-test")) return hv.invalidPlanTestHgatpWriteGate();
    if (equals(cmd, "hv hgatp-write-gate require-hext-test")) return hv.requireHextTestHgatpWriteGate();
    if (equals(cmd, "hv hgatp-write-gate require-csr-safety-test")) return hv.requireCsrSafetyTestHgatpWriteGate();
    if (equals(cmd, "hv hgatp-write-gate source-integrity-test")) return hv.sourceIntegrityTestHgatpWriteGate();
    if (equals(cmd, "hv hgatp-write-gate boundary-attempt-test")) return hv.boundaryAttemptTestHgatpWriteGate();
    if (equals(cmd, "hv hgatp-write-gate write-attempt-test")) return hv.writeAttemptTestHgatpWriteGate();
    if (equals(cmd, "hv hgatp-write-gate write-performed-test")) return hv.writePerformedTestHgatpWriteGate();
    if (equals(cmd, "hv hgatp-write-gate active-stage2-test")) return hv.activeStage2TestHgatpWriteGate();
    if (equals(cmd, "hv hgatp-write-plan") or equals(cmd, "hv-hgatp-write-plan") or equals(cmd, "hv hgatp-write-plan status")) return hv.printHgatpWritePlan();
    if (equals(cmd, "hv hgatp-write-plan build")) return hv.buildHgatpWritePlan();
    if (equals(cmd, "hv hgatp-write-plan validate")) return hv.validateHgatpWritePlan();
    if (equals(cmd, "hv hgatp-write-plan blockers")) return hv.blockersHgatpWritePlan();
    if (equals(cmd, "hv hgatp-write-plan next")) return hv.nextHgatpWritePlan();
    if (equals(cmd, "hv hgatp-write-plan checksum")) return hv.checksumHgatpWritePlan();
    if (equals(cmd, "hv hgatp-write-plan reset")) return hv.resetHgatpWritePlan();
    if (equals(cmd, "hv hgatp-write-plan fields")) return hv.fieldsHgatpWritePlan();
    if (equals(cmd, "hv hgatp-write-plan invariant-lifecycle-test")) return hv.invariantLifecycleTestHgatpWritePlan();
    if (equals(cmd, "hv hgatp-write-plan invariant-consumption-test")) return hv.invariantConsumptionTestHgatpWritePlan();
    if (equals(cmd, "hv hgatp-write-plan invariant-corruption-test")) return hv.invariantCorruptionTestHgatpWritePlan();
    if (equals(cmd, "hv hgatp-write-plan require-candidate-test")) return hv.requireCandidateTestHgatpWritePlan();
    if (equals(cmd, "hv hgatp-write-plan invalid-candidate-test")) return hv.invalidCandidateTestHgatpWritePlan();
    if (equals(cmd, "hv hgatp-write-plan require-readiness-test")) return hv.requireReadinessTestHgatpWritePlan();
    if (equals(cmd, "hv hgatp-write-plan invalid-readiness-test")) return hv.invalidReadinessTestHgatpWritePlan();
    if (equals(cmd, "hv hgatp-write-plan readiness-not-ready-test")) return hv.readinessNotReadyTestHgatpWritePlan();
    if (equals(cmd, "hv hgatp-write-plan require-hext-test")) return hv.requireHextTestHgatpWritePlan();
    if (equals(cmd, "hv hgatp-write-plan require-csr-safety-test")) return hv.requireCsrSafetyTestHgatpWritePlan();
    if (equals(cmd, "hv hgatp-write-plan require-stage2-metadata-test")) return hv.requireStage2MetadataTestHgatpWritePlan();
    if (equals(cmd, "hv hgatp-write-plan require-stage2-table-test")) return hv.requireStage2TableTestHgatpWritePlan();
    if (equals(cmd, "hv hgatp-write-plan source-integrity-test")) return hv.sourceIntegrityTestHgatpWritePlan();
    if (equals(cmd, "hv hgatp-write-plan write-allowed-test")) return hv.writeAllowedTestHgatpWritePlan();
    if (equals(cmd, "hv hgatp-write-plan write-attempt-test")) return hv.writeAttemptTestHgatpWritePlan();
    if (equals(cmd, "hv hgatp-write-plan active-stage2-test")) return hv.activeStage2TestHgatpWritePlan();
    if (equals(cmd, "hv hgatp-readiness") or equals(cmd, "hv-hgatp-readiness") or equals(cmd, "hv hgatp-readiness status")) return hv.printHgatpReadiness();
    if (equals(cmd, "hv hgatp-readiness build")) return hv.buildHgatpReadiness();
    if (equals(cmd, "hv hgatp-readiness validate")) return hv.validateHgatpReadiness();
    if (equals(cmd, "hv hgatp-readiness blockers")) return hv.blockersHgatpReadiness();
    if (equals(cmd, "hv hgatp-readiness next")) return hv.nextHgatpReadiness();
    if (equals(cmd, "hv hgatp-readiness checksum")) return hv.checksumHgatpReadiness();
    if (equals(cmd, "hv hgatp-readiness reset")) return hv.resetHgatpReadiness();
    if (equals(cmd, "hv hgatp-readiness invariant-lifecycle-test")) return hv.invariantLifecycleTestHgatpReadiness();
    if (equals(cmd, "hv hgatp-readiness invariant-consumption-test")) return hv.invariantConsumptionTestHgatpReadiness();
    if (equals(cmd, "hv hgatp-readiness invariant-corruption-test")) return hv.invariantCorruptionTestHgatpReadiness();
    if (equals(cmd, "hv hgatp-readiness require-candidate-test")) return hv.requireCandidateTestHgatpReadiness();
    if (equals(cmd, "hv hgatp-readiness invalid-candidate-test")) return hv.invalidCandidateTestHgatpReadiness();
    if (equals(cmd, "hv hgatp-readiness require-stage2-test")) return hv.requireStage2TestHgatpReadiness();
    if (equals(cmd, "hv hgatp-readiness require-table-test")) return hv.requireTableTestHgatpReadiness();
    if (equals(cmd, "hv hgatp-readiness require-hext-test")) return hv.requireHextTestHgatpReadiness();
    if (equals(cmd, "hv hgatp-readiness require-csr-safety-test")) return hv.requireCsrSafetyTestHgatpReadiness();
    if (equals(cmd, "hv hgatp-readiness write-attempt-test")) return hv.writeAttemptTestHgatpReadiness();
    if (equals(cmd, "hv hgatp-readiness active-stage2-test")) return hv.activeStage2TestHgatpReadiness();
    if (equals(cmd, "hv hgatp-readiness source-integrity-test")) return hv.sourceIntegrityTestHgatpReadiness();
    if (equals(cmd, "hv hgatp") or equals(cmd, "hv-hgatp") or equals(cmd, "hv hgatp status")) return hv.printHgatpCandidate();
    if (equals(cmd, "hv hgatp build")) return hv.buildHgatpCandidate();
    if (equals(cmd, "hv hgatp validate")) return hv.validateHgatpCandidate();
    if (equals(cmd, "hv hgatp blockers")) return hv.blockersHgatpCandidate();
    if (equals(cmd, "hv hgatp fields")) return hv.fieldsHgatpCandidate();
    if (equals(cmd, "hv hgatp checksum")) return hv.checksumHgatpCandidate();
    if (equals(cmd, "hv hgatp reset")) return hv.resetHgatpCandidate();
    if (equals(cmd, "hv hgatp invariant-lifecycle-test")) return hv.invariantLifecycleTestHgatpCandidate();
    if (equals(cmd, "hv hgatp invariant-derivation-test")) return hv.invariantDerivationTestHgatpCandidate();
    if (equals(cmd, "hv hgatp invariant-corruption-test")) return hv.invariantCorruptionTestHgatpCandidate();
    if (equals(cmd, "hv hgatp mode-test")) return hv.modeTestHgatpCandidate();
    if (equals(cmd, "hv hgatp ppn-alignment-test")) return hv.ppnAlignmentTestHgatpCandidate();
    if (equals(cmd, "hv hgatp vmid-bounds-test")) return hv.vmidBoundsTestHgatpCandidate();
    if (equals(cmd, "hv hgatp require-hext-test")) return hv.requireHextTestHgatpCandidate();
    if (equals(cmd, "hv hgatp write-attempt-test")) return hv.writeAttemptTestHgatpCandidate();
    if (equals(cmd, "hv hgatp active-stage2-test")) return hv.activeStage2TestHgatpCandidate();
    if (equals(cmd, "hv h-ext") or equals(cmd, "hv-hext") or equals(cmd, "hv h-ext status")) return hv.printHExtension();
    if (equals(cmd, "hv h-ext discover")) return hv.discoverHExtension();
    if (equals(cmd, "hv h-ext validate")) return hv.validateHExtension();
    if (equals(cmd, "hv h-ext blockers")) return hv.blockersHExtension();
    if (equals(cmd, "hv h-ext csr-table")) return hv.csrTableHExtension();
    if (equals(cmd, "hv h-ext safety")) return hv.safetyHExtension();
    if (equals(cmd, "hv h-ext fake-detected-test")) return hv.fakeDetectedTestHExtension();
    if (equals(cmd, "hv h-ext unsafe-probe-test")) return hv.unsafeProbeTestHExtension();
    if (equals(cmd, "hv h-ext reset")) return hv.resetHExtension();
    if (equals(cmd, "hv entry-stub") or equals(cmd, "hv-entry-stub") or equals(cmd, "hv entry-stub status")) return hv.printEntryStub();
    if (equals(cmd, "hv entry-stub prepare")) return hv.prepareEntryStub();
    if (equals(cmd, "hv entry-stub validate")) return hv.validateEntryStub();
    if (equals(cmd, "hv entry-stub blockers")) return hv.blockersEntryStub();
    if (equals(cmd, "hv entry-stub registers")) return hv.registersEntryStub();
    if (equals(cmd, "hv entry-stub gates")) return hv.gatesEntryStub();
    if (equals(cmd, "hv entry-stub descriptor")) return hv.descriptorEntryStub();
    if (equals(cmd, "hv entry-stub checksum")) return hv.checksumEntryStub();
    if (equals(cmd, "hv entry-stub attempt")) return hv.attemptEntryStub();
    if (equals(cmd, "hv entry-stub require-plan-test")) return hv.requirePlanTestEntryStub();
    if (equals(cmd, "hv entry-stub pc-bounds-test")) return hv.pcBoundsTestEntryStub();
    if (equals(cmd, "hv entry-stub sp-bounds-test")) return hv.spBoundsTestEntryStub();
    if (equals(cmd, "hv entry-stub fdt-bounds-test")) return hv.fdtBoundsTestEntryStub();
    if (equals(cmd, "hv entry-stub active-stage2-test")) return hv.activeStage2TestEntryStub();
    if (equals(cmd, "hv entry-stub reset")) return hv.resetEntryStub();
    if (equals(cmd, "hv trap-plan") or equals(cmd, "hv-trap-plan") or equals(cmd, "hv trap-plan status")) return hv.printTrapPlan();
    if (equals(cmd, "hv trap-plan prepare")) return hv.prepareTrapPlan();
    if (equals(cmd, "hv trap-plan validate")) return hv.validateTrapPlan();
    if (equals(cmd, "hv trap-plan blockers")) return hv.blockersTrapPlan();
    if (equals(cmd, "hv trap-plan registers")) return hv.registersTrapPlan();
    if (equals(cmd, "hv trap-plan gates")) return hv.gatesTrapPlan();
    if (equals(cmd, "hv trap-plan attempt")) return hv.attemptTrapPlan();
    if (equals(cmd, "hv trap-plan require-context-test")) return hv.requireContextTestTrapPlan();
    if (equals(cmd, "hv trap-plan pc-bounds-test")) return hv.pcBoundsTestTrapPlan();
    if (equals(cmd, "hv trap-plan sp-bounds-test")) return hv.spBoundsTestTrapPlan();
    if (equals(cmd, "hv trap-plan fdt-bounds-test")) return hv.fdtBoundsTestTrapPlan();
    if (equals(cmd, "hv trap-plan active-stage2-test")) return hv.activeStage2TestTrapPlan();
    if (equals(cmd, "hv trap-plan reset")) return hv.resetTrapPlan();
    if (equals(cmd, "hv sbi") or equals(cmd, "hv-sbi") or equals(cmd, "hv sbi status")) return hv.printSbi();
    if (equals(cmd, "hv sbi validate")) return hv.validateSbi();
    if (equals(cmd, "hv sbi reset")) return hv.resetSbi();
    if (equals(cmd, "hv sbi blockers")) return hv.blockersSbi();
    if (equals(cmd, "hv sbi base-test")) return hv.baseTestSbi();
    if (equals(cmd, "hv sbi timer-test")) return hv.timerTestSbi();
    if (equals(cmd, "hv sbi console-test")) return hv.consoleTestSbi();
    if (equals(cmd, "hv timer") or equals(cmd, "hv-timer") or equals(cmd, "hv timer status")) return hv.printVirtualTimer();
    if (equals(cmd, "hv timer arm")) return hv.armVirtualTimer();
    if (equals(cmd, "hv timer validate")) return hv.validateVirtualTimer();
    if (equals(cmd, "hv timer blockers")) return hv.blockersVirtualTimer();
    if (equals(cmd, "hv timer pending-test")) return hv.pendingTestVirtualTimer();
    if (equals(cmd, "hv timer sbi-set-test")) return hv.sbiSetTestVirtualTimer();
    if (equals(cmd, "hv timer invalid-test")) return hv.invalidTestVirtualTimer();
    if (equals(cmd, "hv timer reset")) return hv.resetVirtualTimer();
    if (equals(cmd, "hv vm") or equals(cmd, "hv-vm")) return hv.printVm();
    if (equals(cmd, "hv vcpu") or equals(cmd, "hv-vcpu")) return hv.printVcpu();
    if (equals(cmd, "hv vcpu lifecycle") or equals(cmd, "hv-vcpu-lifecycle")) return hv.printVcpuLifecycle();
    if (equals(cmd, "hv vcpu init") or equals(cmd, "hv-vcpu-init")) return hv.initializeVcpu();
    if (equals(cmd, "hv vcpu prepare") or equals(cmd, "hv-vcpu-prepare")) return hv.prepareVcpu();
    if (equals(cmd, "hv vcpu halt") or equals(cmd, "hv-vcpu-halt")) return hv.haltVcpu();
    if (equals(cmd, "hv vcpu reset") or equals(cmd, "hv-vcpu-reset")) return hv.resetVcpu();
    if (equals(cmd, "hv inspect") or equals(cmd, "hv-inspect")) return hv.printInspect();
    if (equals(cmd, "hv-objects")) return hv.printObjects();
    if (equals(cmd, "panic-test")) return panicTestCommand();
    if (equals(cmd, "trap-test")) return trapTestCommand();
    if (equals(cmd, "version")) return versionCommand();
    if (equals(cmd, "build")) return buildCommand();
    if (equals(cmd, "breadcrumbs")) return breadcrumbsCommand();
    if (equals(cmd, "tasks")) return task.printStatus();
    if (equals(cmd, "devices")) return device.printStatus();
    if (equals(cmd, "mmio")) return mmio_probe.printReport();
    if (equals(cmd, "syscalls")) return syscall.printStatus();
    if (equals(cmd, "comm")) return comm.printStatus();
    if (equals(cmd, "zbus") or equals(cmd, "zbus status") or equals(cmd, "zbus-status")) return zbus.printStatus();
    if (equals(cmd, "zbus ping") or equals(cmd, "zbus-ping")) return zbus.printPing();
    if (equals(cmd, "zbus providers") or equals(cmd, "zbus-providers")) return zbus.printProviders();
    if (equals(cmd, "bridge status") or equals(cmd, "bridge-status")) return comm.bridge.printStatus();
    if (equals(cmd, "net status") or equals(cmd, "net-status")) return comm.net.printStatus();
    if (startsWith(cmd, "net get ")) return comm.net.printGet(cmd["net get ".len..]);
    if (startsWith(cmd, "net-get ")) return comm.net.printGet(cmd["net-get ".len..]);
    if (equals(cmd, "net get") or equals(cmd, "net-get")) return comm.net.printGet("");
    if (equals(cmd, "sms inbox") or equals(cmd, "sms-inbox")) return comm.sms.printInbox();
    if (startsWith(cmd, "sms send ")) return smsSendCommand(cmd["sms send ".len..]);
    if (startsWith(cmd, "sms-send ")) return smsSendCommand(cmd["sms-send ".len..]);
    if (equals(cmd, "sms send") or equals(cmd, "sms-send")) return comm.sms.printSend("");
    if (equals(cmd, "sms wait") or equals(cmd, "sms-wait")) return comm.sms.printWait();
    if (equals(cmd, "modem status") or equals(cmd, "modem-status")) return comm.modem.printStatus();
    if (equals(cmd, "net")) return net.printStatus();
    if (startsWith(cmd, "ping")) return pingCommand(cmd);
    if (equals(cmd, "phone")) return phone.printStatus();
    if (startsWith(cmd, "call")) return callCommand(cmd);
    if (startsWith(cmd, "sms")) return smsCommand(cmd);

    log.warn("SHELL", "SHELL002", "unknown shell command; inspect kernel/console/shell.zig command table");
    uart.write("unknown command: ");
    uart.write(cmd);
    uart.write("\r\n");
}

fn help() void {
    uart.write("commands: help mem pmm pmm stats pmm alloc-test pmm free-test pmm invalid-free-test pmm double-free-test pmm exhaustion-test pmm-stats pmm-alloc-test pmm-free-test pmm-invalid-free-test pmm-double-free-test pmm-exhaustion-test memory memmap kernel-bounds heap heap stats heap alloc-test heap reset-test heap overflow-test heap-stats heap-alloc-test heap-reset-test heap-overflow-test board board profile board devices board-profile board-devices virtio virtio summary virtio slots virtio-summary virtio-slots fs fs list fs stat fs cat fs checksum fs write-test ramfs ramfs stats ramfs list ramfs create ramfs write ramfs cat ramfs append ramfs stat ramfs checksum ramfs delete ramfs missing-test ramfs capacity-test ramfs overflow-test vfs vfs mounts vfs route vfs list vfs stat vfs cat vfs checksum vfs create vfs write vfs append vfs delete uptime time ticks heartbeat reboot shutdown log status version build breadcrumbs logs machine cpu csr tasks devices mmio syscalls net ping phone call sms panic-test trap-test comm zbus zbus status zbus ping zbus providers bridge status net status net get sms inbox sms send sms wait modem status hv hv status hv-status hv capability hv-capability hv guest-memory hv guest memory hv-guest-memory hv guest-memory alloc hv guest-memory free hv guest-memory reset hv guest-memory bounds-test hv guest-memory double-free-test hv guest-memory overflow-test hv vm hv-vm hv vcpu hv-vcpu hv vcpu lifecycle hv-vcpu-lifecycle hv vcpu init hv-vcpu-init hv vcpu prepare hv-vcpu-prepare hv vcpu halt hv-vcpu-halt hv vcpu reset hv-vcpu-reset hv guest-image hv-image hv guest-image load-tiny hv guest-image verify hv guest-image reset hv guest-image bounds-test hv guest-entry hv-entry hv guest-entry prepare hv guest-entry reset hv guest-entry bounds-test hv guest-entry require-image-test hv guest-exit hv-exit hv guest-exit record-instruction hv guest-exit record-memory-fault hv guest-exit record-timer hv guest-exit record-halt hv guest-exit reset hv guest-exit require-entry-test hv guest-run hv-run hv guest-run check hv guest-run arm-no-execute hv guest-run reset hv guest-run require-entry-test hv guest-run require-exit-test hv exec hv-exec hv execution hv exec-status hv exec status hv exec-check hv exec check hv exec-arm hv exec arm hv exec-blockers hv exec blockers hv exec-reset hv exec reset hv exec-require-prereq-test hv exec require-prereq-test hv second-stage hv-stage2 hv second-stage configure hv second-stage validate hv second-stage lookup-zero hv second-stage lookup-page hv second-stage bounds-test hv second-stage alignment-test hv second-stage execute-permission-test hv second-stage reset hv stage2-table hv-stage2-table hv stage2-table build hv stage2-table validate hv stage2-table walk-zero hv stage2-table walk-page hv stage2-table bounds-test hv stage2-table alignment-test hv stage2-table execute-permission-test hv stage2-table reset hv bootpkg hv-bootpkg hv bootpkg status hv bootpkg attach-kernel hv bootpkg set-entry hv bootpkg set-cmdline hv bootpkg attach-initrd hv bootpkg attach-dtb hv bootpkg validate hv bootpkg blockers hv bootpkg overlap-test hv bootpkg bounds-test hv bootpkg reset hv dtb hv-dtb hv dtb status hv dtb build hv dtb validate hv dtb blockers hv dtb nodes hv dtb bounds-test hv dtb overlap-test hv dtb reset hv fdt hv-fdt hv fdt status hv fdt build hv fdt validate hv fdt header hv fdt nodes hv fdt strings hv fdt checksum hv fdt bounds-test hv fdt missing-contract-test hv fdt reset hv handoff hv-handoff hv handoff status hv handoff prepare hv handoff validate hv handoff blockers hv handoff ranges hv handoff summary hv handoff overlap-test hv handoff bounds-test hv handoff missing-fdt-test hv handoff missing-bootpkg-test hv handoff reset hv console hv-console hv console status hv console putchar-test hv console putstring-test hv console getchar-test hv console invalid-test hv console overflow-test hv console validate hv console blockers hv console buffer hv console reset hv sbi-dispatch hv-dispatch hv sbi-dispatch status hv sbi-dispatch base-test hv sbi-dispatch timer-test hv sbi-dispatch console-putchar-test hv sbi-dispatch console-getchar-test hv sbi-dispatch unknown-test hv sbi-dispatch unsupported-function-test hv sbi-dispatch validate hv context hv-context hv context status hv context prepare hv context validate hv context blockers hv context registers hv context ranges hv context require-handoff-test hv context require-fdt-test hv context bounds-test hv context reset hv entry-stub hv-entry-stub hv entry-stub status hv entry-stub prepare hv entry-stub validate hv entry-stub blockers hv entry-stub registers hv entry-stub gates hv entry-stub descriptor hv entry-stub checksum hv entry-stub attempt hv entry-stub require-plan-test hv entry-stub pc-bounds-test hv entry-stub sp-bounds-test hv entry-stub fdt-bounds-test hv entry-stub active-stage2-test hv entry-stub reset hv h-ext hv-hext hv h-ext status hv h-ext discover hv h-ext validate hv h-ext blockers hv h-ext csr-table hv h-ext safety hv h-ext fake-detected-test hv h-ext unsafe-probe-test hv h-ext reset hv trap-plan hv-trap-plan hv trap-plan status hv trap-plan prepare hv trap-plan validate hv trap-plan blockers hv trap-plan registers hv trap-plan gates hv trap-plan attempt hv trap-plan require-context-test hv trap-plan pc-bounds-test hv trap-plan sp-bounds-test hv trap-plan fdt-bounds-test hv trap-plan active-stage2-test hv trap-plan reset hv sbi-dispatch blockers hv sbi-dispatch reset hv sbi hv-sbi hv sbi status hv sbi validate hv sbi reset hv sbi blockers hv sbi base-test hv sbi timer-test hv sbi console-test hv timer hv-timer hv timer status hv timer arm hv timer validate hv timer blockers hv timer pending-test hv timer sbi-set-test hv timer invalid-test hv timer reset hv hgatp-csr-interface hv-hgatp-csr-interface hv hgatp-csr-interface status hv hgatp-csr-interface build hv hgatp-csr-interface validate hv hgatp-csr-interface blockers hv hgatp-csr-interface next hv hgatp-csr-interface checksum hv hgatp-csr-interface reset hv hgatp-csr-interface fields hv hgatp-csr-interface request hv hgatp-csr-interface result hv hgatp-csr-interface decision hv hgatp-csr-interface require-attempt-test hv hgatp-csr-interface source-integrity-test hv hgatp-csr-interface request-value-test hv hgatp-csr-interface csr-called-test hv hgatp-csr-interface raw-asm-called-test hv hgatp-csr-interface write-attempted-test hv hgatp-csr-interface write-performed-test hv hgatp-csr-interface active-stage2-test hv hgatp-csr-interface invariant-consumption-test hv hgatp-csr-interface invariant-corruption-test hv hgatp-write-attempt hv-hgatp-write-attempt hv hgatp-write-attempt status hv hgatp-write-attempt build hv hgatp-write-attempt validate hv hgatp-write-attempt blockers hv hgatp-write-attempt next hv hgatp-write-attempt checksum hv hgatp-write-attempt reset hv hgatp-write-attempt fields hv hgatp-write-attempt request hv hgatp-write-attempt decision hv hgatp-write-attempt require-boundary-test hv hgatp-write-attempt source-integrity-test hv hgatp-write-attempt request-value-test hv hgatp-write-attempt invariant-consumption-test hv hgatp-write-attempt invariant-corruption-test hv inspect hv-inspect hv-objects\r\n");
}

fn vfsWriteCommand(args: []const u8) void {
    if (splitOnce(args)) |parts| return vfs.printWrite(parts.path, parts.rest);
    return vfs.printWrite(args, "");
}

fn vfsAppendCommand(args: []const u8) void {
    if (splitOnce(args)) |parts| return vfs.printAppend(parts.path, parts.rest);
    return vfs.printAppend(args, "");
}

fn ramfsWriteCommand(args: []const u8) void {
    if (splitOnce(args)) |parts| return ramfs.printWrite(parts.path, parts.rest);
    return ramfs.printWrite(args, "");
}

fn ramfsAppendCommand(args: []const u8) void {
    if (splitOnce(args)) |parts| return ramfs.printAppend(parts.path, parts.rest);
    return ramfs.printAppend(args, "");
}

const Split = struct { path: []const u8, rest: []const u8 };

fn splitOnce(args: []const u8) ?Split {
    for (args, 0..) |ch, i| {
        if (ch == ' ') return Split{ .path = args[0..i], .rest = args[i + 1 ..] };
    }
    return null;
}

fn uptime() void {
    const first = timer.ticks();
    const second = timer.ticks();
    uart.write("[ZIGN01D][INFO][TIMER][TIMER002] uptime ticks=");
    uart.writeDec(second);
    uart.write(" delta_probe=");
    uart.writeDec(second - first);
    uart.write(" source=rdtime\r\n");
}

fn reboot() noreturn {
    log.warn("SHELL", "SHELL003", "reboot requested via qemu virt finisher");
    finisher().* = FINISHER_RESET;
    cpu.halt();
}

fn shutdown() noreturn {
    log.warn("SHELL", "SHELL004", "shutdown requested via qemu virt finisher");
    finisher().* = FINISHER_PASS;
    cpu.halt();
}

fn logCommand() void {
    log.info("SHELL", "SHELL005", "log command reached; boot log is visible in serial transcript");
}

fn logsCommand() void {
    logCommand();
    uart.write("logs: no ring buffer yet; inspect serial transcript and docs/LOGGING_AND_BREADCRUMBS.md\r\n");
}

fn versionCommand() void {
    uart.write("version: ");
    uart.write(VERSION);
    uart.write("\r\n");
}

fn buildCommand() void {
    uart.write("build: mode=");
    uart.write(BUILD_MODE);
    uart.write(" target=");
    uart.write(TARGET);
    uart.write(" output=zig-out/bin/zign01d-v0 compiler_rt=disabled\r\n");
}

fn breadcrumbsCommand() void {
    diag.printDoctrineStatus();
}

fn statusCommand() void {
    uart.write("status: kernel_version=");
    uart.write(VERSION);
    uart.write(" build_mode=");
    uart.write(BUILD_MODE);
    uart.write(" target=");
    uart.write(TARGET);
    uart.write(" boot_stage=complete\r\n");
    uart.write("status: uart=active polling-mmio memory=qemu-virt-dram timer=rdtime-polling scheduler=cooperative-stub shell=active\r\n");
    uart.write("timer: rdtime-polling active; interrupts not enabled\r\n");
    uart.write("trap: vector installed; cause names available; recovery limited\r\n");
    uart.write("heartbeat: polling diagnostic active\r\n");
    uart.write("virtio-mmio: probing deferred until fault recovery is proven\r\n");
    uart.write("guarded-mmio: V4 fixed QEMU virt window scaffold live_probe=");
    uart.write(if (mmio_probe.LIVE_PROBE_ENABLED) "enabled" else "disabled");
    uart.write(" policy=");
    uart.write(mmio_probe.POLICY);
    uart.write("\r\n");
    task.printStatus();
    device.printStatus();
    syscall.printStatus();
    net.printStatus();
    phone.printStatus();
    comm.printStatusSummary();
    zbus.printSummaryFields();
    board.printStatusFields();
    memory_v0.printStatusFields();
    mem.printStatusFields();
    virtio_discovery.printStatusFields();
    trap.printStatus();
    uart.write("status: placeholders=plic,timer-interrupts,modem,cellular,audio,sms; virtio-net=not-implemented virtio-blk=not-implemented userspace=not-implemented no-userspace-boundary tarfs=implemented-v0 filesystem_core=not-implemented\r\n");
}

fn machineCommand() void {
    cpu.printMachineStatus();
    trap.printStatus();
}

fn panicTestCommand() void {
    trap.controlledPanicReport();
}

fn timeCommand() void {
    timer.printTimeDiagnostic();
}

fn ticksCommand() void {
    timer.printTicksDiagnostic();
}

fn heartbeatCommand() void {
    timer.printHeartbeatDiagnostic();
}

fn trapTestCommand() void {
    trap.syntheticTrapTest();
}

fn pingCommand(cmd: []const u8) void {
    if (cmd.len == "ping".len or startsWith(cmd, "ping ")) {
        net.pingUnavailable();
        return;
    }
    unknownArgument("NET", "NET003", "ping command malformed; expected ping <target>; inspect kernel/console/shell.zig");
}

fn callCommand(cmd: []const u8) void {
    if (cmd.len == "call".len or startsWith(cmd, "call ")) {
        phone.callUnavailable();
        return;
    }
    unknownArgument("PHONE", "PHONE004", "call command malformed; expected call <number>; inspect kernel/console/shell.zig");
}

fn smsCommand(cmd: []const u8) void {
    if (cmd.len == "sms".len or startsWith(cmd, "sms ")) {
        phone.smsUnavailable();
        return;
    }
    unknownArgument("PHONE", "PHONE005", "sms command malformed; expected sms <number> <message>; inspect kernel/console/shell.zig");
}

fn smsSendCommand(args: []const u8) void {
    comm.sms.printSend(firstToken(args));
}

fn firstToken(args: []const u8) []const u8 {
    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (args[i] == ' ') return args[0..i];
    }
    return args;
}

fn unknownArgument(subsystem: []const u8, code: []const u8, message: []const u8) void {
    diag.warn(subsystem, code, message);
}

fn equals(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;
    for (a, 0..) |ch, i| {
        if (ch != b[i]) return false;
    }
    return true;
}

fn startsWith(a: []const u8, prefix: []const u8) bool {
    if (a.len < prefix.len) return false;
    for (prefix, 0..) |ch, i| {
        if (a[i] != ch) return false;
    }
    return true;
}
