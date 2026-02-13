pub const AssetsPlugin = struct {
    pub fn build(self: @This(), app: *core.App) !void {
        _ = self;
        const assets_mgr = app.getResource(engine.assets.AssetManager).?;
        _ = try assets_mgr.loadTexture("map", "resources/map.png");
        _ = try assets_mgr.loadTexture("abol", "resources/abol.png");
        _ = try assets_mgr.loadTexture("wall1", "resources/wall1.png");
        _ = try assets_mgr.loadTexture("wall2", "resources/wall2.png");

        const greenman_model = try assets_mgr.loadModel("greenman", "resources/gltf/greenman.glb");
        const skinning_shader = try assets_mgr.loadShader(
            "skinning",
            "resources/shaders/glsl330/skinning.vs",
            "resources/shaders/glsl330/skinning.fs",
        );
        greenman_model.model.materials[1].shader = skinning_shader.*;
    }
};

const engine = @import("engine");
const core = engine.core;
