const std = @import("std");
const rl = @import("raylib");
const zphy = @import("zphysics");
const vec4 = @import("./vec.zig").vec4;

const DIFFUSE_IDX: usize = @as(usize, @intFromEnum(rl.MATERIAL_MAP_DIFFUSE));

pub const GameObject = struct {
    model: rl.Model,
    tint: rl.Color = rl.Color.white,
    body_id: zphy.BodyId,
    fn getColor(self: @This()) rl.Color {
        return self.model.materials[0].maps[DIFFUSE_IDX].color;
    }
    fn setColor(self: @This(), color: rl.Color) void {
        self.model.materials[0].maps[DIFFUSE_IDX].color = color;
    }
    fn getShader(self: @This()) rl.Shader {
        return self.model.materials[0].shader;
    }
    fn setShader(self: @This(), shader: rl.Shader) void {
        self.model.materials[0].shader = shader;
    }
    fn getMaterial(self: @This()) rl.Material {
        return self.model.materials[0];
    }
    fn setMaterial(self: @This(), material: rl.Material) void {
        self.setColor(material.maps[DIFFUSE_IDX].color);
        self.setShader(material.shader);
    }
};

pub const GameWorld = struct {
    game_objects: std.ArrayList(GameObject),
    body_interface: *zphy.BodyInterface,
    allocator: std.mem.Allocator,
    pub fn init(allocator: std.mem.Allocator, body_interface: *zphy.BodyInterface) !GameWorld {
        return GameWorld{
            .game_objects = try std.ArrayList(GameObject).initCapacity(allocator, 0),
            .body_interface = body_interface,
            .allocator = allocator,
        };
    }
    pub fn deinit(self: *@This()) void {
        self.game_objects.deinit(self.allocator);
    }

    pub fn draw(self: *@This()) void {
        for (self.game_objects.items) |obj| {
            const pos: [3]f32 = self.body_interface.getPosition(obj.body_id);
            const rot: [4]f32 = self.body_interface.getRotation(obj.body_id);

            rl.gl.rlPushMatrix();
            defer rl.gl.rlPopMatrix();

            rl.gl.rlTranslatef(pos[0], pos[1], pos[2]);
            var axis: rl.Vector3 = undefined;
            var angle: f32 = undefined;
            rl.Quaternion
                .initVec(vec4(rot))
                .toAxisAngle(&axis, &angle);
            const rad2deg = 180.0 / std.math.pi;
            rl.gl.rlRotatef(angle * rad2deg, axis.x, axis.y, axis.z); // rlgl ใช้หน่วยองศา (Degree)

            rl.drawModel(obj.model, rl.Vector3.zero(), 1.0, obj.tint);
        }
    }
    pub fn create_and_add(game: *@This(), args: anytype) !zphy.BodyId {
        const shape_instance = args.shape;
        const pos = if (@hasField(@TypeOf(args), "position")) args.position else [4]f32{ 0, 0, 0, 0 };
        const rot = if (@hasField(@TypeOf(args), "rotation")) args.rotation else [4]f32{ 0, 0, 0, 1 };
        if (!@hasField(@TypeOf(args), "motion_type")) {
            @compileError("require .motion_type");
        }
        const motion: zphy.MotionType = args.motion_type;
        const tint: rl.Color = if (@hasField(@TypeOf(args), "tint")) args.tint else rl.Color.white;

        const ObjectLayer = @import("./jolt.zig").object_layers;
        const body_id = try game.body_interface.createAndAddBody(.{
            .position = pos,
            .rotation = rot,
            .shape = try shape_instance.generateJolt(),
            .motion_type = motion,
            .object_layer = switch (motion) {
                .static => ObjectLayer.non_moving,
                .dynamic, .kinematic => ObjectLayer.moving,
            },
        }, .activate);

        const mesh = shape_instance.generateMesh();
        var model = try rl.loadModelFromMesh(mesh);

        if (@hasField(@TypeOf(args), "material")) {
            const mat = args.material;
            model.materials[0].maps[DIFFUSE_IDX].color = mat.maps[DIFFUSE_IDX].color;
            model.materials[0].shader = mat.shader;
        }

        try game.game_objects.append(game.allocator, .{
            .model = model,
            .tint = tint,
            .body_id = body_id,
        });
        return body_id;
    }
};
