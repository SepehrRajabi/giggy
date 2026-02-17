pub const Plugin = struct {
    pub fn build(self: @This(), app: *core.App) !void {
        _ = self;
        var render_targets = try resources.RenderTargets.init(app.gpa);
        errdefer render_targets.deinit();
        _ = try app.insertResource(resources.RenderTargets, render_targets);

        var renderables_state = try resources.Renderables.init(app.gpa);
        errdefer renderables_state.deinit();
        _ = try app.insertResource(resources.Renderables, renderables_state);

        try app.addSystem(.fixed_update, systems.UpdateLocomotionAnimationSystem);
        try app.addSystem(.update, systems.Update3dModelAnimationsSystem);
        try app.addSystem(.render, systems.Render3dModelsSystem);
        try app.addSystem(.render, systems.RenderBeginSystem);
        try app.addSystem(.render, systems.CollectRenderablesSystem);
        try app.addSystem(.render, systems.RenderRenderablesSystem);
        try app.addSystem(.render, systems.RenderEndMode2DSystem);
        try app.addSystem(.render, systems.RenderEndSystem);
        try app.addSystem(.render, systems.ClearRenderablesSystem);
    }
};

const engine = @import("engine");
const core = engine.core;

const resources = @import("resources.zig");
const systems = @import("systems.zig");
