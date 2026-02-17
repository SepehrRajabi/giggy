pub const Model3D = struct {
    name: []const u8,
    mesh: usize,
    material: usize,
    render_texture: usize,
};

pub const Model3DView = struct {
    pub const Of = Model3D;
    name: *[]const u8,
    mesh: *usize,
    material: *usize,
    render_texture: *usize,
};

pub const Texture = struct {
    name: []const u8,
    z_index: i16,
};

pub const TextureView = struct {
    pub const Of = Texture;
    name: *[]const u8,
    z_index: *i16,
};

pub const WidthHeight = struct {
    w: f32,
    h: f32,
};

pub const WidthHeightView = struct {
    pub const Of = WidthHeight;
    w: *f32,
    h: *f32,
};

pub const RenderInto = struct {
    into: []const u8,
};

pub const RenderIntoView = struct {
    pub const Of = RenderInto;
    into: *[]const u8,
};
