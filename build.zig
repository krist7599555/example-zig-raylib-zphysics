const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const raylib_dep = b.dependency("raylib_zig", .{
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "zig_car_gl",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "raylib", .module = raylib_dep.module("raylib") },
                .{ .name = "raygui", .module = raylib_dep.module("raygui") },
            },
        }),
    });

    exe.linkLibrary(raylib_dep.artifact("raylib"));
    b.installArtifact(exe);

    // ทำให้ส่วนการรันสั้นลง
    const run_cmd = b.addRunArtifact(exe);
    if (b.args) |args| run_cmd.addArgs(args);
    b.step("run", "Run app").dependOn(&run_cmd.step);
}
