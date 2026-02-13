const std = @import("std");
const rl = @import("raylib");
const zphy = @import("zphysics");
const zm = @import("zmath");
const znoise = @import("znoise");
const zphy_helper = @import("./zphy_helper.zig");
const Jolt = @import("./jolt.zig");
const Config = @import("./config.zig").GameConfig;
// const game_world = @import("./game_world.zig").game_world;
const GameWorld = @import("./game_world.zig").GameWorld;
const splat = @import("./vec.zig").splat;
const vec3 = @import("./vec.zig").vec3;
const vec3jtr = @import("./vec.zig").vec3jtr;
const vec4 = @import("./vec.zig").vec4;
const Vec2 = @Vector(2, f32);
const Vec3 = @Vector(3, f32);
const Vec4 = @Vector(4, f32);
const Player = @import("./player.zig").Player;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const seed: u64 = 12345;
    var pcg = std.Random.Pcg.init(seed);
    const random = pcg.random();

    var jolt_wrapper = try Jolt.JoltWrapper.init(allocator);
    defer jolt_wrapper.destroy(allocator);

    jolt_wrapper.physics_system.setGravity(.{ 0, -Config.gravity, 0 });

    var game_world = try GameWorld.init(
        allocator,
        jolt_wrapper.physics_system.getBodyInterfaceMut(),
    );
    defer game_world.deinit();

    rl.initWindow(Config.screen_width, Config.screen_height, "Zig Game");
    defer rl.closeWindow();
    rl.setTargetFPS(Config.fps);

    var camera = rl.Camera3D{
        .position = rl.Vector3.init(10, 10, 10),
        .target = rl.Vector3.init(0.0, 0.5, 0.0),
        .up = vec3jtr(Config.up),
        .fovy = Config.camera.fov,
        .projection = .perspective,
    };

    // var shadowMapper = Render.ShadowMapper.init();

    const body_interface = jolt_wrapper.physics_system.getBodyInterfaceMut();
    _ = body_interface;

    const SphereShape = @import("./shape_object.zig").SphereShape;
    const PlaneShape = @import("./shape_object.zig").PlaneShape;

    _ = try game_world.create_and_add(.{
        .position = .{ 0, 0, 0, 0 },
        .shape = PlaneShape.init(.{ .size = .{ 20, 20 } }),
        .tint = rl.Color.dark_green,
        .motion_type = .static,
    });

    // rl.drawMeshInstanced(mesh: Mesh, material: Material, transforms: []const Matrix)
    for (0..70) |i| {
        const x = @as(f32, @floatFromInt(i));
        _ = try game_world.create_and_add(.{
            .position = .{
                @as(f32, @floatFromInt(random.intRangeLessThan(i32, 0, 40) - 20)),
                3 + x,
                @as(f32, @floatFromInt(random.intRangeLessThan(i32, 0, 40) - 20)),
                0,
            },
            .shape = SphereShape.init(.{ .radius = 0.2, .sub = .{ 5, 8 } }),
            // .tint = rl.Color.init(
            //     random.uintLessThan(u8, 255),
            //     random.uintLessThan(u8, 255),
            //     random.uintLessThan(u8, 255),
            //     255,
            // ),
            .motion_type = .dynamic,
            .material = blk: {
                var material = try rl.loadMaterialDefault();
                material.maps[@as(usize, @intFromEnum(rl.MATERIAL_MAP_DIFFUSE))].color =
                    rl.Color.init(
                        random.uintLessThan(u8, 255),
                        random.uintLessThan(u8, 255),
                        random.uintLessThan(u8, 255),
                        255,
                    );
                break :blk material;
            },
        });
    }

    // player need override physic system when create,
    // override camera by listen user input
    var player = try Player.init(
        jolt_wrapper.physics_system,
        &camera,
    );

    jolt_wrapper.physics_system.optimizeBroadPhase();

    while (!rl.windowShouldClose()) {
        jolt_wrapper.update(); // update physic by 1/60
        player.update();

        rl.updateCamera(&camera, .third_person);

        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(.dark_blue);

        rl.beginMode3D(camera);
        defer rl.endMode3D();

        game_world.draw();
        player.draw();
    }
}
