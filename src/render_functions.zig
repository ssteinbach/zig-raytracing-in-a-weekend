//! the "main" functions from RiaW

const std = @import("std");
const raytrace = @import("root.zig");
const ray = @import("ray.zig");
const ray_hit = @import("ray_hit.zig");
const vector = @import("vector.zig");
const comath_wrapper = @import("comath_wrapper.zig");
const utils = @import("utils.zig");
const geometry = @import("geometry.zig");
pub const img22 = @import("renderers/image_22.zig");
pub const img23 = @import("renderers/image_23.zig");

pub const BaseType = vector.V3f.BaseType;
pub const INF = std.math.inf(BaseType);

/// pointer to a render function
pub const render_fn = *const fn(
    std.mem.Allocator,
    *raytrace.Image_rgba_u8,
    usize,
) void;

/// list of all the renderers in the project.  Generally, each one corresponds
/// to a different image in the "Raytracing in a Weekend" book
pub const RENDERERS = [_]Renderer{
    Renderer.init(struct{ const render = display_check;}, "coordinate check"),
    Renderer.init(struct{ const render = image_1;}, "color over image"),
    Renderer.init(image_2, "ray.y = color"),
    Renderer.init(image_3, "geometry.sphere hit"),
    Renderer.init(image_4, "geometry.sphere color"),
    Renderer.init(image_5, "geometry.sphere color w/ ray_hit.Hittable"),
    Renderer.init(image_6, "Antialiasing"),
    Renderer.init(image_7, "Diffuse Sampling"),
    Renderer.init(image_8, "Limited bounces"),
    Renderer.init(image_9, "No Shadow Acne"),
    Renderer.init(image_10, "Correct Lambertian response"),
    Renderer.init(@import("renderers/image_11.zig").RNDR, "Gamut at the moment"),
    Renderer.init(@import("renderers/image_12.zig").RNDR, "Gamma Corrected Gamut"),
    Renderer.init(@import("renderers/image_13.zig").RNDR, "Shiny Metal"),
    Renderer.init(@import("renderers/image_14.zig").RNDR, "Fuzzed Metal"),
    Renderer.init(@import("renderers/image_16.zig").RNDR, "Glass"),
    Renderer.init(@import("renderers/image_17.zig").RNDR, "Air bubble sometimes refracts, sometimes reflects"),
    Renderer.init(@import("renderers/image_18.zig").RNDR, "Hollow Glass Sphere"),
    Renderer.init(@import("renderers/image_19.zig").RNDR, "Wide Angle View"),
    Renderer.init(@import("renderers/image_20.zig").RNDR, "A distant view"),
    Renderer.init(@import("renderers/image_21.zig").RNDR, "Zooming in"),
    Renderer.init(img22.RNDR, "Spheres with depth-of-field"),
    Renderer.init(@import("renderers/image_23.zig").RNDR, "Final scene"),
    // Renderer.init(@import("renderers/image_15.zig").RNDR, "Glass First"),
};

fn maybe_decl(
    comptime T: type,
    comptime name: []const u8,
    comptime fn_type: type,
) ?*const fn_type
{
    return (
        if (@hasDecl(T, name)) &@field(T, name) 
        else null
    );
}

pub const Renderer = struct {
    /// pointers
    _maybe_init: ?*const INITFN_TYPE = null,
    _render : *const fn (
        allocator: std.mem.Allocator,
        context: raytrace.RenderContext,
    ) void,
    _maybe_deinit: ?*const CLEANUPFNTYPE = null,
    /// description string
    desc: [:0]const u8,

    /// types
    pub const INITFN_TYPE = fn(
       allocator: std.mem.Allocator,
       img: *raytrace.Image_rgba_u8,
   ) void;
    pub const CLEANUPFNTYPE = fn() void;

    pub fn init(
        comptime T: type,
        comptime desc: [:0]const u8,
    ) Renderer
    {
        return .{
            .desc = desc,
            ._maybe_init = maybe_decl(T, "init", INITFN_TYPE),
            ._render = &@field(T, "render"),
            ._maybe_deinit = maybe_decl(T, "deinit", CLEANUPFNTYPE),
        };
    }
};

pub fn display_check(
    _: std.mem.Allocator,
    context: raytrace.RenderContext,
) void
{
    const cols = context.img.width;
    const rows = context.img.height;

    context.progress.store(0, .monotonic);

    var x:usize = 0;
    while (x < cols)
        : (x += 1)
    {
        var y:usize = 0;
        while (y < rows)
            : (y += 1)
        {
            const x_ratio = (
                @as(f32, @floatFromInt(x)) / @as(f32, @floatFromInt(cols))
            );
            const y_ratio = (
                @as(f32, @floatFromInt(y)) / @as(f32, @floatFromInt(rows))
            );

            const RAD = 3;
            const pixel_color_f = if (
                (x < RAD and y < RAD)
                or (x < RAD and y > rows - RAD)
                or (x > cols - RAD and y < RAD)
                or (x > cols - RAD and y > rows - RAD)
            )
                vector.Color3f.init([_]f32{0, 0, 1})
            else
                vector.Color3f.init([_]f32{x_ratio, y_ratio, 0});

            const pixel_color = pixel_color_f.mul(255.999).as(u8);

            var pixel = context.img.pixel(x, y);

            pixel[0] = pixel_color.x;
            pixel[1] = pixel_color.y;
            pixel[2] = pixel_color.z;
            pixel[3] = 255;
        }

        if (@mod(x, 20) == 0) 
        {
            context.progress.store(x * 100 / cols, .monotonic);
        }
    }
}

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
    context: raytrace.RenderContext,
) void
{
    const cols = context.img.width;
    const rows = context.img.height;

    context.progress.store(0, .monotonic);

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
                "(((v2(x,y) + f) % dim) / (dim - 1)) * 255.999",
                .{ .x = x, .y = y, .f = context.frame_number, .dim = dim, },
            );
            pixel_color_f.z = 0;
            const pixel_color = pixel_color_f.as(u8);

            var pixel = context.img.pixel(x, y);

            pixel[0] = pixel_color.x;
            pixel[1] = pixel_color.y;
            pixel[2] = 0;
            pixel[3] = 255;
        }

        if (@mod(x, 20) == 0) 
        {
            context.progress.store(x * 100 / cols, .monotonic);
        }
    }
}

