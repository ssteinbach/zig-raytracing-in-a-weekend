//! utility functions for Raytracing in a Weekend

const std = @import("std");
const comath_wrapper = @import("comath_wrapper.zig");
const vector = @import("vector.zig");

const BaseType = vector.V3f.BaseType;
const INF = std.math.inf(BaseType);

var prng = std.Random.DefaultPrng.init(0);
pub const rand = prng.random();

// random number in [-0.5, 0.5)
pub fn rnd_float_centered(
    comptime T: type,
) T
{
    return (rand.float(T) - 0.5);
}

/// Random number / vector in [-0.5, 0.5]
pub fn rnd_num(
    comptime T: type,
) T 
{
    return switch (@typeInfo(T)) {
        .float, .comptime_float, => return rnd_float_centered(T),
        // .int, .comptime_int, => return rand.float(T),
        .@"struct" => switch (T) {
            vector.V3f => vector.V3f{
                .x = rnd_float_centered(vector.V3f.BaseType),
                .y = rnd_float_centered(vector.V3f.BaseType),
                .z = rnd_float_centered(vector.V3f.BaseType),
            },
            else => @compileError(
                    "Can only generate random ints, floats, and V3f, not: " 
                    ++ @typeName(T)
            ),
        },
        else => @compileError(
            "Can only generate random ints, floats, and V3f, not: " 
            ++ @typeName(T)
        ),
    };
}

test "random number: [-0.5, 0.5)"
{ 
    const low = -0.5;
    const hi = 0.5;

    var i: usize = 0;
    while (i < 10000)
        : (i += 1)
    {
        const n = rnd_num(BaseType);

        errdefer std.debug.print("Error with n: {d}\n", .{ n });

        try std.testing.expect(n >= low and n < hi);
    }

}

/// Random number in [low_inclusive, high_exclusive)
pub fn rnd_num_range(
    comptime T: type,
    low_inclusive: T,
    high_exclusive: T,
) T
{
    return comath_wrapper.lerp(
        rand.float(T),
        low_inclusive,
        high_exclusive
    );
}

// Random number in [low_inclusive, high_exclusive)
pub fn rnd_vec_range(
    comptime T: type,
    low_inclusive: T.BaseType,
    high_exclusive: T.BaseType,
) T
{
    return T.init_3(
        comath_wrapper.lerp(
            rand.float(T.BaseType),
            low_inclusive,
            high_exclusive
        ),
        comath_wrapper.lerp(
            rand.float(T.BaseType),
            low_inclusive,
            high_exclusive
        ),
        comath_wrapper.lerp(
            rand.float(T.BaseType),
            low_inclusive,
            high_exclusive
        )
    );
}

test "random number generator: [2, 3)" 
{
    const low = 2;
    const hi = 3;

    var i: usize = 0;
    while (i < 10000)
        : (i += 1)
    {
        const n = rnd_num_range(BaseType, low, hi);

        errdefer std.debug.print("Error with n: {d}\n", .{ n });

        try std.testing.expect(n >= low and n < hi);
    }
}

pub const Interval = struct {
    start: BaseType = INF,
    end: BaseType = -INF,
    
    pub const EMPTY: Interval = .{ .start = INF, .end = -INF};
    pub const EVERYTHING: Interval = .{ .start = -INF, .end = INF};
    pub const UNIT_RIGHT_INCLUSIVE: Interval = .{ .start = 0, .end = 1 };
    pub const UNIT_RIGHT_EXCLUSIVE: Interval = .{ .start = 0, .end = 0.99999 };
    pub const ZERO_TO_INF: Interval = .{ .start = 0, .end = INF };
    pub const EPS_TO_INF: Interval = .{ .start = 0.001, .end = INF };

    pub fn size(
        self: @This(),
    ) BaseType
    {
        // assumes that end > start
        return self.end - self.start;
    }
    
    pub fn contains(
        self: @This(),
        ord: anytype,
    ) bool
    {
        return switch (@typeInfo(@TypeOf(ord))) {
            .@"struct" => (
                self.start <= ord.x and ord.x <= self.end
                and self.start <= ord.y and ord.y <= self.end
                and self.start <= ord.z and ord.z <= self.end
            ),
            .@"float", .@"int", .comptime_float, .comptime_int => (
                self.start <= ord and self.end >= ord
            ),
            else => @compileError(
                "cannot compare to things of type: " 
                ++ @typeName(@TypeOf(ord))
            ),
        };
    }

    pub fn surrounds(
        self: @This(),
        ord: BaseType,
    ) bool
    {
        return switch (@typeInfo(@TypeOf(ord))) {
            .@"struct" => (
                self.start < ord.x and ord.x < self.end
                and self.start < ord.y and ord.y < self.end
                and self.start < ord.z and ord.z < self.end
            ),
            .@"float", .@"int", .comptime_float, .comptime_int => (
                self.start < ord and ord < self.end
            ),
            else => @compileError(
                "cannot compare to things of type: " 
                ++ @typeName(@TypeOf(ord))
            ),
        };
    }

    pub fn clamp(
        self: @This(),
        ord: anytype,
    ) @TypeOf(ord)
    {
        return switch (@typeInfo(@TypeOf(ord))) {
            .@"struct" => ord.max(self.start).min(self.end),
            .@"float", .@"int", .comptime_float, .comptime_int => (
                @min(@max(ord, self.end), self.start)
            ),
            else => @compileError(
                "cannot clamp things of type: " ++ @typeName(@TypeOf(ord))
            ),
        };
    }
};

