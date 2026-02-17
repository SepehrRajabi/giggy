pub const Plugin = @import("plugin.zig").Plugin;
pub const AssetManager = @import("resources.zig").AssetManager;
pub const Model = @import("resources.zig").Model;

test {
    _ = std.testing.refAllDecls(@This());
}

const std = @import("std");
