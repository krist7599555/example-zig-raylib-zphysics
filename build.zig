const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const is_wasm = target.result.cpu.arch == .wasm32;

    const raylib_dep = b.dependency("raylib_zig", .{
        .target = target,
        .optimize = optimize,
    });
    const zphysics = b.dependency("zphysics", .{
        .use_double_precision = false,
        .enable_cross_platform_determinism = true,
        .target = target,
        .optimize = optimize,
    });

    // Zemscripten dependency (only used for bindings in this setup,
    // relying on system emcc for linking)

    if (is_wasm) {
        const lib = b.addExecutable(.{
            .name = "zig_car_gl",
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/main.zig"),
                .target = target,
                .optimize = optimize,
                .imports = &.{
                    .{ .name = "raylib", .module = raylib_dep.module("raylib") },
                    .{ .name = "raygui", .module = raylib_dep.module("raygui") },
                    .{ .name = "zphysics", .module = zphysics.module("root") },
                },
            }),
        });
        lib.linkLibC();
        lib.linkSystemLibrary("c");

        lib.linkLibrary(zphysics.artifact("joltc"));
        lib.linkLibrary(raylib_dep.artifact("raylib"));

        b.installArtifact(lib);

        const emcc = b.addSystemCommand(&.{
            "emcc",
            "-o",
            "zig-out/bin/game.js",
            "-s",
            "USE_GLFW=3",
            "-s",
            "ALLOW_MEMORY_GROWTH=1",
            "-s",
            "ASYNCIFY",
            "-s",
            "USE_OFFSET_CONVERTER=1",
            "-DPLATFORM_WEB",
        });

        if (optimize == .ReleaseSmall or optimize == .ReleaseFast) {
            emcc.addArg("-Os");
        }

        emcc.addArtifactArg(lib);
        emcc.addArtifactArg(raylib_dep.artifact("raylib"));
        emcc.addArtifactArg(zphysics.artifact("joltc"));

        b.getInstallStep().dependOn(&emcc.step);
    } else {
        const exe = b.addExecutable(.{
            .name = "zig_car_gl",
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/main.zig"),
                .target = target,
                .optimize = optimize,
                .imports = &.{
                    .{ .name = "raylib", .module = raylib_dep.module("raylib") },
                    .{ .name = "raygui", .module = raylib_dep.module("raygui") },
                    .{ .name = "zphysics", .module = zphysics.module("root") },
                },
            }),
        });

        exe.linkLibrary(zphysics.artifact("joltc"));
        exe.linkLibrary(raylib_dep.artifact("raylib"));

        b.installArtifact(exe);

        const run_cmd = b.addRunArtifact(exe);
        if (b.args) |args| run_cmd.addArgs(args);
        b.step("run", "Run app").dependOn(&run_cmd.step);
    }
}
