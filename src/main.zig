const std = @import("std");
const rl = @import("raylib");
const zphy = @import("zphysics");
const zm = @import("zmath");
const zphy_helper = @import("./zphy_helper.zig");

const X = zm.Vec{ 1, 0, 0, 0 };
const Y = zm.Vec{ 0, 1, 0, 0 };
const Z = zm.Vec{ 0, 0, 1, 0 };
const DT: f32 = 1.0 / 60.0; // delta time

const PhyRef = struct {
    body_id: zphy.BodyId,
    interface: *zphy.BodyInterface,
    fn position(self: *const @This()) zm.Vec {
        return zm.loadArr3(self.interface.getPosition(self.body_id));
    }
    fn rotation(self: *const @This()) zm.Vec {
        return zm.loadArr4(self.interface.getRotation(self.body_id));
    }
    fn velocity(self: *const @This()) zm.Vec {
        return zm.loadArr3(self.interface.getLinearVelocity(self.body_id));
    }
};

const Player = struct {
    ref: PhyRef,
    shader: rl.Shader,

    const size = rl.Vector3.init(1.0, 2.0, 1.0);
    const moveSpeed: f32 = 5.0;
    const turnSpeed: f32 = 3.0;

    pub fn init(shader: rl.Shader, physics_system: *zphy.PhysicsSystem) Player {
        const body_interface = physics_system.getBodyInterfaceMut();

        const box_shape = zphy_helper.createBoxShape(.{ size.x, size.y, size.z }) catch unreachable;

        const body_id = body_interface.createAndAddBody(.{
            .position = .{ 0, size.y / 2.0, 0, 1 },
            .rotation = .{ 0, 0, 0, 1 },
            .shape = box_shape,
            .motion_type = .dynamic,
            .object_layer = zphy_helper.object_layers.moving,

            // .override_mass_properties = .calc_mass_inertia,
            .mass_properties_override = .{
                .mass = 1.0,
                .inertia = @splat(0),
            },

            // .mass_properties_override.inertia = zphysics.Mat44.zero,
            .allowed_DOFs = @enumFromInt(0 |
                @intFromEnum(zphy.AllowedDOFs.translation_x) |
                @intFromEnum(zphy.AllowedDOFs.translation_y) |
                @intFromEnum(zphy.AllowedDOFs.translation_z)),
        }, .activate) catch unreachable;

        return Player{
            .ref = .{ .body_id = body_id, .interface = body_interface },
            .shader = shader,
        };
    }

    fn update(self: *Player, dt: f32, body_interface: *zphy.BodyInterface) void {
        _ = body_interface;

        // Handling Turning via Rotation State
        const turn_input = (if (rl.isKeyDown(.a)) turnSpeed else 0.0) - (if (rl.isKeyDown(.d)) turnSpeed else 0.0);
        if (turn_input != 0) {
            const current_q = self.ref.rotation();
            const dq = zm.quatFromAxisAngle(Y, turn_input * dt);
            const new_q = zm.qmul(dq, current_q); // Rotate around world Y
            self.ref.interface.setRotation(self.ref.body_id, zm.vecToArr4(new_q), .activate);
        }

        const walk_dist = (if (rl.isKeyDown(.w)) moveSpeed else 0.0) - (if (rl.isKeyDown(.s)) moveSpeed else 0.0);

        // Compute forward from current rotation
        const forward = zm.rotate(self.ref.rotation(), Z);
        const current_vel = self.ref.velocity();

        var gravity_scale: f32 = 1.0;
        if (current_vel[1] < -0.1) {
            gravity_scale = 2.5; // Fast fall: ขาลงรวดเร็ว
        } else if (current_vel[1] > 0.1 and !rl.isKeyDown(.space)) {
            gravity_scale = 4.0; // Early release "Low Jump"
        }

        // Apply extra gravity velocity change
        // Note: engine already applied 1.0 gravity. we add (scale - 1.0) more.
        const extra_gravity = -9.81 * (gravity_scale - 1.0) * dt;
        var target_vel_y = current_vel[1] + extra_gravity;

        if (rl.isKeyPressed(.space)) {
            // Ground check: check if vertical velocity is near zero or negative
            if (@abs(current_vel[1]) < 0.1) {
                target_vel_y = 10.0; // Upward impulse: ขาขึ้นนุ่มนวล
            }
        }

        self.ref.interface.setLinearVelocity(self.ref.body_id, .{ forward[0] * walk_dist, target_vel_y, forward[2] * walk_dist });
    }

    fn draw(self: Player, body_interface: *const zphy.BodyInterface) void {
        _ = body_interface;
        const p = self.ref.position();
        const q = self.ref.rotation();

        rl.gl.rlPushMatrix();
        defer rl.gl.rlPopMatrix();

        rl.beginShaderMode(self.shader);
        defer rl.endShaderMode();

        rl.gl.rlTranslatef(p[0], p[1], p[2]);

        var angle_val: f32 = 0;
        var axis: zm.Vec = undefined;
        zm.quatToAxisAngle(q, &axis, &angle_val);
        rl.gl.rlRotatef(angle_val * 180.0 / std.math.pi, axis[0], axis[1], axis[2]);

        rl.drawCube(rl.Vector3.zero(), size.x, size.y, size.z, .red);
        rl.drawCubeWires(rl.Vector3.zero(), size.x, size.y, size.z, .maroon);
    }
};