const image_2 = struct {
    pub fn hit_sphere(
        s: geometry.Sphere,
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

    pub fn render(
        _: std.mem.Allocator,
        context: raytrace.RenderContext,
    ) void
    {
        context.progress.store(0, .monotonic);

        const aspect_ratio:vector.V3f.BaseType = @floatFromInt(context.img.width / context.img.height);
        const image_width:usize = context.img.width;

        const image_height:usize = @intFromFloat(
            @max(1.0, @as(BaseType, @floatFromInt(image_width)) / aspect_ratio)
        );

        const viewport_height : BaseType = 2.0;
        const viewport_width : BaseType = (
            ( viewport_height * @as(BaseType, @floatFromInt(image_width))) 
            / @as(BaseType, @floatFromInt(image_height))
        );

        const camera = struct {
            const focal_length : BaseType = 1.0;

            // camera at the origin
            const center = vector.Point3f.init(0);
        };

        const viewport_u: vector.V3f = .{ 
            .x = viewport_width,
            .y = 0,
            .z = 0,
        };
        const viewport_v: vector.V3f = .{ 
            .x = 0,
            .y = -viewport_height,
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
        while (j < context.img.height)
            : (j+=1)
        {
            var i:usize = 0;
            while (i < context.img.width)
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

                var pixel = context.img.pixel(i, j);

                pixel[0] = pixel_color.x;
                pixel[1] = pixel_color.y;
                pixel[2] = pixel_color.z;
                pixel[3] = 255;
            }

            context.progress.store(j*100/context.img.height, .monotonic);
        }
    }
};


const image_3 = struct {
    pub fn ray_color(
        r: ray.Ray,
    ) vector.Color3f
    {

        if (hit_sphere(.{ .center_worldspace  = .{ .x = 0, .y = 0, .z = -1 }, .radius = 0.5 }, r) != null)
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

    pub fn render(
        _: std.mem.Allocator,
        context: raytrace.RenderContext,
    ) void
    {
        context.progress.store(0, .monotonic);

        const image_width:usize = context.img.width;
        const image_height:usize = context.img.height;

        const viewport_height : BaseType = 2.0;
        const viewport_width : BaseType = (
            (
             viewport_height 
             * @as(BaseType, @floatFromInt(image_width))) / @as(BaseType, @floatFromInt(image_height))
            );

        const camera = struct {
            const focal_length : BaseType = 1.0;

            // camera at the origin
            const center = vector.Point3f.init(0);
        };

        const viewport_u: vector.V3f = .{ 
            .x = viewport_width,
            .y = 0,
            .z = 0,
        };
        const viewport_v: vector.V3f = .{ 
            .x = 0,
            .y = -viewport_height,
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

                var pixel = context.img.pixel(i, j);

                pixel[0] = pixel_color.x;
                pixel[1] = pixel_color.y;
                pixel[2] = pixel_color.z;
                pixel[3] = 255;
            }

            context.progress.store(j*100/context.img.height, .monotonic);
        }
    }
};

pub fn hit_sphere(
    s: geometry.Sphere,
    r: ray.Ray,
) ?BaseType
{
    const oc = s.center_worldspace.sub(r.origin);
    const a = r.dir.length_squared();
    const b = r.dir.dot(oc);
    const c = oc.length_squared() - s.radius*s.radius;
    const discriminant = b*b - a*c;

    if (discriminant < 0)
    {
        return null;
    }
    else 
    {
        return (b - std.math.sqrt(discriminant) ) / (a);
    }
}

const image_4 = struct {
    pub fn ray_color(
        r: ray.Ray,
    ) vector.Color3f
    {
        const maybe_t = hit_sphere(
            .{
                .center_worldspace = .{ .x = 0, .y = 0, .z = -1 },
                .radius = 0.5 
            },
            r
        );
        if (maybe_t) 
            |t|
        {
            return comath_wrapper.eval(
                "((r.at(t) - v3(0,0,-1)).unit_vector() + 1) * 0.5",
                .{ .r = r, .t = t },
            );
        }

        const unit_dir = r.dir.unit_vector();
        const a = 0.5 * (unit_dir.y + 1.0);

        return comath_wrapper.lerp(
            a,
            vector.Color3f.init(1.0),
            vector.Color3f.init([_]f32{0.5, 0.7, 1.0}),
        );
    }


    pub fn render(
        _: std.mem.Allocator,
        context: raytrace.RenderContext,
    ) void
    {
        context.progress.store(0, .monotonic);

        const image_width:usize = context.img.width;
        const image_height:usize = context.img.height;

        const viewport_height : BaseType = 2.0;
        const viewport_width : BaseType = (
            (
             viewport_height 
             * @as(BaseType, @floatFromInt(image_width))) / @as(BaseType, @floatFromInt(image_height))
            );

        const camera = struct {
            const focal_length : BaseType = 1.0;

            // camera at the origin
            const center = vector.Point3f.init(0);
        };

        const viewport_u: vector.V3f = .{ 
            .x = viewport_width,
            .y = 0,
            .z = 0,
        };
        const viewport_v: vector.V3f = .{ 
            .x = 0,
            .y = -viewport_height,
            .z = 0,
        };

        const pixel_delta_u = viewport_u.div(image_width);
        const pixel_delta_v = viewport_v.div(image_height);

        const viewport_upper_left = comath_wrapper.eval(
            "camera_center - v3(0,0,focal_length) - (v_u/2) - (v_v/2)",
            .{
                .camera_center = camera.center,
                .focal_length = camera.focal_length,
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

                var pixel = context.img.pixel(i, j);

                pixel[0] = pixel_color.x;
                pixel[1] = pixel_color.y;
                pixel[2] = pixel_color.z;
                pixel[3] = 255;
            }

            context.progress.store(j*100/context.img.height, .monotonic);
        }
    }
};

pub fn hit_world(
    args: struct {
        world: ray_hit.HittableSlice,
        r: ray.Ray,
        interval: utils.Interval,
    },
) ?ray_hit.HitRecord
{
    var maybe_first_hit : ?ray_hit.HitRecord = null;

    for (args.world)
        |it|
    {
        if (it.hit(args.r, args.interval))
            |hitrec|
        {
            if (maybe_first_hit == null or maybe_first_hit.?.t > hitrec.t)
            {
                maybe_first_hit = hitrec;
            }
        }
    }

    return maybe_first_hit;
}

const image_5 = struct {
    pub fn ray_color(
        r: ray.Ray,
        world: ray_hit.HittableList,
    ) vector.Color3f
    {
        if (
            hit_world(
                .{ 
                    .world = world.items,
                    .r = r,
                    .interval = utils.Interval.ZERO_TO_INF, 
                }
            ) 
        )
            |hitrec|
        {
            return comath_wrapper.eval(
                "(n + 1) * 0.5",
                .{ .n = hitrec.normal },
            );
        }

        const unit_dir = r.dir.unit_vector();
        const a = 0.5 * (unit_dir.y + 1.0);

        return comath_wrapper.lerp(
            a,
            vector.Color3f.init(1.0),
            vector.Color3f.init([_]f32{0.5, 0.7, 1.0}),
        );
    }

    pub fn render(
        allocator: std.mem.Allocator,
        context: raytrace.RenderContext,
    ) void
    {
        context.progress.store(0, .monotonic);

        // build the world
        var world = ray_hit.HittableList.init(allocator);
        defer world.deinit();

        world.append(
            ray_hit.Hittable.init(
                geometry.Sphere{
                    .center_worldspace = vector.V3f.init_3(0,0,-1),
                    .radius = 0.5,
                }
            )
        ) catch @panic("OOM!");
        world.append(
            ray_hit.Hittable.init(
                geometry.Sphere{
                    .center_worldspace = vector.V3f.init_3(0, -100.5,-1),
                    .radius = 100,
                }
            )
        ) catch @panic("OOM!");

        const image_width:usize = context.img.width;
        const image_height:usize = context.img.height;

        const viewport_height : BaseType = 2.0;
        const viewport_width : BaseType = (
            (
             viewport_height 
             * @as(BaseType, @floatFromInt(image_width))) / @as(BaseType, @floatFromInt(image_height))
            );

        const camera = struct {
            const focal_length : BaseType = 1.0;

            // camera at the origin
            const center = vector.Point3f.init(0);
        };

        const viewport_u: vector.V3f = .{ 
            .x = viewport_width,
            .y = 0,
            .z = 0,
        };
        const viewport_v: vector.V3f = .{ 
            .x = 0,
            .y = -viewport_height,
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
                const pixel_color = ray_color(r, world).mul(255.999).as(u8);

                var pixel = context.img.pixel(i, j);

                pixel[0] = pixel_color.x;
                pixel[1] = pixel_color.y;
                pixel[2] = pixel_color.z;
                pixel[3] = 255;
            }

            context.progress.store(j*100/context.img.height, .monotonic);
        }
    }
};

