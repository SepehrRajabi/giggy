pub const Plugin = struct {
    pub fn build(self: @This(), app: *core.App) !void {
        _ = self;
        _ = try app.insertResource(resources.ScreenFade, .{});
        try app.addSystem(.fixed_update, systems.FadeSystem);
        try app.addSystem(.render, systems.FadeOverlaySystem);
    }
};
const engine = @import("engine");
const core = engine.core;

const resources = @import("resources.zig");
const systems = @import("systems.zig");
