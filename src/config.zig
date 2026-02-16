pub const GameConfig = .{
    .up = @Vector(3, f32){ 0, 1, 0 },
    .epsilon = 0.001,
    .screen_width = 800,
    .screen_height = 800,
    .fps = 60,
    .camera = .{
        .fov = 45,
    },
    .shadow_map = .{
        .texture_size = 1024,
        .light_direction = @Vector(3, f32){ 10.0, -40.0, 70.0 },
    },
    .random_seed = @as(u64, 12345),
};
