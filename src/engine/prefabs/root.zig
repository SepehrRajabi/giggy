pub const Plugin = @import("plugin.zig").Plugin;
pub const Registry = @import("resources.zig").Registry;

test {
    _ = std.testing.refAllDecls(@This());
}

const std = @import("std");
