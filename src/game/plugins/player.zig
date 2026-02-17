pub const PlayerPlugin = struct {
    pub fn build(self: @This(), app: *core.App) !void {
        _ = self;
        const render_targets = app.getResource(resources.RenderTargets).?;
        _ = try render_targets.loadRenderTexture("player", 64, 64);
        const assets_mgr = app.getResource(engine.assets.AssetManager).?;

        const loco_animset = blk: {
            const val = assets_mgr.configValuePath(
                "animations",
                &.{ "locomotion", "greenman" },
            ).?;
            break :blk try json.parseFromValue(comps.LocomotionAnimSet, app.gpa, val, .{});
        };
        defer loco_animset.deinit();

        const player = try app.world.spawn(.{
            comps.Player{ .id = 1, .just_spawned = true, .spawn_id = 0 },
            comps.Position{ .x = 70, .y = 70, .prev_x = 70, .prev_y = 70 },
            comps.Velocity{ .x = 0, .y = 0 },
            comps.ColliderCircle{ .radius = 16.0, .mask = 1 },
            comps.Rotation{ .teta = 0, .prev_teta = 0, .target_teta = 0, .turn_speed_deg = 360.0 * 3 },
            comps.Model3D{ .name = "greenman", .render_texture = 0, .mesh = 0, .material = 1 },
            comps.RenderInto{ .into = "player" },
            comps.Animation{ .index = 0, .frame = 0, .acc = 0, .speed = 0 },
            loco_animset.value,
            comps.LocomotionAnimState{ .moving = false },
            comps.Room.init("level1"),
        });
        _ = try app.insertResource(resources.Player, .{ .entity = player });

        try app.addSystem(.update, PlayerInputSystem);
        try app.addSystem(.fixed_update, PlayerSpawnSystem);
    }
};

const PlayerInputSystem = struct {
    pub const provides: []const []const u8 = &.{"input"};

    pub fn run(app: *core.App) !void {
        const world = &app.world;
        const player = app.getResource(resources.Player).?.entity;
        const vel = world.get(comps.VelocityView, player).?;
        const rot = world.get(comps.RotationView, player).?;
        var x: f32 = 0;
        var y: f32 = 0;

        if (app.getResource(resources.ScreenFade)) |fade| {
            if (fade.active()) {
                vel.x.* = 0;
                vel.y.* = 0;
                return;
            }
        }

        if (rl.IsKeyDown(rl.KEY_D)) {
            x = 10;
        } else if (rl.IsKeyDown(rl.KEY_A)) {
            x = -10;
        }
        if (rl.IsKeyDown(rl.KEY_W)) {
            y = -10;
        } else if (rl.IsKeyDown(rl.KEY_S)) {
            y = 10;
        }

        if (rl.IsGamepadAvailable(0)) {
            var gx = rl.GetGamepadAxisMovement(0, rl.GAMEPAD_AXIS_LEFT_X);
            var gy = rl.GetGamepadAxisMovement(0, rl.GAMEPAD_AXIS_LEFT_Y);
            const deadzone: f32 = 0.2;
            if (@abs(gx) < deadzone) gx = 0;
            if (@abs(gy) < deadzone) gy = 0;

            if (rl.IsGamepadButtonDown(0, rl.GAMEPAD_BUTTON_LEFT_FACE_LEFT)) gx = -1;
            if (rl.IsGamepadButtonDown(0, rl.GAMEPAD_BUTTON_LEFT_FACE_RIGHT)) gx = 1;
            if (rl.IsGamepadButtonDown(0, rl.GAMEPAD_BUTTON_LEFT_FACE_UP)) gy = -1;
            if (rl.IsGamepadButtonDown(0, rl.GAMEPAD_BUTTON_LEFT_FACE_DOWN)) gy = 1;

            if (@abs(gx) > 0 or @abs(gy) > 0) {
                x = gx;
                y = gy;
            }
        }

        const l = std.math.sqrt(x * x + y * y);
        if (l > 0.1) {
            x = x / l * 250.0;
            y = y / l * 250.0;

            const angle = std.math.atan2(y, -x);
            rot.target_teta.* = std.math.radiansToDegrees(angle) - 45.0;
        }
        vel.x.* = x;
        vel.y.* = y;
    }
};

const PlayerSpawnSystem = struct {
    pub const provides: []const []const u8 = &.{"spawn"};
    pub const after_all_labels: []const []const u8 = &.{"teleport"};

    pub fn run(app: *core.App) !void {
        var it_player = app.world.query(&[_]type{
            comps.Player,
            comps.Position,
            comps.Rotation,
            comps.Room,
        });
        while (it_player.next()) |_| {
            const pos = it_player.get(comps.PositionView);
            const rot = it_player.get(comps.RotationView);
            const player = it_player.get(comps.PlayerView);
            const room = it_player.get(comps.RoomView);
            if (!player.just_spawned.*) continue;

            const desired_spawn_id = player.spawn_id.*;
            var best_fallback_id: ?u8 = null;
            var best_fallback_x: f32 = 0;
            var best_fallback_y: f32 = 0;
            var found_x: f32 = 0;
            var found_y: f32 = 0;
            var found = false;

            var it_spawn = app.world.query(&[_]type{ comps.SpawnPoint, comps.Position, comps.Room });
            while (it_spawn.next()) |_| {
                const sp = it_spawn.get(comps.SpawnPointView);
                const sp_pos = it_spawn.get(comps.PositionView);
                const sp_room = it_spawn.get(comps.RoomView);
                if (sp_room.id.* != room.id.*) continue;

                // Deterministic fallback: choose the lowest spawn id in the room.
                if (best_fallback_id == null or sp.id.* < best_fallback_id.?) {
                    best_fallback_id = sp.id.*;
                    best_fallback_x = sp_pos.x.*;
                    best_fallback_y = sp_pos.y.*;
                }

                if (desired_spawn_id != 0 and sp.id.* == desired_spawn_id) {
                    found_x = sp_pos.x.*;
                    found_y = sp_pos.y.*;
                    found = true;
                    break;
                }
            }

            const x = if (found) found_x else if (best_fallback_id != null) best_fallback_x else pos.x.*;
            const y = if (found) found_y else if (best_fallback_id != null) best_fallback_y else pos.y.*;

            rot.teta.* = 45;
            rot.target_teta.* = 45;
            pos.x.* = x;
            pos.y.* = y;
            pos.prev_x.* = x;
            pos.prev_y.* = y;
            player.just_spawned.* = false;
            player.spawn_id.* = 0;
        }
    }
};

const std = @import("std");
const json = std.json;

const engine = @import("engine");
const core = engine.core;
const rl = engine.rl;
const xmath = engine.math;
const ecs = engine.ecs;

const comps = @import("../components.zig");
const resources = @import("../resources.zig");
