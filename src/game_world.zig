const std = @import("std");
const rl = @import("raylib");
const zphy = @import("zphysics");

pub const GameObject = struct {
    model: rl.Model,
    tint: rl.Color = rl.Color.white,
    body_id: zphy.BodyId,
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
            const pos = self.body_interface.getPosition(obj.body_id);

            rl.gl.rlPushMatrix();
            defer rl.gl.rlPopMatrix();

            rl.gl.rlTranslatef(pos[0], pos[1], pos[2]);

            rl.drawModel(
                obj.model,
                rl.Vector3.zero(),
                1.0,
                obj.tint,
            );
            rl.drawModelWires(
                obj.model,
                rl.Vector3.zero(),
                1.0,
                .white,
            );
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

        const tint = if (@hasField(@TypeOf(args), "tint")) args.tint else rl.Color.white;

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

        try game.game_objects.append(game.allocator, .{
            .model = try rl.loadModelFromMesh(mesh),
            .tint = tint,
            .body_id = body_id,
        });

        return body_id;
    }
};
