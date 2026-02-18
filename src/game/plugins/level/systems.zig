pub fn levelSystem(app: *core.App) !void {
    const assets_mgr = app.getResource(engine.assets.AssetManager).?;
    const room_mgr = app.getResource(resources.RoomManager).?;
    const registry = app.getResource(engine_prefabs.Registry).?;

    if (assets_mgr.configValuePath("levels", &.{"spawn"})) |spawn| {
        room_mgr.current = resources.roomIdFromName(spawn.string);
    }

    const rooms = assets_mgr.configValuePath("levels", &.{"rooms"}).?;
    var it = rooms.object.iterator();
    while (it.next()) |lvl_entry| {
        var parsed = try engine_prefabs.Registry.loadTiledJson(
            std.heap.page_allocator,
            lvl_entry.value_ptr.*.string,
        );
        defer parsed.deinit();
        try registry.spawnFromTiledValue(app, parsed.value, lvl_entry.key_ptr.*);
    }
}

pub fn doorSystem(app: *core.App) !void {
    const room_mgr = app.getResource(resources.RoomManager).?;
    const fade = app.getResource(fade_resources.ScreenFade).?;

    var it = app.world.query(&[_]type{
        components.player.Player,
        components.transform.Position,
        components.transform.Velocity,
        components.world.Room,
    });
    while (it.next()) |_| {
        const pos = it.get(components.transform.PositionView);
        const vel = it.get(components.transform.VelocityView);
        const room = it.get(components.world.RoomView);

        if (fade.active()) continue;

        var it_door = app.world.query(&[_]type{
            components.world.Teleport,
            components.transform.Position,
            components.collision.ColliderCircle,
            components.world.Room,
        });
        it_door = it_door;
        while (it_door.next()) |_| {
            const tp = it_door.get(components.world.TeleportView);
            const tp_pos = it_door.get(components.transform.PositionView);
            const tp_col = it_door.get(components.collision.ColliderCircleView);
            const tp_room = it_door.get(components.world.RoomView);

            if (room.id.* != tp_room.id.*) continue;

            if (rl.CheckCollisionPointCircle(
                .{ .x = pos.x.*, .y = pos.y.* },
                .{ .x = tp_pos.x.*, .y = tp_pos.y.* },
                tp_col.radius.*,
            )) {
                vel.x.* = 0;
                vel.y.* = 0;
                fade.begin(.{ .room_id = tp.room_id.*, .spawn_id = tp.spawn_id.* });
                _ = room_mgr;
                break;
            }
        }
    }
}

const std = @import("std");

const engine = @import("engine");
const core = engine.core;
const rl = engine.raylib;
const engine_prefabs = engine.prefabs;

const game = @import("game");
const components = game.components;
const resources = game.plugins.level.resources;
const fade_resources = game.plugins.fade.resources;
