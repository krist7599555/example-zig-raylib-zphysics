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
    lightVP_loc: i32,
    // uniformLightVP: UniformWriter(rl.Matrix, "lightVP") = .{},
    shadowMap_loc: i32,
    // uniformshadowMap: UniformWriter(i32, "shadowMap") = .{},
    shadowMap: rl.RenderTexture2D,
    shadowMapResolution: i32,
    shadowShader: rl.Shader,

    pub fn init(config: ShadowMapperConfig) !ShadowMapper {
        // NOTE: raylib will not throw error if file not exists
        const shadowShader = try rl.loadShader(
            "resources/shaders/shadowmap.vert",
            "resources/shaders/shadowmap.frag",
        );
        shadowShader.locs[@intFromEnum(rl.ShaderLocationIndex.vector_view)] = rl.getShaderLocation(shadowShader, "viewPos");
        {
            setShaderValue(shadowShader, "lightDir", &config.light_dir.normalize(), .vec3);
            setShaderValue(shadowShader, "lightColor", &rl.colorNormalize(config.light_color), .vec4);
            setShaderValue(shadowShader, "ambient", &rl.colorNormalize(config.ambient_color), .vec4);
        }

        setShaderValue(shadowShader, "shadowMapResolution", &[_]i32{config.resolution}, .int);

        return ShadowMapper{
            .lightCam = .{
                .position = config.light_dir.scale(-15.0),
                .target = rl.Vector3.zero(),
                .up = rl.Vector3.init(0, 1, 0),
                .fovy = config.fovy, // Try Change this to fix shadow error (low = no shadow, hi = too dark)
                .projection = .orthographic,
            },
            .lightVP_loc = rl.getShaderLocation(shadowShader, "lightVP"),
            .shadowMap_loc = rl.getShaderLocation(shadowShader, "shadowMap"),
            .shadowMap = try create_texture_with_depth(config.resolution),

            .shadowShader = shadowShader,
            .shadowMapResolution = config.resolution,
        };
    }

    pub fn deinit(self: *@This()) void {
        rl.unloadShader(self.shadowShader);
        self.shadowMap.unload();
    }

    pub fn render_game_world(self: *ShadowMapper, game: *GameWorld) void {
        const light_view_proj_mat = blk: {
            // Render ฉากจากมุมมองของแสง
            // Rerturn Light View-Projection Matrix
            self.shadowMap.begin();
            defer self.shadowMap.end();

            self.lightCam.begin();
            defer self.lightCam.end();

            const lightView = rl.gl.rlGetMatrixModelview();
            const lightProj = rl.gl.rlGetMatrixProjection();

            rl.clearBackground(.white);
            game.draw();

            break :blk lightView.multiply(lightProj);
        };

        {
            // ตั้ง state ให้ GPU รู้เรื่อง
            var SHADOW_TEX_SLOT: i32 = 10; // GL_TEXTURE0 + 10 = GL_TEXTURE10

            // DO: *TEXTURE10 = shadowMap.depth.id
            rl.gl.rlActiveTextureSlot(SHADOW_TEX_SLOT);
            rl.gl.rlEnableTexture(self.shadowMap.depth.id);

            // DO: glsl(uniform mat4 lightVP) -> mat(light_view_proj_mat)
            rl.setShaderValueMatrix(
                self.shadowShader,
                self.lightVP_loc,
                light_view_proj_mat,
            );
            // DO: glsl(uniform sampler2D shadowMap) -> *TEXTURE10
            rl.gl.rlSetUniform(
                self.shadowMap_loc,
                @ptrCast(&SHADOW_TEX_SLOT),
                @intFromEnum(rl.gl.rlShaderUniformDataType.rl_shader_uniform_int),
                1,
            );
        }
    }

    pub fn inject_shadow_shader(self: *ShadowMapper, model: rl.Model) void {
        for (model.materials[0..@intCast(model.materialCount)]) |*mat| {
            mat.shader = self.shadowShader;
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

    pub fn update_camera(self: *ShadowMapper, camera: rl.Camera3D) void {
        rl.setShaderValue(
            self.shadowShader,
            self.shadowShader.locs[@intFromEnum(rl.ShaderLocationIndex.vector_view)],
            &camera.position,
            .vec3,
        );
    }
};
