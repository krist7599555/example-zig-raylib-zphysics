const std = @import("std");
const rl = @import("raylib");
const zphy = @import("zphysics");
const zm = @import("zmath");

// --- Physics Configuration ---
const object_layers = struct {
    const non_moving: zphy.ObjectLayer = 0;
    const moving: zphy.ObjectLayer = 1;
    const len: u32 = 2;
};

const broad_phase_layers = struct {
    const non_moving: zphy.BroadPhaseLayer = 0;
    const moving: zphy.BroadPhaseLayer = 1;
    const len: u32 = 2;
};

const MyBroadphaseLayerInterface = extern struct {
    interface: zphy.BroadPhaseLayerInterface = .init(@This()),
    object_to_broad_phase: [object_layers.len]zphy.BroadPhaseLayer = undefined,

    fn init() MyBroadphaseLayerInterface {
        var layer_interface: MyBroadphaseLayerInterface = .{};
        layer_interface.object_to_broad_phase[object_layers.non_moving] = broad_phase_layers.non_moving;
        layer_interface.object_to_broad_phase[object_layers.moving] = broad_phase_layers.moving;
        return layer_interface;
    }

    pub fn getNumBroadPhaseLayers(interface: *const zphy.BroadPhaseLayerInterface) callconv(.c) u32 {
        const self: *const MyBroadphaseLayerInterface = @alignCast(@fieldParentPtr("interface", interface));
        return @intCast(self.object_to_broad_phase.len);
    }

    pub fn getBroadPhaseLayer(interface: *const zphy.BroadPhaseLayerInterface, layer: zphy.ObjectLayer) callconv(.c) zphy.BroadPhaseLayer {
        const self: *const MyBroadphaseLayerInterface = @alignCast(@fieldParentPtr("interface", interface));
        return self.object_to_broad_phase[@intCast(layer)];
    }
};

const MyObjectVsBroadPhaseLayerFilter = extern struct {
    filter: zphy.ObjectVsBroadPhaseLayerFilter = .init(@This()),

    pub fn shouldCollide(_: *const zphy.ObjectVsBroadPhaseLayerFilter, layer1: zphy.ObjectLayer, layer2: zphy.BroadPhaseLayer) callconv(.c) bool {
        return switch (layer1) {
            object_layers.non_moving => layer2 == broad_phase_layers.moving,
            object_layers.moving => true,
            else => unreachable,
        };
    }
};

const MyObjectLayerPairFilter = extern struct {
    interface: zphy.ObjectLayerPairFilter = .init(@This()),

    pub fn shouldCollide(_: *const zphy.ObjectLayerPairFilter, object1: zphy.ObjectLayer, object2: zphy.ObjectLayer) callconv(.c) bool {
        return switch (object1) {
            object_layers.non_moving => object2 == object_layers.moving,
            object_layers.moving => true,
            else => unreachable,
        };
    }
};

const PhyRef = struct {
    body_id: zphy.BodyId,
    interface: *zphy.BodyInterface,
    fn position(self: *@This()) zm.Vec {
        return zm.loadArr3(self.interface.getPosition(self.body_id));
    }
    fn rotation(self: *@This()) zm.Vec {
        return zm.loadArr4(self.interface.getRotation(self.body_id));
    }
    fn velocity(self: *@This()) zm.Vec {
        return zm.loadArr4(self.interface.getLinearVelocity(self.body_id));
    }
};

