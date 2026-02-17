pub const ScreenFade = struct {
    state: State = .idle,
    t: f32 = 0,
    alpha: f32 = 0, // 0..1

    out_duration: f32 = 0.20,
    hold_duration: f32 = 0.05,
    in_duration: f32 = 0.20,

    pending: ?Pending = null,

    pub const Pending = struct {
        room_id: u32,
        spawn_id: u8,
    };

    pub const State = enum {
        idle,
        fading_out,
        hold_black,
        fading_in,
    };

    pub fn active(self: *const @This()) bool {
        return self.state != .idle;
    }

    pub fn begin(self: *@This(), pending: Pending) void {
        // Ignore requests while already transitioning.
        if (self.state != .idle) return;
        self.pending = pending;
        self.state = .fading_out;
        self.t = 0;
        self.alpha = 0;
    }
};