test "clamp"
{
    for (
        &[_]utils.Interval{
            utils.Interval{ .start = -3, .end = 5 }
        }
    ) |t_i|
    {
        for (
            &[_]BaseType{ -4, -1 , 0, 1, 6, 1231242342 }
        ) |t_ord|
        {
            try std.testing.expect(
                t_i.contains(
                    t_i.clamp(t_ord)
                )
            );

            try std.testing.expect(
                t_i.contains(
                    t_i.clamp(vector.V3f.init(t_ord))
                )
            );
        }
    }
}

const image_6 = struct {
    const Camera = struct {
        /// focal length of the camera (thin lens) of 1.0
        focal_length : BaseType = 1.0,
        /// camera at the origin by default
        center :vector.V3f = vector.Point3f.init(0),

        image_width: usize,
        image_height: usize,

        pixel00_loc: vector.Point3f,
        pixel_delta_u: vector.V3f,
        pixel_delta_v: vector.V3f,

        const samples_per_pixel:usize = 20;
        const pixel_sample_scale:BaseType = (
            1.0/@as(BaseType, @floatFromInt(samples_per_pixel))
        );

        pub fn init(
            focal_length: BaseType,
            center: vector.V3f,
            img: *raytrace.Image_rgba_u8,
        ) @This()
        {
            const image_width:usize = img.width;
            const image_height:usize = img.height;

            const viewport_height : BaseType = 2.0;
            const viewport_width : BaseType = (
                (
                 viewport_height 
                 * @as(BaseType, @floatFromInt(image_width))) / @as(BaseType, @floatFromInt(image_height))
            );

            const viewport_u: vector.V3f = .{ 
                .x = viewport_width,
                .y = 0,
                .z = 0,
            };
            const viewport_v: vector.V3f = .{ 
                .x = 0,
                .y = -viewport_height,
                .z = 0,
            };

            const viewport_upper_left = comath_wrapper.eval(
                "camera_center - v_fl - (v_u/2) - (v_v/2)",
                .{
                    .camera_center = center,
                    .v_fl = vector.V3f.init([_]BaseType{0,0, focal_length}),
                    .v_u = viewport_u,
                    .v_v = viewport_v,
                },
                );

            const pixel_delta_u = viewport_u.div(image_width);
            const pixel_delta_v = viewport_v.div(image_height);

            return .{
                .center = center,
                .focal_length = focal_length,
                .image_width = image_width,
                .image_height = image_height,
                .pixel_delta_u = pixel_delta_u,
                .pixel_delta_v = pixel_delta_v,
                .pixel00_loc = comath_wrapper.eval(
                    "v_ul + (pdu + pdv) * 0.5",
                    .{
                        .v_ul = viewport_upper_left,
                        .pdu = pixel_delta_u,
                        .pdv = pixel_delta_v,
                    },
                ),
            };
        }

        pub fn ray_color(
            r: ray.Ray,
            world: ray_hit.HittableSlice,
        ) vector.Color3f
        {
            if (
                hit_world(
                    .{ 
                        .world = world,
                        .r = r,
                        .interval = utils.Interval.ZERO_TO_INF,
                    }
                ) 
            )
                |hitrec|
            {
                return comath_wrapper.eval(
                    "(n + 1) * 0.5",
                    .{ .n = hitrec.normal },
                );
            }

            const a = 0.5 * (r.dir.unit_vector().y + 1.0);

            return comath_wrapper.lerp(
                a,
                vector.Color3f.init(1.0),
                vector.Color3f.init([_]f32{0.5, 0.7, 1.0}),
            );
        }

        pub fn render(
            self: @This(),
            world: ray_hit.HittableSlice,
            img: *raytrace.Image_rgba_u8,
            progress: *std.atomic.Value(usize),
        ) void
        {
            progress.store(0, .monotonic);

            var j:usize = 0;
            while (j < self.image_height)
                : (j+=1)
            {
                var i:usize = 0;
                while (i < self.image_width)
                    : (i+=1)
                {
                    var pixel_color = vector.Color3f.init(0);

                    var sample: usize = 0;
                    while (sample < samples_per_pixel)
                        : (sample += 1)
                    {
                        const r = self.get_ray(
                            @floatFromInt(i),
                            @floatFromInt(j)
                        );

                        // scale and convert to output pixel foormat
                        pixel_color = pixel_color.add(ray_color(r, world));
                    }
                    img.write_pixel(i,j, pixel_color.mul(pixel_sample_scale));

                }
                progress.store(j*100/self.image_height, .monotonic);
            }

        }

        fn get_ray(
            self: @This(),
            i: BaseType,
            j: BaseType,
        ) ray.Ray 
        {
            const offset = sample_square();
            const pixel_sample = comath_wrapper.eval(
                "p00 + (pdu*(i + o_x)) + (pdv*(j+o_y))",
                .{
                    .p00 = self.pixel00_loc,
                    .i = i,
                    .j = j,
                    .o_x = offset.x,
                    .o_y = offset.y,
                    .pdu = self.pixel_delta_u,
                    .pdv = self.pixel_delta_v,
                },
            );

            return .{
                .origin = self.center,
                .dir = pixel_sample.sub(self.center),
            };
        }

        fn sample_square() vector.V3f
        {
            return .{
                .x = utils.rnd_num(BaseType) - 0.5,
                .y = utils.rnd_num(BaseType) - 0.5,
                .z = 0
            };
        }
    };

    pub const State = struct {
        world: ray_hit.HittableSlice,
        camera: Camera,
        allocator: std.mem.Allocator,

        pub fn init(
            allocator: std.mem.Allocator,
            img: *raytrace.Image_rgba_u8,
        ) State
        {
            // build the world
            var world = ray_hit.HittableList.init(allocator);
            defer world.deinit();

            world.append(
                ray_hit.Hittable.init(
                    geometry.Sphere{
                        .center_worldspace = vector.V3f.init_3(0,0,-1),
                        .radius = 0.5,
                    }
                )
            ) catch @panic("OOM!");
            world.append(
                ray_hit.Hittable.init(
                    geometry.Sphere{
                        .center_worldspace = vector.V3f.init_3(0, -100.5,-1),
                        .radius = 100,
                    }
                )
            ) catch @panic("OOM!");

            const camera = Camera.init(
                1.0,
                // camera at the origin
                vector.Point3f.init(0),
                img,
            );

            return .{
                .camera = camera,
                .world =  world.toOwnedSlice() catch @panic("OOM"),
                .allocator = allocator,
            };
        }

        pub fn render(
            self: @This(),
            img: *raytrace.Image_rgba_u8,
            progress: *std.atomic.Value(usize),
        ) void
        {
            self.camera.render(self.world, img, progress);
        }

        pub fn deinit(
            self: @This(),
        ) void
        {
            self.allocator.free(self.world);
        }
    };
    var state: ?State = null;

    pub fn render(
        allocator: std.mem.Allocator,
        context: raytrace.RenderContext,
    ) void
    {
        if (state == null)
        {
            state = State.init(allocator, context.img);
        }

        state.?.render(context.img, context.progress);
    }

    pub fn init(
       allocator: std.mem.Allocator,
       img: *raytrace.Image_rgba_u8,
    ) void
    {
        state = State.init(allocator, img);
    }

    pub fn deinit(
    ) void
    {
        if (state)
            |definitely_state|
        {
            definitely_state.deinit();
        }
        state = null;
    }
};