const Player = struct {
    body_id: zphy.BodyId,
    shader: rl.Shader,
    yaw: f32, // Y-rotation (from aircraft)

    const radius: f32 = 0.5;
    const height: f32 = 1.0;
    const moveSpeed: f32 = 5.0;
    const turnSpeed: f32 = 3.0;

    pub fn init(shader: rl.Shader, physics_system: *zphy.PhysicsSystem) Player {
        const body_interface = physics_system.getBodyInterfaceMut();

        const capsule_settings = zphy.CapsuleShapeSettings.create(height / 2.0, radius) catch unreachable;
        defer capsule_settings.asShapeSettings().release();
        const capsule_shape = capsule_settings.asShapeSettings().createShape() catch unreachable;
        defer capsule_shape.release();

        const body_id = body_interface.createAndAddBody(.{
            .position = .{ 0, height, 0, 1 },
            .rotation = .{ 0, 0, 0, 1 },
            .shape = capsule_shape,
            .motion_type = .dynamic,
            .object_layer = object_layers.moving,
// .allowed_DOFs = 0b010111,
            .allowed_DOFs = @enumFromInt(0 |
                @intFromEnum(zphy.AllowedDOFs.translation_x) |
                @intFromEnum(zphy.AllowedDOFs.translation_y) |
                @intFromEnum(zphy.AllowedDOFs.translation_z) |
                @intFromEnum(zphy.AllowedDOFs.rotation_y)),
        }, .activate) catch unreachable;

        return Player{
            .body_id = body_id,
            .shader = shader,
            .yaw = 0.0,
        };
    }

    fn update(self: *Player, dt: f32, body_interface: *zphy.BodyInterface) void {
        const turn_input = (if (rl.isKeyDown(.a)) turnSpeed else 0.0) - (if (rl.isKeyDown(.d)) turnSpeed else 0.0);
        self.yaw += turn_input * dt;

        const walk_dist = (if (rl.isKeyDown(.w)) moveSpeed else 0.0) - (if (rl.isKeyDown(.s)) moveSpeed else 0.0);

        const forward = rl.Vector3.init(@sin(self.yaw), 0, @cos(self.yaw));
        const target_vel = forward.scale(walk_dist);
        const current_vel = body_interface.getLinearVelocity(self.body_id);

        body_interface.setLinearVelocity(self.body_id, .{ target_vel.x, current_vel[1], target_vel.z });

        if (rl.isKeyPressed(.space)) {
            if (@abs(current_vel[1]) < 0.1) {
                body_interface.addImpulse(self.body_id, .{ 0, 8, 0 });
            }
        }
    }

    fn draw(self: Player, body_interface: *const zphy.BodyInterface) void {
        const p = body_interface.getPosition(self.body_id);

        rl.gl.rlPushMatrix();
        defer rl.gl.rlPopMatrix();

        rl.beginShaderMode(self.shader);
        defer rl.endShaderMode();

        rl.gl.rlTranslatef(p[0], p[1], p[2]);
        rl.gl.rlRotatef(self.yaw * 180.0 / std.math.pi, 0.0, 1.0, 0.0);

        const centerOffset = rl.Vector3.init(0.0, 0.0, 0.0);
        rl.drawCylinder(centerOffset, radius, radius, height, 12, .white);
        rl.drawCylinderWires(centerOffset, radius, radius, height, 12, .white);
    }
};

const Ground = struct {
    body_id: zphy.BodyId,
    size: rl.Vector2,

    fn init(center: rl.Vector3, size: rl.Vector2, physics_system: *zphy.PhysicsSystem) Ground {
        const body_interface = physics_system.getBodyInterfaceMut();

        const box_settings = zphy.BoxShapeSettings.create(.{ size.x / 2.0, 0.1, size.y / 2.0 }) catch unreachable;
        defer box_settings.asShapeSettings().release();
        const box_shape = box_settings.asShapeSettings().createShape() catch unreachable;
        defer box_shape.release();

        const body_id = body_interface.createAndAddBody(.{
            .position = .{ center.x, center.y - 0.1, center.z, 1 },
            .shape = box_shape,
            .motion_type = .static,
            .object_layer = object_layers.non_moving,
        }, .activate) catch unreachable;

        return .{
            .body_id = body_id,
            .size = size,
        };
    }

    fn draw(self: Ground, body_interface: *const zphy.BodyInterface) void {
        const p = body_interface.getPosition(self.body_id);
        rl.drawPlane(rl.Vector3.init(p[0], p[1] + 0.1, p[2]), self.size, .green);
        rl.drawGrid(@intFromFloat(self.size.x), 1.0);
    }

    fn update(_: *Ground, _: f32, _: *zphy.BodyInterface) void {}
};

const Box = struct {
    body_id: zphy.BodyId,
    size: rl.Vector3,
    color: rl.Color,

    fn init(pos: rl.Vector3, size: rl.Vector3, color: rl.Color, physics_system: *zphy.PhysicsSystem) Box {
        const body_interface = physics_system.getBodyInterfaceMut();

        const box_settings = zphy.BoxShapeSettings.create(.{ size.x / 2.0, size.y / 2.0, size.z / 2.0 }) catch unreachable;
        defer box_settings.asShapeSettings().release();
        const box_shape = box_settings.asShapeSettings().createShape() catch unreachable;
        defer box_shape.release();

        const body_id = body_interface.createAndAddBody(.{
            .position = .{ pos.x, pos.y, pos.z, 1 },
            .shape = box_shape,
            .motion_type = .dynamic,
            .object_layer = object_layers.moving,
        }, .activate) catch unreachable;

        return .{
            .body_id = body_id,
            .size = size,
            .color = color,
        };
    }

    fn draw(self: Box, body_interface: *const zphy.BodyInterface) void {
        const p = body_interface.getPosition(self.body_id);
        const q = body_interface.getRotation(self.body_id);

        rl.gl.rlPushMatrix();
        defer rl.gl.rlPopMatrix();

        rl.gl.rlTranslatef(p[0], p[1], p[2]);

        var angle_val: f32 = 0;
        var axis = zm.f32x4(0, 1, 0, 0);
        zm.quatToAxisAngle(zm.loadArr4(q), &axis, &angle_val);
        rl.gl.rlRotatef(angle_val * 180.0 / std.math.pi, axis[0], axis[1], axis[2]);

        rl.drawCube(rl.Vector3.zero(), self.size.x, self.size.y, self.size.z, self.color);
        rl.drawCubeWires(rl.Vector3.zero(), self.size.x, self.size.y, self.size.z, .black);
    }

    fn update(_: *Box, _: f32, _: *zphy.BodyInterface) void {}
};

