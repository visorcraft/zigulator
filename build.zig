const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});

    // Workaround for hosts whose glibc CRT objects contain .sframe sections
    // (e.g. binutils >= 2.46 / GCC 16 with --enable-default-sframe): zig 0.16's
    // linker cannot handle the R_X86_64_PC64 relocations in .rela.sframe.
    // tools/gen-crt-nosframe.sh writes tools/libc-nosframe.txt (a --libc
    // manifest pointing at .sframe-stripped CRT copies). If the manifest
    // exists, apply it; other hosts are unaffected.
    const target = b.standardTargetOptions(.{});
    if (target.query.isNative() and
        target.result.os.tag == .linux and
        target.result.abi.isGnu())
    {
        if (b.build_root.handle.access(b.graph.io, "tools/libc-nosframe.txt", .{})) {
            b.libc_file = "tools/libc-nosframe.txt";
        } else |_| {}
    }

    const exe = b.addExecutable(.{
        .name = "zigulator",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });

    const zglfw = b.dependency("zglfw", .{ .target = target, .optimize = optimize });
    exe.root_module.addImport("zglfw", zglfw.module("root"));
    exe.root_module.linkLibrary(zglfw.artifact("glfw"));

    const zopengl = b.dependency("zopengl", .{});
    exe.root_module.addImport("zopengl", zopengl.module("root"));

    const zgui = b.dependency("zgui", .{
        .target = target,
        .optimize = optimize,
        .backend = .glfw_opengl3,
        .with_implot = true,
    });
    exe.root_module.addImport("zgui", zgui.module("root"));
    exe.root_module.linkLibrary(zgui.artifact("imgui"));

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    b.step("run", "Run zigulator").dependOn(&run_cmd.step);

    const core_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/core.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.step("test", "Run core unit tests").dependOn(&b.addRunArtifact(core_tests).step);
}