const image_7 = struct {
    const Camera = struct {
        /// focal length of the camera (thin lens) of 1.0
        focal_length : BaseType = 1.0,
        /// camera at the origin by default
        center :vector.V3f = vector.Point3f.init(0),

        image_width: usize,
        image_height: usize,

        pixel00_loc: vector.Point3f,
        pixel_delta_u: vector.V3f,
        pixel_delta_v: vector.V3f,

        const samples_per_pixel:usize = 10;
        const pixel_sample_scale:BaseType = (
            1.0/@as(BaseType, @floatFromInt(samples_per_pixel))
        );

        pub fn init(
            focal_length: BaseType,
            center: vector.V3f,
            img: *raytrace.Image_rgba_u8,
        ) @This()
        {
            const image_width:usize = img.width;
            const image_height:usize = img.height;

            const viewport_height : BaseType = 2.0;
            const viewport_width : BaseType = (
                (
                 viewport_height 
                 * @as(BaseType, @floatFromInt(image_width))) / @as(BaseType, @floatFromInt(image_height))
            );

            const viewport_u: vector.V3f = .{ 
                .x = viewport_width,
                .y = 0,
                .z = 0,
            };
            const viewport_v: vector.V3f = .{ 
                .x = 0,
                .y = -viewport_height,
                .z = 0,
            };

            const viewport_upper_left = comath_wrapper.eval(
                "camera_center - v_fl - (v_u/2) - (v_v/2)",
                .{
                    .camera_center = center,
                    .v_fl = vector.V3f.init([_]BaseType{0,0, focal_length}),
                    .v_u = viewport_u,
                    .v_v = viewport_v,
                },
                );

            const pixel_delta_u = viewport_u.div(image_width);
            const pixel_delta_v = viewport_v.div(image_height);

            return .{
                .center = center,
                .focal_length = focal_length,
                .image_width = image_width,
                .image_height = image_height,
                .pixel_delta_u = pixel_delta_u,
                .pixel_delta_v = pixel_delta_v,
                .pixel00_loc = comath_wrapper.eval(
                    "v_ul + (pdu + pdv) * 0.5",
                    .{
                        .v_ul = viewport_upper_left,
                        .pdu = pixel_delta_u,
                        .pdv = pixel_delta_v,
                    },
                ),
            };
        }

        pub fn ray_color(
            r: ray.Ray,
            world: ray_hit.HittableSlice,
        ) vector.Color3f
        {
            if (
                hit_world(
                    .{ 
                        .world = world,
                        .r = r,
                        .interval = utils.Interval.ZERO_TO_INF,
                    }
                ) 
            )
                |hitrec|
            {
                const dir = utils.random_on_hemisphere(hitrec.normal);
                return ray_color(
                    .{ .origin = hitrec.p, .dir = dir},
                    world,
                ).mul(0.5);
            }

            const a = 0.5 * (r.dir.unit_vector().y + 1.0);

            return comath_wrapper.lerp(
                a,
                vector.Color3f.init(1.0),
                vector.Color3f.init([_]f32{0.5, 0.7, 1.0}),
            );
        }

        pub fn render(
            self: @This(),
            world: ray_hit.HittableSlice,
            img: *raytrace.Image_rgba_u8,
            progress: *std.atomic.Value(usize),
        ) void
        {
            progress.store(0, .monotonic);

            var j:usize = 0;
            while (j < self.image_height)
                : (j+=1)
            {
                var i:usize = 0;
                while (i < self.image_width)
                    : (i+=1)
                {
                    var pixel_color = vector.Color3f.init(0);

                    var sample: usize = 0;
                    while (sample < samples_per_pixel)
                        : (sample += 1)
                    {
                        const r = self.get_ray(
                            @floatFromInt(i),
                            @floatFromInt(j)
                        );

                        // scale and convert to output pixel foormat
                        pixel_color = pixel_color.add(ray_color(
                                r,
                                world,
                            )
                        );
                    }
                    img.write_pixel(i,j, pixel_color.mul(pixel_sample_scale));

                }
                progress.store(j*100/self.image_height, .monotonic);
            }

        }

        fn get_ray(
            self: @This(),
            i: BaseType,
            j: BaseType,
        ) ray.Ray 
        {
            const offset = sample_square();
            const pixel_sample = comath_wrapper.eval(
                "p00 + (pdu*(i + o_x)) + (pdv*(j+o_y))",
                .{
                    .p00 = self.pixel00_loc,
                    .i = i,
                    .j = j,
                    .o_x = offset.x,
                    .o_y = offset.y,
                    .pdu = self.pixel_delta_u,
                    .pdv = self.pixel_delta_v,
                },
            );

            return .{
                .origin = self.center,
                .dir = pixel_sample.sub(self.center),
            };
        }

        fn sample_square() vector.V3f
        {
            return .{
                .x = utils.rnd_num(BaseType) - 0.5,
                .y = utils.rnd_num(BaseType) - 0.5,
                .z = 0
            };
        }
    };

    pub const State = struct {
        world: ray_hit.HittableSlice,
        camera: Camera,
        allocator: std.mem.Allocator,

        pub fn init(
            allocator: std.mem.Allocator,
            img: *raytrace.Image_rgba_u8,
        ) State
        {
            // build the world
            var world = ray_hit.HittableList.init(allocator);
            defer world.deinit();

            world.append(
                ray_hit.Hittable.init(
                    geometry.Sphere{
                        .center_worldspace = vector.V3f.init_3(0,0,-1),
                        .radius = 0.5,
                    }
                )
            ) catch @panic("OOM!");
            world.append(
                ray_hit.Hittable.init(
                    geometry.Sphere{
                        .center_worldspace = vector.V3f.init_3(0, -100.5,-1),
                        .radius = 100,
                    }
                )
            ) catch @panic("OOM!");

            const camera = Camera.init(
                1.0,
                // camera at the origin
                vector.Point3f.init(0),
                img,
            );

            return .{
                .camera = camera,
                .world =  world.toOwnedSlice() catch @panic("OOM"),
                .allocator = allocator,
            };
        }

        pub fn render(
            self: @This(),
            img: *raytrace.Image_rgba_u8,
            progress: *std.atomic.Value(usize),
        ) void
        {
            self.camera.render(self.world, img, progress);
        }

        pub fn deinit(
            self: @This(),
        ) void
        {
            self.allocator.free(self.world);
        }
    };
    var state: ?State = null;

    pub fn render(
        allocator: std.mem.Allocator,
        context: raytrace.RenderContext,
    ) void
    {
        if (state == null)
        {
            state = State.init(allocator, context.img);
        }

        state.?.render(context.img, context.progress);
    }

    pub fn init(
       allocator: std.mem.Allocator,
       img: *raytrace.Image_rgba_u8,
    ) void
    {
        state = State.init(allocator, img);
    }

    pub fn deinit(
    ) void
    {
        if (state)
            |definitely_state|
        {
            definitely_state.deinit();
        }
        state = null;
    }
};

