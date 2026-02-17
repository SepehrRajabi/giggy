pub const Plugin = struct {
    pub fn build(self: @This(), app: *core.App) !void {
        _ = self;
        var registry = resources.Registry.init(app.gpa);
        errdefer registry.deinit();
        _ = try app.insertResource(resources.Registry, registry);
    }
};

const engine = @import("engine");
const core = engine.core;
const resources = @import("resources.zig");
