const rl = @import("raylib");

pub const DepthVisualize = struct {
    shader: rl.Shader,

    const vert =
        \\#version 330
        \\
        \\in vec3 vertexPosition;
        \\in vec2 vertexTexCoord;
        \\
        \\out vec2 fragTexCoord;
        \\
        \\uniform mat4 mvp;
        \\
        \\void main() {
        \\    fragTexCoord = vertexTexCoord;
        \\    gl_Position = mvp * vec4(vertexPosition, 1.0);
        \\}
    ;

    const frag =
        \\#version 330
        \\
        \\in vec2 fragTexCoord;
        \\out vec4 finalColor;
        \\
        \\uniform sampler2D depthTex;
        \\
        \\void main() {
        \\    float d = texture(depthTex, fragTexCoord).r;
        \\    float d2 = fract(d * 200.0);
        \\    float wave = sin(d * 2000.0 * 3.14159);
        \\    wave = wave * 0.5 + 0.5;
        \\    finalColor = vec4(wave, wave, wave, 1.0);
        \\}
    ;

    pub fn init() !DepthVisualize {
        return .{
            .shader = try rl.loadShaderFromMemory(vert, frag),
        };
    }
    pub fn deinit(self: @This()) void {
        rl.unloadShader(self.shader);
    }
    pub fn begin_shader(self: @This()) void {
        rl.beginShaderMode(self.shader);
    }
    pub fn end_shader(_: @This()) void {
        rl.endShaderMode();
    }
};
