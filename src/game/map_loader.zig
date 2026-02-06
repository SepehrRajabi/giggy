pub const Layer = struct {
    name: []const u8,
    points: []Point,
    polygons: []Polygon,
};

pub const Point = struct {
    name: []const u8,
    position: Vertex,
};

pub const Polygon = struct {
    name: []const u8,
    closed: bool,
    vertices: []Vertex,
};

pub const Vertex = struct {
    x: f32,
    y: f32,
};

pub const ParsedLayer = json.Parsed(Layer);

pub fn loadLayer(allocator: std.mem.Allocator, file_path: []const u8) !ParsedLayer {
    var file = try fs.cwd().openFile(file_path, .{});
    defer file.close();

    const contents = try file.readToEndAlloc(allocator, math.maxInt(usize));
    //BUG: memory leak here: this free also frees parsed json memories.
    //defer allocator.free(contents);

    return try json.parseFromSlice(
        Layer,
        allocator,
        contents,
        .{ .ignore_unknown_fields = true },
    );
}

const std = @import("std");
const fs = std.fs;
const json = std.json;
const mem = std.mem;
const math = std.math;

const ArrayList = std.ArrayList;
