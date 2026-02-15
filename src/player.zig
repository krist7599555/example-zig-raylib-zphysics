const std = @import("std");
const rl = @import("raylib");
const zphy = @import("zphysics");

const Jolt = @import("./jolt.zig");
const splat = @import("./vec.zig").splat;
const vec3 = @import("./vec.zig").vec3;
const vec4 = @import("./vec.zig").vec4;
const vec3jtr = @import("./vec.zig").vec3jtr;
const Vec2 = @Vector(2, f32);
const Vec3 = @Vector(3, f32);
const Vec4 = @Vector(4, f32);
const GameWorld = @import("./game_world.zig").GameWorld;

const AppShape = @import("./shape.zig");
const UP_VECTOR = rl.Vector3{ .x = 0, .y = 1, .z = 0 };

pub const PlayerSetting = struct {
    game: *GameWorld,
    height: f32 = 1.8,
    radius: f32 = 0.5,
    camera: rl.Camera3D,
    shader: ?rl.Shader,
};

pub const Player = struct {
    character: *zphy.Character,
    headCamera: rl.Camera3D,
    firstPerson: bool = false,

    model: rl.Model,

    height: f32,
    radius: f32,

    pub fn init(
        arg: PlayerSetting,
    ) anyerror!Player {
        const shape = try AppShape.calc(AppShape.Cylinder{
            .height = arg.height,
            .radius = arg.radius,
        });

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
        characterSettings.base.shape = shape.shape;

        const character = try zphy.Character.create(
            characterSettings,
            .{ 0, 10, 0 },
            .{ 0, 0, 0, 1 },
            0,
            arg.game.physics_system,
        );

        character.addToPhysicsSystem(.{});

        const model = try rl.Model.fromMesh(shape.mesh);
        if (arg.shader) |shader| {
            model.materials[0].shader = shader;
        }

        const player = Player{
            .height = arg.height,
            .radius = arg.radius,
            .character = character,
            .headCamera = arg.camera,
            .model = model,
        };
        arg.game.player = player;
        return player;
    }

    pub fn update(self: *Player) void {
        if (rl.isKeyPressed(.e)) {
            self.firstPerson = !self.firstPerson;
        }
        self.rotateHeadFromMouseInput();
        self.walkOnXZaxisFromKeyInput();
    }

    pub fn getForwardVectorXZ(camera: *const rl.Camera) rl.Vector3 {
        const out = camera.target.subtract(camera.position);
        return rl.Vector3.init(out.x, 0, out.z).normalize();
    }

    pub fn walkOnXZaxisFromKeyInput(self: *Player) void {
        const curr_v: rl.Vector3 = vec3jtr(self.character.getLinearVelocity());

        const dir_w_s: rl.Vector3 = getForwardVectorXZ(&self.headCamera);
        const dir_d_a: rl.Vector3 = dir_w_s.crossProduct(UP_VECTOR).normalize();

        const new_v_xz = blk: {
            var res = rl.Vector3.zero();
            if (rl.isKeyDown(.w)) res = res.add(dir_w_s);
            if (rl.isKeyDown(.s)) res = res.subtract(dir_w_s);
            if (rl.isKeyDown(.d)) res = res.add(dir_d_a);
            if (rl.isKeyDown(.a)) res = res.subtract(dir_d_a);
            break :blk res.normalize().scale(5);
        };

        var curr_v_xz = rl.Vector3.init(curr_v.x, 0, curr_v.z);
        if (curr_v_xz.length() < new_v_xz.length()) {
            self.character.setLinearVelocity(.{ new_v_xz.x, curr_v.y, new_v_xz.z });
        }
    }

    pub fn rotateHeadFromMouseInput(self: *Player) void {
        const d = rl.getMouseDelta();

        const curr_arm = self.headCamera.target.subtract(self.headCamera.position); // x_vector
        const z_vector = curr_arm.crossProduct(UP_VECTOR).normalize();
        const new_arm = curr_arm
            .rotateByAxisAngle(UP_VECTOR, -d.x / 100) // rotate(y) = left-right
            .rotateByAxisAngle(z_vector, -d.y / 100); // rotate(z) = up-down

        const position = self.character.getPosition();

        if (self.firstPerson) {
            var target = vec3jtr(position);
            target.y += 0.8; // eye should be on head, not center of body
            self.headCamera.fovy = 80;
            self.headCamera.position = target;
            self.headCamera.target = target.add(new_arm);
        } else {
            self.headCamera.fovy = 55;
            self.headCamera.target = vec3jtr(position);
            self.headCamera.position = vec3jtr(position).subtract(new_arm);
        }
    }

    pub fn draw(self: *const Player) void {
        if (self.firstPerson) return; // if first person - not draw
        const position = self.character.getPosition();
        self.model.draw(rl.Vector3.init(position[0], position[1] - self.height * 0.5, position[2]), 1.0, .white);
    }
};
