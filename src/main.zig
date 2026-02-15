const std = @import("std");
const rl = @import("raylib");
const zphy = @import("zphysics");
const Config = @import("./config.zig").GameConfig;
const game = @import("./game.zig");
const vec3jtr = @import("./vec.zig").vec3jtr;
const PlayerEntity = @import("./player.zig").PlayerEntity;
const Util = @import("./util.zig");
const shaders = @import("./shader/index.zig");
const physic = @import("./physic.zig");
const shapes = @import("./shape.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var pcg = std.Random.Pcg.init(Config.random_seed);
    const random = pcg.random();

    var physic_backend = try physic.Backend.init(allocator);
    defer physic_backend.destroy(allocator);

    var game_state = try game.State.init(allocator);

    rl.initWindow(Config.screen_width, Config.screen_height, "Zig Game");
    rl.setTargetFPS(Config.fps);
    defer rl.closeWindow();

    const shadow_pass = try shaders.ShadowMapPass.init(.{
        .texture_resolution = Config.shadow_map.texture_resolution,
        .light_dir = rl.Vector3.initVec(Config.shadow_map.light_direction),
    });
    defer shadow_pass.deinit();

    const depth_visualize_pass = try shaders.DepthVisualize.init();
    defer depth_visualize_pass.deinit();

    var ground: game.Entity = undefined;
    {
        // CREATE GROUND PLANE
        const plane_size = @Vector(2, f32){ 50, 50 };
        ground = try game.createBody(.{
            .physic_backend = physic_backend,
            .game_state = &game_state,
            .graphic = .{
                .mesh = shapes.plane_mesh(plane_size, .{ 50, 50 }),
                .shader = shadow_pass.depth_shader,
                .tint = .dark_green,
            },
            .physic = .{
                .shape = try shapes.plane_shape(plane_size),
                .motion_type = .static,
            },
        });
    }

    const unit_sphere_mesh = shapes.sphere_mesh(1.0, 10, 16);
    for (0..100) |i| {
        // CREATE 100 RANDOM BALL
        const radius = Util.rand_f32(random, 0.2, 2.0);
        _ = try game.createBody(.{
            .physic_backend = physic_backend,
            .game_state = &game_state,
            .graphic = .{
                .mesh = unit_sphere_mesh,
                .shader = shadow_pass.depth_shader,
                .tint = Util.rand_color(random),
                .scale = .init(radius, radius, radius),
            },
            .physic = .{
                .shape = try shapes.sphere_shape(radius),
                .motion_type = .dynamic,
                .restitution = 0.5, // Coefficient of restitution https://en.wikipedia.org/wiki/Coefficient_of_restitution
                .position = .{
                    Util.rand_f32(random, -20, 20),
                    @as(f32, @floatFromInt(i)) * 4 + 4,
                    Util.rand_f32(random, -20, 20),
                    0,
                },
            },
        });
    }
    const unit_box_mesh = shapes.box_mesh(.{ 1, 1, 1 });
    for (0..100) |i| {
        // CREATE 100 RANDOM BOX
        const size = @Vector(3, f32){
            Util.rand_f32(random, 0.2, 2.5),
            Util.rand_f32(random, 0.2, 2.5),
            Util.rand_f32(random, 0.2, 2.5),
        };
        _ = try game.createBody(.{
            .physic_backend = physic_backend,
            .game_state = &game_state,
            .graphic = .{
                .mesh = unit_box_mesh,
                .shader = shadow_pass.depth_shader,
                .tint = Util.rand_color(random),
                .scale = .initVec(size),
            },
            .physic = .{
                .shape = try shapes.box_shape(size),
                .motion_type = .dynamic,
                .restitution = 0.5, // Coefficient of restitution https://en.wikipedia.org/wiki/Coefficient_of_restitution
                .position = .{
                    Util.rand_f32(random, -20, 20),
                    @as(f32, @floatFromInt(i)) * 4 + 4,
                    Util.rand_f32(random, -20, 20),
                    0,
                },
            },
        });
    }

    // CREATE PLAYER
    var player = try PlayerEntity.init(.{
        .height = 1.8,
        .radius = 0.5,
        .physic_backend = physic_backend,
        .shader = shadow_pass.depth_shader,
        .camera = rl.Camera3D{
            .position = rl.Vector3.init(10, 10, 10),
            .target = rl.Vector3.init(0.0, 0.5, 0.0),
            .up = vec3jtr(Config.up),
            .fovy = Config.camera.fov,
            .projection = .perspective,
        },
    });
    try game_state.add(player.enitity);

    physic_backend.optimize();
    while (!rl.windowShouldClose()) {
        {
            // UPDATE
            const dt = rl.getFrameTime();
            physic_backend.update(dt); // update physic by 1/60
            player.update();
        }
        {
            // Compute shadowTexture
            shadow_pass.begin_shadow_pass();
            defer shadow_pass.end_shadow_pass();
            game.draw(&game_state);
        }
        {
            // DRAW
            rl.beginDrawing();
            defer rl.endDrawing();

            {
                // DRAW 3D
                rl.beginMode3D(player.headCamera);
                defer rl.endMode3D();

                rl.clearBackground(.dark_blue);

                game.draw(&game_state);
                ground.drawWires();
            }

            {
                // DRAW 2D
                var y: i32 = 10;
                rl.drawFPS(10, y);
                rl.drawText("Zig Game (WASD + E)", 100, y, 20, rl.Color.light_gray);
                y += 25;
                {
                    depth_visualize_pass.begin_shader();
                    defer depth_visualize_pass.end_shader();
                    rl.drawTextureEx(shadow_pass.get_texture_depth(), .init(10, @floatFromInt(y)), 0.0, 0.3, .white);
                }
                rl.drawText("Shadow.Depth", 10 + 10, y + 10, 20, rl.Color.white);
                y += 320;
                rl.drawTextureEx(shadow_pass.get_texture_rgb(), .init(10, @floatFromInt(y)), 0.0, 0.3, .white);
                rl.drawText("Shadow.Texture", 10 + 10, y + 10, 20, rl.Color.light_gray);
            }
        }
    }
}
