//! Ray structure definition

const vector = @import("vector.zig");
const comath_wrapper = @import("comath_wrapper.zig");

const std = @import("std");

/// A ray through the world, with origin and direction
pub const Ray = struct {
    origin: vector.Point3f,
    dir: vector.V3f,

    /// compute the point along the ray at distance t from origin
    pub fn at(
        self: @This(),
        t: vector.V3f.BaseType,
    ) vector.Point3f
    {
        return comath_wrapper.eval(
            "self.origin + self.dir * t",
            .{ .self = self, .t = t },
        );
    }

    pub fn format(
        self: @This(),
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void 
    {
        try writer.print(
            "ray({s} -> {s})",
            .{ self.origin, self.dir },
        );
    }
};

test "at"
{
    const r = Ray{
        .origin = .{ .x = 0, .y = 0, .z = 0 },
        .dir = .{ .x = 1, .y = 1, .z = 1 },
    };

    try vector.expectV3fEqual(r.dir, r.at(1.0));

    try vector.expectV3fEqual(0.5, r.at(0.5));
}
