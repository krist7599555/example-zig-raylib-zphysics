const rl = @import("raylib");
const std = @import("std");
const Vec3 = rl.Vector3;
const Vec2 = rl.Vector2;

const Player = struct {
    position: Vec3,
    forward: Vec3, // force normalize && y = 0
    velocity: Vec3, // force x = 0, z = 0

    const Y = Vec3.init(0.0, 1.0, 0.0);
    const moveSpeed: f32 = 5.0;
    const turnSpeed: f32 = 3.0;
    const gravity: Vec3 = Vec3.init(0.0, -20.0, 0.0);
    const jumpForce = Vec3.init(0.0, 8.0, 0.0);

    fn angle(self: *const Player) f32 {
        return std.math.atan2(self.forward.x, self.forward.z);
    }

    fn update(self: *Player, dt: f32) void {
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

        // --- JUMP & GRAVITY ---
        self.velocity =
            if (self.position.y == 0.0 and rl.isKeyPressed(.space))
                jumpForce
            else
                self.velocity.add(gravity.scale(dt));

        self.position = self.position.add(self.velocity.scale(dt));
        if (self.position.y < 0.0) self.position.y = 0.0;
    }

    fn draw(self: Player, shader: rl.Shader) void {
        rl.gl.rlPushMatrix();
        defer rl.gl.rlPopMatrix();

        rl.beginShaderMode(shader);
        defer rl.endShaderMode();

        rl.gl.rlTranslatef(self.position.x, self.position.y, self.position.z);
        rl.gl.rlRotatef(self.angle() * 180.0 / std.math.pi, 0.0, 1.0, 0.0);

        rl.drawCylinder(Vec3.zero(), 0.5, 0.7, 1.0, 12, .white);
        rl.drawSphere(Vec3.init(0.0, 1.0, 0.5), 0.1, .white);
        rl.drawCylinderWires(Vec3.zero(), 0.5, 0.7, 1.0, 12, .white);
    }
};

const Ground = struct {
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
    const ground = Ground{};

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
        player.update(dt);

        // UPDATE Camera (Third Person)
        {
            const camDistance: f32 = 5.0;
            const camHeight: f32 = 2.5;
            camera.position = player.position.subtract(player.forward.scale(camDistance));
            camera.position.y += camHeight;
            camera.target = player.position;
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