const Ground = struct {
    ref: PhyRef,
    size: rl.Vector2,

    fn init(center: rl.Vector3, size: rl.Vector2, physics_system: *zphy.PhysicsSystem) Ground {
        const body_interface = physics_system.getBodyInterfaceMut();
        const box_shape = zphy_helper.createBoxShape(.{ size.x, 0.1, size.y }) catch unreachable;

        const body_id = body_interface.createAndAddBody(.{
            .position = .{ center.x, center.y - 0.1, center.z, 1 },
            .shape = box_shape,
            .motion_type = .static,
            .object_layer = zphy_helper.object_layers.non_moving,
        }, .activate) catch unreachable;

        return .{
            .ref = .{ .body_id = body_id, .interface = body_interface },
            .size = size,
        };
    }

    fn draw(self: Ground, body_interface: *const zphy.BodyInterface) void {
        _ = body_interface;
        const p = self.ref.position();
        rl.drawPlane(rl.Vector3.init(p[0], p[1] + 0.1, p[2]), self.size, .green);
        rl.drawGrid(@intFromFloat(self.size.x), 1.0);
    }

    fn update(_: *Ground, _: f32, _: *zphy.BodyInterface) void {}
};

const Box = struct {
    ref: PhyRef,
    size: rl.Vector3,
    color: rl.Color,

    fn init(pos: rl.Vector3, size: rl.Vector3, color: rl.Color, physics_system: *zphy.PhysicsSystem) Box {
        const body_interface = physics_system.getBodyInterfaceMut();

        const box_shape = zphy_helper.createBoxShape(.{ size.x, size.y, size.z }) catch unreachable;

        const body_id = body_interface.createAndAddBody(.{
            .position = .{ pos.x, pos.y, pos.z, 1 },
            .shape = box_shape,
            .motion_type = .dynamic,
            .object_layer = zphy_helper.object_layers.moving,
        }, .activate) catch unreachable;

        return .{
            .ref = .{ .body_id = body_id, .interface = body_interface },
            .size = size,
            .color = color,
        };
    }

    fn draw(self: Box, body_interface: *const zphy.BodyInterface) void {
        _ = body_interface;
        const p = self.ref.position();
        const q = self.ref.rotation();

        rl.gl.rlPushMatrix();
        defer rl.gl.rlPopMatrix();

        rl.gl.rlTranslatef(p[0], p[1], p[2]);

        var angle_val: f32 = 0;
        var axis = zm.f32x4(0, 1, 0, 0);
        zm.quatToAxisAngle(q, &axis, &angle_val);
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

    // const layer_interface = MyBroadphaseLayerInterface.init();
    // const object_vs_broad_phase_filter = MyObjectVsBroadPhaseLayerFilter{};
    // const object_layer_pair_filter = MyObjectLayerPairFilter{};

    var physics_system = try zphy_helper.createPhysicsSystem(allocator);
    defer physics_system.destroy();
    physics_system.setGravity(.{ 0, -9.81, 0 });

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

        // Camera update: pull position and rotation directly from physics
        const player_pos_v = player.ref.position();
        const player_pos = rl.Vector3.init(player_pos_v[0], player_pos_v[1], player_pos_v[2]);
        const q = player.ref.rotation();

        // Calculate camera offset by rotating the local offset (0, 5, -10) by the player's world rotation
        const camOffset_v = zm.rotate(q, zm.f32x4(0, 5, -10, 0));
        camera.position = player_pos.add(rl.Vector3.init(camOffset_v[0], camOffset_v[1], camOffset_v[2]));
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
