const rl = @import("raylib");
const std = @import("std");
const Vec3 = rl.Vector3;
const Vec2 = rl.Vector2;

const Player = struct {
    position: Vec3,
    forward: Vec3, // force normalize && y = 0
    velocity: Vec3, // force x = 0, z = 0
    shader: rl.Shader,

    const radius: f32 = 0.5;
    const height: f32 = 1.0;
    const Y = Vec3.init(0.0, 1.0, 0.0);
    const moveSpeed: f32 = 5.0;
    const turnSpeed: f32 = 3.0;
    const gravity: Vec3 = Vec3.init(0.0, -20.0, 0.0);
    const jumpForce = Vec3.init(0.0, 8.0, 0.0);

    pub fn init(shader: rl.Shader) Player {
        return Player{ .position = Vec3.init(0, 0, 0), .forward = Vec3.init(0, 0, 1), .velocity = Vec3.zero(), .shader = shader };
    }

    fn angle(self: *const Player) f32 {
        return std.math.atan2(self.forward.x, self.forward.z);
    }

    fn getBounds(self: *const Player) rl.BoundingBox {
        return .{
            .min = .{ .x = self.position.x - radius, .y = self.position.y, .z = self.position.z - radius },
            .max = .{ .x = self.position.x + radius, .y = self.position.y + height, .z = self.position.z + radius },
        };
    }

    fn update(self: *Player, dt: f32, meshs: []const Mesh) void {
        // --- Rotation ---
        var angle_: f32 = 0;
        if (rl.isKeyDown(.a)) angle_ += turnSpeed * dt;
        if (rl.isKeyDown(.d)) angle_ -= turnSpeed * dt;
        self.forward =
            self.forward.rotateByAxisAngle(Y, angle_);

        // --- Horizontal Movement ---
        var walk_: f32 = 0;
        if (rl.isKeyDown(.w)) walk_ += moveSpeed * dt;
        if (rl.isKeyDown(.s)) walk_ -= moveSpeed * dt;
        self.position = self.position.add(self.forward.scale(walk_));

        // --- PHYSICS: Gravity ---
        self.velocity = self.velocity.add(gravity.scale(dt));
        self.position = self.position.add(self.velocity.scale(dt));

        // --- Collision Checker System ---
        const playerBounds = self.getBounds();
        for (meshs) |mesh| {
            if (@intFromPtr(self) == @intFromPtr(mesh.ptr)) continue;
            const targetBounds = mesh.getBounds();
            if (rl.checkCollisionBoxes(playerBounds, targetBounds)) {
                // ถ้าชนวัตถุ ให้หยุดตกลงมา และวางเท้าบนวัตถุพอดี
                self.position.y = targetBounds.max.y;
                self.velocity.y = 0;

                if (rl.isKeyPressed(.space)) {
                    self.velocity = self.velocity.add(jumpForce);
                }
            }
        }
    }

    fn draw(self: Player) void {
        rl.drawBoundingBox(self.getBounds(), .red);

        rl.gl.rlPushMatrix();
        defer rl.gl.rlPopMatrix();

        rl.beginShaderMode(self.shader);
        defer rl.endShaderMode();

        rl.gl.rlTranslatef(self.position.x, self.position.y, self.position.z);
        rl.gl.rlRotatef(self.angle() * 180.0 / std.math.pi, 0.0, 1.0, 0.0);

        const centerOffset = Vec3.init(0.0, 0.0, 0.0);
        rl.drawCylinder(centerOffset, radius, radius * 1.2, height, 12, .white);
        rl.drawSphere(Vec3.init(0.0, height, 0.5 * radius), 0.1, .white);
        rl.drawCylinderWires(centerOffset, radius, radius * 1.2, height, 12, .white);
    }
};

const Ground = struct {
    bounds: rl.BoundingBox,

    fn init() Ground {
        return .{
            .bounds = .{
                .min = .{ .x = -10, .y = -0.1, .z = -10 },
                .max = .{ .x = 10, .y = 0.0, .z = 10 },
            },
        };
    }

    fn getBounds(self: Ground) rl.BoundingBox {
        return self.bounds;
    }

    fn draw(self: Ground) void {
        rl.drawBoundingBox(self.getBounds(), .red);
        rl.drawPlane(Vec3.init(0.0, 0.0, 0.0), Vec2.init(20, 20), .green);
        rl.drawGrid(20, 1.0);
    }
    fn update(self: *Ground, _: f32, _: []const Mesh) void {
        _ = self;
        // noop
    }
};

const Box = struct {
    position: Vec3,
    size: Vec3,
    color: rl.Color,
    velocity: Vec3 = Vec3{ .x = 0, .y = 0, .z = 0 },

    const gravity: Vec3 = Vec3.init(0.0, -9.8, 0.0);

    fn getBounds(self: *const Box) rl.BoundingBox {
        return .{
            .min = self.position.subtract(self.size.scale(0.5)),
            .max = self.position.add(self.size.scale(0.5)),
        };
    }

    fn update(self: *Box, dt: f32, meshs: []const Mesh) void {
        // อัปเดตฟิสิกส์พื้นฐาน
        self.velocity = self.velocity.add(gravity.scale(dt));
        self.position = self.position.add(self.velocity.scale(dt));

        // การเช็ก Collision กับ Mesh อื่นๆ (เช่น พื้น หรือ กล่องใบอื่น)
        const myBounds = self.getBounds();
        for (meshs) |mesh| {
            if (@intFromPtr(self) == @intFromPtr(mesh.ptr)) continue;

            const targetBounds = mesh.getBounds();
            if (rl.checkCollisionBoxes(myBounds, targetBounds)) {
                // ถ้าชน (หลักๆ คือพื้น) ให้หยุด
                if (self.position.y > targetBounds.max.y) {
                    self.position.y = targetBounds.max.y + self.size.y / 2.0;
                    self.velocity.y *= -0.2; // กระดอนนิดหน่อย
                }
            }
        }
    }

    fn draw(self: Box) void {
        rl.drawCube(self.position, self.size.x, self.size.y, self.size.z, self.color);
        rl.drawCubeWires(self.position, self.size.x, self.size.y, self.size.z, .black);
    }
};

