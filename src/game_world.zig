const std = @import("std");
const rl = @import("raylib");
const zphy = @import("zphysics");
const Util = @import("./util.zig");
const Player = @import("./player.zig").Player;
const physic = @import("./physic.zig");

pub const Entity = struct {
    model: rl.Model,
    tint: rl.Color = rl.Color.white,
    wires: ?rl.Color = undefined,
    body_id: zphy.BodyId,

    fn draw(self: @This()) void {
        self.model.draw(rl.Vector3.zero(), 1.0, self.tint);

        if (self.wires) |color| {
            self.model.drawWires(rl.Vector3.zero(), 1.0, color);
        }
    }
};

pub const WorldState = struct {
    entities: std.ArrayList(Entity),
    player: ?Player = null,
    allocator: std.mem.Allocator,
    pub fn init(allocator: std.mem.Allocator) !WorldState {
        return .{
            .entities = try std.ArrayList(Entity).initCapacity(allocator, 0),
            .allocator = allocator,
            .player = null,
        };
    }
    pub fn deinit(self: *@This()) void {
        self.game_objects.deinit(self.allocator);
    }
    pub fn add(self: *@This(), item: Entity) !void {
        try self.entities.append(self.allocator, item);
    }
};

pub const CreateBodyArg = struct {
    graphic: struct {
        mesh: rl.Mesh,
        shader: ?rl.Shader = null,
        tint: rl.Color = .white,
        wires: ?rl.Color = null,
    },
    physic: zphy.BodyCreationSettings,
    world_state: *WorldState,
    physic_backend: *physic.Backend,
};

pub const GameWorld = struct {
    body_interface: *zphy.BodyInterface,
    physics_system: *zphy.PhysicsSystem,

    pub fn init(physic_backend: *physic.Backend) !GameWorld {
        return GameWorld{
            .body_interface = physic_backend.physics_system.getBodyInterfaceMut(),
            .physics_system = physic_backend.physics_system,
        };
    }
    pub fn deinit(self: *@This()) void {
        _ = self;
    }
};

fn _applyBodyTransform(body_interface: *zphy.BodyInterface, body_id: zphy.BodyId) void {
    const pos: [3]f32 = body_interface.getPosition(body_id);
    const rot: [4]f32 = body_interface.getRotation(body_id);

    var axis: rl.Vector3 = undefined;
    var angle: f32 = undefined;
    rl.Quaternion.init(rot[0], rot[1], rot[2], rot[3]).toAxisAngle(&axis, &angle);
    const rad2deg = 180.0 / std.math.pi;

    rl.gl.rlTranslatef(pos[0], pos[1], pos[2]);
    rl.gl.rlRotatef(angle * rad2deg, axis.x, axis.y, axis.z); // rlgl ใช้หน่วยองศา (Degree)
}

pub fn createBody(args_: CreateBodyArg) !zphy.BodyId {
    var args = args_;
    const body_id = try args.physic_backend.add(args.physic);

    var model = try rl.loadModelFromMesh(args.graphic.mesh);
    if (args.graphic.shader) |shader| {
        model.materials[0].shader = shader;
    }
    try args.world_state.add(.{
        .model = model,
        .tint = args.graphic.tint,
        .body_id = body_id,
        .wires = args.graphic.wires,
    });
    return body_id;
}

pub fn draw(game_world: *GameWorld, world_state: *WorldState) void {
    if (world_state.player) |p| {
        p.draw();
    }
    for (world_state.entities.items) |obj| {
        rl.gl.rlPushMatrix();
        defer rl.gl.rlPopMatrix();

        _applyBodyTransform(
            game_world.body_interface,
            obj.body_id,
        );

        obj.draw();
    }
}
