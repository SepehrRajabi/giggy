pub const Scheduler = struct {
    startup: std.ArrayListUnmanaged(SystemFn),
    fixed_update: std.ArrayListUnmanaged(SystemFn),
    update: std.ArrayListUnmanaged(SystemFn),
    render: std.ArrayListUnmanaged(SystemFn),
    gpa: mem.Allocator,
    fixed_dt: f32,
    accumulator: f32,
    startup_ran: bool,

    const Self = @This();
    pub const SystemFn = *const fn (*App) anyerror!void;
    pub const Step = enum {
        startup,
        fixed_update,
        update,
        render,
    };

    pub fn init(gpa: mem.Allocator) Self {
        return .{
            .startup = .{},
            .fixed_update = .{},
            .update = .{},
            .render = .{},
            .gpa = gpa,
            .fixed_dt = 1.0 / 60.0,
            .accumulator = 0,
            .startup_ran = false,
        };
    }

    pub fn deinit(self: *Self) void {
        self.startup.deinit(self.gpa);
        self.fixed_update.deinit(self.gpa);
        self.update.deinit(self.gpa);
        self.render.deinit(self.gpa);
    }

    pub fn add(self: *Self, step: Step, system: SystemFn) !void {
        switch (step) {
            .startup => try self.startup.append(self.gpa, system),
            .fixed_update => try self.fixed_update.append(self.gpa, system),
            .update => try self.update.append(self.gpa, system),
            .render => try self.render.append(self.gpa, system),
        }
    }

    pub fn runStep(self: *Self, step: Step, app: *App) !void {
        const list = switch (step) {
            .startup => self.startup.items,
            .fixed_update => self.fixed_update.items,
            .update => self.update.items,
            .render => self.render.items,
        };
        for (list) |system| {
            try system(app);
        }
    }

    pub fn setFixedDelta(self: *Self, fixed_dt: f32) void {
        self.fixed_dt = fixed_dt;
    }

    pub fn tick(self: *Self, app: *App, dt: f32) !void {
        if (!self.startup_ran) {
            try self.runStep(.startup, app);
            self.startup_ran = true;
        }

        self.accumulator += dt;
        while (self.accumulator >= self.fixed_dt) : (self.accumulator -= self.fixed_dt) {
            try self.runStep(.fixed_update, app);
        }

        try self.runStep(.update, app);
        try self.runStep(.render, app);
    }
};

const std = @import("std");
const mem = std.mem;

const App = @import("app.zig").App;
