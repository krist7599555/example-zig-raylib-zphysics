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
    tint: rl.Color = rl.Color.white,
    ref: PhysicsHandle,

    pub fn draw(self: @This()) void {
        self.model.draw(rl.Vector3.zero(), 1.0, self.tint);
    }
    pub fn drawWires(self: @This()) void {
        self.model.drawWires(rl.Vector3.zero(), 1.0, .white);
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
    },
    physic: zphy.BodyCreationSettings,
    game_state: *game.State,
    physic_backend: *physic.Backend,
};

fn _applyBodyTransform(
    pos: [3]f32,
    rot: [4]f32,
) void {
    var axis: rl.Vector3 = undefined;
    var angle: f32 = undefined;
    rl.Quaternion.init(rot[0], rot[1], rot[2], rot[3]).toAxisAngle(&axis, &angle);
    const rad2deg = 180.0 / std.math.pi;

    rl.gl.rlTranslatef(pos[0], pos[1], pos[2]);
    rl.gl.rlRotatef(angle * rad2deg, axis.x, axis.y, axis.z); // rlgl ใช้หน่วยองศา (Degree)
}

pub fn createBody(args_: CreateBodyArg) !*zphy.Body {
    var args = args_;
    const body = try args.physic_backend.add(args.physic);

    var model = try rl.loadModelFromMesh(args.graphic.mesh);
    if (args.graphic.shader) |shader| {
        model.materials[0].shader = shader;
    }
    try args.game_state.add(.{
        .model = model,
        .tint = args.graphic.tint,
        .ref = .{ .body = body },
    });

    return body;
}

pub fn draw(state: *game.State) void {
    for (state.entities.items) |obj| {
        rl.gl.rlPushMatrix();
        defer rl.gl.rlPopMatrix();

        _applyBodyTransform(
            obj.position(),
            obj.rotation(),
        );

        obj.draw();
    }
}
