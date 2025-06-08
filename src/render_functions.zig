//! the "main" functions from RiaW

const std = @import("std");
const raytrace = @import("root.zig");
const ray = @import("ray.zig");
const vector = @import("vector.zig");
const comath_wrapper = @import("comath_wrapper.zig");

/// pointer to a render function
pub const render_fn = *const fn(
    std.mem.Allocator,
    *raytrace.Image_rgba_u8,
    usize,
) void;

/// fun way of cataloging the history of the renders that this project can make
pub const CHECKPOINTS:[]const render_fn = &[_]render_fn{
    image_1,
    image_2.render,
    image_3.render,
};

pub const CHECKPOINT_NAMES = [_][:0]const u8{
    "Image 1 (color over image)",
    "Image 2 (ray.y = color)",
    "Image 3 (sphere hit)",
};

/// main render function - this is where the "main" code from Raytracing in a
/// Weekend goes.
///
/// image 1: testing the image class, making a red-green gradient over the
///          image plane.  I added an offset that pushes hte gradient around
///          to test the imgui integration.
/// 
/// The render functions are named after name of the figures in the book
pub fn image_1(
    _: std.mem.Allocator,
    img: *raytrace.Image_rgba_u8,
    frame_number: usize,
) void
{
    const cols = img.width;
    const rows = img.height;

    const dim = vector.Color3f.init([_]usize{ cols, rows, 0});

    var x:usize = 0;
    while (x < cols)
        : (x += 1)
    {
        var y:usize = 0;
        while (y < rows)
            : (y += 1)
        {
            var pixel_color_f = comath_wrapper.eval(
                "(((p + f) % dim) / (dim - 1)) * 255.999",
                .{ 
                    .p = vector.Color3f.init([_]usize{x,y,0}),
                    .f = frame_number,
                    .dim = dim,
                }
            );
            pixel_color_f.z = 0;
            const pixel_color = pixel_color_f.as(u8);

            var pixel = img.pixel(x, y);

            pixel[0] = pixel_color.x;
            pixel[1] = pixel_color.y;
            pixel[2] = 0;
            pixel[3] = 255;
        }
    }
}

const image_2 = struct {
    pub fn ray_color(
        r: ray.Ray,
    ) vector.Color3f
    {
        const unit_dir = r.dir.unit_vector();
        const a = 0.5 * (unit_dir.y + 1.0);

        return comath_wrapper.lerp(
            a,
            vector.Color3f.init(1.0),
            vector.Color3f.init([_]f32{0.5, 0.7, 1.0}),
        );
    }

    const BaseType = vector.V3f.BaseType;


    pub fn render(
        _: std.mem.Allocator,
        img: *raytrace.Image_rgba_u8,
        _: usize,
    ) void
    {
        const aspect_ratio:vector.V3f.BaseType = 16.0 / 9.0;
        const image_width:usize = 400;

        const image_height:usize = @intFromFloat(
            @max(1.0, @as(BaseType, @floatFromInt(image_width)) / aspect_ratio)
        );

        const camera = struct {
            const focal_length : BaseType = 1.0;
            const viewport_height : BaseType = 2.0;
            const viewport_width : BaseType = (
                (viewport_height * image_width) / image_height
            );

            // camera at the origin
            const center = vector.Point3f.init(0);
        };

        const viewport_u: vector.V3f = .{ 
            .x = camera.viewport_width,
            .y = 0,
            .z = 0,
        };
        const viewport_v: vector.V3f = .{ 
            .x = 0,
            .y = -camera.viewport_height,
            .z = 0,
        };

        const pixel_delta_u = viewport_u.div(image_width);
        const pixel_delta_v = viewport_v.div(image_height);

        const viewport_upper_left = comath_wrapper.eval(
            "camera_center - v_fl - (v_u/2) - (v_v/2)",
            .{
                .camera_center = camera.center,
                .v_fl = vector.V3f.init([_]BaseType{0,0, camera.focal_length}),
                .v_u = viewport_u,
                .v_v = viewport_v,
            },
        );

        const pixel00_loc = comath_wrapper.eval(
            "v_ul + (pdu + pdv) * 0.5",
            .{
                .v_ul = viewport_upper_left,
                .pdu = pixel_delta_u,
                .pdv = pixel_delta_v,
            },
        );

        var j:usize = 0;
        while (j < image_height)
            : (j+=1)
        {
            var i:usize = 0;
            while (i < image_width)
                : (i+=1)
            {
                const pixel_center = comath_wrapper.eval(
                    "p00 + (p_du*i) + (p_dv * j)",
                    .{ 
                        .p00 = pixel00_loc,
                        .p_du = pixel_delta_u,
                        .p_dv = pixel_delta_v,
                        .i = i,
                        .j = j,
                    },
                );

                const r = ray.Ray{
                    .origin = camera.center,
                    .dir = pixel_center.sub(camera.center),
                };

                // scale and convert to output pixel format
                const pixel_color = ray_color(r).mul(255.999).as(u8);

                var pixel = img.pixel(i, j);

                pixel[0] = pixel_color.x;
                pixel[1] = pixel_color.y;
                pixel[2] = pixel_color.z;
                pixel[3] = 255;
            }
        }
    }
};

