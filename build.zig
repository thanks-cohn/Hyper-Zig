const std = @import("std");

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
}
