const std = @import("std");
const rl = @import("raylib");
const zphy = @import("zphysics");
const physic = @import("../physic.zig");
const Player = @import("../player.zig").PlayerEntity;
const Util = @import("../util.zig");
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
    size: i32,
    depth_shader: rl.Shader,
    _shader: ShadowMap,

    pub fn get_texture_rgb(self: @This()) rl.Texture {
        return self.depth_target.texture;
    }
    pub fn get_texture_depth(self: @This()) rl.Texture {
        return self.depth_target.depth;
    }

    pub fn init(config: PassConfig) !ShadowMapPass {
        // NOTE: raylib will not throw error if file not exists
        const _shader = try ShadowMap.init();

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
            .size = config.texture_resolution,
            ._shader = _shader,
        };
    }

    pub fn deinit(self: *const @This()) void {
        rl.unloadShader(self.depth_shader);
        self.depth_target.unload();
    }

    pub fn begin_shadow_pass(self: @This()) void {
        self.depth_target.begin();
        self.light_camera.begin();

        rl.gl.rlClearScreenBuffers();
        // then draw
    }
    pub fn end_shadow_pass(self: @This()) void {

        // after draw finished
        // IMPORTANT UPDATE DEPT TEXTURE TO memo shader program
        self._shader.set_uniform(.{
            .light_view_proj = _calcLightViewProjMat(self.light_camera),
            .depth_target = _bindDepthTexture(self.depth_target.depth),
        });

        self.depth_target.end();
        self.light_camera.end();
    }

    fn _calcLightViewProjMat(light_camera: rl.Camera3D) rl.Matrix {
        light_camera.begin();
        defer light_camera.end();
        const lightView = rl.gl.rlGetMatrixModelview();
        const lightProj = rl.gl.rlGetMatrixProjection();
        const light_view_proj = lightView.multiply(lightProj);
        return light_view_proj;
    }

    fn _bindDepthTexture(depht_texture: rl.Texture2D) i32 {
        // ตั้ง state ให้ GPU รู้เรื่อง
        // random unused texture slot
        const SHADOW_TEX_SLOT: i32 = 10; // GL_TEXTURE0 + 10 = GL_TEXTURE10

        // DO: *TEXTURE10 = depth_target.depth.id
        rl.gl.rlActiveTextureSlot(SHADOW_TEX_SLOT);
        rl.gl.rlEnableTexture(depht_texture.id);

        // DO: glsl(uniform sampler2D depth_target) -> *TEXTURE10
        // self._shader.uniform.depth_target.set(SHADOW_TEX_SLOT);
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
