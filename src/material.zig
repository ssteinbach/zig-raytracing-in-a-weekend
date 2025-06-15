const ray = @import("ray.zig");
const vector = @import("vector.zig");
const render_functions = @import("render_functions.zig");

const Diffuse = struct {
};

const Metallic = struct {
};

const Material = union (enum) {
    diffuse : Diffuse,
    metallic : Metallic,

    pub fn scatter(
        self: @This(),
        r_in: ray.Ray,
        rec: render_functions.HitRecord,
    ) struct { attentuation: vector.Color3f, scattered: ray.Ray }
    {
        return switch (self) {
            inline else => self.scatter(r_in, rec),
        };
    }
};
