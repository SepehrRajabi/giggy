pub const ResourceStore = struct {
    map: std.StringHashMap(Entry),
    gpa: mem.Allocator,

    const Self = @This();
    const Entry = struct {
        ptr: *anyopaque,
        deinit: *const fn (*anyopaque, mem.Allocator) void,
    };
    const Error = error{ResourceExists};

    pub fn init(gpa: mem.Allocator) Self {
        return .{
            .gpa = gpa,
            .map = std.StringHashMap(Entry).init(gpa),
        };
    }

    pub fn deinit(self: *Self) void {
        var it = self.map.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.deinit(entry.value_ptr.ptr, self.gpa);
        }
        self.map.deinit();
    }

    pub fn insert(self: *Self, comptime T: type, value: T) (Error || mem.Allocator.Error)!*T {
        return self.insertWithDeinit(T, value, defaultDeinit(T));
    }

    pub fn insertWithDeinit(
        self: *Self,
        comptime T: type,
        value: T,
        comptime deinit_fn: *const fn (*T, mem.Allocator) void,
    ) (Error || mem.Allocator.Error)!*T {
        const key = @typeName(T);
        if (self.map.contains(key)) {
            return Error.ResourceExists;
        }

        const ptr = try self.gpa.create(T);
        ptr.* = value;

        const entry = Entry{
            .ptr = ptr,
            .deinit = wrapDeinit(T, deinit_fn),
        };
        try self.map.put(key, entry);
        return ptr;
    }

    pub fn get(self: *Self, comptime T: type) ?*T {
        const entry = self.map.get(@typeName(T)) orelse return null;
        return @ptrCast(@alignCast(entry.ptr));
    }

    pub fn remove(self: *Self, comptime T: type) bool {
        const entry = self.map.fetchRemove(@typeName(T)) orelse return false;
        entry.value.deinit(entry.value.ptr, self.gpa);
        return true;
    }

    fn defaultDeinit(comptime T: type) *const fn (*T, mem.Allocator) void {
        return struct {
            fn call(ptr: *T, gpa: mem.Allocator) void {
                _ = gpa;
                if (@hasDecl(T, "deinit")) {
                    ptr.deinit();
                }
            }
        }.call;
    }

    fn wrapDeinit(
        comptime T: type,
        comptime deinit_fn: *const fn (*T, mem.Allocator) void,
    ) *const fn (*anyopaque, mem.Allocator) void {
        return struct {
            fn call(ptr: *anyopaque, gpa: mem.Allocator) void {
                const typed_ptr: *T = @ptrCast(@alignCast(ptr));
                deinit_fn(typed_ptr, gpa);
                gpa.destroy(typed_ptr);
            }
        }.call;
    }
};

const std = @import("std");
const mem = std.mem;
