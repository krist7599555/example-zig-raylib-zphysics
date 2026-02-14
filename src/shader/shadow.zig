const rl = @import("raylib");
const std = @import("std");

fn Uniform(comptime T: type, comptime name: []const u8) type {
    return struct {
        loc: i32 = undefined,
        shader: rl.Shader = undefined,
        pub fn init(self: *@This(), shader: rl.Shader) void {
            self.loc = rl.getShaderLocation(shader, name ++ "\x00");
            self.shader = shader;
        }
        pub fn set(self: *const @This(), val: T) void {
            switch (T) {
                f32 => rl.setShaderValue(self.shader, self.loc, &.{val}, .float),
                i32 => rl.setShaderValue(self.shader, self.loc, &.{val}, .int),
                rl.Vector2 => rl.setShaderValue(self.shader, self.loc, &val, .vec2),
                rl.Vector3 => rl.setShaderValue(self.shader, self.loc, &val, .vec3),
                rl.Vector4 => rl.setShaderValue(self.shader, self.loc, &val, .vec4),
                rl.Matrix => rl.setShaderValueMatrix(self.shader, self.loc, val),
                else => {
                    @compileError("no matching type in Uniform");
                },
            }
        }
    };
}

const ShadowShaderUniform = struct {
    colDiffuse: Uniform(rl.Vector4, "colDiffuse") = .{},
    lightDir: Uniform(rl.Vector3, "lightDir") = .{},
    lightColor: Uniform(rl.Vector4, "lightColor") = .{},
    ambient: Uniform(rl.Vector4, "ambient") = .{},
    viewPos: Uniform(rl.Vector3, "viewPos") = .{}, // = camera position =
    lightVP: Uniform(rl.Matrix, "lightVP") = .{},
    shadowMapResolution: Uniform(i32, "shadowMapResolution") = .{},
    shadowMap: Uniform(i32, "shadowMap") = .{}, // sampler2D
};

