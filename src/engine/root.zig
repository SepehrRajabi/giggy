pub const ecs = @import("ecs.zig");
pub const math = @import("math.zig");
pub const rl = @import("rl.zig").rl;
pub const rm = @import("rl.zig").rm;

test {
    _ = ecs;
    _ = math;
    _ = rl;
    _ = rm;
}
