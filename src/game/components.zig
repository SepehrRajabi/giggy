pub const Position = struct {
    pub const cid = 1;
    x: f32,
    y: f32,
};

pub const PositionView = struct {
    pub const Of = Position;
    x: *f32,
    y: *f32,
};

pub const Velocity = struct {
    pub const cid = 2;
    x: f32,
    y: f32,
};

pub const VelocityView = struct {
    pub const Of = Velocity;
    x: *f32,
    y: *f32,
};

pub const Circle = struct {
    pub const cid = 3;
    color: rl.Color,
    r: f32,
};

pub const CircleView = struct {
    pub const Of = Circle;
    color: *rl.Color,
    r: *f32,
};

pub const Model3D = struct {
    pub const cid = 4;
    index: usize,
    mesh: usize,
    material: usize,
    render_texture: usize,
};

pub const Model3DView = struct {
    pub const Of = Model3D;
    index: *usize,
    mesh: *usize,
    material: *usize,
    render_texture: *usize,
};

pub const Animation = struct {
    pub const cid = 5;
    index: usize,
    animation_index: usize,
    frame: usize,
};

pub const AnimationView = struct {
    pub const Of = Animation;
    index: *usize,
    animation_index: *usize,
    frame: *usize,
};

pub const MoveAnimation = struct {
    pub const cid = 6;
    idle: usize,
    run: usize,
};

pub const MoveAnimationView = struct {
    pub const Of = MoveAnimation;
    idle: *usize,
    run: *usize,
};

pub const Rotation = struct {
    pub const cid = 7;
    teta: f32,
};

pub const RotationView = struct {
    pub const Of = Rotation;
    teta: *f32,
};

const rl = @import("../rl.zig").rl;
