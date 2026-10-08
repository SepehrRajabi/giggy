const std = @import("std");

pub fn build(b: *std.Build) void {
    const name = "giggy";
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const homebrew_raylib_prefix = detectHomebrewRaylib(b);
    const use_system_raylib = b.option(
        bool,
        "system-raylib",
        "Use system-installed raylib instead of bundled static lib (auto-detected if not set)",
    ) orelse (homebrew_raylib_prefix != null or detectSystemRaylib(b));

    const raylib_include_dir = if (homebrew_raylib_prefix) |prefix|
        b.pathJoin(&.{ prefix, "include" })
    else
        null;
    const raylib_header = if (raylib_include_dir) |include_dir|
        std.Build.LazyPath{ .cwd_relative = b.pathJoin(&.{ include_dir, "raylib.h" }) }
    else
        b.path("third_party/raylib/include/raylib.h");
    const raymath_header = if (raylib_include_dir) |include_dir|
        std.Build.LazyPath{ .cwd_relative = b.pathJoin(&.{ include_dir, "raymath.h" }) }
    else
        b.path("third_party/raylib/include/raymath.h");

    const raylib_translate = b.addTranslateC(.{
        .root_source_file = raylib_header,
        .target = target,
        .optimize = optimize,
    });
    const raymath_translate = b.addTranslateC(.{
        .root_source_file = raymath_header,
        .target = target,
        .optimize = optimize,
    });
    if (raylib_include_dir) |include_dir| {
        const include_path = std.Build.LazyPath{ .cwd_relative = include_dir };
        raylib_translate.addSystemIncludePath(include_path);
        raymath_translate.addSystemIncludePath(include_path);
    } else {
        raylib_translate.addIncludePath(b.path("third_party/raylib/include/"));
        raymath_translate.addIncludePath(b.path("third_party/raylib/include/"));
    }

    const engine_mod = b.createModule(.{
        .root_source_file = b.path("src/engine/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    engine_mod.addImport("engine", engine_mod);
    engine_mod.addImport("raylib_c", raylib_translate.createModule());
    engine_mod.addImport("raymath_c", raymath_translate.createModule());
    if (!use_system_raylib) {
        engine_mod.addIncludePath(b.path("third_party/raylib/include/"));
    } else if (homebrew_raylib_prefix) |prefix| {
        engine_mod.addSystemIncludePath(.{ .cwd_relative = b.pathJoin(&.{ prefix, "include" }) });
    }

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/game/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    exe_mod.addImport("engine", engine_mod);
    const game_mod = b.createModule(.{
        .root_source_file = b.path("src/game/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    game_mod.addImport("engine", engine_mod);
    game_mod.addImport("game", game_mod);
    exe_mod.addImport("game", game_mod);

    const exe = b.addExecutable(.{
        .name = name,
        .root_module = exe_mod,
    });

    if (use_system_raylib) {
        if (homebrew_raylib_prefix) |prefix| {
            exe.root_module.addLibraryPath(.{ .cwd_relative = b.pathJoin(&.{ prefix, "lib" }) });
            exe.root_module.linkSystemLibrary("raylib", .{ .use_pkg_config = .no });
        } else {
        exe.root_module.linkSystemLibrary("raylib", .{});
        }
    } else {
        exe.root_module.addIncludePath(b.path("third_party/raylib/include/"));
        exe.root_module.addObjectFile(b.path("third_party/raylib/lib/libraylib.a"));
    }

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const examples_step = b.step("examples", "Build all examples");
    addExample(b, engine_mod, target, optimize, use_system_raylib, "blob", "src/examples/blob/main.zig", examples_step);
    addExample(b, engine_mod, target, optimize, use_system_raylib, "ecs-stress", "src/examples/ecs_stress/main.zig", examples_step);
    addExample(b, engine_mod, target, optimize, use_system_raylib, "path-finding", "src/examples/path_finding/main.zig", examples_step);
}

fn detectSystemRaylib(b: *std.Build) bool {
    const result = std.process.run(b.allocator, b.graph.io, .{
        .argv = &.{ "pkg-config", "--exists", "raylib" },
    }) catch return false;
    defer b.allocator.free(result.stdout);
    defer b.allocator.free(result.stderr);
    switch (result.term) {
        // Child.Term's fields are lowercase as of 0.16 (.Exited -> .exited).
        .exited => |code| return code == 0,
        else => return false,
    }
}

fn detectHomebrewRaylib(b: *std.Build) ?[]const u8 {
    const result = std.process.run(b.allocator, b.graph.io, .{
        .argv = &.{ "brew", "--prefix", "raylib" },
    }) catch return null;
    defer b.allocator.free(result.stdout);
    defer b.allocator.free(result.stderr);

    switch (result.term) {
        .exited => |code| if (code == 0) {
            const prefix = std.mem.trim(u8, result.stdout, " \r\n\t");
            if (prefix.len != 0) return b.allocator.dupe(u8, prefix) catch @panic("OOM");
        },
        else => {},
    }
    return null;
}

fn addExample(
    b: *std.Build,
    engine_mod: *std.Build.Module,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    use_system_raylib: bool,
    name: []const u8,
    root_path: []const u8,
    examples_step: *std.Build.Step,
) void {
    const mod = b.createModule(.{
        .root_source_file = b.path(root_path),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    mod.addImport("engine", engine_mod);

    const exe = b.addExecutable(.{
        .name = b.fmt("example-{s}", .{name}),
        .root_module = mod,
    });

    if (use_system_raylib) {
        exe.root_module.linkSystemLibrary("raylib", .{});
    } else {
        exe.root_module.addIncludePath(b.path("third_party/raylib/include/"));
        exe.root_module.addObjectFile(b.path("third_party/raylib/lib/libraylib.a"));
    }

    b.installArtifact(exe);

    const build_step = b.step(b.fmt("example-{s}", .{name}), "Build example");
    build_step.dependOn(&exe.step);
    examples_step.dependOn(&exe.step);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    const run_step = b.step(b.fmt("run-example-{s}", .{name}), "Run example");
    run_step.dependOn(&run_cmd.step);
}
