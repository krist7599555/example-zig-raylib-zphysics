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
    pub fn init(allocator: std.mem.Allocator) !GameWorld {
        return GameWorld{
            .game_objects = try std.ArrayList(GameObject).initCapacity(allocator, 0),
        };
    }
    pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
        self.game_objects.deinit(allocator);
    }
};

// pub var game_world: ?GameWorld = null;
