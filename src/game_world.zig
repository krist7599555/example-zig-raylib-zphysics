const std = @import("std");
const rl = @import("raylib");
const zphy = @import("zphysics");
const Util = @import("./util.zig");
const Player = @import("./player.zig").Player;
const Jolt = @import("./jolt.zig");

const DIFFUSE_IDX: usize = @as(usize, @intFromEnum(rl.MATERIAL_MAP_DIFFUSE));

pub const GameObject = struct {
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

pub const CreateBodyArg = struct {
    graphic: struct {
        mesh: rl.Mesh,
        shader: ?rl.Shader = null,
        tint: rl.Color = .white,
        wires: ?rl.Color = null,
    },
    physic: zphy.BodyCreationSettings,
};

pub const GameWorld = struct {
    game_objects: std.ArrayList(GameObject),
    body_interface: *zphy.BodyInterface,
    physics_system: *zphy.PhysicsSystem,
    allocator: std.mem.Allocator,
    player: ?Player = null,
    pub fn init(allocator: std.mem.Allocator, jolt_wrapper: *Jolt.JoltWrapper) !GameWorld {
        return GameWorld{
            .game_objects = try std.ArrayList(GameObject).initCapacity(allocator, 0),
            .body_interface = jolt_wrapper.physics_system.getBodyInterfaceMut(),
            .physics_system = jolt_wrapper.physics_system,
            .allocator = allocator,
        };
    }
    pub fn deinit(self: *@This()) void {
        self.game_objects.deinit(self.allocator);
    }

    pub fn draw(self: *@This()) void {
        if (self.player) |p| {
            p.draw();
        }
        for (self.game_objects.items) |obj| {
            rl.gl.rlPushMatrix();
            defer rl.gl.rlPopMatrix();

            _applyBodyTransform(self.body_interface, obj.body_id);

            obj.draw();
        }
    }

    pub fn createBody(game: *@This(), args_: CreateBodyArg) !zphy.BodyId {
        var args = args_;
        args.physic.object_layer = switch (args.physic.motion_type) {
            .static => @import("./jolt.zig").object_layers.non_moving,
            .dynamic, .kinematic => @import("./jolt.zig").object_layers.moving,
        };
        if (args.physic.shape == null) return rl.RaylibError.LoadModel;

        const body_id = try game.body_interface.createAndAddBody(args.physic, .activate);

        var model = try rl.loadModelFromMesh(args.graphic.mesh);
        if (args.graphic.shader) |shader| {
            model.materials[0].shader = shader;
        }
        try game.game_objects.append(game.allocator, .{
            .model = model,
            .tint = args.graphic.tint,
            .body_id = body_id,
            .wires = args.graphic.wires,
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