const image_8 = struct {
    const Camera = struct {
        /// focal length of the camera (thin lens) of 1.0
        focal_length : BaseType = 1.0,
        /// camera at the origin by default
        center :vector.V3f = vector.Point3f.init(0),

        image_width: usize,
        image_height: usize,

        pixel00_loc: vector.Point3f,
        pixel_delta_u: vector.V3f,
        pixel_delta_v: vector.V3f,

        const samples_per_pixel:usize = 10;
        const pixel_sample_scale:BaseType = (
            1.0/@as(BaseType, @floatFromInt(samples_per_pixel))
        );

        // maximum number of ray bounces
        const max_depth = 10;

        pub fn init(
            focal_length: BaseType,
            center: vector.V3f,
            img: *raytrace.Image_rgba_u8,
        ) @This()
        {
            const image_width:usize = img.width;
            const image_height:usize = img.height;

            const viewport_height : BaseType = 2.0;
            const viewport_width : BaseType = (
                (
                 viewport_height 
                 * @as(BaseType, @floatFromInt(image_width))) / @as(BaseType, @floatFromInt(image_height))
            );

            const viewport_u: vector.V3f = .{ 
                .x = viewport_width,
                .y = 0,
                .z = 0,
            };
            const viewport_v: vector.V3f = .{ 
                .x = 0,
                .y = -viewport_height,
                .z = 0,
            };

            const viewport_upper_left = comath_wrapper.eval(
                "camera_center - v_fl - (v_u/2) - (v_v/2)",
                .{
                    .camera_center = center,
                    .v_fl = vector.V3f.init([_]BaseType{0,0, focal_length}),
                    .v_u = viewport_u,
                    .v_v = viewport_v,
                },
                );

            const pixel_delta_u = viewport_u.div(image_width);
            const pixel_delta_v = viewport_v.div(image_height);

            return .{
                .center = center,
                .focal_length = focal_length,
                .image_width = image_width,
                .image_height = image_height,
                .pixel_delta_u = pixel_delta_u,
                .pixel_delta_v = pixel_delta_v,
                .pixel00_loc = comath_wrapper.eval(
                    "v_ul + (pdu + pdv) * 0.5",
                    .{
                        .v_ul = viewport_upper_left,
                        .pdu = pixel_delta_u,
                        .pdv = pixel_delta_v,
                    },
                ),
            };
        }

        pub fn ray_color(
            r: ray.Ray,
            depth: i16,
            world: ray_hit.HittableSlice,
        ) vector.Color3f
        {
            if (depth <= 0)
            {
                return vector.Color3f.ZERO;
            }

            if (
                hit_world(
                    .{ 
                        .world = world,
                        .r = r,
                        .interval = utils.Interval.ZERO_TO_INF,
                    }
                ) 
            )
                |hitrec|
            {
                const dir = utils.random_on_hemisphere(hitrec.normal);
                return ray_color(
                    .{ .origin = hitrec.p, .dir = dir},
                    depth - 1,
                    world,
                ).mul(0.5);
            }

            const a = 0.5 * (r.dir.unit_vector().y + 1.0);

            return comath_wrapper.lerp(
                a,
                vector.Color3f.init(1.0),
                vector.Color3f.init([_]f32{0.5, 0.7, 1.0}),
            );
        }

        pub fn render(
            self: @This(),
            world: ray_hit.HittableSlice,
            img: *raytrace.Image_rgba_u8,
            progress: *std.atomic.Value(usize),
        ) void
        {
            progress.store(0, .monotonic);

            var j:usize = 0;
            while (j < self.image_height)
                : (j+=1)
            {
                var i:usize = 0;
                while (i < self.image_width)
                    : (i+=1)
                {
                    var pixel_color = vector.Color3f.init(0);

                    var sample: usize = 0;
                    while (sample < samples_per_pixel)
                        : (sample += 1)
                    {
                        const r = self.get_ray(
                            @floatFromInt(i),
                            @floatFromInt(j)
                        );

                        // scale and convert to output pixel foormat
                        pixel_color = pixel_color.add(ray_color(
                                r,
                                max_depth,
                                world,
                            )
                        );
                    }
                    img.write_pixel(i,j, pixel_color.mul(pixel_sample_scale));

                }
                progress.store(j*100/self.image_height, .monotonic);
            }

        }

        fn get_ray(
            self: @This(),
            i: BaseType,
            j: BaseType,
        ) ray.Ray 
        {
            const offset = sample_square();
            const pixel_sample = comath_wrapper.eval(
                "p00 + (pdu*(i + o_x)) + (pdv*(j+o_y))",
                .{
                    .p00 = self.pixel00_loc,
                    .i = i,
                    .j = j,
                    .o_x = offset.x,
                    .o_y = offset.y,
                    .pdu = self.pixel_delta_u,
                    .pdv = self.pixel_delta_v,
                },
            );

            return .{
                .origin = self.center,
                .dir = pixel_sample.sub(self.center),
            };
        }

        fn sample_square() vector.V3f
        {
            return .{
                .x = utils.rnd_num(BaseType) - 0.5,
                .y = utils.rnd_num(BaseType) - 0.5,
                .z = 0
            };
        }
    };

    pub const State = struct {
        world: ray_hit.HittableSlice,
        camera: Camera,
        allocator: std.mem.Allocator,

        pub fn init(
            allocator: std.mem.Allocator,
            img: *raytrace.Image_rgba_u8,
        ) State
        {
            // build the world
            var world = ray_hit.HittableList.init(allocator);
            defer world.deinit();

            world.append(
                ray_hit.Hittable.init(
                    geometry.Sphere{
                        .center_worldspace = vector.V3f.init_3(0,0,-1),
                        .radius = 0.5,
                    }
                )
            ) catch @panic("OOM!");
            world.append(
                ray_hit.Hittable.init(
                    geometry.Sphere{
                        .center_worldspace = vector.V3f.init_3(0, -100.5,-1),
                        .radius = 100,
                    }
                )
            ) catch @panic("OOM!");

            const camera = Camera.init(
                1.0,
                // camera at the origin
                vector.Point3f.init(0),
                img,
            );

            return .{
                .camera = camera,
                .world =  world.toOwnedSlice() catch @panic("OOM"),
                .allocator = allocator,
            };
        }

        pub fn render(
            self: @This(),
            img: *raytrace.Image_rgba_u8,
            progress: *std.atomic.Value(usize),
        ) void
        {
            self.camera.render(self.world, img, progress);
        }

        pub fn deinit(
            self: @This(),
        ) void
        {
            self.allocator.free(self.world);
        }
    };
    var state: ?State = null;

    pub fn render(
        allocator: std.mem.Allocator,
        context: raytrace.RenderContext,
    ) void
    {
        if (state == null)
        {
            state = State.init(allocator, context.img);
        }

        state.?.render(context.img, context.progress);
    }

    pub fn init(
       allocator: std.mem.Allocator,
       img: *raytrace.Image_rgba_u8,
    ) void
    {
        state = State.init(allocator, img);
    }

    pub fn deinit(
    ) void
    {
        if (state)
            |definitely_state|
        {
            definitely_state.deinit();
        }
        state = null;
    }
};

