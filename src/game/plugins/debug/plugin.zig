pub const Plugin = struct {
    pub fn build(self: @This(), app: *core.App) !void {
        _ = self;
        _ = try app.insertResource(resources.DebugState, resources.DebugState.init(app.gpa));
        try app.addSystem(.update, systems.UpdateDebugModeSystem);
        try app.addSystem(.update, systems.UpdateDebugValuesSystem);
        try app.addSystem(.render, systems.RenderDebugSystem);
        try app.addSystem(.render, systems.RenderDebugOverlaySystem);
    }
};
const core = engine.core;

const engine = @import("engine");
const resources = @import("resources.zig");
const systems = @import("systems.zig");
