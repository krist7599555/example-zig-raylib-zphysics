const std = @import("std");
const zphy = @import("zphysics");
const rl = @import("raylib");
const zm = @import("zmath");
const vec3 = @import("./vec.zig").vec3;
const vec4 = @import("./vec.zig").vec4;
const Vec2 = @Vector(2, f32);
const Vec3 = @Vector(3, f32);
const Vec4 = @Vector(4, f32);

// BEGIN -COPYCODE
// https://github.com/zig-gamedev/zig-gamedev/blob/main/samples/physics_test_wgpu/src/physics_test_wgpu.zig#L51

pub const object_layers = struct {
    pub const non_moving: zphy.ObjectLayer = 0;
    pub const moving: zphy.ObjectLayer = 1;
    pub const len: u32 = 2;
};

const broad_phase_layers = struct {
    const non_moving: zphy.BroadPhaseLayer = 0;
    const moving: zphy.BroadPhaseLayer = 1;
    const len: u32 = 2;
};

const BroadPhaseLayerInterface = extern struct {
    broad_phase_layer_interface: zphy.BroadPhaseLayerInterface = .init(@This()),
    object_to_broad_phase: [object_layers.len]zphy.BroadPhaseLayer = undefined,

    fn init() BroadPhaseLayerInterface {
        var object_to_broad_phase: [object_layers.len]zphy.BroadPhaseLayer = undefined;
        object_to_broad_phase[object_layers.non_moving] = broad_phase_layers.non_moving;
        object_to_broad_phase[object_layers.moving] = broad_phase_layers.moving;
        return .{ .object_to_broad_phase = object_to_broad_phase };
    }

    fn selfPtr(broad_phase_layer_interface: *zphy.BroadPhaseLayerInterface) *BroadPhaseLayerInterface {
        return @alignCast(@fieldParentPtr("broad_phase_layer_interface", broad_phase_layer_interface));
    }

    fn selfPtrConst(broad_phase_layer_interface: *const zphy.BroadPhaseLayerInterface) *const BroadPhaseLayerInterface {
        return @alignCast(@fieldParentPtr("broad_phase_layer_interface", broad_phase_layer_interface));
    }

    pub fn getNumBroadPhaseLayers(_: *const zphy.BroadPhaseLayerInterface) callconv(.c) u32 {
        return broad_phase_layers.len;
    }

    pub fn getBroadPhaseLayer(
        broad_phase_layer_interface: *const zphy.BroadPhaseLayerInterface,
        layer: zphy.ObjectLayer,
    ) callconv(.c) zphy.BroadPhaseLayer {
        return selfPtrConst(broad_phase_layer_interface).object_to_broad_phase[layer];
    }
};

const ObjectVsBroadPhaseLayerFilter = extern struct {
    object_vs_broad_phase_layer_filter: zphy.ObjectVsBroadPhaseLayerFilter = .init(@This()),

    pub fn shouldCollide(
        _: *const zphy.ObjectVsBroadPhaseLayerFilter,
        layer1: zphy.ObjectLayer,
        layer2: zphy.BroadPhaseLayer,
    ) callconv(.c) bool {
        return switch (layer1) {
            object_layers.non_moving => layer2 == broad_phase_layers.moving,
            object_layers.moving => true,
            else => unreachable,
        };
    }
};

const ObjectLayerPairFilter = extern struct {
    object_layer_pair_filter: zphy.ObjectLayerPairFilter = .init(@This()),

    pub fn shouldCollide(
        _: *const zphy.ObjectLayerPairFilter,
        object1: zphy.ObjectLayer,
        object2: zphy.ObjectLayer,
    ) callconv(.c) bool {
        return switch (object1) {
            object_layers.non_moving => object2 == object_layers.moving,
            object_layers.moving => true,
            else => unreachable,
        };
    }
};

