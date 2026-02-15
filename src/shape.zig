const zphy = @import("zphysics");
const rl = @import("raylib");
const Vec3 = @Vector(3, f32);
const Vec2 = @Vector(2, f32);

pub fn sphere_mesh(radius: f32, ring: i32, slide: i32) rl.Mesh {
    return rl.genMeshSphere(radius, ring, slide);
}
pub fn sphere_shape(radius: f32) !*zphy.Shape {
    const setting = try zphy.SphereShapeSettings.create(radius);
    return try setting.asShapeSettings().createShape();
}
pub fn box_mesh(size: Vec3) rl.Mesh {
    return rl.genMeshCube(size[0], size[1], size[2]);
}
pub fn box_shape(size: Vec3) !*zphy.Shape {
    const half_extents: [3]f32 = .{ size[0] * 0.5, size[1] * 0.5, size[2] * 0.5 };
    const settings = try zphy.BoxShapeSettings.create(half_extents);
    return try settings.asShapeSettings().createShape();
}
pub fn plane_mesh(size: Vec2, sub: @Vector(2, i32)) rl.Mesh {
    return rl.genMeshPlane(size[0], size[1], sub[0], sub[1]);
}
pub fn plane_shape(size: Vec2) !*zphy.Shape {
    const y_hight = 0.05;
    const settings = try zphy.BoxShapeSettings.create(.{ size[0] * 0.5, y_hight, size[1] * 0.5 });
    return try settings.asShapeSettings().createShape();
}

pub fn cylinder_mesh(radius: f32, height: f32, sub: i32) rl.Mesh {
    return rl.genMeshCylinder(radius, height, sub);
}
pub fn cylinder_shape(radius: f32, height: f32) !*zphy.Shape {
    const setting = try zphy.CylinderShapeSettings.create(height * 0.5, radius);
    return try setting.asShapeSettings().createShape();
}

pub fn capsule_mesh(radius: f32, height: f32, sub: i32) rl.Mesh {
    _ = radius;
    _ = height;
    _ = sub;
    @compileError("NOT IMPLEMENT");
}
pub fn capsule_shape(radius: f32, height: f32) !*zphy.Shape {
    const setting = try zphy.CapsuleShapeSettings.create(height * 0.5, radius);
    return try setting.asShapeSettings().createShape();
}
