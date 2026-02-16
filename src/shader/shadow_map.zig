const rl = @import("raylib");
const std = @import("std");
const ShaderWrapper = @import("./uniform_helper.zig").ShaderWrapper;

pub const ShadowMap = ShaderWrapper(
    @embedFile("./shadow.vert"),
    @embedFile("./shadow.frag"),
    struct {
        diffuse_color: rl.Vector4,
        light_direction: rl.Vector3,
        light_color: rl.Vector4,
        ambient_color: rl.Vector4,
        view_position: rl.Vector3,
        light_view_proj: rl.Matrix,
        depth_texture_size: i32,
        depth_target: i32,
    },
);
