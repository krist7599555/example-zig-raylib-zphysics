const zphy = @import("zphysics");
const rl = @import("raylib");

pub const ShapeOut = struct {
    // - Mesh: ตัวละคร 20k vertices (for draw)
    mesh: rl.Mesh,
    // - Shape: Capsule เดียวจบ (simple for calculate phyic)
    shape: *zphy.Shape,
};

pub fn calc(obj: anytype) !ShapeOut {
    return obj.calc();
}

pub const Sphere = struct {
    radius: f32,
    sub: @Vector(2, i32) = .{ 10, 10 },

    pub fn mesh(self: *const @This()) rl.Mesh {
        return rl.genMeshSphere(self.radius, self.sub[0], self.sub[1]);
    }
    pub fn shape(self: *const @This()) !*zphy.Shape {
        const setting = try zphy.SphereShapeSettings.create(self.radius);
        return try setting.asShapeSettings().createShape();
    }
    pub fn calc(self: *const @This()) !ShapeOut {
        return .{ .mesh = self.mesh(), .shape = try self.shape() };
    }
};

pub const Box = struct {
    size: @Vector(3, f32),

    pub fn mesh(self: *const @This()) rl.Mesh {
        return rl.genMeshCube(self.size[0], self.size[1], self.size[2]);
    }
    pub fn shape(self: *const @This()) !*zphy.Shape {
        // Jolt takes half-extents: size / 2
        const half_extents = self.size * @Vector(3, f32){ 0.5, 0.5, 0.5 };
        const settings = try zphy.BoxShapeSettings.create(half_extents);
        return try settings.asShapeSettings().createShape();
    }
    pub fn calc(self: *const @This()) !ShapeOut {
        return .{ .mesh = self.mesh(), .shape = try self.shape() };
    }
};

pub const Plane = struct {
    size: @Vector(2, f32),
    sub: @Vector(2, i32) = .{ 10, 10 }, // Default subdivisions

    pub fn mesh(self: *const @This()) rl.Mesh {
        return rl.genMeshPlane(self.size[0], self.size[1], self.sub[0], self.sub[1]);
    }
    pub fn shape(self: *const @This()) !*zphy.Shape {
        const mini_height = 0.05;
        const half_width = self.size[0] / 2.0;
        const half_length = self.size[1] / 2.0;
        const settings = try zphy.BoxShapeSettings.create(.{ half_width, mini_height, half_length });
        return try settings.asShapeSettings().createShape();
    }
    pub fn calc(self: *const @This()) !ShapeOut {
        return .{ .mesh = self.mesh(), .shape = try self.shape() };
    }
};

pub const Cylinder = struct {
    radius: f32,
    height: f32, // ครึ่งความสูง
    sub: i32 = 16, // radial, height

    /// สำหรับ render
    pub fn mesh(self: *const @This()) rl.Mesh {
        // raylib ใช้ height เต็ม
        return rl.genMeshCylinder(
            self.radius,
            self.height,
            self.sub,
        );
    }

    /// สำหรับ physics
    pub fn shape(self: *const @This()) !*zphy.Shape {
        const setting = try zphy.CylinderShapeSettings.create(
            self.height * 0.5,
            self.radius,
        );
        return try setting.asShapeSettings().createShape();
    }

    pub fn calc(self: *const @This()) !ShapeOut {
        return .{
            .mesh = self.mesh(),
            .shape = try self.shape(),
        };
    }
};

pub const Capsule = struct {
    radius: f32,
    height: f32,
    sub: i32 = 16,

    pub fn mesh(self: *const @This()) rl.Mesh {
        return rl.genMeshCylinder(self.radius, self.height, self.sub);
    }
    pub fn shape(self: *const @This()) !*zphy.Shape {
        const setting = try zphy.CapsuleShapeSettings.create(self.height * 0.5, self.radius);
        return try setting.asShapeSettings().createShape();
    }
    pub fn calc(self: *const @This()) !ShapeOut {
        return .{ .mesh = self.mesh(), .shape = try self.shape() };
    }
};
