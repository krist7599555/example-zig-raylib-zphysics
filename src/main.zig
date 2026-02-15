const std = @import("std");
const rl = @import("raylib");
const Config = @import("./config.zig").GameConfig;
const GameWorld = @import("./game_world.zig").GameWorld;
const vec3jtr = @import("./vec.zig").vec3jtr;
const Player = @import("./player.zig").Player;
const Util = @import("./util.zig");
const AppShader = @import("./shader/index.zig");
const AppShape = @import("./shape.zig");
const physic = @import("./physic.zig");
const ShadowMapper = @import("./shadow_maper.zig").ShadowMapper;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const seed: u64 = 12345;
    var pcg = std.Random.Pcg.init(seed);
    const random = pcg.random();

    var physics = try physic.Backend.init(allocator);
    defer physics.destroy(allocator);

    physics.physics_system.setGravity(.{ 0, -Config.gravity, 0 });

    var game_world = try GameWorld.init(
        allocator,
        physics,
    );
    defer game_world.deinit();

    rl.initWindow(Config.screen_width, Config.screen_height, "Zig Game");
    defer rl.closeWindow();
    rl.setTargetFPS(Config.fps);

    var shadow_mapper = try ShadowMapper.init(.{
        .resolution = Config.shadow_map.resolution,
        .light_dir = rl.Vector3.initVec(Config.shadow_map.light_direction).normalize(),
    });
    defer shadow_mapper.deinit();

    {
        // CREATE GROUND PLANE
        const shape = try AppShape.calc(AppShape.Plane{
            .size = .{ 50, 50 },
            .sub = .{ 50, 50 },
        });
        _ = try game_world.createBody(.{
            .graphic = .{
                .mesh = shape.mesh,
                .shader = shadow_mapper.shadowShader,
                .tint = .dark_green,
                .wires = .white,
            },
            .physic = .{
                .shape = shape.shape,
                .motion_type = .static,
            },
        });
    }

    for (0..100) |i| {
        // CREATE 100 RANDOM BALL
        const position: [4]f32 = .{
            Util.randomFloat(random, -20, 20),
            @as(f32, @floatFromInt(i)) * 4 + 4,
            Util.randomFloat(random, -20, 20),
            0,
        };

        const shape = try AppShape.calc(AppShape.Sphere{
            .radius = Util.randomFloat(random, 0.2, 2.0),
            .sub = .{ 10, 16 },
        });
        _ = try game_world.createBody(.{
            .graphic = .{
                .mesh = shape.mesh,
                .shader = shadow_mapper.shadowShader,
                .tint = Util.randomColor(random),
            },
            .physic = .{
                .position = position,
                .shape = shape.shape,
                .motion_type = .dynamic,
                .restitution = 0.5, // Coefficient of restitution https://en.wikipedia.org/wiki/Coefficient_of_restitution
            },
        });
    }
    for (0..100) |i| {
        // CREATE 100 RANDOM BOX
        const position: [4]f32 = .{
            Util.randomFloat(random, -20, 20),
            @as(f32, @floatFromInt(i)) * 4 + 4,
            Util.randomFloat(random, -20, 20),
            0,
        };

        const shape = try AppShape.calc(AppShape.Box{
            .size = .{
                Util.randomFloat(random, 0.2, 2.5),
                Util.randomFloat(random, 0.2, 2.5),
                Util.randomFloat(random, 0.2, 2.5),
            },
        });
        _ = try game_world.createBody(.{
            .graphic = .{
                .mesh = shape.mesh,
                .shader = shadow_mapper.shadowShader,
                .tint = Util.randomColor(random),
            },
            .physic = .{
                .position = position,
                .shape = shape.shape,
                .motion_type = .dynamic,
                .restitution = 0.5, // Coefficient of restitution https://en.wikipedia.org/wiki/Coefficient_of_restitution
            },
        });
    }

    // CREATE PLAYER
    var player = try Player.init(.{
        .height = 1.8,
        .radius = 0.5,
        .game = &game_world,
        .shader = shadow_mapper.shadowShader,
        .camera = rl.Camera3D{
            .position = rl.Vector3.init(10, 10, 10),
            .target = rl.Vector3.init(0.0, 0.5, 0.0),
            .up = vec3jtr(Config.up),
            .fovy = Config.camera.fov,
            .projection = .perspective,
        },
    });

    physics.physics_system.optimizeBroadPhase();
    const depthShader: rl.Shader = (try AppShader.DebugDepthShader.init()).shader;
    while (!rl.windowShouldClose()) {
        {
            // UPDATE
            const dt = rl.getFrameTime();
            physics.update(dt); // update physic by 1/60
            player.update();
        }
        {
            // Compute shadowTexture
            shadow_mapper.drawToShadowMapTexture(&game_world);
        }
        {
            // DRAW
            rl.beginDrawing();
            defer rl.endDrawing();

            {
                rl.beginMode3D(player.headCamera);
                defer rl.endMode3D();

                rl.clearBackground(.dark_blue);
                game_world.draw();
            }

            var y: i32 = 10;
            rl.drawFPS(10, y);
            rl.drawText("Zig Game (WASD + E)", 100, y, 20, rl.Color.light_gray);
            y += 25;
            {
                rl.beginShaderMode(depthShader);
                defer rl.endShaderMode();
                rl.drawTextureEx(shadow_mapper.shadowMap.depth, .init(10, @floatFromInt(y)), 0.0, 0.3, .white);
                rl.drawText("Shadow.Depth", 10 + 10, y + 10, 20, rl.Color.white);
                y += 320;
            }
            rl.drawTextureEx(shadow_mapper.shadowMap.texture, .init(10, @floatFromInt(y)), 0.0, 0.3, .white);
            rl.drawText("Shadow.Texture", 10 + 10, y + 10, 20, rl.Color.light_gray);
        }
    }
}
