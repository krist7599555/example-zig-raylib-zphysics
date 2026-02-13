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

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const jolt_wrapper = try Jolt.JoltWrapper.init(allocator);
    defer jolt_wrapper.destroy(allocator);

    var game_world = try GameWorld.init(allocator);
    defer game_world.deinit(allocator);

    rl.initWindow(Config.screen_width, Config.screen_height, "Zig Game");
    defer rl.closeWindow();
    rl.setTargetFPS(Config.fps);

    const camera = rl.Camera3D{
        .position = rl.Vector3.init(10, 10, 10),
        .target = rl.Vector3.init(0.0, 0.5, 0.0),
        .up = vec3jtr(Config.up),
        .fovy = Config.camera.fov,
        .projection = .perspective,
    };

    // var shadowMapper = Render.ShadowMapper.init();

    const body_interface = jolt_wrapper.physics_system.getBodyInterfaceMut();
    _ = body_interface;
    // var player = try Player.init(joltWrapper, &camera);

    // // const model = rl.LoadModel("resources/models/robot.glb");
    // // const model = rl.LoadModel("resources/vhacd/meshes/al.obj");
    // // const model = rl.LoadModel("resources/models/house.obj");
    // // const model = rl.LoadModel("resources/vhacd/decomp.obj");
    // // _ = model;
    // // std.debug.print("meshCount: {}\n", .{model.meshCount});
    // // if (model.meshes) |meshes| {
    // // for (meshes) |_| {
    // //     std.debug.print("len\n");
    // // }
    // // }
    // // for ( // model.meshes.?[0].

    // {
    //     const floor_shape_settings = try zphy.BoxShapeSettings.create(.{ 5.0, 0.5, 5.0 });
    //     defer floor_shape_settings.release();

    //     const floor_shape = try floor_shape_settings.createShape();
    //     defer floor_shape.release();

    //     const floorBodyId = try body_interface.createAndAddBody(.{
    //         .position = .{ 0.0, -1.0, 0.0, 1.0 },
    //         .rotation = .{ 0.0, 0.0, 0.0, 1.0 },
    //         .shape = floor_shape,
    //         .motion_type = .static,
    //         .object_layer = Jolt.object_layers.non_moving,
    //     }, .activate);

    //     const floorModel = rl.LoadModelFromMesh(rl.GenMeshCube(10.0, 1.0, 10.0));
    //     shadowMapper.InjectShadowShader(floorModel);
    //     const floorObject = game_world.GameObject{ .model = floorModel, .tint = Colors.darkgreen, .bodyId = floorBodyId };
    //     try game_world.game_world.?.gameObjects.append(floorObject);
    // }

    // {
    //     var prng = std.rand.DefaultPrng.init(0);
    //     var buffer = [_]rl.Color{ Colors.yellow, Colors.blue, Colors.cyan, Colors.red, Colors.brown, Colors.green, Colors.verydarkblue, Colors.darkblue };
    //     // prng.random.float(f32)
    //     for (0..40) |i| {
    //         const size = prng.random().float(f32) * 0.3 + 0.1;
    //         // const scaleHalf = scale * 0.5;
    //         const box_shape_settings = try zphy.BoxShapeSettings.create(.{ size, size, size });
    //         defer box_shape_settings.release();
    //         const box_shape = try box_shape_settings.createShape();
    //         defer box_shape.release();
    //         const floatI: f32 = @floatFromInt(i);
    //         const body = try body_interface.createBody(.{
    //             // .position = .{ floatI * 0.1, floatI * 2.0 + 2.0, floatI * 0.1, 1.0 },
    //             .position = .{ prng.random().float(f32) * 10 - 5, floatI * 0.2, prng.random().float(f32) * 10 - 5, 1.0 },
    //             .rotation = .{ 0.0, 0.0, 0.0, 1.0 },
    //             .shape = box_shape,
    //             .motion_type = .dynamic,
    //             .object_layer = Jolt.object_layers.moving,
    //             .angular_velocity = .{ 0.0, 0.0, 0.0, 0 },
    //         });
    //         body_interface.addBody(body.id, .activate);

    //         // const cube1 = rl.LoadModelFromMesh(rl.GenMeshCube(1, 1, 1));
    //         const cube1 = rl.LoadModelFromMesh(rl.GenMeshCube(size * 2, size * 2, size * 2));
    //         shadowMapper.InjectShadowShader(cube1);
    //         prng.random().shuffle(rl.Color, &buffer);
    //         const cube1_object = game_world.GameObject{ .model = cube1, .tint = buffer[0], .bodyId = body.id };
    //         try game_world.game_world.?.gameObjects.append(cube1_object);
    //     }
    // }

    jolt_wrapper.physics_system.optimizeBroadPhase();

    while (!rl.windowShouldClose()) {
        jolt_wrapper.update();
        // shadowMapper.UpadateCamera(player.headCamera.*);
        // player.process();

        rl.beginDrawing();
        defer rl.endDrawing();

        // shadowMapper.RenderGameObjects(joltWrapper);

        rl.beginMode3D(camera);
        defer rl.endMode3D();
        // Render.DrawScene(joltWrapper);
        // player.drawWires(joltWrapper);
    }

    // rl.UnloadShader(shadowMapper.shadowShader);
    // // FIX IT
    // // for (game_world.game_world.gameObjects.items) |object| {
    // //     rl.UnloadModel(object.model);
    // // }
    // shadowMapper.UnloadShadowmapRenderTexture();
    // joltWrapper.destroy(allocator);
}
