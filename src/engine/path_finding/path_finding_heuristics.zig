const std = @import("std");
const math = std.math;

/// Integer grid coordinate used by the pathfinder.
pub const GridPos = struct {
    x: i32,
    y: i32,
};

/// Common grid heuristics for A*.
pub const Heuristic = enum {
    /// Manhattan distance: |dx| + |dy|
    manhattan,
    /// Euclidean distance: sqrt(dx*dx + dy*dy)
    euclidean,
    /// Diagonal (Chebyshev-like) distance: max(|dx|, |dy|)
    diagonal,
};

/// Estimate remaining cost between two grid positions using the chosen heuristic.
///
/// Returned value is an integer cost compatible with step cost = 1.
pub fn estimate(kind: Heuristic, a: GridPos, b: GridPos) f32 {
    return switch (kind) {
        .manhattan => @floatFromInt(manhattan(a, b)),
        .euclidean => euclidean(a, b),
        .diagonal => @floatFromInt(diagonal(a, b)),
    };
}

pub fn manhattan(a: GridPos, b: GridPos) u32 {
    const dx: u32 = @abs(a.x - b.x);
    const dy: u32 = @abs(a.y - b.y);
    return @intCast(dx + dy);
}

pub fn euclidean(a: GridPos, b: GridPos) f32 {
    const dx: u32 = @abs(a.x - b.x);
    const dy: u32 = @abs(a.y - b.y);
    const fdx: f32 = @floatFromInt(dx);
    const fdy: f32 = @floatFromInt(dy);
    const dist = math.sqrt(fdx * fdx + fdy * fdy);
    // Round to nearest integer to keep it compatible with u32 g-costs.
    return dist + 0.5;
}

pub fn diagonal(a: GridPos, b: GridPos) u32 {
    const dx: u32 = @abs(a.x - b.x);
    const dy: u32 = @abs(a.y - b.y);
    const m = if (dx > dy) dx else dy;
    return @intCast(m);
}
