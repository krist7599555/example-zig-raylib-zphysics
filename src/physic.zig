const std = @import("std");
const zphy = @import("zphysics");
const rl = @import("raylib");
const physic = @import("./physic.zig");
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

pub const Backend = struct {
    pub const ObjectLayer = object_layers;

    broad_phase_layer_interface: *BroadPhaseLayerInterface,
    object_vs_broad_phase_layer_filter: *ObjectVsBroadPhaseLayerFilter,
    object_layer_pair_filter: *ObjectLayerPairFilter,
    contact_listener: *ContactListener,
    physics_system: *zphy.PhysicsSystem,

    pub fn init(allocator: std.mem.Allocator) !*Backend {
        try zphy.init(allocator, .{});

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

        const wrapper = try allocator.create(Backend);
        wrapper.* = .{
            .broad_phase_layer_interface = broad_phase_layer_interface,
            .object_vs_broad_phase_layer_filter = object_vs_broad_phase_layer_filter,
            .object_layer_pair_filter = object_layer_pair_filter,
            .contact_listener = contact_listener,
            .physics_system = physics_system,
        };

        return wrapper;
    }

    pub fn destroy(self: *Backend, allocator: std.mem.Allocator) void {
        self.physics_system.destroy();
        allocator.destroy(self.contact_listener);
        allocator.destroy(self.object_vs_broad_phase_layer_filter);
        allocator.destroy(self.object_layer_pair_filter);
        allocator.destroy(self.broad_phase_layer_interface);
        zphy.deinit();
        allocator.destroy(self);
    }

    pub fn update(self: *Backend, dt: f32) void {
        self.physics_system.update(dt, .{}) catch unreachable;
    }

    // Halper

    pub fn add(self: *Backend, arg_: zphy.BodyCreationSettings) !zphy.BodyId {
        var arg = arg_;
        arg.object_layer = switch (arg.motion_type) {
            .static => physic.object_layers.non_moving,
            .dynamic, .kinematic => physic.object_layers.moving,
        };
        return try self.physics_system
            .getBodyInterfaceMut()
            .createAndAddBody(arg, .activate);
    }
};
