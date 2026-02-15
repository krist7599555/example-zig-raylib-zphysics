const std = @import("std");
const zphy = @import("zphysics");
const rl = @import("raylib");
const vec3 = @import("./vec.zig").vec3;
const vec4 = @import("./vec.zig").vec4;
const Vec2 = @Vector(2, f32);
const Vec3 = @Vector(3, f32);
const Vec4 = @Vector(4, f32);

// BEGIN My Own
const ZphysicsError = error{
    CreateBoxShapeSettingsError,
    CreateBoxShapeError,
};
pub fn createBoxShape(full_extent: Vec3) ZphysicsError!*zphy.Shape {
    const box_settings = zphy.BoxShapeSettings.create(.{
        full_extent[0] / 2.0,
        full_extent[1] / 2.0,
        full_extent[2] / 2.0,
    }) catch return ZphysicsError.CreateBoxShapeSettingsError;
    defer box_settings.asShapeSettings().release();
    const box_shape = box_settings
        .asShapeSettings()
        .createShape() catch return ZphysicsError.CreateBoxShapeError;
    errdefer box_shape.release();
    return box_shape;
}

pub fn getAxisInput(pos_key: rl.KeyboardKey, neg_key: rl.KeyboardKey) f32 {
    var val: f32 = 0;
    if (rl.isKeyDown(pos_key)) val += 1.0;
    if (rl.isKeyDown(neg_key)) val -= 1.0;
    return val;
}

pub fn remapClamp(val: f32, in_min: f32, in_max: f32, out_min: f32, out_max: f32) f32 {
    const t = (val - in_min) / (in_max - in_min);
    const clamped_t = std.math.clamp(t, 0.0, 1.0);
    return out_min + clamped_t * (out_max - out_min);
}
