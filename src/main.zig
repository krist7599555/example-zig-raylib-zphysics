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
const Util = @import("./util.zig");

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

    const ShadowMapper = @import("./shadow_maper.zig").ShadowMapper;
    var shadow_mapper = try ShadowMapper.init();
    defer shadow_mapper.deinit();

    const body_interface = jolt_wrapper.physics_system.getBodyInterfaceMut();
    _ = body_interface;

    const SphereShape = @import("./shape_object.zig").SphereShape;
    const PlaneShape = @import("./shape_object.zig").PlaneShape;

    _ = try game_world.createBody(.{
        .position = .{ 0, 0, 0, 0 },
        .shape = PlaneShape.init(.{ .size = .{ 50, 50 } }),
        .material = try Util.createMaterialFromColor(.dark_green),
        .motion_type = .static,
    });

    // rl.drawMeshInstanced(mesh: Mesh, material: Material, transforms: []const Matrix)
    for (0..100) |i| {
        const x = @as(f32, @floatFromInt(i));
        _ = try game_world.createBody(.{
            .position = .{
                Util.randomFloat(random, -20, 20),
                3 + x,
                Util.randomFloat(random, -20, 20),
                0,
            },
            .shape = SphereShape.init(.{
                .radius = Util.randomFloat(random, 0.2, 0.5),
                .sub = .{ 5, 8 },
            }),
            .motion_type = .dynamic,
            .material = try Util.createMaterialFromColor(Util.randomColor(random)),
            // .wires = rl.Color.white,
        });
    }

    // player need override physic system when create,
    // override camera by listen user input
    var player = try Player.init(
        jolt_wrapper.physics_system,
        &camera,
    );

    for (game_world.game_objects.items) |obj| {
        shadow_mapper.inject_shadow_shader(obj.model);
    }

    jolt_wrapper.physics_system.optimizeBroadPhase();

    while (!rl.windowShouldClose()) {
        {
            // UPDATE
            const dt = rl.getFrameTime();
            jolt_wrapper.update(dt); // update physic by 1/60
            player.update();

            shadow_mapper.update_camera(player.headCamera.*);
        }
        {
            // DRAW
            rl.beginDrawing();
            defer rl.endDrawing();

            rl.clearBackground(.dark_blue);

            shadow_mapper.render_game_world(&game_world);

            {
                rl.beginMode3D(camera);
                defer rl.endMode3D();

                game_world.draw();
                player.draw();
            }

            rl.drawFPS(10, 35);
            rl.drawText("Zig Game (WASD + E)", 10, 10, 20, rl.Color.light_gray);
        }
    }
}
