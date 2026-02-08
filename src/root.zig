const game = @import("game/main.zig");
const examples = @import("examples.zig");
const ecs = @import("ecs.zig");

pub fn main() !void {
    try game.main();
}

test {
    _ = game;
    _ = examples;
    _ = ecs;
}
