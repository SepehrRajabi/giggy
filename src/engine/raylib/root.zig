pub const raylib = @cImport({
    @cInclude("raylib.h");
});
pub const raymath = @cImport({
    @cInclude("raymath.h");
});

test {
    _ = std.testing.refAllDecls(@This());
}

const std = @import("std");
