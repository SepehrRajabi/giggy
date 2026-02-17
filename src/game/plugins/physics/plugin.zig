pub const Plugin = struct {
    pub fn build(self: @This(), app: *core.App) !void {
        _ = self;
        try app.addSystem(.fixed_update, systems.UpdatePositionsSystem);
        try app.addSystem(.fixed_update, systems.UpdateRotationsSystem);
        try app.addSystem(.fixed_update, systems.ColliderRigidBodySystem);
    }
};
const engine = @import("engine");
const core = engine.core;

const systems = @import("systems.zig");
