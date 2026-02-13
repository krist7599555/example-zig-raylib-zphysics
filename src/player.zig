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
        const capsuleShape = try capsuleSettings.asShapeSettings().createShape();
        // _ = capsuleShape;
        var characterSettings = try zphy.CharacterSettings.create();
        defer characterSettings.release();

        // 1. ตั้งค่าพื้นฐาน (Basic properties)
        characterSettings.layer = Jolt.object_layers.moving;
        characterSettings.mass = 10.0;
        characterSettings.friction = 0.5; // ปกติค่า friction จะอยู่ระหว่าง 0-1 (20.0 อาจจะหนืดเกินไป)
        characterSettings.gravity_factor = 1.0;

        // 2. ตั้งค่าการเคลื่อนที่และรูปร่าง (มักจะอยู่ในฟิลด์หลักหรือฟิลด์ที่สืบทอดมา)
        characterSettings.base.up = .{ 0, 1, 0, 0 };
        characterSettings.base.supporting_volume = .{ 0, -1, 0, 0.5 }; // Plane normal + constant
        characterSettings.base.max_slope_angle = 0.78; // ประมาณ 45 องศา (ในหน่วย Radians)
        characterSettings.base.shape = capsuleShape;

        const character = try zphy.Character.create(
            characterSettings,
            .{ 0, 1, 0 },
            .{ 0, 0, 0, 1 },
            0,
            joltWrapper.physics_system,
        );
        character.addToPhysicsSystem(.{});

        return Player{
            .character = character,
            .headCamera = inCamera,
            .height = height,
            .radius = radius,
            .halfHeight = halfHeight,
        };
    }

    pub fn process(self: *Player) void {
        if (rl.isKeyPressed(.e)) {
            self.firstPerson = !self.firstPerson;
        }
        self.moveHead();
        self.walk();
    }

    pub fn walk(self: *Player) void {
        const linVel = vec3jtr(self.character.getLinearVelocity());
        var linVelHorizontal = linVel;
        linVelHorizontal.y = 0;
        var forward = self.headCamera.target.subtract(self.headCamera.position);
        forward.y = 0;
        forward = forward.normalize();
        // const forward = rl.Vector3Project(self.headCamera.target.sub(self.headCamera.position), upVector).normalize();
        const perp = forward.crossProduct(upVector).normalize();

        var desiredHorizontal = rl.Vector3.zero();
        if (rl.isKeyDown(.w)) {
            desiredHorizontal = desiredHorizontal.add(forward);
        }
        if (rl.isKeyDown(.s)) {
            desiredHorizontal = desiredHorizontal.subtract(forward);
        }
        if (rl.isKeyDown(.d)) {
            desiredHorizontal = desiredHorizontal.add(perp);
        }
        if (rl.isKeyDown(.a)) {
            desiredHorizontal = desiredHorizontal.subtract(perp);
        }
        desiredHorizontal = desiredHorizontal.normalize().scale(5);

        if (linVelHorizontal.length() < desiredHorizontal.length()) {
            self.character.setLinearVelocity(.{ desiredHorizontal.x, linVel.y, desiredHorizontal.z });
        }
    }

    pub fn moveHead(self: *Player) void {
        const mouseDelta = rl.getMouseDelta();
        var arm = self.headCamera.target.subtract(self.headCamera.position);
        arm = arm.rotateByAxisAngle(rl.Vector3.init(0, 1, 0), -mouseDelta.x / 100);

        const perp = arm.crossProduct(upVector).normalize();
        arm = arm.rotateByAxisAngle(perp, -mouseDelta.y / 100);

        const position = self.character.getPosition();
        self.headCamera.target = vec3jtr(position);
        self.headCamera.position = self.headCamera.target.subtract(arm);

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
            rl.drawCapsuleWires(
                rl.Vector3{
                    .x = position[0],
                    .y = position[1] - self.halfHeight + self.radius,
                    .z = position[2],
                },
                rl.Vector3{
                    .x = position[0],
                    .y = position[1] + self.halfHeight - self.radius,
                    .z = position[2],
                },
                self.radius * 2,
                8,
                4,
                rl.Color.white,
            );
        }
    }
};
