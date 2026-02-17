pub const SpawnPoint = struct {
    id: u8 = 0,
};

pub const SpawnPointView = struct {
    pub const Of = SpawnPoint;
    id: *u8,
};

pub const Room = struct {
    name: []const u8,
    id: u32,

    pub fn init(name: []const u8) Room {
        var hash = std.hash.Wyhash.init(0);
        hash.update(name);
        const id: u32 = @truncate(hash.final());
        return .{ .name = name, .id = id };
    }
};

pub const RoomView = struct {
    pub const Of = Room;
    name: *[]const u8,
    id: *u32,
};

pub const Teleport = struct {
    room_id: u32,
    // Which SpawnPoint.id to use in the destination room. 0 means "any/default".
    spawn_id: u8 = 0,
};

pub const TeleportView = struct {
    pub const Of = Teleport;
    room_id: *u32,
    spawn_id: *u8,
};

const std = @import("std");
