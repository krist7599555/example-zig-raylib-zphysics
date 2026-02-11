const rl = @import("raylib");

pub fn main() anyerror!void {
    // Initialization
    //--------------------------------------------------------------------------------------
    const screenWidth = 800;
    const screenHeight = 450;

    rl.initWindow(screenWidth, screenHeight, "raylib-zig [core] example - basic window");
    defer rl.closeWindow(); // Close window and OpenGL context

    rl.setTargetFPS(60); // Set our game to run at 60 frames-per-second
    //--------------------------------------------------------------------------------------

    var y: i32 = 200;
    // const bg = rl.Color.orange;
    var hue: f32 = 0.0;
    // Main game loop
    while (!rl.windowShouldClose()) { // Detect window close button or ESC key
        // Update
        y += 1;
        hue += 2.0;
        if (y > screenHeight) y = -20;

        // Draw
        //----------------------------------------------------------------------------------
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.fromHSV(hue, 0.5, 0.5));

        rl.drawText("Congrats! Krist\nYou created\nyour first window!", 190, y, 20, .white);
        //----------------------------------------------------------------------------------
        rl.drawFPS(10, 10);
    }
}
