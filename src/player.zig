const std = @import("std");
const rl = @import("raylib");
const zphy = @import("zphysics");

const physic = @import("./physic.zig");
const vec3jtr = @import("./vec.zig").vec3jtr;
const shapes = @import("./shape.zig");
const game = @import("./game.zig");

const AppShape = @import("./shape.zig");
const UP_VECTOR = rl.Vector3{ .x = 0, .y = 1, .z = 0 };

pub const PlayerSetting = struct {
    physic_backend: *physic.Backend,
    height: f32 = 1.8,
    radius: f32 = 0.5,
    camera: rl.Camera3D,
    shader: ?rl.Shader,
};

pub const PlayerEntity = struct {
    character: *zphy.Character,
    headCamera: rl.Camera3D,
    enitity: game.Entity,
    firstPerson: bool = false,

    pub fn init(
        arg: PlayerSetting,
    ) anyerror!PlayerEntity {
        var characterSettings = try zphy.CharacterSettings.create();
        defer characterSettings.release();

        // 1. ตั้งค่าพื้นฐาน (Basic properties)
        characterSettings.layer = physic.object_layers.moving;
        characterSettings.mass = 10.0;
        characterSettings.friction = 0.5; // ปกติค่า friction จะอยู่ระหว่าง 0-1 (20.0 อาจจะหนืดเกินไป)
        characterSettings.gravity_factor = 1.0;

        // 2. ตั้งค่าการเคลื่อนที่และรูปร่าง (มักจะอยู่ในฟิลด์หลักหรือฟิลด์ที่สืบทอดมา)
        characterSettings.base.up = .{ 0, 1, 0, 0 };
        characterSettings.base.supporting_volume = .{ 0, -1, 0, 0.5 }; // Plane normal + constant
        characterSettings.base.max_slope_angle = 0.78; // ประมาณ 45 องศา (ในหน่วย Radians)
        characterSettings.base.shape = try shapes.cylinder_shape(arg.radius, arg.height);
        const character = try zphy.Character.create(
            characterSettings,
            .{ 0, 10, 0 },
            .{ 0, 0, 0, 1 },
            0,
            arg.physic_backend.physics_system,
        );

        character.addToPhysicsSystem(.{});

        const mesh = shapes.cylinder_mesh(arg.radius, arg.height, 12);
        const model = try rl.loadModelFromMesh(mesh);
        if (arg.shader) |shader| {
            model.materials[0].shader = shader;
        }

        const player = PlayerEntity{
            .character = character,
            .headCamera = arg.camera,
            .enitity = game.Entity{
                .model = model,
                .ref = .{ .character = character },
            },
        };
        return player;
    }

    pub fn update(self: *@This()) void {
        if (rl.isKeyPressed(.e)) { // switch camera
            self.firstPerson = !self.firstPerson;
        }
        if (rl.isKeyPressed(.space)) { // jump + jump on air
            const v = self.character.getLinearVelocity();
            self.character.setLinearVelocity(.{ v[0], 10, v[2] });
        }
        if (self.enitity.position()[1] < -100) { // fallout = restart
            self.character.setPosition(.{ 0, 5, 0 });
        }
        self._rotateHeadFromMouseInput();
        self._walkOnXZaxisFromKeyInput();
    }

    fn _getForwardVectorXZ(camera: *const rl.Camera) rl.Vector3 {
        const out = camera.target.subtract(camera.position);
        return rl.Vector3.init(out.x, 0, out.z).normalize();
    }

    fn _walkOnXZaxisFromKeyInput(self: @This()) void {
        const curr_v: rl.Vector3 = vec3jtr(self.character.getLinearVelocity());

        const dir_w_s: rl.Vector3 = _getForwardVectorXZ(&self.headCamera);
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

    fn _rotateHeadFromMouseInput(self: *@This()) void {
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
};
