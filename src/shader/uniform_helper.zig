const rl = @import("raylib");
const std = @import("std");

pub fn Uniform(comptime T: type, comptime name: []const u8) type {
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
pub fn ReplaceValue(comptime T: type, comptime V: type) type {
    const info = @typeInfo(T);
    if (info != .@"struct") {
        @compileError("ReplaceValue expects a struct type");
    }

    const fields = info.@"struct".fields;
    comptime var new_fields: [fields.len]std.builtin.Type.StructField = undefined;

    inline for (fields, 0..) |f, i| {
        if (f.is_comptime) {
            @compileError("ReplaceValue does not support comptime fields");
        }
        new_fields[i] = .{
            .name = f.name,
            .type = V,
            .is_comptime = false,
            .alignment = @alignOf(V),
            .default_value_ptr = null,
        };
    }

    return @Type(.{ .@"struct" = .{
        .layout = info.@"struct".layout,
        .is_tuple = info.@"struct".is_tuple,
        .fields = &new_fields,
        .decls = &.{},
    } });
}

pub fn ShaderWrapper(
    vert: [:0]const u8,
    frag: [:0]const u8,
    comptime U: type,
) type {
    // const all_fields = get_all_fields_str(U);
    return struct {
        shader: rl.Shader,
        uniform_loc: ReplaceValue(U, i32),

        pub fn init() !@This() {
            const shader = try rl.loadShaderFromMemory(vert, frag);
            var uniform_loc: ReplaceValue(U, i32) = undefined;
            inline for (@typeInfo(U).@"struct".fields) |f| {
                @field(uniform_loc, f.name) = rl.getShaderLocation(shader, f.name ++ "\x00");
            }
            // FIX BELOW IS HARD CODED!!!
            if (@hasField(U, "view_position")) {
                shader.locs[@intCast(@intFromEnum(rl.ShaderLocationIndex.vector_view))] = uniform_loc.view_position;
            }
            if (@hasField(U, "ambient_color")) {
                shader.locs[@intCast(@intFromEnum(rl.ShaderLocationIndex.color_ambient))] = uniform_loc.ambient_color;
            }
            if (@hasField(U, "diffuse_color")) {
                shader.locs[@intCast(@intFromEnum(rl.ShaderLocationIndex.color_diffuse))] = uniform_loc.diffuse_color;
            }

            const res: @This() = .{
                .shader = shader,
                .uniform_loc = uniform_loc,
            };
            return res;
        }

        pub fn set_uniform(self: @This(), data: anytype) void {
            const V = @TypeOf(data);
            inline for (@typeInfo(V).@"struct".fields) |f| {
                if (@hasField(U, f.name)) {
                    const UT = @FieldType(U, f.name);
                    const VT = @FieldType(@TypeOf(data), f.name);
                    if (UT == VT) {
                        const loc = @field(self.uniform_loc, f.name);
                        const val = @field(data, f.name);
                        std.debug.print("setunform", .{});
                        setUniformValue(UT, self.shader, loc, val);
                    } else {
                        @compileError("." ++ f.name ++ " Expect Type " ++ @typeName(UT) ++ " Got " ++ @typeName(VT));
                    }
                } else {
                    @compileError("XX");
                }
            }
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
}

fn get_all_fields_str(comptime T: type) []const u8 {
    var msg: []const u8 = "";
    inline for (@typeInfo(T).@"struct".fields) |f| {
        msg = msg ++ "  " ++ f.name ++ ": " ++ @typeName(f.type) ++ ",\n";
    }
    return @typeName(T) ++ "{\n" ++ msg ++ "}\n";
}
fn setUniformValue(comptime T: type, shader: rl.Shader, loc: i32, val: T) void {
    switch (T) {
        f32 => rl.setShaderValue(shader, loc, &.{val}, .float),
        i32 => rl.setShaderValue(shader, loc, &.{val}, .int),
        rl.Vector2 => rl.setShaderValue(shader, loc, &val, .vec2),
        rl.Vector3 => rl.setShaderValue(shader, loc, &val, .vec3),
        rl.Vector4 => rl.setShaderValue(shader, loc, &val, .vec4),
        rl.Matrix => rl.setShaderValueMatrix(shader, loc, val),
        else => {
            @compileError("no matching type in Uniform");
        },
    }
}
