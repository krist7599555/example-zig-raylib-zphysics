const std = @import("std");
const rl = @import("raylib");
const zphy = @import("zphysics");
const physic = @import("./physic.zig");
const GameWorld = @import("./game_world.zig").GameWorld;
const Player = @import("./player.zig").Player;
const Util = @import("./util.zig");
const AppShader = @import("./shader/index.zig");

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
    _shader: AppShader.ShadowShader,

    pub fn init(config: PassConfig) !ShadowMapPass {
        // NOTE: raylib will not throw error if file not exists
        const _shader = try AppShader.ShadowShader.init();

        _shader.uniform.lightDir.set(config.light_dir.normalize());
        _shader.uniform.light_color.set(rl.colorNormalize(config.light_color));
        _shader.uniform.ambient_color.set(rl.colorNormalize(config.ambient_color));
        _shader.uniform.depth_texture_size.set(config.texture_resolution);

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

    pub fn deinit(self: *@This()) void {
        rl.unloadShader(self.depth_shader);
        self.depth_target.unload();
    }

    pub fn begin(self: @This()) void {
        self.depth_target.begin();
        self.light_camera.begin();

        rl.gl.rlClearScreenBuffers();
        // then draw
    }
    pub fn end(self: @This()) void {

        // after draw finished
        // IMPORTANT UPDATE DEPT TEXTURE TO memo shader program
        self.writeLightMatrix();
        self.writeDepthTexture();

        self.depth_target.end();
        self.light_camera.end();
    }

    fn writeLightMatrix(self: @This()) void {
        self.light_camera.begin();
        defer self.light_camera.end();
        const lightView = rl.gl.rlGetMatrixModelview();
        const lightProj = rl.gl.rlGetMatrixProjection();
        const lightVP = lightView.multiply(lightProj);
        // DO: glsl(uniform mat4 lightVP) -> mat(light_view_proj_mat)
        self._shader.uniform.lightVP.set(lightVP);
    }
    fn writeDepthTexture(self: @This()) void {
        // ตั้ง state ให้ GPU รู้เรื่อง
        // random unused texture slot
        const SHADOW_TEX_SLOT: i32 = 10; // GL_TEXTURE0 + 10 = GL_TEXTURE10

        // DO: *TEXTURE10 = depth_target.depth.id
        rl.gl.rlActiveTextureSlot(SHADOW_TEX_SLOT);
        rl.gl.rlEnableTexture(self.depth_target.depth.id);

        // DO: glsl(uniform sampler2D depth_target) -> *TEXTURE10
        self._shader.uniform.depth_target.set(SHADOW_TEX_SLOT);
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
