pub const App = struct {
    world: ecs.World,
    resources: ResourceStore,
    scheduler: Scheduler,
    gpa: mem.Allocator,

    const Self = @This();

    pub fn init(gpa: mem.Allocator) !Self {
        return .{
            .world = try ecs.World.init(gpa),
            .resources = ResourceStore.init(gpa),
            .scheduler = Scheduler.init(gpa),
            .gpa = gpa,
        };
    }

    pub fn deinit(self: *Self) void {
        self.scheduler.deinit();
        self.resources.deinit();
        self.world.deinit();
    }

    pub fn addPlugin(self: *Self, comptime Plugin: type, context: anytype) !void {
        comptime assertPlugin(Plugin);
        try Plugin.build(self, context);
    }

    pub fn addSystem(self: *Self, step: Scheduler.Step, system: Scheduler.SystemFn) !void {
        try self.scheduler.add(step, system);
    }

    pub fn runStep(self: *Self, step: Scheduler.Step) !void {
        try self.scheduler.runStep(step, self);
    }

    pub fn setFixedDelta(self: *Self, fixed_dt: f32) void {
        self.scheduler.setFixedDelta(fixed_dt);
    }

    pub fn tick(self: *Self, dt: f32) !void {
        try self.scheduler.tick(self, dt);
    }

    pub fn insertResource(self: *Self, comptime T: type, value: T) !*T {
        return self.resources.insert(T, value);
    }

    pub fn insertResourceWithDeinit(
        self: *Self,
        comptime T: type,
        value: T,
        deinit_fn: *const fn (*T, mem.Allocator) void,
    ) !*T {
        return self.resources.insertWithDeinit(T, value, deinit_fn);
    }

    pub fn getResource(self: *Self, comptime T: type) ?*T {
        return self.resources.get(T);
    }
};

pub fn assertPlugin(comptime P: type) void {
    comptime if (!isPlugin(P)) @compileError("expected to be plugin");
}

pub fn isPlugin(comptime P: type) bool {
    return std.meta.hasFn(P, "build");
}

test "App plugins, resources, and scheduler" {
    const testing = std.testing;
    const alloc = testing.allocator;

    const Counter = struct {
        value: u32,
        pub fn inc(self: *@This(), v: u32) void {
            self.value += v;
        }
    };

    const Tracker = struct {
        value: u8,
        deinit_called: *bool,
        pub fn init(deinit_called: *bool) @This() {
            return .{ .value = 0, .deinit_called = deinit_called };
        }
        pub fn deinit(self: *@This()) void {
            self.deinit_called.* = true;
        }
    };

    const CounterPlugin = struct {
        pub fn build(app: *App, context: anytype) !void {
            _ = try app.insertResource(Counter, .{ .value = 0 });
            _ = try app.insertResource(Tracker, .init(context));
        }
    };

    const Systems = struct {
        fn addOne(app: *App) !void {
            const counter = app.getResource(Counter).?;
            counter.inc(1);
        }

        fn addTwo(app: *App) !void {
            const counter = app.getResource(Counter).?;
            counter.inc(2);
        }
    };

    var app = try App.init(alloc);
    defer app.deinit();

    var tracker_deinit_called = false;
    try app.addPlugin(CounterPlugin, &tracker_deinit_called);
    try app.addSystem(.update, Systems.addOne);
    try app.addSystem(.update, Systems.addTwo);
    try app.runStep(.update);

    const actual_counter = app.getResource(Counter).?;
    try testing.expectEqual(@as(u32, 3), actual_counter.value);
    const removed_tacker = app.resources.remove(Tracker);
    try testing.expect(removed_tacker);
}

const std = @import("std");
const mem = std.mem;
const assert = std.debug.assert;

const ecs = @import("../ecs.zig");
const ResourceStore = @import("resources.zig").ResourceStore;
const Scheduler = @import("scheduler.zig").Scheduler;
