const zphy = @import("zphysics");
const rl = @import("raylib");

pub fn ShapeObject(comptime config: anytype) type {
    return struct {
        const Self = @This();
        const InputType = config.input;

        // The actual data stored in the instance
        data: InputType,

        pub fn init(args: InputType) Self {
            return .{ .data = args };
        }

        // We expose the logic so the 'create' function can call them
        pub fn generateMesh(self: Self) rl.Mesh {
            return config.for_raylib(self.data);
        }

        pub fn generateJolt(self: Self) !*zphy.Shape {
            return try config.for_jolt(self.data);
        }
    };
}

pub const SphereShape = ShapeObject(.{
    .input = struct { radius: f32, sub: @Vector(2, i32) = .{ 10, 10 } },

    .for_raylib = struct {
        fn func(input: anytype) rl.Mesh {
            // Unpack vector: sub[0] is rings (x), sub[1] is slices (y)
            return rl.genMeshSphere(input.radius, input.sub[0], input.sub[1]);
        }
    }.func,

    .for_jolt = struct {
        fn func(input: anytype) !*zphy.Shape {
            const setting = try zphy.SphereShapeSettings.create(input.radius);
            const shape = try setting.asShapeSettings().createShape();
            return shape;
        }
    }.func,
});

pub const BoxShape = ShapeObject(.{
    .input = struct { size: @Vector(3, f32) },

    .for_raylib = struct {
        fn func(input: anytype) rl.Mesh {
            // Unpack vector for raylib: x, y, z
            return rl.genMeshCube(input.size[0], input.size[1], input.size[2]);
        }
    }.func,

    .for_jolt = struct {
        fn func(input: anytype) !*zphy.Shape {
            // Jolt takes half-extents: size / 2
            const half_extents = input.size / @as(@Vector(3, f32), @splat(2.0));
            const settings = try zphy.BoxShapeSettings.create(half_extents);
            return try settings.asShapeSettings().createShape();
        }
    }.func,
});

pub const PlaneShape = ShapeObject(.{
    .input = struct {
        size: @Vector(2, f32),
        sub: @Vector(2, i32) = .{ 10, 10 }, // Default subdivisions
    },

    .for_raylib = struct {
        fn func(input: anytype) rl.Mesh {
            return rl.genMeshPlane(input.size[0], input.size[1], input.sub[0], input.sub[1]);
        }
    }.func,

    .for_jolt = struct {
        fn func(input: anytype) !*zphy.Shape {
            // Using a thin box for the physics floor
            const half_width = input.size[0] / 2.0;
            const half_length = input.size[1] / 2.0;
            const settings = try zphy.BoxShapeSettings.create(.{ half_width, 0.05, half_length });
            return try settings.asShapeSettings().createShape();
        }
    }.func,
});
