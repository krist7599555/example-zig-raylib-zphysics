const std = @import("std");
const rl = @import("raylib");
const zphy = @import("zphysics");
const zm = @import("zmath");
const znoise = @import("znoise");
const Jolt = @import("./jolt.zig");
const splat = @import("./vec.zig").splat;
const vec3 = @import("./vec.zig").vec3;
const vec4 = @import("./vec.zig").vec4;
const vec3jtr = @import("./vec.zig").vec3jtr;
const Vec2 = @Vector(2, f32);
const Vec3 = @Vector(3, f32);
const Vec4 = @Vector(4, f32);

const upVector = rl.Vector3{ .x = 0, .y = 1, .z = 0 };

pub const Player = struct {
    height: f32,
    radius: f32,
    halfHeight: f32,
    character: *zphy.Character,
    headCamera: *rl.Camera3D,
    firstPerson: bool = false,

    pub fn init(joltWrapper: *Jolt.JoltWrapper, inCamera: *rl.Camera3D) anyerror!Player {
        const height = 1.8;
        const radius = 0.25;
        const halfHeight = (height / 2.0) - radius;
        const capsuleSettings = try zphy.CapsuleShapeSettings.create(radius, halfHeight);
        defer capsuleSettings.release();
        const capsuleShape = try capsuleSettings.createShape();
        defer capsuleShape.release();

        const characterSettings = try zphy.CharacterSettings.create();
        defer characterSettings.release();
        characterSettings.base = .{
            .up = .{ 0, 1, 0, 0 },
            .supporting_volume = .{ 0, -1, 0, 0 },
            .max_slope_angle = 0.78,
            .shape = capsuleShape,
        };
        characterSettings.layer = Jolt.object_layers.moving;
        characterSettings.mass = 10.0;
        characterSettings.friction = 20.0;
        characterSettings.gravity_factor = 1.0;

        const character = try zphy.Character.create(characterSettings, .{ 0, 1, 0 }, .{ 0, 0, 0, 1 }, 0, joltWrapper.physics_system);
        character.addToPhysicsSystem(.{});

        return Player{ .character = character, .headCamera = inCamera, .height = height, .radius = radius, .halfHeight = halfHeight };
    }

    pub fn process(self: *Player) void {
        if (rl.IsKeyPressed(rl.KeyboardKey.KEY_W)) {
            self.firstPerson = !self.firstPerson;
        }
        self.moveHead();
        self.walk();
    }

    pub fn walk(self: *Player) void {
        const linVel = vec3jtr(self.character.getLinearVelocity());
        var linVelHorizontal = linVel;
        linVelHorizontal.y = 0;
        var forward = self.headCamera.target.sub(self.headCamera.position);
        forward.y = 0;
        forward = forward.normalize();
        // const forward = rl.Vector3Project(self.headCamera.target.sub(self.headCamera.position), upVector).normalize();
        const perp = rl.Vector3CrossProduct(forward, upVector).normalize();

        var desiredHorizontal = rl.Vector3Zero();
        if (rl.IsKeyDown(rl.KeyboardKey.KEY_E)) {
            desiredHorizontal = desiredHorizontal.add(forward);
        }
        if (rl.IsKeyDown(rl.KeyboardKey.KEY_D)) {
            desiredHorizontal = desiredHorizontal.sub(forward);
        }
        if (rl.IsKeyDown(rl.KeyboardKey.KEY_F)) {
            desiredHorizontal = desiredHorizontal.add(perp);
        }
        if (rl.IsKeyDown(rl.KeyboardKey.KEY_S)) {
            desiredHorizontal = desiredHorizontal.sub(perp);
        }
        desiredHorizontal = desiredHorizontal.normalize().scale(5);

        if (linVelHorizontal.length() < desiredHorizontal.length()) {
            self.character.setLinearVelocity(.{ desiredHorizontal.x, linVel.y, desiredHorizontal.z });
        }
    }

    pub fn moveHead(self: *Player) void {
        const mouseDelta = rl.GetMouseDelta();
        var arm = self.headCamera.target.sub(self.headCamera.position);
        arm = rl.Vector3RotateByAxisAngle(arm, .{ .y = 1 }, -mouseDelta.x / 100);

        const perp = rl.Vector3CrossProduct(arm, upVector).normalize();
        arm = rl.Vector3RotateByAxisAngle(arm, perp, -mouseDelta.y / 100);

        const position = self.character.getPosition();
        self.headCamera.target = vec3jtr(position);
        self.headCamera.position = self.headCamera.target.sub(arm);

        if (self.firstPerson) {
            var target = self.headCamera.target;
            target.y += 0.8;
            self.headCamera.position = target;
            self.headCamera.target = target.add(arm);
            self.headCamera.fovy = 80;
        } else {
            self.headCamera.fovy = 55;
        }
    }

    pub fn drawWires(self: *Player, joltWrapper: *Jolt.JoltWrapper) void {
        _ = joltWrapper;
        const position = self.character.getPosition();
        if (!self.firstPerson) {
            rl.DrawCapsuleWires(rl.Vector3{
                .x = position[0],
                .y = position[1] - self.halfHeight + self.radius,
                .z = position[2],
            }, rl.Vector3{
                .x = position[0],
                .y = position[1] + self.halfHeight - self.radius,
                .z = position[2],
            }, self.radius * 2, 8, 4, rl.Color.white);
        }
    }
};
