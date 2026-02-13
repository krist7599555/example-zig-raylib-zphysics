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

pub const ShadowMapper = struct {
    lightCam: rl.Camera3D,
    lightVPLoc: i32,
    shadowMapLoc: i32,
    shadowMap: rl.RenderTexture2D,
    shadowMapResolution: i32,
    shadowShader: rl.Shader,

    pub fn init() !ShadowMapper {
        // NOTE: raylib will not throw error if file not exists
        const shadowShader = try rl.loadShader(
            "resources/shaders/shadowmap.vert",
            "resources/shaders/shadowmap.frag",
        );
        shadowShader.locs[@intFromEnum(rl.ShaderLocationIndex.vector_view)] = rl.getShaderLocation(shadowShader, "viewPos");
        var lightDir = rl.Vector3.init(0.35, -1.0, -0.35).normalize();
        const lightColor = rl.Color.white;
        const lightColorNormalized = rl.colorNormalize(lightColor);
        const lightDirloc = rl.getShaderLocation(shadowShader, "lightDir");
        const lightColLoc = rl.getShaderLocation(shadowShader, "lightColor");
        rl.setShaderValue(shadowShader, lightDirloc, &lightDir, .vec3);
        rl.setShaderValue(shadowShader, lightColLoc, &lightColorNormalized, .vec4);
        const ambientLoc = rl.getShaderLocation(shadowShader, "ambient");
        const ambient: [4]f32 = [4]f32{ 0.1, 0.1, 0.1, 1.0 };
        rl.setShaderValue(shadowShader, ambientLoc, &ambient, .vec4);

        const lightVPLoc = rl.getShaderLocation(shadowShader, "lightVP");
        const shadowMapLoc = rl.getShaderLocation(shadowShader, "shadowMap");
        const shadowMapResolution = 1024;
        const res: [1]i32 = [1]i32{shadowMapResolution};
        const shadowMapResolutionLoc = rl.getShaderLocation(shadowShader, "shadowMapResolution");
        rl.setShaderValue(shadowShader, shadowMapResolutionLoc, &res, .int);

        const shadowMap = load_shadowmap_render_texture(shadowMapResolution, shadowMapResolution);

        const lightCam = rl.Camera3D{
            .position = lightDir.scale(-15.0),
            .target = rl.Vector3.zero(),
            .up = .{ .x = 0.0, .y = 1.0, .z = 0.0 },
            .fovy = 20.0,
            .projection = .orthographic,
        };

        return ShadowMapper{
            .lightCam = lightCam,
            .lightVPLoc = lightVPLoc,
            .shadowMapLoc = shadowMapLoc,
            .shadowMap = shadowMap,
            .shadowShader = shadowShader,
            .shadowMapResolution = shadowMapResolution,
        };
    }

    pub fn deinit(self: *@This()) void {
        rl.unloadShader(self.shadowShader);
        self.unload_shadowmap_render_texture();
    }

    pub fn render_game_world(self: *ShadowMapper, game: *GameWorld) void {
        var lightView: rl.Matrix = undefined;
        var lightProj: rl.Matrix = undefined;
        rl.beginTextureMode(self.shadowMap);
        rl.clearBackground(.white);
        rl.beginMode3D(self.lightCam);
        lightView = rl.gl.rlGetMatrixModelview();
        lightProj = rl.gl.rlGetMatrixProjection();

        game.draw();

        rl.endMode3D();
        rl.endTextureMode();
        const lightViewProj: rl.Matrix = lightView.multiply(lightProj);

        rl.clearBackground(.black);

        rl.setShaderValueMatrix(self.shadowShader, self.lightVPLoc, lightViewProj);

        rl.gl.rlEnableShader(self.shadowShader.id);
        var slot: i32 = 10;
        rl.gl.rlActiveTextureSlot(10);
        rl.gl.rlEnableTexture(self.shadowMap.depth.id);
        rl.gl.rlSetUniform(self.shadowMapLoc, @ptrCast(&slot), @intFromEnum(rl.gl.rlShaderUniformDataType.rl_shader_uniform_int), 1);
    }

    pub fn inject_shadow_shader(self: *ShadowMapper, model: rl.Model) void {
        var i: usize = 0;
        while (i < model.materialCount) : (i += 1) {
            model.materials[i].shader = self.shadowShader;
        }
    }

    pub fn load_shadowmap_render_texture(width: i32, height: i32) rl.RenderTexture2D {
        var target: rl.RenderTexture2D = undefined;

        target.id = rl.gl.rlLoadFramebuffer(); // Load an empty framebuffer
        target.texture.width = width;
        target.texture.height = height;

        if (target.id > 0) {
            rl.gl.rlEnableFramebuffer(target.id);

            // Create depth texture
            // We don't need a color texture for the shadowmap
            target.depth.id = rl.gl.rlLoadTextureDepth(width, height, false);
            target.depth.width = width;
            target.depth.height = height;
            target.depth.format = .compressed_etc2_rgb; // 19; // DEPTH_COMPONENT_24BIT?
            target.depth.mipmaps = 1;

            // Attach depth texture to FBO
            rl.gl.rlFramebufferAttach(target.id, target.depth.id, @intFromEnum(rl.gl.rlFramebufferAttachType.rl_attachment_depth), @intFromEnum(rl.gl.rlFramebufferAttachTextureType.rl_attachment_texture2d), 0);

            // Check if FBO is complete with attachments (valid)
            if (rl.gl.rlFramebufferComplete(target.id)) std.log.info("FBO: [ID {d}] Framebuffer object created successfully", .{target.id});

            rl.gl.rlDisableFramebuffer();
        } else std.log.warn("FBO: Framebuffer object cannot be created", .{});

        return target;
    }

    pub fn unload_shadowmap_render_texture(self: *ShadowMapper) void {
        if (self.shadowMap.id > 0) {
            rl.gl.rlUnloadFramebuffer(self.shadowMap.id);
        }
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
