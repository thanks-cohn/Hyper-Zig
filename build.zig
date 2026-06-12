const std = @import("std");

const hyperzig_status_text =
    \\Hyper-Zig developer status
    \\  current project: Hyper-Zig
    \\  Zig target: 0.14.x
    \\  current proven milestones: HV0, HV1, HV2, HV3, HV4, HV5, HV6, HV7 when smoke validation passes
    \\  next milestone: HV8 guest trap/exit handling research
    \\  canonical validation command: ./scripts/validate-hyperzig.sh
    \\  no Linux guest support yet
    \\  no guest execution yet
    \\  no guest execution yet; HV7 only prepares guest-entry metadata
    \\  no second-stage translation yet
    \\  VM/vCPU model, vCPU lifecycle, guest-memory object, guest-address-space metadata, tiny-flat-v0 guest-image loader, and guest-entry preparation implemented and smoke-proven when validation passes
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
