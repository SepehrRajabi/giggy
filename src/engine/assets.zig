pub const AssetManager = struct {
    textures: std.StringHashMap(rl.Texture2D),
    models: std.StringHashMap(Model),
    shaders: std.StringHashMap(rl.Shader),
    gpa: mem.Allocator,

    const Self = @This();

    pub fn init(gpa: mem.Allocator) !Self {
        return Self{
            .textures = std.StringHashMap(rl.Texture2D).init(gpa),
            .models = std.StringHashMap(Model).init(gpa),
            .shaders = std.StringHashMap(rl.Shader).init(gpa),
            .gpa = gpa,
        };
    }

    pub fn deinit(self: *Self) void {
        {
            var it = self.textures.valueIterator();
            while (it.next()) |v| _ = rl.UnloadTexture(v.*);
            self.textures.deinit();
        }
        {
            var it = self.models.valueIterator();
            while (it.next()) |v| _ = v.unload();
            self.models.deinit();
        }
        {
            var it = self.shaders.valueIterator();
            while (it.next()) |v| _ = rl.UnloadShader(v.*);
            self.shaders.deinit();
        }
    }

    pub fn loadTexture(self: *Self, key: []const u8, filename: [:0]const u8) !*rl.Texture2D {
        if (self.textures.get(key)) |t| rl.UnloadTexture(t);
        const texture = rl.LoadTexture(@ptrCast(filename));
        try self.textures.put(key, texture);
        return self.textures.getPtr(key).?;
    }

    pub fn unloadTexture(self: *Self, key: []const u8) bool {
        const ptr = self.textures.getPtr(key) orelse return false;
        rl.UnloadTexture(ptr.*);
        return self.textures.remove(key);
    }

    pub fn loadModel(self: *Self, key: []const u8, filename: [:0]const u8) !*Model {
        if (self.models.getPtr(key)) |m| m.unload();
        const model = Model.load(filename);
        try self.models.put(key, model);
        return self.models.getPtr(key).?;
    }

    pub fn unloadModel(self: *Self, key: []const u8) bool {
        const ptr = self.models.getPtr(key) orelse return false;
        ptr.unload();
        return self.models.remove(key);
    }

    pub fn loadShader(self: *Self, key: []const u8, vs_filename: [:0]const u8, fs_filename: [:0]const u8) !*rl.Shader {
        if (self.shaders.get(key)) |s| rl.UnloadShader(s);
        const shader = rl.LoadShader(
            @ptrCast(vs_filename),
            @ptrCast(fs_filename),
        );
        try self.shaders.put(key, shader);
        return self.shaders.getPtr(key).?;
    }

    pub fn unloadShader(self: *Self, key: []const u8) bool {
        const ptr = self.shaders.getPtr(key) orelse return false;
        rl.UnloadShader(ptr.*);
        return self.textures.remove(key);
    }
};

pub const Model = struct {
    model: rl.Model,
    animations: []rl.ModelAnimation,

    pub fn load(filename: [:0]const u8) Model {
        const model = rl.LoadModel(@ptrCast(filename));
        var anim_count: c_int = undefined;
        const anim = rl.LoadModelAnimations(filename, &anim_count);
        return Model{
            .model = model,
            .animations = anim[0..@as(usize, @intCast(anim_count))],
        };
    }

    pub fn unload(self: *Model) void {
        rl.UnloadModelAnimations(
            @ptrCast(self.animations.ptr),
            @intCast(self.animations.len),
        );
        rl.UnloadModel(self.model);
    }
};

const std = @import("std");
const mem = std.mem;
const rl = @import("engine").rl;