const ContactListener = extern struct {
    contact_listener: zphy.ContactListener = .init(@This()),

    fn selfPtr(contact_listener: *zphy.ContactListener) *ContactListener {
        return @alignCast(@fieldParentPtr("contact_listener", contact_listener));
    }

    fn selfPtrConst(contact_listener: *const zphy.ContactListener) *const ContactListener {
        return @alignCast(@fieldParentPtr("contact_listener", contact_listener));
    }

    pub fn onContactValidate(
        contact_listener: *zphy.ContactListener,
        body1: *const zphy.Body,
        body2: *const zphy.Body,
        base_offset: *const [3]zphy.Real,
        collision_result: *const zphy.CollideShapeResult,
    ) callconv(.c) zphy.ValidateResult {
        _ = contact_listener;
        _ = body1;
        _ = body2;
        _ = base_offset;
        _ = collision_result;
        return .accept_all_contacts;
    }

    pub fn onContactAdded(
        contact_listener: *zphy.ContactListener,
        body1: *const zphy.Body,
        body2: *const zphy.Body,
        _: *const zphy.ContactManifold,
        _: *zphy.ContactSettings,
    ) callconv(.c) void {
        _ = contact_listener;
        _ = body1;
        _ = body2;
    }

    pub fn onContactPersisted(
        contact_listener: *zphy.ContactListener,
        body1: *const zphy.Body,
        body2: *const zphy.Body,
        _: *const zphy.ContactManifold,
        _: *zphy.ContactSettings,
    ) callconv(.c) void {
        _ = contact_listener;
        _ = body1;
        _ = body2;
    }

    pub fn onContactRemoved(
        contact_listener: *zphy.ContactListener,
        sub_shape_id_pair: *const zphy.SubShapeIdPair,
    ) callconv(.c) void {
        _ = contact_listener;
        _ = sub_shape_id_pair;
    }
};
// END copy

pub fn createPhysicsSystem(allocator: std.mem.Allocator) !*zphy.PhysicsSystem {
    const broad_phase_layer_interface = try allocator.create(BroadPhaseLayerInterface);
    broad_phase_layer_interface.* = BroadPhaseLayerInterface.init();

    const object_vs_broad_phase_layer_filter = try allocator.create(ObjectVsBroadPhaseLayerFilter);
    object_vs_broad_phase_layer_filter.* = .{};

    const object_layer_pair_filter = try allocator.create(ObjectLayerPairFilter);
    object_layer_pair_filter.* = .{};

    const contact_listener = try allocator.create(ContactListener);
    contact_listener.* = .{};

    const physics_system = try zphy.PhysicsSystem.create(
        @as(*const zphy.BroadPhaseLayerInterface, @ptrCast(broad_phase_layer_interface)),
        @as(*const zphy.ObjectVsBroadPhaseLayerFilter, @ptrCast(object_vs_broad_phase_layer_filter)),
        @as(*const zphy.ObjectLayerPairFilter, @ptrCast(object_layer_pair_filter)),
        .{
            .max_bodies = 1024,
            .num_body_mutexes = 0,
            .max_body_pairs = 1024,
            .max_contact_constraints = 1024,
        },
    );

    return physics_system;
}

// END Copy

// BEGIN My Own
const ZphysicsError = error{
    CreateBoxShapeSettingsError,
    CreateBoxShapeError,
};
pub fn createBoxShape(full_extent: Vec3) ZphysicsError!*zphy.Shape {
    const box_settings = zphy.BoxShapeSettings.create(.{
        full_extent[0] / 2.0,
        full_extent[1] / 2.0,
        full_extent[2] / 2.0,
    }) catch return ZphysicsError.CreateBoxShapeSettingsError;
    defer box_settings.asShapeSettings().release();
    const box_shape = box_settings
        .asShapeSettings()
        .createShape() catch return ZphysicsError.CreateBoxShapeError;
    errdefer box_shape.release();
    return box_shape;
}

pub fn getAxisInput(pos_key: rl.KeyboardKey, neg_key: rl.KeyboardKey) f32 {
    var val: f32 = 0;
    if (rl.isKeyDown(pos_key)) val += 1.0;
    if (rl.isKeyDown(neg_key)) val -= 1.0;
    return val;
}

pub fn rotateY(current_q: Vec4, by: f32) Vec4 {
    const dq = zm.quatFromAxisAngle(.{ 0, 1, 0, 0 }, by);
    const new_q = zm.qmul(dq, current_q); // Rotate around world Y
    return new_q;
}
