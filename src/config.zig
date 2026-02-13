pub const GameConfig = .{
    .up = @Vector(3, f32){ 0, 1, 0 },
    .gravity = 9.8,
    .epsilon = 0.001,
    .screen_width = 800,
    .screen_height = 800,
    .fps = 60,
    .camera = .{
        .fov = 45,
    },
};