pub fn random_unit_vector(
) vector.V3f
{
    while (true)
    {
        const p = rnd_num(vector.V3f);
        const len_sq = p.length_squared();

        if (1e-160 < len_sq and len_sq <= 1.0)
        {
            // normalize the length
            return p.div(std.math.sqrt(len_sq));
        }
    }
}

// produce a point in the z=0 plane such that x,y [-1, 1)
pub fn random_in_unit_disk(
) vector.V3f
{
    while (true)
    {
        const p = vector.V3f.init_2(
           rnd_num_range(BaseType, -1, 1), 
           rnd_num_range(BaseType, -1, 1), 
        );

        if ((p.x*p.x) + (p.y * p.y) < 1)
        {
            return p;
        }
    }
}

test "random in unit disk"
{
    const low = -1;
    const hi = 1;

    var i: usize = 0;
    while (i < 10000)
        : (i += 1)
    {
        const p = random_in_unit_disk();

        errdefer std.debug.print("Error with p: {s}\n", .{ p });

        try std.testing.expect(p.length_squared() < 1 and p.length_squared() > 0);
        try std.testing.expect(p.x > low and p.x < hi);
        try std.testing.expect(p.y > low and p.y < hi);
    }
}

pub fn random_on_hemisphere(
    normal: vector.V3f,
) vector.V3f
{
    const on_unit_sphere = random_unit_vector();

    return (
        if (on_unit_sphere.dot(normal) > 0.0) on_unit_sphere 
        else on_unit_sphere.neg()
    );
}

/// take the square root as an approximation of the linear to gamma space
/// transform
pub fn linear_to_gamma(
    /// the linear component (or vector of components) to correct
    lin_comp: anytype,
) @TypeOf(lin_comp)
{
    return switch (@typeInfo(@TypeOf(lin_comp))) {
        .int, .comptime_int, .float, .comptime_float => (
            if (lin_comp > 0) std.math.sqrt(lin_comp)
            else 0
        ),
        .@"struct" => (
            vector.V3f{
                .x = if (lin_comp.x > 0) std.math.sqrt(lin_comp.x) else 0,
                .y = if (lin_comp.y > 0) std.math.sqrt(lin_comp.y) else 0,
                .z = if (lin_comp.z > 0) std.math.sqrt(lin_comp.z) else 0,
            }
        ),
        else => @compileError(
            "Can only take the linear component of int, float, and Vector, not:"
            ++ @typeName(@TypeOf(lin_comp))
        ),
    };
}

/// reflect v about the surface normal n
pub fn reflect(
    v: vector.V3f,
    n: vector.V3f,
) vector.V3f
{
    return comath_wrapper.eval(
        "v - (n * 2 * v.dot(n))",
        .{ .v = v, .n = n },
    );
}

/// refract uv about normal n and etai_over_etat
pub fn refract(
    uv: vector.V3f,
    n: vector.V3f,
    etai_over_etat: BaseType,
) vector.V3f
{
    const cos_theta = @min(uv.neg().dot(n), 1.0);
    const r_out_perp = comath_wrapper.eval(
        "(uv + n * cos_theta) * etai_over_etat",
        .{
            .uv = uv,
            .n = n,
            .cos_theta = cos_theta,
            .etai_over_etat = etai_over_etat,
        },
    );
    const r_out_parallel = n.mul(
        - std.math.sqrt(@abs(1.0 - r_out_perp.length_squared()))
    );
    return r_out_perp.add(r_out_parallel);
}

// inline vec3 refract(const vec3& uv, const vec3& n, double etai_over_etat) {
//     auto cos_theta = std::fmin(dot(-uv, n), 1.0);
//     vec3 r_out_perp =  etai_over_etat * (uv + cos_theta*n);
//     vec3 r_out_parallel = -std::sqrt(std::fabs(1.0 - r_out_perp.length_squared())) * n;
//     return r_out_perp + r_out_parallel;
// }
