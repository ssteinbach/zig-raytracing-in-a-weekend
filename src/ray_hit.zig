//! Geometry library

const std = @import("std");

const vector = @import("vector.zig");
const ray = @import("ray.zig");
const geometry = @import("geometry.zig");
const utils = @import("utils.zig");


const BaseType = vector.V3f.BaseType;

/// represents a hit along a ray in the scene
pub const HitRecord = struct {
    /// hit point
    p: vector.Point3f,
    /// unit normal at the hit location
    normal: vector.V3f = .{},
    /// distance along the ray the hit occured
    t: BaseType,

    pub fn set_face_normal(
        self: *@This(),
        r: ray.Ray,
        outward_normal: vector.V3f,
    ) void
    {
        const front_face = r.dir.dot(outward_normal) < 0;
        self.*.normal = if (front_face) outward_normal else outward_normal.neg();
    }
};

pub const Hittable = union (enum) {
    sphere : geometry.Sphere,

    pub fn init(
        thing: anytype,
    ) Hittable
    {
        return switch (@TypeOf(thing)) {
            geometry.Sphere => .{ .sphere = thing },
            else => @compileError(
                "Type " ++ @typeName(@TypeOf(thing)) ++ " is not hittable."
                ),
                
        };
    }

    pub fn hit (
        self: @This(),
        r: ray.Ray,
        interval: utils.Interval,
    ) ?HitRecord
    {
        return switch (self) {
            inline else => |h| (
                if (@hasDecl(@TypeOf(h), "hit")) h.hit(
                    r,
                    interval,
                )
                else null
            ),
        };
    }

    pub fn format(
        self: @This(),
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void
    {
        return switch (self) {
            inline else => |h| (
                if (@hasDecl(@TypeOf(h), "format")) h.format(
                    fmt,
                    options,
                    writer
                )
                else {
                    std.debug.print(
                        "type: {s} has no format \n",
                        .{ @typeName(@TypeOf(h))}
                    );
                }
            ),
        };
    }
};

pub const HittableList = std.ArrayList(Hittable);
pub const HittableSlice = []Hittable;

