const std = @import("std");

const ray = @import("ray.zig");
const ray_hit = @import("ray_hit.zig");
const vector = @import("vector.zig");
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
    fuzz: vector.V3f.BaseType = 0,

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
        var reflected = utils.reflect(r_in.dir, rec.normal);
        reflected = reflected.unit_vector().add(utils.random_unit_vector().mul(self.fuzz));

        const result = ScatterResult{
            .attentuation = self.albedo,
            .scattered = .{ .origin = rec.p, .dir = reflected },
        };

        if (result.scattered.dir.dot(rec.normal) > 0)
        {
            return result;
        }
        else
        {
            return null;
        }
    }
};

/// material that always refracts (image 16)
pub const DielectricAlwaysRefract = struct {
    albedo: vector.Color3f = vector.Color3f.init(0.2),
    refraction_index: vector.V3f.BaseType,

    pub fn scatter(
        self: @This(),
        r_in: ray.Ray,
        rec: ray_hit.HitRecord,
    ) ?ScatterResult
    {
        const attenuation = vector.Color3f.init(1.0);
        const ri = (
            if (rec.front_face) 1.0 / self.refraction_index 
            else self.refraction_index
        );

        const unit_direction = r_in.dir.unit_vector();
        const refracted = utils.refract(
            unit_direction,
            rec.normal,
            ri
        );

        return .{
            .scattered = .{ .origin = rec.p, .dir = refracted },
            .attentuation = attenuation,
        };
    }
};

/// image 17
pub const DielectricReflRefr = struct {
    albedo: vector.Color3f = vector.Color3f.init(0.2),
    refraction_index: vector.V3f.BaseType,

    pub fn init(
        albedo: vector.Color3f,
        refraction_index: vector.V3f.BaseType,
    ) Material
    {
        return .{
            .dielectric_refl_refr = .{
                .albedo = albedo,
                .refraction_index = refraction_index,
            },
        };
    }

    pub fn scatter(
        self: @This(),
        r_in: ray.Ray,
        rec: ray_hit.HitRecord,
    ) ?ScatterResult
    {
        const attenuation = vector.Color3f.init(1.0);
        const ri = (
            if (rec.front_face) 1.0 / self.refraction_index 
            else self.refraction_index
        );

        const unit_direction = r_in.dir.unit_vector();
        const cos_theta = @min(unit_direction.neg().dot(rec.normal), 1.0);
        const sin_theta = std.math.sqrt(1.0 - (cos_theta*cos_theta));

        const cannot_refract = ri * sin_theta > 1.0;

        const dir = (
            if (cannot_refract) utils.reflect(unit_direction, rec.normal)
            else utils.refract(unit_direction, rec.normal, ri)
        );

        return .{
            .scattered = .{ .origin = rec.p, .dir = dir },
            .attentuation = attenuation,
        };
    }
};

pub const Material = union (enum) {
    diffuse : Lambertian,
    metallic : Metallic,
    dielectric_always_refract: DielectricAlwaysRefract,
    dielectric_refl_refr: DielectricReflRefr,

    /// initialize a Material from a unioned enum type
    pub fn init(
        thing: anytype,
    ) Material
    {
        return switch (@TypeOf(thing)) {
            Lambertian => .{ .diffuse = thing },
            Metallic => .{ .metallic = thing },
            DielectricAlwaysRefract => .{ .dielectric_always_refract= thing },
            DielectricReflRefr => .{ .dielectric_refl_refr= thing },
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