const image_9 = struct {
    const Camera = struct {
        /// focal length of the camera (thin lens) of 1.0
        focal_length : BaseType = 1.0,
        /// camera at the origin by default
        center :vector.V3f = vector.Point3f.init(0),

        image_width: usize,
        image_height: usize,

        pixel00_loc: vector.Point3f,
        pixel_delta_u: vector.V3f,
        pixel_delta_v: vector.V3f,

        const samples_per_pixel:usize = 10;
        const pixel_sample_scale:BaseType = (
            1.0/@as(BaseType, @floatFromInt(samples_per_pixel))
        );

        // maximum number of ray bounces
        const max_depth = 10;

        pub fn init(
            focal_length: BaseType,
            center: vector.V3f,
            img: *raytrace.Image_rgba_u8,
        ) @This()
        {
            const image_width:usize = img.width;
            const image_height:usize = img.height;

            const viewport_height : BaseType = 2.0;
            const viewport_width : BaseType = (
                (
                 viewport_height 
                 * @as(BaseType, @floatFromInt(image_width))) / @as(BaseType, @floatFromInt(image_height))
            );

            const viewport_u: vector.V3f = .{ 
                .x = viewport_width,
                .y = 0,
                .z = 0,
            };
            const viewport_v: vector.V3f = .{ 
                .x = 0,
                .y = -viewport_height,
                .z = 0,
            };

            const viewport_upper_left = comath_wrapper.eval(
                "camera_center - v_fl - (v_u/2) - (v_v/2)",
                .{
                    .camera_center = center,
                    .v_fl = vector.V3f.init([_]BaseType{0,0, focal_length}),
                    .v_u = viewport_u,
                    .v_v = viewport_v,
                },
                );

            const pixel_delta_u = viewport_u.div(image_width);
            const pixel_delta_v = viewport_v.div(image_height);

            return .{
                .center = center,
                .focal_length = focal_length,
                .image_width = image_width,
                .image_height = image_height,
                .pixel_delta_u = pixel_delta_u,
                .pixel_delta_v = pixel_delta_v,
                .pixel00_loc = comath_wrapper.eval(
                    "v_ul + (pdu + pdv) * 0.5",
                    .{
                        .v_ul = viewport_upper_left,
                        .pdu = pixel_delta_u,
                        .pdv = pixel_delta_v,
                    },
                ),
            };
        }

        pub fn ray_color(
            r: ray.Ray,
            depth: i16,
            world: ray_hit.HittableSlice,
        ) vector.Color3f
        {
            if (depth <= 0)
            {
                return vector.Color3f.ZERO;
            }

            if (
                hit_world(
                    .{ 
                        .world = world,
                        .r = r,
                        .interval = utils.Interval.EPS_TO_INF,
                    }
                ) 
            )
                |hitrec|
            {
                const dir = utils.random_on_hemisphere(hitrec.normal);
                return ray_color(
                    .{ .origin = hitrec.p, .dir = dir},
                    depth - 1,
                    world,
                ).mul(0.5);
            }

            const a = 0.5 * (r.dir.unit_vector().y + 1.0);

            return comath_wrapper.lerp(
                a,
                vector.Color3f.init(1.0),
                vector.Color3f.init([_]f32{0.5, 0.7, 1.0}),
            );
        }

        pub fn render(
            self: @This(),
            world: ray_hit.HittableSlice,
            img: *raytrace.Image_rgba_u8,
            progress: *std.atomic.Value(usize),
        ) void
        {
            progress.store(0, .monotonic);

            var j:usize = 0;
            while (j < self.image_height)
                : (j+=1)
            {
                var i:usize = 0;
                while (i < self.image_width)
                    : (i+=1)
                {
                    var pixel_color = vector.Color3f.init(0);

                    var sample: usize = 0;
                    while (sample < samples_per_pixel)
                        : (sample += 1)
                    {
                        const r = self.get_ray(
                            @floatFromInt(i),
                            @floatFromInt(j)
                        );

                        // scale and convert to output pixel foormat
                        pixel_color = pixel_color.add(ray_color(
                                r,
                                max_depth,
                                world,
                            )
                        );
                    }
                    img.write_pixel(i,j, pixel_color.mul(pixel_sample_scale));

                }
                progress.store(j*100/self.image_height, .monotonic);
            }

        }

        fn get_ray(
            self: @This(),
            i: BaseType,
            j: BaseType,
        ) ray.Ray 
        {
            const offset = sample_square();
            const pixel_sample = comath_wrapper.eval(
                "p00 + (pdu*(i + o_x)) + (pdv*(j+o_y))",
                .{
                    .p00 = self.pixel00_loc,
                    .i = i,
                    .j = j,
                    .o_x = offset.x,
                    .o_y = offset.y,
                    .pdu = self.pixel_delta_u,
                    .pdv = self.pixel_delta_v,
                },
            );

            return .{
                .origin = self.center,
                .dir = pixel_sample.sub(self.center),
            };
        }

        fn sample_square() vector.V3f
        {
            return .{
                .x = utils.rnd_num(BaseType) - 0.5,
                .y = utils.rnd_num(BaseType) - 0.5,
                .z = 0
            };
        }
    };

    pub const State = struct {
        world: ray_hit.HittableSlice,
        camera: Camera,
        allocator: std.mem.Allocator,

        pub fn init(
            allocator: std.mem.Allocator,
            img: *raytrace.Image_rgba_u8,
        ) State
        {
            // build the world
            var world = ray_hit.HittableList.init(allocator);
            defer world.deinit();

            world.append(
                ray_hit.Hittable.init(
                    geometry.Sphere{
                        .center_worldspace = vector.V3f.init_3(0,0,-1),
                        .radius = 0.5,
                    }
                )
            ) catch @panic("OOM!");
            world.append(
                ray_hit.Hittable.init(
                    geometry.Sphere{
                        .center_worldspace = vector.V3f.init_3(0, -100.5,-1),
                        .radius = 100,
                    }
                )
            ) catch @panic("OOM!");

            const camera = Camera.init(
                1.0,
                // camera at the origin
                vector.Point3f.init(0),
                img,
            );

            return .{
                .camera = camera,
                .world =  world.toOwnedSlice() catch @panic("OOM"),
                .allocator = allocator,
            };
        }

        pub fn render(
            self: @This(),
            img: *raytrace.Image_rgba_u8,
            progress: *std.atomic.Value(usize),
        ) void
        {
            self.camera.render(self.world, img, progress);
        }

        pub fn deinit(
            self: @This(),
        ) void
        {
            self.allocator.free(self.world);
        }
    };
    var state: ?State = null;

    pub fn render(
        allocator: std.mem.Allocator,
        context: raytrace.RenderContext,
    ) void
    {
        if (state == null)
        {
            state = State.init(allocator, context.img);
        }

        state.?.render(context.img, context.progress);
    }

    pub fn init(
       allocator: std.mem.Allocator,
       img: *raytrace.Image_rgba_u8,
    ) void 
    {
        state = State.init(allocator, img);
    }

    pub fn deinit(
    ) void
    {
        if (state)
            |definitely_state|
        {
            definitely_state.deinit();
        }
        state = null;
    }
};

