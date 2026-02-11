const rl = @import("raylib");

pub fn main() anyerror!void {
    const screenWidth = 800;
    const screenHeight = 450;

    rl.initWindow(screenWidth, screenHeight, "raylib-zig [core] 2D + 3D");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    // ตั้งค่ากล้อง 3D
    var camera = rl.Camera3D{
        .position = .{ .x = 10.0, .y = 10.0, .z = 10.0 },
        .target = .{ .x = 0.0, .y = 0.0, .z = 0.0 },
        .up = .{ .x = 0.0, .y = 1.0, .z = 0.0 },
        .fovy = 45.0,
        .projection = .perspective,
    };

    var y: i32 = 200;
    var hue: f32 = 0.0;
    var seconds: f32 = 0.0;

    // Load Shader (Vertex = null ใช้ตัวตั้งต้น, Fragment = ไฟล์ที่เราสร้าง)
    const shader = try rl.loadShader(null, "src/shaders/wave.frag");
    defer rl.unloadShader(shader);

    const seconds_loc = rl.getShaderLocation(shader, "seconds");

    while (!rl.windowShouldClose()) {
        // Update
        const dt = rl.getFrameTime();
        seconds += dt;

        y += 1;
        hue += 1.0;
        if (y > screenHeight) y = -20;

        // ส่งค่า seconds ไปที่ Shader
        rl.setShaderValue(shader, seconds_loc, &seconds, .float);

        // ให้กล้องหมุนรอบจุดศูนย์กลาง
        rl.updateCamera(&camera, .orbital);

        // Draw
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.fromHSV(hue, 0.2, 0.1));

        // --- LAYER 1: 3D WORLD ---
        rl.beginMode3D(camera);
        rl.drawGrid(10, 1.0); // ตารางพื้น
        rl.drawCube(.{ .x = 0, .y = 0.5, .z = 0 }, 1, 1, 1, .red); // กล่องตรงกลาง
        rl.drawCubeWires(.{ .x = 0, .y = 0.5, .z = 0 }, 1.1, 1.1, 1.1, .white);
        rl.endMode3D();

        // --- LAYER 2: 2D OVERLAY (UI) ---
        rl.beginShaderMode(shader);
        rl.drawTriangle(
            .{ .x = 400, .y = 100 },
            .{ .x = 300, .y = 300 },
            .{ .x = 500, .y = 300 },
            rl.Color.gold.fade(0.5),
        );
        rl.endShaderMode();

        rl.drawText("Congrats! Krist\nHybrid 2D + 3D!", 10, y, 20, .white);
        rl.drawFPS(10, 10);
    }
}
