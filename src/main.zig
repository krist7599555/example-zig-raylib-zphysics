const rl = @import("raylib");
const std = @import("std");

pub fn main() anyerror!void {
    const screenWidth = 800;
    const screenHeight = 450;

    rl.initWindow(screenWidth, screenHeight, "raylib-zig [3rd Person Player]");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    // ข้อมูลผู้เล่น
    var playerPos = rl.Vector3{ .x = 0.0, .y = 0.0, .z = 0.0 };
    var playerAngle: f32 = 0.0; // มุมที่ผู้เล่นหันหน้าไป (เป็นเรเดียน)
    const moveSpeed: f32 = 5.0;
    const turnSpeed: f32 = 3.0;

    // ตั้งค่ากล้อง 3D (เริ่มต้น)
    var camera = rl.Camera3D{
        .position = .{ .x = 0.0, .y = 2.0, .z = -5.0 },
        .target = playerPos,
        .up = .{ .x = 0.0, .y = 1.0, .z = 0.0 },
        .fovy = 45.0,
        .projection = .perspective,
    };

    while (!rl.windowShouldClose()) {
        const dt = rl.getFrameTime();

        // --- UPDATE: Movement ---
        if (rl.isKeyDown(.a)) playerAngle += turnSpeed * dt;
        if (rl.isKeyDown(.d)) playerAngle -= turnSpeed * dt;

        // คำนวณทิศทางการเคลื่อนที่ตามมุมที่หันหน้า
        const forward = rl.Vector3.init(std.math.sin(playerAngle), 0.0, std.math.cos(playerAngle));

        if (rl.isKeyDown(.w)) {
            playerPos = playerPos.add(forward.scale(moveSpeed * dt));
        }
        if (rl.isKeyDown(.s)) {
            playerPos = playerPos.subtract(forward.scale(moveSpeed * dt));
        }

        // --- UPDATE: Camera (Third Person) ---
        // วางกล้องไว้หลังผู้เล่นที่ระยะห่างระดับหนึ่ง
        const camDistance: f32 = 5.0;
        const camHeight: f32 = 2.5;

        camera.position = playerPos.subtract(forward.scale(camDistance));
        camera.position.y += camHeight;
        camera.target = playerPos; // มองไปที่ตัวผู้เล่น

        // --- DRAW ---
        {
            rl.beginDrawing();
            defer rl.endDrawing();

            rl.clearBackground(.black);

            {
                rl.beginMode3D(camera);
                defer rl.endMode3D();

                rl.drawPlane(rl.Vector3.init(0.0, 0.0, 0.0), rl.Vector2.init(20, 20), .green); // ตารางพื้น
                rl.drawGrid(20, 1.0); // ตารางพื้น

                // วาดตัวผู้เล่น (Cylinder) หมุนตามทิศหน้า
                {
                    rl.gl.rlPushMatrix();
                    defer rl.gl.rlPopMatrix();

                    rl.gl.rlTranslatef(playerPos.x, playerPos.y, playerPos.z);
                    rl.gl.rlRotatef(playerAngle * 180.0 / std.math.pi, 0.0, 1.0, 0.0);

                    rl.drawCylinder(rl.Vector3.zero(), 0.5, 0.7, 1.0, 12, .gold);
                    rl.drawCylinderWires(rl.Vector3.zero(), 0.5, 0.7, 1.0, 12, .white);
                    rl.drawSphere(rl.Vector3.init(0.0, 1.0, 0.5), 0.1, .red);
                }
            }

            rl.drawText("Use WSDA to WALK", 10, 40, 20, .white);
            rl.drawFPS(10, 10);
        }
    }
}
