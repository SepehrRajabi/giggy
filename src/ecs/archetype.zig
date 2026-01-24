meta: Meta,
components: []MultiField,

const Self = @This();
const Field = @import("field.zig");
const MultiField = @import("multi_field.zig");

pub const Meta = struct {
    components: []const MultiField.Meta,

    pub inline fn from(comptime Ts: []const type) Meta {
        var metas: [Ts.len]MultiField.Meta = undefined;
        inline for (Ts, 0..) |T, i| {
            metas[i] = MultiField.Meta.from(T);
        }
        std.sort.insertion(MultiField.Meta, &metas, {}, struct {
            fn lessThan(_: void, a: MultiField.Meta, b: MultiField.Meta) bool {
                return a.cid < b.cid;
            }
        }.lessThan);
        inline for (1..metas.len) |i| {
            assert(metas[i - 1].cid != metas[i].cid);
        }
        return .{ .components = &metas };
    }

    pub fn clone(self: *const Meta, gpa: mem.Allocator) !Meta {
        var comps = try gpa.alloc(MultiField.Meta, self.components.len);
        for (comps, 0..) |_, i| {
            comps[i] = self.components[i].clone(gpa) catch |err| {
                for (0..i) |j|
                    comps[j].deinit(gpa);
                return err;
            };
        }
        return .{ .components = comps };
    }

    pub fn deinit(self: *const Meta, gpa: mem.Allocator) void {
        for (self.components) |comp|
            comp.deinit(gpa);
        gpa.free(self.components);
    }
};

pub fn init(gpa: mem.Allocator, meta: Meta) !Self {
    var comps = try gpa.alloc(MultiField, meta.components.len);
    errdefer gpa.free(comps);

    for (meta.components, 0..) |cm, i| {
        comps[i] = MultiField.init(gpa, cm) catch |err| {
            for (0..i) |j|
                comps[j].deinit(gpa);
            return err;
        };
    }

    return .{
        .meta = try meta.clone(gpa),
        .components = comps,
    };
}

pub fn deinit(self: *Self, gpa: mem.Allocator) void {
    for (self.components) |comp|
        comp.deinit(gpa);
    gpa.free(self.components);
    self.meta.deinit(gpa);
}

pub fn appendRaw(self: *Self, gpa: mem.Allocator, data: []const []const []const u8) !void {
    assert(data.len == self.components.len);
    for (self.components, data, 0..) |*c, d, i| {
        c.appendRaw(gpa, d) catch |err| {
            for (0..i) |j|
                self.components[j].pop();
            return err;
        };
    }
}

pub fn remove(self: *Self, index: usize) void {
    assert(index < self.len());
    for (self.components) |comp|
        comp.remove(index);
}

pub fn pop(self: *Self) void {
    self.remove(self.len() - 1);
}

pub fn len(self: *const Self) usize {
    const l = self.components[0].len();
    for (self.components[1..]) |comp|
        assert(l == comp.len());
    return l;
}

test "Archetype.Meta.from" {
    const C1 = struct {
        pub const cid = 1;
        x: u32,
        y: u32,
    };
    const C2 = struct {
        pub const cid = 2;
        a: u8,
        b: u32,
        c: u16,
    };
    const expected = Meta{ .components = ([_]MultiField.Meta{
        MultiField.Meta{
            .cid = 1,
            .fields = ([_]Field.Meta{
                Field.Meta{ .index = 0, .name = "x", .size = 4, .alignment = 4 },
                Field.Meta{ .index = 1, .name = "y", .size = 4, .alignment = 4 },
            })[0..],
        },
        MultiField.Meta{
            .cid = 2,
            .fields = ([_]Field.Meta{
                Field.Meta{ .index = 0, .name = "a", .size = 1, .alignment = 1 },
                Field.Meta{ .index = 1, .name = "b", .size = 4, .alignment = 4 },
                Field.Meta{ .index = 2, .name = "c", .size = 2, .alignment = 2 },
            })[0..],
        },
    })[0..] };
    try testing.expectEqualDeep(expected, Meta.from(&[_]type{ C1, C2 }));
}

test "Archetype.Meta.clone" {
    const alloc = testing.allocator;
    const C1 = struct {
        pub const cid = 1;
        x: u32,
        y: u32,
    };
    const C2 = struct {
        pub const cid = 2;
        a: u8,
        b: u32,
        c: u16,
    };
    const meta = Meta.from(&[_]type{ C1, C2 });
    const meta_clone = try meta.clone(alloc);
    defer meta_clone.deinit(alloc);
    try testing.expectEqualDeep(meta, meta_clone);
}

const std = @import("std");
const mem = std.mem;
const testing = std.testing;
const assert = std.debug.assert;
