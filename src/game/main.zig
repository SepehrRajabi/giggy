const screenWidth: u32 = 800;
const screenHeight: u32 = 600;

pub const SystemCtx = struct {
    resc: *Resources,
    world: *ecs.World,
    cb: *ecs.CommandBuffer,
    dt: f32,
    alpha: f32,
};

pub fn main() !void {
    rl.InitWindow(screenWidth, screenHeight, "Giggy: Blob Splits");
    defer rl.CloseWindow();
    const hz = rl.GetMonitorRefreshRate(rl.GetCurrentMonitor());
    rl.SetTargetFPS(hz);

    // init ecs
    const allocator = std.heap.c_allocator;

    var world = try ecs.World.init(allocator);
    defer world.deinit();

    var resc = try Resources.init(allocator);
    defer resc.deinit();

    _ = try resc.loadTexture("map", "resources/map.png");
    _ = try resc.loadTexture("abol", "resources/abol.png");
    _ = try resc.loadTexture("wall1", "resources/wall1.png");
    _ = try resc.loadTexture("wall2", "resources/wall2.png");

    const greenman_model = try resc.loadModel("greenman", "resources/gltf/greenman.glb");
    const skinning_shader = try resc.loadShader(
        "skinning",
        "resources/shaders/glsl330/skinning.vs",
        "resources/shaders/glsl330/skinning.fs",
    );
    greenman_model.model.materials[1].shader = skinning_shader.*;

    _ = try resc.loadJson("level1", "resources/json/layers.json");

    _ = try resc.loadRenderTexture("player", 64, 64);

    // setup camera
    var camera = rl.Camera2D{
        .offset = rl.Vector2{
            .x = @as(f32, @floatFromInt(screenWidth)) / 2.0,
            .y = @as(f32, @floatFromInt(screenHeight)) / 2.0,
        },
        .target = rl.Vector2{ .x = 0, .y = 0 },
        .rotation = 0.0,
        .zoom = 1.0,
    };

    // init entities
    const player = try world.spawn(.{
        comps.Position{ .x = 70, .y = 70, .prev_x = 70, .prev_y = 70 },
        comps.Velocity{ .x = 0, .y = 0 },
        comps.Rotation{ .teta = 0, .prev_teta = 0, .target_teta = 0, .turn_speed_deg = 360.0 * 3 },
        comps.Model3D{ .name = "greenman", .render_texture = 0, .mesh = 0, .material = 1 },
        comps.RenderInto{ .into = "player" },
        comps.Animation{ .index = 0, .frame = 0, .acc = 0, .speed = 0 },
        comps.MoveAnimation{ .idle = 0, .run = 2, .speed = 200.0 },
    });

    const lvl1 = resc.jsons.get("level1").?;
    for (lvl1.value.images) |img| {
        if (img.index == 0) continue; // dont load backgorund
        assert(resc.textures.getPtr(img.name) != null);
        _ = try world.spawn(.{
            comps.Position{
                .x = img.position.x,
                .y = img.position.y,
                .prev_x = img.position.x,
                .prev_y = img.position.y,
            },
            comps.WidthHeight{ .w = img.width, .h = img.height },
            comps.Texture{ .name = img.name },
        });
    }
    for (lvl1.value.polygons) |poly| {
        if (!std.mem.eql(u8, poly.name, "edge")) continue;
        var last = poly.vertices[0];
        for (poly.vertices[1..]) |v| {
            _ = try world.spawn(.{
                comps.Line{
                    .x0 = last.x,
                    .y0 = last.y,
                    .x1 = v.x,
                    .y1 = v.y,
                },
            });
            last.x = v.x;
            last.y = v.y;
        }
        if (poly.closed) {
            _ = try world.spawn(.{
                comps.Line{
                    .x0 = last.x,
                    .y0 = last.y,
                    .x1 = poly.vertices[0].x,
                    .y1 = poly.vertices[0].y,
                },
            });
        }
    }

    var command_buffer = try ecs.CommandBuffer.init(allocator);
    var to_render = try systems.RenderableList.initCapacity(allocator, 4);
    defer to_render.deinit(allocator);

    const fixed_dt = @as(f32, 1) / 60.0;
    var accumulator: f32 = 0;
    // main loop
    while (!rl.WindowShouldClose()) {
        const frame_dt = rl.GetFrameTime();
        accumulator += frame_dt;

        const frame_ctx = SystemCtx{
            .resc = &resc,
            .world = &world,
            .cb = &command_buffer,
            .dt = frame_dt,
            .alpha = 0,
        };
        systems.playerInput(frame_ctx, player);
        const debug = systems.updateDebugMode(frame_ctx);

        while (accumulator >= fixed_dt) : (accumulator -= fixed_dt) {
            const sim_ctx = SystemCtx{
                .resc = &resc,
                .world = &world,
                .cb = &command_buffer,
                .dt = fixed_dt,
                .alpha = 0,
            };
            systems.updatePositions(sim_ctx);
            systems.updateRotations(sim_ctx);
            systems.playMovingsAnim(sim_ctx);
        }

        const alpha = @min(@max(accumulator / fixed_dt, 0), 1);
        const render_ctx = SystemCtx{
            .resc = &resc,
            .world = &world,
            .cb = &command_buffer,
            .dt = frame_dt,
            .alpha = alpha,
        };

        systems.cameraOnObject(render_ctx, &camera, player);
        systems.upldate3dModelAnimations(render_ctx);
        systems.render3dModels(render_ctx);

        rl.BeginDrawing();
        rl.ClearBackground(rl.GRAY);
        rl.BeginMode2D(camera);
        // render main scene
        systems.renderBackground(render_ctx, "map");
        try systems.collectRenderables(render_ctx, allocator, &to_render);
        systems.renderRenderables(render_ctx, &to_render);
        to_render.clearRetainingCapacity();
        if (debug) {
            systems.renderBoxes(render_ctx);
            systems.renderColliders(render_ctx);
        }
        rl.EndMode2D();
        // render gui
        if (debug) rl.DrawFPS(10, screenHeight - 30);
        rl.EndDrawing();

        try command_buffer.flush(&world);
    }
}

const std = @import("std");
const assert = std.debug.assert;
const rl = @import("../rl.zig").rl;
const rm = @import("../rl.zig").rm;

const ecs = @import("../ecs.zig");
const comps = @import("components.zig");
const systems = @import("systems.zig");
const map_loader = @import("map_loader.zig");

const Resources = @import("resources.zig");
