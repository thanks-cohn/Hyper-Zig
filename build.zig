const std = @import("std");

const hyperzig_status_text =
    \\Hyper-Zig developer status
    \\  current project: Hyper-Zig
    \\  Zig target: 0.14.x
    \\  current proven milestones: HV0 through HV25 when smoke validation passes
    \\  current milestone: HV25 Software HGATP Candidate Foundation (software-only candidate; no Linux boot, guest execution, guest mode entry, trap return, hgatp write, active stage2, H-extension support, or printk claim unless safely detected)
    \\  canonical validation command: ./scripts/validate-hyperzig.sh
    \\  no Linux guest support yet
    \\  no guest execution yet
    \\  no guest mode entry yet; HV24 records safe H-extension discovery state and blocks unsafe hypervisor CSR reads
    \\  no active second-stage translation yet; HV24 keeps hgatp writes not-attempted and active translation false
    \\  VM/vCPU through HV25 software HGATP candidate foundations are smoke-proven when validation passes
    \\  next: read docs/hypervisor/DEVELOPER_START_HERE.md
    \\
;

pub fn build(b: *std.Build) void {
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .riscv64,
        .os_tag = .freestanding,
        .abi = .none,
    });
    const optimize = std.builtin.OptimizeMode.ReleaseSmall;

    const exe = b.addExecutable(.{
        .name = "zign01d-v0",
        .root_source_file = b.path("kernel/main.zig"),
        .target = target,
        .optimize = optimize,
        .code_model = .medium,
    });

    exe.addAssemblyFile(b.path("boot/entry.S"));
    exe.setLinkerScript(b.path("boot/linker.ld"));
    exe.entry = .{ .symbol_name = "_start" };

    // Bare-metal V0: do not bundle Zig compiler_rt.
    // Pulling compiler_rt drags in math/runtime code and breaks this tiny RISC-V kernel link.
    exe.bundle_compiler_rt = false;

    b.installArtifact(exe);

    const default_status_cmd = b.addSystemCommand(&.{ "sh", "-c", "printf '%s\n' \"$1\"", "hyperzig-status", hyperzig_status_text });
    default_status_cmd.step.dependOn(&exe.step);
    b.getInstallStep().dependOn(&default_status_cmd.step);

    const hyperzig_status_cmd = b.addSystemCommand(&.{ "sh", "-c", "printf '%s\n' \"$1\"", "hyperzig-status", hyperzig_status_text });
    const hyperzig_status_step = b.step("hyperzig-status", "Print the current Hyper-Zig developer activation status");
    hyperzig_status_step.dependOn(&hyperzig_status_cmd.step);

    const validate_hyperzig_cmd = b.addSystemCommand(&.{ "sh", "-c", "./scripts/validate-hyperzig.sh" });
    validate_hyperzig_cmd.step.dependOn(b.getInstallStep());
    const validate_hyperzig_step = b.step("validate-hyperzig", "Run the canonical Hyper-Zig validation script with Minimus-Log output");
    validate_hyperzig_step.dependOn(&validate_hyperzig_cmd.step);
}
