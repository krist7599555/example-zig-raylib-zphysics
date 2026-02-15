const rl = @import("raylib");
const std = @import("std");

pub fn rand_color(random: std.Random) rl.Color {
    return rl.Color.init(
        random.uintLessThan(u8, 255),
        random.uintLessThan(u8, 255),
        random.uintLessThan(u8, 255),
        255,
    );
}

pub fn rand_f32(random: std.Random, at_least: f32, less_than: f32) f32 {
    // 1. random.float(f32) จะคืนค่าในช่วง [0.0, 1.0)
    const r = random.float(f32);

    // 2. คำนวณช่วง (Range) ที่ต้องการ
    const range = less_than - at_least;

    // 3. Scale และ Shift
    // r * range -> [0.0, range)
    // (r * range) + at_least -> [at_least, less_than)
    return (r * range) + at_least;
}