const Sphere = struct {
    center_worldspace : vector.Point3f,
    radius: vector.V3f.BaseType,
};

pub fn hit_sphere(
    s: Sphere,
    r: ray.Ray
) bool
{
    const oc = s.center_worldspace.sub(r.origin);
    const a = r.dir.dot(r.dir);
    const b = r.dir.dot(oc) * -2.0;
    const c = oc.dot(oc) - s.radius*s.radius;
    const discriminant = b*b - 4*a*c;
    return (discriminant >= 0);
}

const image_3 = struct {
    pub fn ray_color(
        r: ray.Ray,
    ) vector.Color3f
    {

        if (hit_sphere(.{ .center_worldspace  = .{ .x = 0, .y = 0, .z = -1 }, .radius = 0.5 }, r))
        {
            return vector.Color3f.init([_]f32{ 1, 0, 0});
        }

        const unit_dir = r.dir.unit_vector();
        const a = 0.5 * (unit_dir.y + 1.0);

        return comath_wrapper.lerp(
            a,
            vector.Color3f.init(1.0),
            vector.Color3f.init([_]f32{0.5, 0.7, 1.0}),
        );
    }

    const BaseType = vector.V3f.BaseType;


    pub fn render(
        _: std.mem.Allocator,
        img: *raytrace.Image_rgba_u8,
        _: usize,
    ) void
    {
        const aspect_ratio:vector.V3f.BaseType = 16.0 / 9.0;
        const image_width:usize = 400;

        const image_height:usize = @intFromFloat(
            @max(1.0, @as(BaseType, @floatFromInt(image_width)) / aspect_ratio)
        );

        const camera = struct {
            const focal_length : BaseType = 1.0;
            const viewport_height : BaseType = 2.0;
            const viewport_width : BaseType = (
                (viewport_height * image_width) / image_height
            );

            // camera at the origin
            const center = vector.Point3f.init(0);
        };

        const viewport_u: vector.V3f = .{ 
            .x = camera.viewport_width,
            .y = 0,
            .z = 0,
        };
        const viewport_v: vector.V3f = .{ 
            .x = 0,
            .y = -camera.viewport_height,
            .z = 0,
        };

        const pixel_delta_u = viewport_u.div(image_width);
        const pixel_delta_v = viewport_v.div(image_height);

        const viewport_upper_left = comath_wrapper.eval(
            "camera_center - v_fl - (v_u/2) - (v_v/2)",
            .{
                .camera_center = camera.center,
                .v_fl = vector.V3f.init([_]BaseType{0,0, camera.focal_length}),
                .v_u = viewport_u,
                .v_v = viewport_v,
            },
        );

        const pixel00_loc = comath_wrapper.eval(
            "v_ul + (pdu + pdv) * 0.5",
            .{
                .v_ul = viewport_upper_left,
                .pdu = pixel_delta_u,
                .pdv = pixel_delta_v,
            },
        );

        var j:usize = 0;
        while (j < image_height)
            : (j+=1)
        {
            var i:usize = 0;
            while (i < image_width)
                : (i+=1)
            {
                const pixel_center = comath_wrapper.eval(
                    "p00 + (p_du*i) + (p_dv * j)",
                    .{ 
                        .p00 = pixel00_loc,
                        .p_du = pixel_delta_u,
                        .p_dv = pixel_delta_v,
                        .i = i,
                        .j = j,
                    },
                );

                const r = ray.Ray{
                    .origin = camera.center,
                    .dir = pixel_center.sub(camera.center),
                };

                // scale and convert to output pixel format
                const pixel_color = ray_color(r).mul(255.999).as(u8);

                var pixel = img.pixel(i, j);

                pixel[0] = pixel_color.x;
                pixel[1] = pixel_color.y;
                pixel[2] = pixel_color.z;
                pixel[3] = 255;
            }
        }
    }
};
