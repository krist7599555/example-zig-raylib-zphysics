const rl = @import("raylib");
const zphy = @import("zphysics");
const std = @import("std");

pub fn createMaterialFromColor(color: rl.Color) !rl.Material {
    var material = try rl.loadMaterialDefault();
    material.maps[@as(usize, @intFromEnum(rl.MATERIAL_MAP_DIFFUSE))].color = color;
    return material;
}

pub fn createMaterial(shader: rl.Shader, color: rl.Color) !rl.Material {
    var material = try rl.loadMaterialDefault();
    material.maps[@as(usize, @intFromEnum(rl.MATERIAL_MAP_DIFFUSE))].color = color;
    material.shader = shader;
    return material;
}

pub fn randomColor(random: std.Random) rl.Color {
    return rl.Color.init(
        random.uintLessThan(u8, 255),
        random.uintLessThan(u8, 255),
        random.uintLessThan(u8, 255),
        255,
    );
}

pub fn randomFloat(random: std.Random, at_least: f32, less_than: f32) f32 {
    // 1. random.float(f32) จะคืนค่าในช่วง [0.0, 1.0)
    const r = random.float(f32);

    // 2. คำนวณช่วง (Range) ที่ต้องการ
    const range = less_than - at_least;

    // 3. Scale และ Shift
    // r * range -> [0.0, range)
    // (r * range) + at_least -> [at_least, less_than)
    return (r * range) + at_least;
}