pub const ShadowShader = struct {
    shader: rl.Shader = undefined,
    uniform: ShadowShaderUniform,

    const vert =
        \\#version 330
        \\
        \\// Input vertex attributes
        \\in vec3 vertexPosition;
        \\in vec2 vertexTexCoord;
        \\in vec3 vertexNormal;
        \\in vec4 vertexColor;
        \\
        \\// Input uniform values
        \\uniform mat4 mvp;
        \\uniform mat4 matModel;
        \\uniform mat4 matNormal;
        \\
        \\// Output vertex attributes (to fragment shader)
        \\out vec3 fragPosition;
        \\out vec2 fragTexCoord;
        \\out vec4 fragColor;
        \\out vec3 fragNormal;
        \\
        \\// NOTE: Add here your custom variables
        \\
        \\void main()
        \\{
        \\    // Send vertex attributes to fragment shader
        \\    fragPosition = vec3(matModel*vec4(vertexPosition, 1.0));
        \\    fragTexCoord = vertexTexCoord;
        \\    fragColor = vertexColor;
        \\    fragNormal = normalize(vec3(matNormal*vec4(vertexNormal, 1.0)));
        \\
        \\    // Calculate final vertex position
        \\    gl_Position = mvp*vec4(vertexPosition, 1.0);
        \\}
    ;

    const frag =
        \\#version 330
        \\
        \\// This shader is based on the basic lighting shader
        \\// This only supports one light, which is directional, and it (of course) supports shadows
        \\
        \\// Input vertex attributes (from vertex shader)
        \\in vec3 fragPosition;
        \\in vec2 fragTexCoord;
        \\//in vec4 fragColor;
        \\in vec3 fragNormal;
        \\
        \\// Input uniform values
        \\uniform sampler2D texture0;
        \\uniform vec4 colDiffuse;
        \\
        \\// Output fragment color
        \\out vec4 finalColor;
        \\
        \\// Input lighting values
        \\uniform vec3 lightDir;
        \\uniform vec4 lightColor;
        \\uniform vec4 ambient;
        \\uniform vec3 viewPos;
        \\
        \\// Input shadowmapping values
        \\uniform mat4 lightVP; // Light source view-projection matrix
        \\uniform sampler2D shadowMap;
        \\
        \\uniform int shadowMapResolution;
        \\
        \\void main()
        \\{
        \\    // Texel color fetching from texture sampler
        \\    vec4 texelColor = texture(texture0, fragTexCoord);
        \\    vec3 lightDot = vec3(0.0);
        \\    vec3 normal = normalize(fragNormal);
        \\    vec3 viewD = normalize(viewPos - fragPosition);
        \\    vec3 specular = vec3(0.0);
        \\
        \\    vec3 l = -lightDir;
        \\
        \\    float NdotL = max(dot(normal, l), 0.0);
        \\    lightDot += lightColor.rgb*NdotL;
        \\
        \\    float specCo = 0.0;
        \\    //if (NdotL > 0.0) specCo = pow(max(0.0, dot(viewD, reflect(-(l), normal))), 16.0); // 16 refers to shine
        \\    //specular += specCo;
        \\
        \\    finalColor = (texelColor*((colDiffuse + vec4(specular, 1.0))*vec4(lightDot, 1.0)));
        \\
        \\    // Shadow calculations
        \\    // f(fragPosition) -> shadowMapCoor
        \\    vec4 fragPosLightSpace = lightVP * vec4(fragPosition, 1);
        \\    fragPosLightSpace.xyz /= fragPosLightSpace.w; // Perform the perspective division
        \\    fragPosLightSpace.xyz = (fragPosLightSpace.xyz + 1.0f) / 2.0f; // Transform from [-1, 1] range to [0, 1] range
        \\    vec2 sampleCoords = fragPosLightSpace.xy;
        \\    float curDepth = fragPosLightSpace.z;
        \\    // Slope-scale depth bias: depth biasing reduces "shadow acne" artifacts, where dark stripes appear all over the scene.
        \\    // The solution is adding a small bias to the depth
        \\    // In this case, the bias is proportional to the slope of the surface, relative to the light
        \\    float bias = max(0.0002 * (1.0 - dot(normal, l)), 0.00002) + 0.00001;
        \\    int shadowCounter = 0;
        \\    const int numSamples = 9;
        \\    // PCF (percentage-closer filtering) algorithm:
        \\    // Instead of testing if just one point is closer to the current point,
        \\    // we test the surrounding points as well.
        \\    // This blurs shadow edges, hiding aliasing artifacts.
        \\
        \\    // 3. ใช้ PCF (Percentage Closer Filtering)
        \\    // แทนที่จะเช็คแค่พิกเซลเดียวใน Shadow Map ให้เช็คพิกเซลรอบๆ แล้วนำมาเฉลี่ยกัน จะช่วยให้ขอบเงาดูนุ่มนวลขึ้น (Soft Shadows)
        \\    // เพิ่มโค้ดนี้ใน Fragment Shader ของคุณ:
        \\    vec2 texelSize = vec2(1.0f / float(shadowMapResolution));
        \\    for (int x = -1; x <= 1; x++)
        \\    {
        \\        for (int y = -1; y <= 1; y++)
        \\        {
        \\            float sampleDepth = texture(shadowMap, sampleCoords + texelSize * vec2(x, y)).r;
        \\            if (curDepth - bias > sampleDepth)
        \\            {
        \\                shadowCounter++;
        \\            }
        \\        }
        \\    }
        \\
        \\    // prefer crisper pixelized shadows
        \\    bool ditherX = mod(gl_FragCoord.x, 2.0) > 0.5;
        \\    bool ditherY = mod(gl_FragCoord.y, 2.0) > 0.5;
        \\    if (shadowCounter > 0 && (ditherY || ditherX)) finalColor = vec4(0.0, 0.0, 0.0, 1.0);
        \\
        \\    //finalColor = mix(finalColor, vec4(0, 0, 0, 1), float(shadowCounter) / float(numSamples));
        \\    //finalColor += texelColor*(ambient/10.0)*colDiffuse;
        \\    //finalColor = pow(finalColor, vec4(1.0/2.2));
        \\}
    ;
    pub fn init() !ShadowShader {
        var res = @This(){
            .shader = try rl.loadShaderFromMemory(vert, frag),
            .uniform = .{},
        };
        inline for (@typeInfo(@TypeOf(res.uniform)).@"struct".fields) |f| {
            @field(res.uniform, f.name).init(res.shader);
        }
        res.shader.locs[@intCast(@intFromEnum(rl.ShaderLocationIndex.vector_view))] = res.uniform.viewPos.loc;
        res.shader.locs[@intCast(@intFromEnum(rl.ShaderLocationIndex.color_ambient))] = res.uniform.ambient.loc;
        res.shader.locs[@intCast(@intFromEnum(rl.ShaderLocationIndex.color_diffuse))] = res.uniform.colDiffuse.loc;

        return res;
    }
};
