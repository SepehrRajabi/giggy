pub const ColliderCircle = struct {
    radius: f32,
    mask: u64,
};

pub const ColliderCircleView = struct {
    pub const Of = ColliderCircle;
    radius: *f32,
    mask: *u64,
};

pub const ColliderLine = struct {
    x0: f32,
    y0: f32,
    x1: f32,
    y1: f32,
    mask: u64,
};

pub const ColliderLineView = struct {
    pub const Of = ColliderLine;
    x0: *f32,
    y0: *f32,
    x1: *f32,
    y1: *f32,
    mask: *u64,
};
