pub const FadeSystem = struct {
    pub const id = "fade.system";
    pub const provides: []const []const u8 = &.{"teleport"};
    pub const after_ids_optional: []const []const u8 = &.{"door.system"};
    pub const after_all_labels: []const []const u8 = &.{"physics"};

    pub fn run(app: *core.App) !void {
        const time = app.getResource(core.Time).?;
        const fade = app.getResource(resources.ScreenFade).?;

        switch (fade.state) {
            .idle => fade.alpha = 0,
            .fading_out => {
                const out_dur = @max(fade.out_duration, 0.001);
                fade.t += time.dt;
                fade.alpha = std.math.clamp(fade.t / out_dur, 0, 1);
                if (fade.alpha >= 1) {
                    if (fade.pending) |p| {
                        commitTeleport(app, p);
                    }
                    fade.pending = null;
                    fade.state = .hold_black;
                    fade.t = 0;
                    fade.alpha = 1;
                }
            },
            .hold_black => {
                fade.alpha = 1;
                fade.t += time.dt;
                if (fade.t >= fade.hold_duration) {
                    fade.state = .fading_in;
                    fade.t = 0;
                }
            },
            .fading_in => {
                const in_dur = @max(fade.in_duration, 0.001);
                fade.t += time.dt;
                const k = std.math.clamp(fade.t / in_dur, 0, 1);
                fade.alpha = 1 - k;
                if (k >= 1) {
                    fade.state = .idle;
                    fade.t = 0;
                    fade.alpha = 0;
                }
            },
        }
    }

    fn commitTeleport(app: *core.App, p: resources.ScreenFade.Pending) void {
        const room_mgr = app.getResource(level_resources.RoomManager).?;
        const player_entity = app.getResource(player_resources.Player).?.entity;

        if (app.world.get(world.RoomView, player_entity)) |room| {
            room.id.* = p.room_id;
            room_mgr.current = p.room_id;
        }
        if (app.world.get(player.PlayerView, player_entity)) |pl| {
            pl.just_spawned.* = true;
            pl.spawn_id.* = p.spawn_id;
        }
        if (app.world.get(transform.VelocityView, player_entity)) |vel| {
            vel.x.* = 0;
            vel.y.* = 0;
        }
    }
};

pub const FadeOverlaySystem = struct {
    pub const id = "fade.overlay";
    pub const provides: []const []const u8 = &.{render.LabelRenderOverlay};
    pub const after_all_labels: []const []const u8 = &.{render.LabelRenderEndMode2D};

    pub fn run(app: *core.App) !void {
        const fade = app.getResource(resources.ScreenFade).?;
        if (fade.alpha <= 0) return;

        const screen = app.getResource(core_resources.Screen).?;
        const a: u8 = @intFromFloat(std.math.clamp(fade.alpha, 0, 1) * 255.0);
        rl.DrawRectangle(
            0,
            0,
            @intCast(screen.width),
            @intCast(screen.height),
            rl.Color{ .r = 0, .g = 0, .b = 0, .a = a },
        );
    }
};

const std = @import("std");

const engine = @import("engine");
const core = engine.core;
const rl = engine.raylib;

const game = @import("game");
const resources = game.plugins.fade.resources;
const core_resources = game.plugins.core.resources;
const level_resources = game.plugins.level.resources;
const player_resources = game.plugins.player.resources;
const render = game.plugins.render;
const player = game.components.player;
const transform = game.components.transform;
const world = game.components.world;
