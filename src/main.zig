const std = @import("std");
const rl = @import("raylib");
const zphy = @import("zphysics");
const zm = @import("zmath");
const zphy_helper = @import("./zphy_helper.zig");
const splat = @import("./vec.zig").splat;
const vec3 = @import("./vec.zig").vec3;
const vec4 = @import("./vec.zig").vec4;
const Vec2 = @Vector(2, f32);
const Vec3 = @Vector(3, f32);
const Vec4 = @Vector(4, f32);

const EPSILON = 0.001;
const EARTH_GRAVITY = 9.8; // additional gravity more from physics_system.setGravity

const PhyRef = struct {
    body_id: zphy.BodyId,
    interface: *zphy.BodyInterface,
    fn position(self: *const @This()) Vec3 {
        return vec3(self.interface.getPosition(self.body_id));
    }
    fn rotation(self: *const @This()) Vec4 {
        return vec4(self.interface.getRotation(self.body_id));
    }
    fn velocity(self: *const @This()) Vec3 {
        return vec3(self.interface.getLinearVelocity(self.body_id));
    }
    fn transformMat(self: *const @This()) zm.Mat {
        const pos = self.position();
        const rot = self.rotation();
        const translation = zm.translation(pos[0], pos[1], pos[2]);
        const rotation_ = zm.quatToMat(rot);
        const model_matrix: zm.Mat = zm.mul(rotation_, translation);
        return model_matrix;
    }
    fn camera_position(self: *const @This()) rl.Vector3 {
        // ดึงข้อมูลพื้นฐาน
        const p_rot = self.rotation();
        const p_pos = self.position();

        // คำนวณตำแหน่งที่กล้องควรจะอยู่ (Target Position)
        const CAM_HEIGHT = 5;
        const CAM_FAR = -10;
        const offset = zm.f32x4(0, CAM_HEIGHT, CAM_FAR, 0);
        const desired_pos = vec4(p_pos) + zm.rotate(p_rot, offset);

        // ส่งค่าให้ Raylib Camera แบบกระชับ
        return rl.Vector3.init(desired_pos[0], desired_pos[1], desired_pos[2]);
    }
};

const Player = struct {
    ref: PhyRef,
    shader: rl.Shader,

    const size = rl.Vector3.init(1.0, 2.0, 1.0);
    const moveSpeed: f32 = 8.0;
    const turnSpeed: f32 = 3.0;

    pub fn init(shader: rl.Shader, physics_system: *zphy.PhysicsSystem) Player {
        const START_Y = 5;
        const body_interface = physics_system.getBodyInterfaceMut();
        const body_id = body_interface.createAndAddBody(.{
            .position = .{ 0, size.y / 2.0 + START_Y, 0, 1 },
            .rotation = .{ 0, 0, 0, 1 },
            .shape = zphy_helper.createBoxShape(vec3(size)) catch unreachable,
            .motion_type = .dynamic,
            .object_layer = zphy_helper.object_layers.moving,
            .allowed_DOFs = @enumFromInt(0 |
                @intFromEnum(zphy.AllowedDOFs.translation_x) |
                @intFromEnum(zphy.AllowedDOFs.translation_y) |
                @intFromEnum(zphy.AllowedDOFs.translation_z)),
        }, .activate) catch unreachable;

        return Player{
            .ref = .{
                .body_id = body_id,
                .interface = body_interface,
            },
            .shader = shader,
        };
    }

    fn update(self: *Player, dt: f32) void {
        const turn_input: f32 = zphy_helper.getAxisInput(rl.KeyboardKey.a, rl.KeyboardKey.d);
        const walk_input: f32 = zphy_helper.getAxisInput(rl.KeyboardKey.w, rl.KeyboardKey.s);
        self._update(
            dt,
            turn_input * turnSpeed,
            walk_input * moveSpeed,
        );
    }
    fn _update(self: *Player, dt: f32, rot_factor: f32, move_factor: f32) void {
        const old_rotation: Vec4 = self.ref.rotation();
        const new_rotation: Vec4 = zphy_helper.rotateY(old_rotation, rot_factor * dt);

        const new_direction = zm.normalize4(zm.rotate(new_rotation, zm.f32x4(0, 0, 1, 0)));

        // velocity
        // v += a * t
        const old_velocity = vec4(self.ref.velocity());
        const new_velocity = blk: {
            const is_downward = old_velocity[1] < -EPSILON;
            const is_upward = old_velocity[1] > EPSILON;
            const is_onground = @abs(old_velocity[1]) < EPSILON;

            const acceleration_y: f32 =
                if (is_onground and rl.isKeyPressed(.space))
                    500.0 // jump start
                else if (is_downward)
                    -1.5 * EARTH_GRAVITY // fast fall (game feeling)
                else if (is_upward and !rl.isKeyDown(.space))
                    -1.5 * EARTH_GRAVITY // short jump
                else
                    -0.0 * EARTH_GRAVITY; // fall normal

            var new_v = old_velocity;
            new_v += Vec4{ 0, acceleration_y, 0, 0 } * splat(dt);
            break :blk new_v;
        };

        const old_position: Vec4 = vec4(self.ref.position());
        const new_position: Vec4 = old_position +
            new_direction * splat(move_factor * dt) + // move forward effected
            new_velocity * splat(dt); // gravity + jump effected

        const p = new_position;
        const r = new_rotation;
        const v = new_velocity;

        self.ref.interface.setPositionRotationAndVelocity(
            self.ref.body_id,
            .{ p[0], p[1], p[2] },
            .{ r[0], r[1], r[2], r[3] },
            .{ v[0], v[1], v[2] },
            .{ 0, 0, 0 },
        );
    }

    fn draw(self: Player) void {
        rl.gl.rlPushMatrix();
        defer rl.gl.rlPopMatrix();

        rl.gl.rlMultMatrixf(@ptrCast(&self.ref.transformMat()));

        rl.beginShaderMode(self.shader);
        defer rl.endShaderMode();

        rl.drawCubeV(rl.Vector3.zero(), size, .red);
        rl.drawCubeWiresV(rl.Vector3.zero(), size, .maroon);
    }
};

