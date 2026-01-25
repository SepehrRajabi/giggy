pub const Entity = u32;

pub const World = struct {
    next_entity: Entity,
    gpa: mem.Allocator,

    const Self = @This();

    pub fn init(gpa: mem.Allocator) !Self {
        return .{
            .next_entity = 0,
            .gpa = gpa,
        };
    }

    pub fn spawn(self: *Self) Entity {
        const e = self.next_entity;
        self.next_entity += 1;
        return e;
    }
};

const std = @import("std");
const mem = std.mem;
const testing = std.testing;
const assert = std.debug.assert;

const Archetype = @import("archetype.zig").Archetype;
