const std = @import("std");
const rl = @import("raylib");
const zphy = @import("zphysics");
const zm = @import("zmath");
const znoise = @import("znoise");
const zphy_helper = @import("./zphy_helper.zig");
const Jolt = @import("./jolt.zig");
const Config = @import("./config.zig").GameConfig;
// const game_world = @import("./game_world.zig").game_world;
const GameWorld = @import("./game_world.zig").GameWorld;
const splat = @import("./vec.zig").splat;
const vec3 = @import("./vec.zig").vec3;
const vec3jtr = @import("./vec.zig").vec3jtr;
const vec4 = @import("./vec.zig").vec4;
const Vec2 = @Vector(2, f32);
const Vec3 = @Vector(3, f32);
const Vec4 = @Vector(4, f32);
const Player = @import("./player.zig").Player;
const Util = @import("./util.zig");
const AppShader = @import("./shader/index.zig");

fn setShaderValue(shader: rl.Shader, comptime name: []const u8, value: *const anyopaque, uniformType: rl.ShaderUniformDataType) void {
    const loc = rl.getShaderLocation(shader, name ++ "\x00");
    rl.setShaderValue(shader, loc, value, uniformType);
}

const ShadowMapperConfig = struct {
    resolution: i32 = 1024 * 2,
    light_dir: rl.Vector3 = .init(0.35, -1.0, -0.35),
    light_color: rl.Color = .white,
    ambient_color: rl.Color = .init(2, 2, 2, 255),
    fovy: f32 = 60.0,
};

pub const ShadowMapper = struct {
    lightCam: rl.Camera3D,
    shadowMap: rl.RenderTexture2D,
    shadowMapResolution: i32,
    shadowShader: rl.Shader,
    shadowShaderWrapper: AppShader.ShadowShader,

    pub fn init(config: ShadowMapperConfig) !ShadowMapper {
        // NOTE: raylib will not throw error if file not exists
        const sh = try AppShader.ShadowShader.init();
        const uniform = sh.uniform;

        uniform.lightDir.set(config.light_dir.normalize());
        uniform.lightColor.set(rl.colorNormalize(config.light_color));
        uniform.ambient.set(rl.colorNormalize(config.ambient_color));
        uniform.shadowMapResolution.set(config.resolution);

        return ShadowMapper{
            .lightCam = .{
                .position = config.light_dir.scale(-15.0),
                .target = rl.Vector3.zero(),
                .up = rl.Vector3.init(0, 1, 0),
                .fovy = config.fovy, // Try Change this to fix shadow error (low = no shadow, hi = too dark)
                .projection = .orthographic,
            },
            .shadowMap = try create_texture_with_depth(config.resolution),

            .shadowShader = sh.shader,
            .shadowMapResolution = config.resolution,
            .shadowShaderWrapper = sh,
        };
    }

    pub fn deinit(self: *@This()) void {
        rl.unloadShader(self.shadowShader);
        self.shadowMap.unload();
    }

    pub fn drawToShadowMapTexture(self: *ShadowMapper, game: *GameWorld) void {
        const light_view_proj_mat = blk: {
            // Render ฉากจากมุมมองของแสง
            // Rerturn Light View-Projection Matrix
            self.shadowMap.begin();
            self.lightCam.begin();
            defer {
                self.shadowMap.end();
                self.lightCam.end();
            }

            const lightView = rl.gl.rlGetMatrixModelview();
            const lightProj = rl.gl.rlGetMatrixProjection();

            rl.gl.rlClearScreenBuffers();
            game.draw();

            break :blk lightView.multiply(lightProj);
        };

        {
            // ตั้ง state ให้ GPU รู้เรื่อง
            const SHADOW_TEX_SLOT: i32 = 10; // GL_TEXTURE0 + 10 = GL_TEXTURE10

            // DO: *TEXTURE10 = shadowMap.depth.id
            rl.gl.rlActiveTextureSlot(SHADOW_TEX_SLOT);
            rl.gl.rlEnableTexture(self.shadowMap.depth.id);

            // DO: glsl(uniform mat4 lightVP) -> mat(light_view_proj_mat)
            self.shadowShaderWrapper.uniform.lightVP.set(light_view_proj_mat);
            // DO: glsl(uniform sampler2D shadowMap) -> *TEXTURE10
            self.shadowShaderWrapper.uniform.shadowMap.set(SHADOW_TEX_SLOT);
        }
    }

    pub fn create_texture_with_depth(size: i32) !rl.RenderTexture2D {
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
};
