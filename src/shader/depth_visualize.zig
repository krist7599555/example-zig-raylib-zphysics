const rl = @import("raylib");
const Uniform = @import("./uniform_helper.zig").Uniform;
const ShaderWrapper = @import("./uniform_helper.zig").ShaderWrapper;

pub const DepthVisualize = ShaderWrapper(
    @embedFile("./depth_visualize.vert"),
    @embedFile("./depth_visualize.frag"),
    struct {
        depthTex: i32, // sampler2D
        mvp: rl.Matrix, // mat4
    },
    &.{
        .{ .matrix_mvp, "mvp" },
    },
);
