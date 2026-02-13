pub const CorePlugin = struct {
    width: u32,
    height: u32,
    fixed_dt: f32 = 1.0 / 60.0,

    pub fn build(self: @This(), app: *core.App) !void {
        const time = app.getResource(core.Time).?;
        time.dt = 0;
        time.fixed_dt = self.fixed_dt;
        time.alpha = 0;
        app.setFixedDelta(self.fixed_dt);

        _ = try app.insertResource(resources.Screen, .{
            .width = self.width,
            .height = self.height,
        });

        _ = try app.insertResource(resources.DebugState, .{ .enabled = false });

        const camera = rl.Camera2D{
            .offset = rl.Vector2{
                .x = @as(f32, @floatFromInt(self.width)) / 2.0,
                .y = @as(f32, @floatFromInt(self.height)) / 2.0,
            },
            .target = rl.Vector2{ .x = 0, .y = 0 },
            .rotation = 0.0,
            .zoom = 1.0,
        };
        _ = try app.insertResource(resources.CameraState, .{ .camera = camera });

        var render_targets = try resources.RenderTargets.init(app.gpa);
        errdefer render_targets.deinit();
        _ = try app.insertResource(resources.RenderTargets, render_targets);

        var renderables = try resources.Renderables.init(app.gpa);
        errdefer renderables.deinit();
        _ = try app.insertResource(resources.Renderables, renderables);

        try app.addSystem(.update, updateDebugMode);
    }
};

fn updateDebugMode(app: *core.App) !void {
    const debug = app.getResource(resources.DebugState).?;
    if (rl.IsKeyReleased(rl.KEY_F9)) {
        debug.enabled = !debug.enabled;
    }
}

const engine = @import("engine");
const core = engine.core;
const rl = engine.rl;

const resources = @import("../resources.zig");
