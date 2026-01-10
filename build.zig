const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "giggy",
        .root_module = exe_mod,
    });

    exe.linkLibC();
    exe.addIncludePath(b.path("include/"));
    exe.addObjectFile(b.path("lib/libraylib.a"));

    b.installArtifact(exe);

    // const raylib_dep = b.dependency("raylib_zig", .{
    //     .target = target,
    //     .optimize = optimize,
    // });
    // const raylib = raylib_dep.module("raylib"); // main raylib module
    // const raygui = raylib_dep.module("raygui"); // raygui module
    // const raylib_artifact = raylib_dep.artifact("raylib"); // raylib C library

    // exe.linkLibrary(raylib_artifact);
    // exe.root_module.addImport("raylib", raylib);
    // exe.root_module.addImport("raygui", raygui);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
