const std = @import("std");
const rl = @import("raylib");
const zphy = @import("zphysics");
const Util = @import("./util.zig");
const vec4 = @import("./vec.zig").vec4;

const DIFFUSE_IDX: usize = @as(usize, @intFromEnum(rl.MATERIAL_MAP_DIFFUSE));

pub const GameObject = struct {
    model: rl.Model,
    tint: rl.Color = rl.Color.white,
    wires: ?rl.Color = undefined,
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
    fn draw(self: @This()) void {
        self.model.draw(rl.Vector3.zero(), 1.0, self.tint);

        if (self.wires) |wires| {
            const color = self.getColor();
            self.setColor(wires);
            self.model.drawWires(rl.Vector3.zero(), 1.0, .white);
            self.setColor(color);
        }
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
            rl.gl.rlPushMatrix();
            defer rl.gl.rlPopMatrix();

            Util.applyBodyTransform(self.body_interface, obj.body_id);

            obj.draw();
        }
    }
    pub fn createBody(game: *@This(), args: anytype) !zphy.BodyId {
        const shape_instance = args.shape;
        const pos = if (@hasField(@TypeOf(args), "position")) args.position else [4]f32{ 0, 0, 0, 0 };
        const rot = if (@hasField(@TypeOf(args), "rotation")) args.rotation else [4]f32{ 0, 0, 0, 1 };
        if (!@hasField(@TypeOf(args), "motion_type")) {
            @compileError("require .motion_type");
        }
        const motion: zphy.MotionType = args.motion_type;
        const tint: rl.Color = if (@hasField(@TypeOf(args), "tint")) args.tint else rl.Color.white;
        const restitution: f32 = if (@hasField(@TypeOf(args), "restitution")) args.restitution else 0.0;
        const linear_damping: f32 = if (@hasField(@TypeOf(args), "linear_damping")) args.linear_damping else 0.05;

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
            .restitution = restitution, // High bounce
            .linear_damping = linear_damping, // Low air resistance
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
            .wires = if (@hasField(@TypeOf(args), "wires")) args.wires else undefined,
        });
        return body_id;
    }
    pub fn getObj(self: *@This(), body_id: zphy.BodyId) ?GameObject {
        for (self.game_objects.items) |obj| {
            if (obj.body_id == body_id) return obj;
        }
        return undefined;
    }
};
