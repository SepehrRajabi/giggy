pub const RoomManager = struct {
    current: ?u32,
    items: std.StringHashMap(void),
    bounds: std.AutoHashMap(u32, RoomBounds),
    gpa: mem.Allocator,

    const Self = @This();

    pub fn init(gpa: mem.Allocator) Self {
        return .{
            .current = null,
            .items = std.StringHashMap(void).init(gpa),
            .bounds = std.AutoHashMap(u32, RoomBounds).init(gpa),
            .gpa = gpa,
        };
    }

    pub fn deinit(self: *Self) void {
        var it = self.items.keyIterator();
        while (it.next()) |key|
            self.gpa.free(key.*);
        self.items.deinit();
        self.bounds.deinit();
    }

    pub fn own(self: *Self, name: []const u8) ![]const u8 {
        if (self.items.getKey(name)) |exists| return exists;
        const name_copy = try self.gpa.dupe(u8, name);
        errdefer self.gpa.free(name_copy);
        try self.items.put(name_copy, {});
        return name_copy;
    }

    pub fn setBounds(self: *Self, room_id: u32, bounds: RoomBounds) !void {
        try self.bounds.put(room_id, bounds);
    }

    pub fn getBounds(self: *Self, room_id: u32) ?RoomBounds {
        return self.bounds.get(room_id);
    }
};

pub const RoomBounds = struct {
    x: f32,
    y: f32,
    w: f32,
    h: f32,
};

const std = @import("std");
const mem = std.mem;
