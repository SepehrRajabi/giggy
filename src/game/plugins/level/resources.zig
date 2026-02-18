pub const RoomManager = struct {
    current: ?u32,
    bounds: std.AutoHashMap(u32, RoomBounds),

    const Self = @This();

    pub fn init(gpa: mem.Allocator) Self {
        return .{
            .current = null,
            .bounds = std.AutoHashMap(u32, RoomBounds).init(gpa),
        };
    }

    pub fn deinit(self: *Self) void {
        self.bounds.deinit();
    }

    pub fn setBounds(self: *Self, room_id: u32, bounds: RoomBounds) !void {
        try self.bounds.put(room_id, bounds);
    }

    pub fn getBounds(self: *Self, room_id: u32) ?RoomBounds {
        return self.bounds.get(room_id);
    }
};

pub fn roomIdFromName(name: []const u8) u32 {
    var hash = std.hash.Wyhash.init(0);
    hash.update(name);
    return @truncate(hash.final());
}

pub fn roomFromName(name: []const u8) components.world.Room {
    return .{ .id = roomIdFromName(name) };
}

pub const RoomBounds = struct {
    x: f32,
    y: f32,
    w: f32,
    h: f32,
};

const std = @import("std");
const mem = std.mem;
const game = @import("game");
const components = game.components;