const Mesh = struct {
    ptr: *anyopaque,
    updateFn: *const fn (ptr: *anyopaque, dt: f32, meshs: []const Mesh) void,
    drawFn: *const fn (ptr: *anyopaque) void,
    getBoundsFn: *const fn (ptr: *anyopaque) rl.BoundingBox,

    fn init(ptr: anytype) Mesh {
        const T = @TypeOf(ptr);
        const PtrT = if (@typeInfo(T) == .pointer) T else *T;
        const gen = struct {
            fn update(ctx: *anyopaque, dt: f32, meshs: []const Mesh) void {
                const self: PtrT = @ptrCast(@alignCast(ctx));
                self.update(dt, meshs);
            }
            fn draw(ctx: *anyopaque) void {
                const self: PtrT = @ptrCast(@alignCast(ctx));
                self.draw();
            }
            fn getBounds(ctx: *anyopaque) rl.BoundingBox {
                const self: PtrT = @ptrCast(@alignCast(ctx));
                return self.getBounds();
            }
        };
        return .{
            .ptr = @constCast(ptr), // บังคับเป็น mutable pointer เพื่อเก็บใน Mesh
            .updateFn = gen.update,
            .drawFn = gen.draw,
            .getBoundsFn = gen.getBounds,
        };
    }

    fn update(self: Mesh, dt: f32, meshs: []const Mesh) void {
        self.updateFn(self.ptr, dt, meshs);
    }

    fn draw(self: Mesh) void {
        self.drawFn(self.ptr);
    }

    fn getBounds(self: Mesh) rl.BoundingBox {
        return self.getBoundsFn(self.ptr);
    }
};

pub fn main() anyerror!void {
    var prng = std.Random.DefaultPrng.init(@intCast(std.time.timestamp()));
    const rand = prng.random();

    const screenWidth = 800;
    const screenHeight = 450;

    rl.initWindow(screenWidth, screenHeight, "raylib-zig [3rd Person Player Refactored]");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    // เริ่มต้นแคลนนิ่งข้อมูลผู้เล่นเข้าระบบ Struct
    const normal_shader = try rl.loadShader("src/shaders/player.vert", "src/shaders/normal.frag");
    defer rl.unloadShader(normal_shader);
    var player = Player.init(normal_shader);
    var ground = Ground.init();

    var mesh_list: [102]Mesh = undefined;
    mesh_list[0] = Mesh.init(&player);
    mesh_list[1] = Mesh.init(&ground);

    var boxes: [100]Box = undefined;
    for (&boxes, 2..) |*box, idx| {
        box.* = Box{
            .position = Vec3.init(
                rand.float(f32) * 20.0 - 10.0,
                rand.float(f32) * 40.0 + 10.0, // กระจายบนฟ้า
                rand.float(f32) * 20.0 - 10.0,
            ),
            .size = Vec3.init(0.5 + rand.float(f32), 0.5 + rand.float(f32), 0.5 + rand.float(f32)),
            .color = rl.Color.init(rand.uintAtMost(u8, 255), rand.uintAtMost(u8, 255), rand.uintAtMost(u8, 255), 255),
        };
        mesh_list[idx] = Mesh.init(box);
    }

    const meshs: []const Mesh = &mesh_list;

    // ตั้งค่ากล้อง 3D
    var camera = rl.Camera3D{
        .position = .{ .x = 0.0, .y = 2.0, .z = -5.0 },
        .target = player.position,
        .up = .{ .x = 0.0, .y = 1.0, .z = 0.0 },
        .fovy = 45.0,
        .projection = .perspective,
    };

    while (!rl.windowShouldClose()) {
        const dt = rl.getFrameTime();

        // UPDATE Logic (Update all meshes)
        for (meshs) |mesh| {
            mesh.update(dt, meshs);
        }

        // UPDATE Camera (Third Person)
        {
            const camDistance: f32 = 5.0;
            const camHeight: f32 = 2.5;
            camera.position = player.position.subtract(player.forward.scale(camDistance));
            camera.position.y += camHeight;
            camera.target = player.position.add(Vec3.init(0.0, 0.5, 0.0)); // มองไปที่กลางตัว
        }

        // DRAW Logic
        {
            rl.beginDrawing();
            defer rl.endDrawing();

            rl.clearBackground(.black);

            {
                rl.beginMode3D(camera);
                defer rl.endMode3D();

                for (meshs) |mesh| {
                    mesh.draw();
                }
            }

            rl.drawText("Use WSDA to WALK | SPACE to JUMP", 10, 40, 20, .white);
            rl.drawFPS(10, 10);
        }
    }
}