const image_10 = struct {
    const Camera = struct {
        /// focal length of the camera (thin lens) of 1.0
        focal_length : BaseType = 1.0,
        /// camera at the origin by default
        center :vector.V3f = vector.Point3f.init(0),

        image_width: usize,
        image_height: usize,

        pixel00_loc: vector.Point3f,
        pixel_delta_u: vector.V3f,
        pixel_delta_v: vector.V3f,

        const samples_per_pixel:usize = 10;
        const pixel_sample_scale:BaseType = (
            1.0/@as(BaseType, @floatFromInt(samples_per_pixel))
        );

        // maximum number of ray bounces
        const max_depth = 10;

        pub fn init(
            focal_length: BaseType,
            center: vector.V3f,
            img: *raytrace.Image_rgba_u8,
        ) @This()
        {
            const image_width:usize = img.width;
            const image_height:usize = img.height;

            const viewport_height : BaseType = 2.0;
            const viewport_width : BaseType = (
                (
                 viewport_height 
                 * @as(BaseType, @floatFromInt(image_width))) / @as(BaseType, @floatFromInt(image_height))
            );

            const viewport_u: vector.V3f = .{ 
                .x = viewport_width,
                .y = 0,
                .z = 0,
            };
            const viewport_v: vector.V3f = .{ 
                .x = 0,
                .y = -viewport_height,
                .z = 0,
            };

            const viewport_upper_left = comath_wrapper.eval(
                "camera_center - v_fl - (v_u/2) - (v_v/2)",
                .{
                    .camera_center = center,
                    .v_fl = vector.V3f.init([_]BaseType{0,0, focal_length}),
                    .v_u = viewport_u,
                    .v_v = viewport_v,
                },
                );

            const pixel_delta_u = viewport_u.div(image_width);
            const pixel_delta_v = viewport_v.div(image_height);

            return .{
                .center = center,
                .focal_length = focal_length,
                .image_width = image_width,
                .image_height = image_height,
                .pixel_delta_u = pixel_delta_u,
                .pixel_delta_v = pixel_delta_v,
                .pixel00_loc = comath_wrapper.eval(
                    "v_ul + (pdu + pdv) * 0.5",
                    .{
                        .v_ul = viewport_upper_left,
                        .pdu = pixel_delta_u,
                        .pdv = pixel_delta_v,
                    },
                ),
            };
        }

        pub fn ray_color(
            r: ray.Ray,
            depth: i16,
            world: ray_hit.HittableSlice,
        ) vector.Color3f
        {
            if (depth <= 0)
            {
                return vector.Color3f.ZERO;
            }

            if (
                hit_world(
                    .{ 
                        .world = world,
                        .r = r,
                        .interval = utils.Interval.EPS_TO_INF,
                    }
                ) 
            )
                |hitrec|
            {
                const dir = hitrec.normal.add(utils.random_unit_vector());
                return ray_color(
                    .{ .origin = hitrec.p, .dir = dir},
                    depth - 1,
                    world,
                ).mul(0.5);
            }

            const a = 0.5 * (r.dir.unit_vector().y + 1.0);

            return comath_wrapper.lerp(
                a,
                vector.Color3f.init(1.0),
                vector.Color3f.init([_]f32{0.5, 0.7, 1.0}),
            );
        }

        pub fn render(
            self: @This(),
            world: ray_hit.HittableSlice,
            img: *raytrace.Image_rgba_u8,
            progress: *std.atomic.Value(usize),
        ) void
        {
            progress.store(0, .monotonic);

            var j:usize = 0;
            while (j < self.image_height)
                : (j+=1)
            {
                var i:usize = 0;
                while (i < self.image_width)
                    : (i+=1)
                {
                    var pixel_color = vector.Color3f.init(0);

                    var sample: usize = 0;
                    while (sample < samples_per_pixel)
                        : (sample += 1)
                    {
                        const r = self.get_ray(
                            @floatFromInt(i),
                            @floatFromInt(j)
                        );

                        // scale and convert to output pixel foormat
                        pixel_color = pixel_color.add(ray_color(
                                r,
                                max_depth,
                                world,
                            )
                        );
                    }
                    img.write_pixel(i,j, pixel_color.mul(pixel_sample_scale));

                }
                progress.store(j*100/self.image_height, .monotonic);
            }

        }

        fn get_ray(
            self: @This(),
            i: BaseType,
            j: BaseType,
        ) ray.Ray 
        {
            const offset = sample_square();
            const pixel_sample = comath_wrapper.eval(
                "p00 + (pdu*(i + o_x)) + (pdv*(j+o_y))",
                .{
                    .p00 = self.pixel00_loc,
                    .i = i,
                    .j = j,
                    .o_x = offset.x,
                    .o_y = offset.y,
                    .pdu = self.pixel_delta_u,
                    .pdv = self.pixel_delta_v,
                },
            );

            return .{
                .origin = self.center,
                .dir = pixel_sample.sub(self.center),
            };
        }

        fn sample_square() vector.V3f
        {
            return .{
                .x = utils.rnd_num(BaseType) - 0.5,
                .y = utils.rnd_num(BaseType) - 0.5,
                .z = 0
            };
        }
    };

    pub const State = struct {
        world: ray_hit.HittableSlice,
        camera: Camera,
        allocator: std.mem.Allocator,

        pub fn init(
            allocator: std.mem.Allocator,
            img: *raytrace.Image_rgba_u8,
        ) State
        {
            // build the world
            var world = ray_hit.HittableList.init(allocator);
            defer world.deinit();

            world.append(
                ray_hit.Hittable.init(
                    geometry.Sphere{
                        .center_worldspace = vector.V3f.init_3(0,0,-1),
                        .radius = 0.5,
                    }
                )
            ) catch @panic("OOM!");
            world.append(
                ray_hit.Hittable.init(
                    geometry.Sphere{
                        .center_worldspace = vector.V3f.init_3(0, -100.5,-1),
                        .radius = 100,
                    }
                )
            ) catch @panic("OOM!");

            const camera = Camera.init(
                1.0,
                // camera at the origin
                vector.Point3f.init(0),
                img,
            );

            return .{
                .camera = camera,
                .world =  world.toOwnedSlice() catch @panic("OOM"),
                .allocator = allocator,
            };
        }

        pub fn render(
            self: @This(),
            img: *raytrace.Image_rgba_u8,
            progress: *std.atomic.Value(usize),
        ) void
        {
            self.camera.render(self.world, img, progress);
        }

        pub fn deinit(
            self: @This(),
        ) void
        {
            self.allocator.free(self.world);
        }
    };
    var state: ?State = null;

    pub fn render(
        allocator: std.mem.Allocator,
        context: raytrace.RenderContext,
    ) void
    {
        if (state == null)
        {
            state = State.init(allocator, context.img);
        }

        state.?.render(context.img, context.progress);
    }

    pub fn init(
       allocator: std.mem.Allocator,
       img: *raytrace.Image_rgba_u8,
    ) void
    {
        state = State.init(allocator, img);
    }

    pub fn deinit(
    ) void
    {
        if (state)
            |definitely_state|
        {
            definitely_state.deinit();
        }
        state = null;
    }
};

