const std = @import("std");

const render_functions = @import("../render_functions.zig");

const raytrace = @import("../root.zig");
const ray = @import("../ray.zig");
const ray_hit = @import("../ray_hit.zig");
const vector = @import("../vector.zig");
const BaseType = vector.V3f.BaseType;
const comath_wrapper = @import("../comath_wrapper.zig");
const utils = @import("../utils.zig");
const geometry = @import("../geometry.zig");

/// public renderer for this image
pub const RNDR = struct {
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

        /// determine the color of a given ray
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
                render_functions.hit_world(
                    .{ 
                        .world = world,
                        .r = r,
                        .interval = utils.Interval.EPS_TO_INF,
                    }
                ) 
            ) |hitrec|
            {
                // wedging to make the gamut image
                const scale:BaseType = (
                    if (hitrec.p.x < -0.4) 0.1
                    else if (hitrec.p.x < -0.2) 0.3
                    else if (hitrec.p.x < 0.2) 0.5
                    else if (hitrec.p.x < 0.4) 0.7
                    else 0.9
                );
                const dir = hitrec.normal.add(utils.random_unit_vector());
                return ray_color(
                    .{ .origin = hitrec.p, .dir = dir},
                    depth - 1,
                    world,
                ).mul(scale);
            }

            const a = 0.5 * (r.dir.unit_vector().y + 1.0);

            return comath_wrapper.lerp(
                a,
                vector.Color3f.init(1.0),
                vector.Color3f.init([_]f32{0.5, 0.7, 1.0}),
            );
        }

        /// given an image to write to and a world of objects to render,
        /// produce an image
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
                    img.write_pixel_corrected(
                        i,
                        j,
                        pixel_color.mul(pixel_sample_scale)
                    );

                }
                progress.store(
                    j * 100 / self.image_height,
                    .monotonic,
                );
            }

        }

        /// build a ray that leaves the given pixel
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
        world: ray_hit.HittableSlice = undefined,
        camera: Camera = undefined,
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
