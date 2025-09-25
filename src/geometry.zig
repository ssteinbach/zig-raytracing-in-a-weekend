const std = @import("std");

const vector = @import("vector.zig");
const ray = @import("ray.zig");
const utils = @import("utils.zig");
const ray_hit = @import("ray_hit.zig");
const material = @import("material.zig");

pub const Sphere = struct {
    name: []const u8 = "",
    center_worldspace : vector.Point3f,
    radius: vector.V3f.BaseType,
    mat: *const material.Material = &material.DEFAULT_LAMBERT,

    pub fn format(
        self: @This(),
        writer: *std.Io.Writer,
    ) !void 
    {
        try writer.print(
            "Sphere{{ {s}, {d} }}",
            .{
                self.center_worldspace,
                self.radius,
            },
        );
    }

    pub fn hit(
        self: @This(),
        r: ray.Ray,
        interval: utils.Interval,
    ) ?ray_hit.HitRecord
    {
        const oc = self.center_worldspace.sub(r.origin);
        const a = r.dir.length_squared();
        const h = r.dir.dot(oc);
        const c = oc.length_squared() - self.radius*self.radius;
        const discriminant = h*h - a*c;

        if (discriminant < 0)
        {
            return null;
        }

        const sqrtd = std.math.sqrt(discriminant);

        // Find the nearest root that lies in the acceptable range.
        var root = (h - sqrtd) / a;
        if (interval.surrounds(root) == false) 
        {
            root = (h + sqrtd) / a;
            if (interval.surrounds(root) == false)
            {
                return null;
            }
        }

        const p = r.at(root);

        return ray_hit.HitRecord.init_face_normal(
            p, 
            root,
            p.sub(self.center_worldspace).div(self.radius),
            self.mat,
            r,
        );
    }
};
