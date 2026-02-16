const std = @import("std");
const rl = @import("raylib");
const zphy = @import("zphysics");
const physic = @import("../physic.zig");
const Uniform = @import("./uniform_helper.zig").Uniform;
const ShaderWrapper = @import("./uniform_helper.zig").ShaderWrapper;

const Shader = ShaderWrapper(
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

// const Shader3 = struct {
//     shader: rl.Shader = undefined,
//     uniform: struct {
//         diffuse_color: Uniform(rl.Vector4, "diffuse_color") = undefined,
//         light_direction: Uniform(rl.Vector3, "light_direction") = undefined,
//         light_color: Uniform(rl.Vector4, "light_color") = undefined,
//         ambient_color: Uniform(rl.Vector4, "ambient_color") = undefined,
//         view_position: Uniform(rl.Vector3, "view_position") = undefined, // = camera position =
//         light_view_proj: Uniform(rl.Matrix, "light_view_proj") = undefined,
//         depth_texture_size: Uniform(i32, "depth_texture_size") = undefined,
//         depth_target: Uniform(i32, "depth_target") = undefined, // sampler2D
//     },

//     const vert = @embedFile("./shadow.vert");
//     const frag = @embedFile("./shadow.frag");

//     pub fn init() !Shader {
//         var res = @This(){
//             .shader = try rl.loadShaderFromMemory(vert, frag),
//             .uniform = .{},
//         };
//         inline for (@typeInfo(@TypeOf(res.uniform)).@"struct".fields) |f| {
//             @field(res.uniform, f.name).init(res.shader);
//         }
//         res.shader.locs[@intCast(@intFromEnum(rl.ShaderLocationIndex.vector_view))] = res.uniform.view_position.loc;
//         res.shader.locs[@intCast(@intFromEnum(rl.ShaderLocationIndex.color_ambient))] = res.uniform.ambient_color.loc;
//         res.shader.locs[@intCast(@intFromEnum(rl.ShaderLocationIndex.color_diffuse))] = res.uniform.diffuse_color.loc;
//         return res;
//     }
//     pub fn deinit(self: @This()) void {
//         rl.unloadShader(self.shader);
//     }
//     pub fn set_uniform(self: @This(), obj: anytype) void {
//         const U = @TypeOf(self.uniform);
//         const V = @TypeOf(obj);
//         inline for (@typeInfo(V).@"struct".fields) |f| {
//             if (@hasField(U, f.name)) {
//                 const item = @field(self.uniform, f.name);
//                 item.set(@field(obj, f.name));
//             } else {
//                 comptime var msg: []const u8 = "FieldsExpect: \n";
//                 inline for (@typeInfo(U).@"struct".fields) |f2| {
//                     const U1 = @TypeOf(@field(self.uniform, f2.name));
//                     const U2 = @TypeOf(@field(U1, "set"));
//                     const UV = @typeInfo(U2).@"fn".params[1].type.?;
//                     msg = msg ++ "    " ++ f2.name ++ ": " ++ @typeName(UV) ++ "\n";
//                 }

//                 @compileError(msg ++ "\nGot " ++ f.name ++ ": " ++ @typeName(@TypeOf(@field(obj, f.name))));
//             }
//         }
//     }
// };

const PassConfig = struct {
    texture_resolution: i32 = 1024 * 2,
    light_dir: rl.Vector3 = .init(0.35, -1.0, -0.35),
    light_color: rl.Color = .white,
    ambient_color: rl.Color = .init(2, 2, 2, 255),
    fovy: f32 = 60.0,
};

pub const ShadowMapPass = struct {
    light_camera: rl.Camera3D,
    depth_target: rl.RenderTexture2D,
    depth_shader: rl.Shader,
    _shader: Shader,

    pub fn get_texture_rgb(self: @This()) rl.Texture {
        return self.depth_target.texture;
    }
    pub fn get_texture_depth(self: @This()) rl.Texture {
        return self.depth_target.depth;
    }

    pub fn init(config: PassConfig) !ShadowMapPass {
        // NOTE: raylib will not throw error if file not exists
        const _shader = try Shader.init();
        _shader.set_uniform(.{
            .light_direction = config.light_dir.normalize(),
            .light_color = rl.colorNormalize(config.light_color),
            .ambient_color = rl.colorNormalize(config.ambient_color),
            .depth_texture_size = config.texture_resolution,
        });

        return ShadowMapPass{
            .light_camera = .{
                .position = config.light_dir.scale(-15.0),
                .target = rl.Vector3.zero(),
                .up = rl.Vector3.init(0, 1, 0),
                .fovy = config.fovy, // Try Change this to fix shadow error (low = no shadow, hi = too dark)
                .projection = .orthographic,
            },
            .depth_target = try _createTextureWithDepth(config.texture_resolution),
            .depth_shader = _shader.shader,
            ._shader = _shader,
        };
    }

    pub fn deinit(self: *const @This()) void {
        rl.unloadShader(self.depth_shader);
        self.depth_target.unload();
        self._shader.deinit();
    }

    // This start capture, will capture as a `light`
    pub fn start_capture_shadow(self: @This()) void {
        self.depth_target.begin();
        self.light_camera.begin();

        rl.gl.rlClearScreenBuffers();
        // then draw
    }
    pub fn finish_capture_shadow(self: @This()) void {
        // after draw finished
        // IMPORTANT UPDATE DEPT TEXTURE TO memo shader program

        self._shader.set_uniform(.{
            .light_view_proj = _captureLightViewProj(self.light_camera),
            .depth_target = _bindTextureToSlot(self.depth_target.depth),
        });

        self.depth_target.end();
        self.light_camera.end();
    }

    fn _captureLightViewProj(light_camera: rl.Camera3D) rl.Matrix {
        light_camera.begin();
        defer light_camera.end();

        const lightView = rl.gl.rlGetMatrixModelview();
        const lightProj = rl.gl.rlGetMatrixProjection();
        const light_view_proj = lightView.multiply(lightProj);

        return light_view_proj;
    }
    // return TEXTURE_SLOT
    fn _bindTextureToSlot(depth_texture: rl.Texture) i32 {
        // ตั้ง state ให้ GPU รู้เรื่อง
        // random unused texture slot
        // any slot that not collition, >9 is ok for most case
        const SHADOW_TEX_SLOT: i32 = 10; // GL_TEXTURE10

        rl.gl.rlActiveTextureSlot(SHADOW_TEX_SLOT);
        rl.gl.rlEnableTexture(depth_texture.id);

        // DO: glsl(uniform sampler2D depth_target) -> *TEXTURE10
        return SHADOW_TEX_SLOT;
    }
};

fn _createTextureWithDepth(size: i32) !rl.RenderTexture2D {
    var texture = try rl.RenderTexture2D.init(size, size);
    errdefer texture.unload();

    const depth_id = rl.gl.rlLoadTextureDepth(size, size, false);
    std.log.info("BAO: [ID {d}] Depth Texture created successfully", .{depth_id});

    {
        defer std.log.info("FAO: [ID {}] attach BAO: [ID {d}]", .{ texture.id, depth_id });
        defer texture.depth.id = depth_id;
        rl.gl.rlFramebufferAttach(
            texture.id,
            depth_id,
            @intFromEnum(rl.gl.rlFramebufferAttachType.rl_attachment_depth),
            @intFromEnum(rl.gl.rlFramebufferAttachTextureType.rl_attachment_texture2d),
            0,
        );
    }
    // Check if FBO is complete with attachments (valid)
    if (!rl.gl.rlFramebufferComplete(texture.id)) {
        return rl.RaylibError.LoadRenderTexture;
    }
    std.log.info("FBO: [ID {d}] Framebuffer object created successfully", .{texture.id});

    return texture;
}
