const rl = @import("raylib");
const std = @import("std");
const Vec3 = rl.Vector3;
const Vec2 = rl.Vector2;

const Player = struct {
    position: Vec3,
    forward: Vec3, // force normalize && y = 0
    velocity: Vec3, // force x = 0, z = 0

    const radius: f32 = 0.5;
    const height: f32 = 1.0;
    const Y = Vec3.init(0.0, 1.0, 0.0);
    const moveSpeed: f32 = 5.0;
    const turnSpeed: f32 = 3.0;
    const gravity: Vec3 = Vec3.init(0.0, -20.0, 0.0);
    const jumpForce = Vec3.init(0.0, 8.0, 0.0);

    fn angle(self: *const Player) f32 {
        return std.math.atan2(self.forward.x, self.forward.z);
    }

    fn getBounds(self: Player) rl.BoundingBox {
        return .{
            .min = .{ .x = self.position.x - radius, .y = self.position.y, .z = self.position.z - radius },
            .max = .{ .x = self.position.x + radius, .y = self.position.y + height, .z = self.position.z + radius },
        };
    }

    fn update(self: *Player, dt: f32, ground_box: rl.BoundingBox) void {
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
        if (rl.checkCollisionBoxes(playerBounds, ground_box)) {
            // ถ้าชนพื้น ให้หยุดตกลงมา และวางเท้าบนพื้นพอดี
            self.position.y = ground_box.max.y;
            self.velocity.y = 0;

            if (rl.isKeyPressed(.space)) {
                self.velocity = self.velocity.add(jumpForce);
            }
        }
    }

    fn draw(self: Player, shader: rl.Shader) void {
        rl.gl.rlPushMatrix();
        defer rl.gl.rlPopMatrix();

        rl.beginShaderMode(shader);
        defer rl.endShaderMode();

        rl.gl.rlTranslatef(self.position.x, self.position.y, self.position.z);
        rl.gl.rlRotatef(self.angle() * 180.0 / std.math.pi, 0.0, 1.0, 0.0);

        const centerOffset = Vec3.init(0.0, height / 2.0, 0.0);
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

    fn draw(_: Ground) void {
        rl.drawPlane(Vec3.init(0.0, 0.0, 0.0), Vec2.init(20, 20), .green);
        rl.drawGrid(20, 1.0);
    }
};
pub fn main() anyerror!void {
    const screenWidth = 800;
    const screenHeight = 450;

    rl.initWindow(screenWidth, screenHeight, "raylib-zig [3rd Person Player Refactored]");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    // เริ่มต้นแคลนนิ่งข้อมูลผู้เล่นเข้าระบบ Struct
    var player = Player{
        .position = Vec3.init(0, 0, 0),
        .forward = Vec3.init(0, 0, 1),
        .velocity = Vec3.zero(),
        // .angle = 0,
    };
    const ground = Ground.init();

    // ตั้งค่ากล้อง 3D
    var camera = rl.Camera3D{
        .position = .{ .x = 0.0, .y = 2.0, .z = -5.0 },
        .target = player.position,
        .up = .{ .x = 0.0, .y = 1.0, .z = 0.0 },
        .fovy = 45.0,
        .projection = .perspective,
    };

    const normal_shader = try rl.loadShader("src/shaders/player.vert", "src/shaders/normal.frag");
    defer rl.unloadShader(normal_shader);

    while (!rl.windowShouldClose()) {
        const dt = rl.getFrameTime();

        // UPDATE Logic
        player.update(dt, ground.bounds);

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

                ground.draw();
                player.draw(normal_shader);
            }

            rl.drawText("Use WSDA to WALK | SPACE to JUMP", 10, 40, 20, .white);
            rl.drawFPS(10, 10);
        }
    }
}
