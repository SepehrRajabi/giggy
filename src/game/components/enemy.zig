pub const EnemyState = enum {
    chase,
    charge,
    dead,
};

pub const Enemy = struct {
    id: u8,
    speed: f32,
    state: EnemyState,
    release_tick: u32, // zero means null
};

pub const EnemyView = struct {
    pub const Of = Enemy;
    id: *u8,
    speed: *f32,
    state: *EnemyState,
    release_tick: *u32,
};

pub const Shockwave = struct {
    speed: f32,
    size: f32,
    size_limit: f32,
    ttl: u16,
};

pub const ShockwaveView = struct {
    pub const Of = Shockwave;
    speed: *f32,
    size: *f32,
    size_limit: *f32,
    ttl: *u16,
};
