const std = @import("std");

const ray = @import("ray.zig");
const ray_hit = @import("ray_hit.zig");
const vector = @import("vector.zig");
const render_functions = @import("render_functions.zig");
const utils = @import("utils.zig");

/// a mapping of name to material
pub const MaterialMap = std.StringArrayHashMap(Material);

/// result of scattering a ray
pub const ScatterResult = struct {
    attentuation: vector.Color3f,
    scattered: ray.Ray 
};

/// simple diffuse lambertian material
pub const Lambertian = struct {
    albedo: vector.Color3f = vector.Color3f.init(0.2),

    pub fn init(c: vector.Color3f) Material {
        return .{
            .diffuse = .{
                .albedo = c,
            },
        };
    }

    pub fn scatter(
        self: @This(),
        _: ray.Ray,
        rec: ray_hit.HitRecord,
    ) ?ScatterResult
    {
        var scatter_direction = rec.normal.add(utils.random_unit_vector());

        if (scatter_direction.near_zero()) 
        {
            scatter_direction = rec.normal;
        }

        return .{
            .attentuation = self.albedo,
            .scattered = ray.Ray{
                .origin = rec.p,
                .dir = scatter_direction 
            },
        };
    }
};

/// default material for objects in the scene
pub const DEFAULT_LAMBERT = Material.init(Lambertian{});

/// simple metallic material
pub const Metallic = struct {
    albedo: vector.Color3f = vector.Color3f.init(0.2),

    pub fn init(c: vector.Color3f) Material {
        return .{
            .metallic = .{
                .albedo = c,
            },
        };
    }

    pub fn scatter(
        self: @This(),
        r_in: ray.Ray,
        rec: ray_hit.HitRecord,
    ) ?ScatterResult
    {
        const reflected = utils.reflect(r_in.dir, rec.normal);

        return .{
            .attentuation = self.albedo,
            .scattered = .{ .origin = rec.p, .dir = reflected },
        };
    }
};

pub const Material = union (enum) {
    diffuse : Lambertian,
    metallic : Metallic,

    pub fn init(
        thing: anytype,
    ) Material
    {
        return switch (@TypeOf(thing)) {
            Lambertian => .{ .diffuse = thing },
            Metallic => .{ .metallic = thing },
            else => @compileError(
                "Type " ++ @typeName(@TypeOf(thing)) ++ " is not a material."
                ),
                
        };
    }

    pub fn scatter(
        self: @This(),
        r_in: ray.Ray,
        rec: ray_hit.HitRecord,
    ) ?ScatterResult
    {
        return switch (self) {
            inline else => |v| v.scatter(r_in, rec),
        };
    }
};