const Mesh = struct {
    ptr: *anyopaque,
    updateFn: *const fn (ptr: *anyopaque, dt: f32, body_interface: *zphy.BodyInterface) void,
    drawFn: *const fn (ptr: *anyopaque, body_interface: *const zphy.BodyInterface) void,

    fn init(ptr: anytype) Mesh {
        const T = @TypeOf(ptr);
        const PtrT = if (@typeInfo(T) == .pointer) T else *T;
        const gen = struct {
            fn update(ctx: *anyopaque, dt: f32, body_interface: *zphy.BodyInterface) void {
                const self: PtrT = @ptrCast(@alignCast(ctx));
                self.update(dt, body_interface);
            }
            fn draw(ctx: *anyopaque, body_interface: *const zphy.BodyInterface) void {
                const self: PtrT = @ptrCast(@alignCast(ctx));
                self.draw(body_interface);
            }
        };
        return .{
            .ptr = @constCast(ptr),
            .updateFn = gen.update,
            .drawFn = gen.draw,
        };
    }

    fn update(self: Mesh, dt: f32, body_interface: *zphy.BodyInterface) void {
        self.updateFn(self.ptr, dt, body_interface);
    }

    fn draw(self: Mesh, body_interface: *const zphy.BodyInterface) void {
        self.drawFn(self.ptr, body_interface);
    }
};

pub fn main() anyerror!void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    try zphy.init(allocator, .{});
    defer zphy.deinit();

    const layer_interface = MyBroadphaseLayerInterface.init();
    const object_vs_broad_phase_filter = MyObjectVsBroadPhaseLayerFilter{};
    const object_layer_pair_filter = MyObjectLayerPairFilter{};

    var physics_system = try zphy.PhysicsSystem.create(
        @ptrCast(&layer_interface),
        @ptrCast(&object_vs_broad_phase_filter),
        @ptrCast(&object_layer_pair_filter),
        .{
            .max_bodies = 1024,
            .num_body_mutexes = 0,
            .max_body_pairs = 1024,
            .max_contact_constraints = 1024,
        },
    );
    defer physics_system.destroy();

    var prng = std.Random.DefaultPrng.init(@intCast(std.time.timestamp()));
    const rand = prng.random();

    const screenWidth = 800;
    const screenHeight = 450;

    rl.initWindow(screenWidth, screenHeight, "Zig Car GL - zphysics integration");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    const normal_shader = try rl.loadShader("src/shaders/player.vert", "src/shaders/normal.frag");
    defer rl.unloadShader(normal_shader);

    var player = Player.init(normal_shader, physics_system);
    var ground = Ground.init(rl.Vector3.init(0, 0, 0), rl.Vector2.init(20, 20), physics_system);

    var boxes: [100]Box = undefined;
    for (&boxes) |*box| {
        box.* = Box.init(
            rl.Vector3.init(
                rand.float(f32) * 20.0 - 10.0,
                rand.float(f32) * 40.0 + 10.0,
                rand.float(f32) * 20.0 - 10.0,
            ),
            rl.Vector3.init(0.5 + rand.float(f32), 0.5 + rand.float(f32), 0.5 + rand.float(f32)),
            rl.Color.init(rand.uintAtMost(u8, 255), rand.uintAtMost(u8, 255), rand.uintAtMost(u8, 255), 255),
            physics_system,
        );
    }

    var mesh_list: [102]Mesh = undefined;
    mesh_list[0] = Mesh.init(&player);
    mesh_list[1] = Mesh.init(&ground);
    for (0..100) |i| {
        mesh_list[i + 2] = Mesh.init(&boxes[i]);
    }
    const meshs: []const Mesh = &mesh_list;

    var camera = rl.Camera3D{
        .position = rl.Vector3.init(0, 10, 10),
        .target = rl.Vector3.init(0, 0, 0),
        .up = rl.Vector3.init(0, 1, 0),
        .fovy = 45.0,
        .projection = .perspective,
    };

    while (!rl.windowShouldClose()) {
        const dt = rl.getFrameTime();

        try physics_system.update(dt, .{});
        const body_interface = physics_system.getBodyInterfaceMut();

        for (meshs) |mesh| {
            mesh.update(dt, body_interface);
        }

        // Camera update: pull position directly from physics
        const p = body_interface.getPosition(player.body_id);
        const player_pos = rl.Vector3.init(p[0], p[1], p[2]);
        const camOffset = rl.Vector3.init(0.0, 5.0, -10.0).rotateByAxisAngle(rl.Vector3.init(0, 1, 0), player.yaw);
        camera.position = player_pos.add(camOffset);
        camera.target = player_pos;

        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(.ray_white);

        {
            camera.begin();
            defer camera.end();

            for (meshs) |mesh| {
                mesh.draw(body_interface);
            }
        }

        rl.drawFPS(10, 10);
    }
}