const Ground = struct {
    ref: PhyRef,
    size: rl.Vector2,

    fn init(center: rl.Vector3, size: rl.Vector2, physics_system: *zphy.PhysicsSystem) Ground {
        const body_interface = physics_system.getBodyInterfaceMut();
        const body_id = body_interface.createAndAddBody(.{
            .position = .{ center.x, center.y - 0.1, center.z, 1 },
            .rotation = .{ 0, 0, 0, 1 },
            .shape = zphy_helper.createBoxShape(.{ size.x, 0.1, size.y }) catch unreachable,
            .motion_type = .static,
            .object_layer = zphy_helper.object_layers.non_moving,
        }, .activate) catch unreachable;
        return .{
            .ref = .{ .body_id = body_id, .interface = body_interface },
            .size = size,
        };
    }

    fn draw(self: Ground) void {
        rl.gl.rlPushMatrix();
        defer rl.gl.rlPopMatrix();

        rl.gl.rlMultMatrixf(@ptrCast(&self.ref.transformMat()));

        rl.drawPlane(rl.Vector3.init(0, -EPSILON, 0), self.size, .dark_purple);
        rl.drawGrid(@intFromFloat(self.size.x), 1.0);
    }

    fn update(_: *Ground, _: f32) void {}
};

const Box = struct {
    ref: PhyRef,
    size: rl.Vector3,
    color: rl.Color,

    fn init(pos: rl.Vector3, size: rl.Vector3, color: rl.Color, physics_system: *zphy.PhysicsSystem) Box {
        const body_interface = physics_system.getBodyInterfaceMut();
        const body_id = body_interface.createAndAddBody(.{
            .position = .{ pos.x, pos.y, pos.z, 1 },
            .shape = zphy_helper.createBoxShape(.{ size.x, size.y, size.z }) catch unreachable,
            .motion_type = .dynamic,
            .object_layer = zphy_helper.object_layers.moving,
        }, .activate) catch unreachable;

        return .{
            .ref = .{ .body_id = body_id, .interface = body_interface },
            .size = size,
            .color = color,
        };
    }

    fn draw(self: Box) void {
        rl.gl.rlPushMatrix();
        defer rl.gl.rlPopMatrix();

        rl.gl.rlMultMatrixf(@ptrCast(&self.ref.transformMat()));

        rl.drawCubeV(rl.Vector3.zero(), self.size, self.color);
        rl.drawCubeWiresV(rl.Vector3.zero(), self.size, .black);
    }

    fn update(_: *Box, _: f32) void {}
};

const Mesh = struct {
    ptr: *anyopaque,
    updateFn: *const fn (ptr: *anyopaque, dt: f32) void,
    drawFn: *const fn (ptr: *anyopaque) void,

    fn init(ptr: anytype) Mesh {
        const T = @TypeOf(ptr);
        const PtrT = if (@typeInfo(T) == .pointer) T else *T;
        const gen = struct {
            fn update(ctx: *anyopaque, dt: f32) void {
                const self: PtrT = @ptrCast(@alignCast(ctx));
                self.update(dt);
            }
            fn draw(ctx: *anyopaque) void {
                const self: PtrT = @ptrCast(@alignCast(ctx));
                self.draw();
            }
        };
        return .{
            .ptr = @constCast(ptr),
            .updateFn = gen.update,
            .drawFn = gen.draw,
        };
    }

    fn update(self: Mesh, dt: f32) void {
        self.updateFn(self.ptr, dt);
    }

    fn draw(self: Mesh) void {
        self.drawFn(self.ptr);
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

    physics_system.setGravity(.{ 0, -EARTH_GRAVITY, 0 });

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

    var camera = rl.Camera3D{
        .position = rl.Vector3.init(0, 10, 10),
        .target = rl.Vector3.init(0, 0, 0),
        .up = rl.Vector3.init(0, 1, 0),
        .fovy = 45.0,
        .projection = .perspective,
    };

    while (!rl.windowShouldClose()) {
        {
            // UPDATE
            const dt = rl.getFrameTime();
            try physics_system.update(dt, .{});
            for (mesh_list) |mesh| {
                mesh.update(dt);
            }

            camera.position = player.ref.camera_position();
            camera.target = rl.Vector3.initVec(player.ref.position());
        }

        {
            // DRAW
            rl.beginDrawing();
            defer rl.endDrawing();

            rl.clearBackground(.ray_white); // BG
            {
                // DRAW 3D
                camera.begin(); // beginMode3D
                defer camera.end();
                for (mesh_list) |mesh| {
                    mesh.draw();
                }
            }
            {
                // fade window when player fall far
                // FG
                const y = player.ref.position()[1];
                var black_overlay = rl.Color.black;
                black_overlay.a = @as(u8, @intFromFloat(zphy_helper.remapClamp(y, -20.0, -100.0, 0.0, 255.00)));
                rl.drawFPS(10, 10);
                rl.drawRectangle(0, 0, screenWidth, screenHeight, black_overlay);
            }
        }
    }
}
