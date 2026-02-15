const std = @import("std");
const rl = @import("raylib");
const zphy = @import("zphysics");
const Util = @import("./util.zig");
const Player = @import("./player.zig").PlayerEntity;
const physic = @import("./physic.zig");
const game = @This();

pub const PhysicsHandle = union(enum) {
    body: *zphy.Body,
    character: *zphy.Character,
};

pub const Entity = struct {
    model: rl.Model,
    ref: PhysicsHandle,
    tint: rl.Color = rl.Color.white,
    scale: rl.Vector3 = .init(1, 1, 1), // optimize draw

    pub fn draw(self: @This()) void {
        self.begin_transform();
        defer self.end_transform();
        self.model.draw(.zero(), 1.0, self.tint);
    }
    pub fn drawWires(self: @This()) void {
        self.model.drawWires(.zero(), 1.0, .white);
    }
    pub fn position(self: @This()) [3]f32 {
        return switch (self.ref) {
            .body => |b| b.getPosition(),
            .character => |c| c.getPosition(),
        };
    }
    pub fn rotation(self: @This()) [4]f32 {
        return switch (self.ref) {
            .body => |b| b.getRotation(),
            .character => .{ 0, 0, 0, 1 },
        };
    }
    pub fn begin_transform(self: @This()) void {
        rl.gl.rlPushMatrix();

        const pos = self.position();
        rl.gl.rlTranslatef(pos[0], pos[1], pos[2]);

        const rot = self.rotation();
        const rot_mat = rl.Quaternion.toMatrix(.init(rot[0], rot[1], rot[2], rot[3]));
        rl.gl.rlMultMatrixf(@as([*]const f32, @ptrCast(&rot_mat.m0))[0..16]);

        const scale = self.scale;
        rl.gl.rlScalef(scale.x, scale.y, scale.z);
    }
    pub fn end_transform(_: @This()) void {
        rl.gl.rlPopMatrix();
    }
};

pub const State = struct {
    entities: std.ArrayList(Entity),
    allocator: std.mem.Allocator,
    pub fn init(allocator: std.mem.Allocator) !@This() {
        return .{
            .entities = try std.ArrayList(Entity).initCapacity(allocator, 0),
            .allocator = allocator,
        };
    }
    pub fn deinit(self: *@This()) void {
        self.game_objects.deinit(self.allocator);
    }
    pub fn add(self: *@This(), item: Entity) !void {
        try self.entities.append(self.allocator, item);
    }
    pub fn get(self: *@This(), id: zphy.BodyId) ?Entity {
        for (self.entities.items) |e| {
            if (e.ref == .body and e.ref.body.id == id) {
                return e;
            }
        }
        return null;
    }
};

pub const CreateBodyArg = struct {
    graphic: struct {
        mesh: rl.Mesh,
        shader: ?rl.Shader = null,
        tint: rl.Color = .white,
        scale: rl.Vector3 = .init(1, 1, 1),
    },
    physic: zphy.BodyCreationSettings,
    game_state: *game.State,
    physic_backend: *physic.Backend,
};

pub fn createBody(args_: CreateBodyArg) !*zphy.Body {
    var args = args_;
    const body = try args.physic_backend.add(args.physic);

    var model = try rl.loadModelFromMesh(args.graphic.mesh);
    if (args.graphic.shader) |shader| {
        model.materials[0].shader = shader;
    }
    try args.game_state.add(.{
        .model = model,
        .ref = .{ .body = body },
        .tint = args.graphic.tint,
        .scale = args.graphic.scale,
    });

    return body;
}

pub fn draw(state: *game.State) void {
    for (state.entities.items) |obj| {
        obj.draw();
    }
}
