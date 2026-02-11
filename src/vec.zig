const std = @import("std");

pub const Vec2 = @Vector(2, f32);
pub const Vec3 = @Vector(3, f32);
pub const Vec4 = @Vector(4, f32);

pub fn splat(val: f32) Vec4 {
    return Vec4{ val, val, val, val };
}

pub fn vec4(obj: anytype) Vec4 {
    const T = @TypeOf(obj);
    const info = @typeInfo(T);

    if (info == .float) {
        return .{ info, info, info, info };
    }

    // กรณีเป็น Struct (เช่น rl.Vector2, rl.Vector3, rl.Vector4)
    if (info == .@"struct") {
        if (info.@"struct".is_tuple) {
            // กรณีเป็น Tuple เช่น .{ 1.0, 2.0, 3.0 }
            const len = info.@"struct".fields.len;
            const x = if (len > 0) obj[0] else 0.0;
            const y = if (len > 1) obj[1] else 0.0;
            const z = if (len > 2) obj[2] else 0.0;
            const w = if (len > 3) obj[3] else 0.0;
            return .{ x, y, z, w };
        } else {
            const x = if (@hasField(T, "x")) obj.x else 0.0;
            const y = if (@hasField(T, "y")) obj.y else 0.0;
            const z = if (@hasField(T, "z")) obj.z else 0.0;
            const w = if (@hasField(T, "w")) obj.w else 0.0;
            return .{ x, y, z, w };
        }
    }

    // กรณีเป็น Array (เช่น [2]f32, [3]f32)
    if (info == .array) {
        const len = info.array.len;
        var temp: @Vector(4, f32) = @splat(0.0);
        inline for (0..@min(len, 4)) |i| {
            temp[i] = obj[i];
        }
        return temp;
    }
    if (info == .vector) {
        const len = info.vector.len;
        var temp: @Vector(4, f32) = @splat(0.0);
        inline for (0..@min(len, 4)) |i| {
            temp[i] = obj[i];
        }
        return temp;
    }
    @compileError("Unsupported type for vec4: " ++ @typeName(T));
}
pub fn vec3(obj: anytype) Vec3 {
    const res = vec4(obj);
    return .{ res[0], res[1], res[2] };
}
