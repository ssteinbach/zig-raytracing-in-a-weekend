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
const material = @import("../material.zig");

/// public renderer for this image
pub const RNDR = struct {
    const Camera = struct {
        /// focal length of the camera (thin lens) of 1.0
        focus_distance : BaseType = 10.0,
        /// camera at the origin by default
        center :vector.V3f = vector.Point3f.init(0),
        look_at :vector.V3f = vector.Point3f.init(0),
        vfov: BaseType = 90,

        image_width: usize,
        image_height: usize,

        pixel00_loc: vector.Point3f,
        pixel_delta_u: vector.V3f,
        pixel_delta_v: vector.V3f,

        // defocus (DoF) controls
        defocus_angle: BaseType = 0.0,

        // horizontal and vertical radius
        defocus_disk_u: vector.V3f,
        defocus_disk_v: vector.V3f,

        const samples_per_pixel:usize = 1;
        const pixel_sample_scale:BaseType = (
            1.0/@as(BaseType, @floatFromInt(samples_per_pixel))
        );

        // maximum number of ray bounces
        const max_depth = 50;

        pub fn init(
            lookfrom: vector.Point3f,
            lookat: vector.Point3f,
            up: vector.V3f,
            vfov: BaseType,
            defocus_angle: BaseType,
            focus_distance: BaseType,
            img: *raytrace.Image_rgba_u8,
        ) @This()
        {
            const image_width:usize = img.width;
            const image_height:usize = img.height;

            const cam_dir = lookfrom.sub(lookat);

            // compute basis vectors
            const w = cam_dir.unit_vector();
            const u = up.cross(w).unit_vector();
            const v = w.cross(u);

            const theta = std.math.degreesToRadians(vfov);
            const h = std.math.tan(theta/2.0);
            const viewport_height : BaseType = 2.0 * h * focus_distance;
            const viewport_width : BaseType = (
                (viewport_height * @as(BaseType, @floatFromInt(image_width))) 
                / @as(BaseType, @floatFromInt(image_height))
            );

            const viewport_u = u.mul(viewport_width);
            const viewport_v = v.mul(-viewport_height);

            const viewport_upper_left = comath_wrapper.eval(
                "camera_center - (w * focus_distance) - (v_u/2) - (v_v/2)",
                .{
                    .camera_center = lookfrom,
                    .focus_distance = focus_distance,
                    .w = w,
                    .v_u = viewport_u,
                    .v_v = viewport_v,
                },
            );

            const pixel_delta_u = viewport_u.div(image_width);
            const pixel_delta_v = viewport_v.div(image_height);

            const defocus_radius = (
                focus_distance 
                * std.math.tan(std.math.degreesToRadians(defocus_angle / 2.0))
            );

            return .{
                .center = lookfrom,
                .look_at = lookat,
                .focus_distance = focus_distance,
                .vfov = vfov,
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
                .defocus_angle = defocus_angle,
                .defocus_disk_u = u.mul(defocus_radius),
                .defocus_disk_v = v.mul(defocus_radius),
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
                if (depth > 0) 
                {
                    return (
                        if (hitrec.mat.*.scatter(r,hitrec))
                            |scatter| 
                        ray_color(
                            scatter.scattered,
                            depth - 1,
                            world
                        ).mul(scatter.attentuation)
                        else vector.Color3f.ZERO
                    );
                }
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
            context: raytrace.RenderContext,
        ) void
        {
            context.progress.store(0, .unordered);
            var j:usize = 0;
            var exec_mode = (
                context.requested_execution_mode.load(.unordered)
            );
            while (j < self.image_height and exec_mode != .stop)
                : (j+=1)
            {
                var i:usize = 0;
                while (i < self.image_width)
                    : (i+=1)
                {
                    var pixel_color = vector.Color3f.init(0);

                    var sample: usize = 0;
                    while (sample < samples_per_pixel and exec_mode != .stop)
                        : (sample += 1)
                    {
                        const r = self.get_ray(
                            @floatFromInt(i),
                            @floatFromInt(j),
                        );

                        // scale and convert to output pixel foormat
                        pixel_color = pixel_color.add(
                            ray_color(
                                r,
                                max_depth,
                                world,
                            )
                        );

                        exec_mode = context.requested_execution_mode.load(
                            .unordered,
                        );
                    }
                    context.img.write_pixel_corrected(
                        i,
                        j,
                        pixel_color.mul(pixel_sample_scale),
                    );
                }
                if (exec_mode != .stop)
                {
                    context.progress.store(
                        j * 100 / self.image_height,
                        .unordered,
                    );
                }
            }
        }

        pub fn rays_for_pixel(
            self: @This(),
            allocator: std.mem.Allocator,
            i: usize,
            j: usize,
        ) ![]ray.Ray
        {
            var ray_list_builder = std.ArrayList(
                ray.Ray
            ){};

            var sample: usize = 0;
            while (sample < samples_per_pixel)
                : (sample += 1)
            {
                const r = self.get_ray(
                    @floatFromInt(i),
                    @floatFromInt(j)
                );

                try ray_list_builder.append(allocator, r);
            }

            return try ray_list_builder.toOwnedSlice(allocator);
        }

        /// build a ray that leaves the given pixel, sampling the defocus disk
        fn get_ray(
            self: @This(),
            /// column of the pixel
            i: BaseType,
            /// row of the pixel
            j: BaseType,
        ) ray.Ray 
        {
            const offset = sample_square();
            const pixel_sample = comath_wrapper.eval(
                "p00 + (pdu*(i + o.x)) + (pdv*(j+o.y))",
                .{
                    .p00 = self.pixel00_loc,
                    .i = i,
                    .j = j,
                    .o = offset,
                    .pdu = self.pixel_delta_u,
                    .pdv = self.pixel_delta_v,
                },
            );

            const sample_origin = (
                if (self.defocus_angle <= 0) self.center
                else self.defocus_disk_sample()
            );

            return .{
                .origin = sample_origin,
                .dir = pixel_sample.sub(sample_origin),
            };
        }

        fn defocus_disk_sample(
            self: @This(),
        ) vector.Point3f
        {
            const p = utils.random_in_unit_disk();
            return comath_wrapper.eval(
                "center + (defocus_disk_u * p.x) + (defocus_disk_v * p.y)",
                .{
                    .center = self.center,
                    .defocus_disk_u = self.defocus_disk_u,
                    .defocus_disk_v = self.defocus_disk_v,
                    .p = p,
                },
            );
        }

        /// generate random numbers over the [-0.5, 0.5] XY square
        fn sample_square(
        ) vector.V3f
        {
            return .{
                .x = utils.rnd_num(BaseType),
                .y = utils.rnd_num(BaseType),
                .z = 0
            };
        }
    };

    pub const State = struct {
        world: ray_hit.HittableSlice,
        materials: material.MaterialMap,
        camera: Camera,
        allocator: std.mem.Allocator,

        pub fn init_fallible(
           allocator: std.mem.Allocator,
           img: *raytrace.Image_rgba_u8,
        ) !State
        {
            // build material list
            var mtl_map = (
                material.MaterialMap.init(allocator)
            );

            // 22*22 spheres + 3 big spheres + ground sphere + inner glass
            try mtl_map.ensureTotalCapacity(22*22 + 3 + 1 + 1);

            var worldbuilder = ray_hit.HittableList.init(
                allocator
            );
            try worldbuilder.ensureTotalCapacity(22*22 + 3 + 1 + 1);

            // ground object
            mtl_map.putAssumeCapacity(
                "ground",
                material.Lambertian.init(
                    vector.Color3f.init_3(0.5, 0.5, 0.5)
                )
            );
            worldbuilder.appendAssumeCapacity(
                ray_hit.Hittable.init(
                    geometry.Sphere{
                        .name = "ground",
                        .center_worldspace = .{ .x = 0, .y = -1000, .z = -1},
                        .radius = 1000.0,
                        .mat = mtl_map.getPtr("ground").?
                    },
                ),
            );

            const threshold = vector.V3f.init_3(4, 0.2, 0);

            var buf = try allocator.alloc(u8, 22*22*12);

            var a:BaseType = -11;
            while (a < 11)
                : (a+=1)
            {
                var b:BaseType = -11;
                while (b < 11)
                    : (b+=1)
                {
                    const name = try std.fmt.bufPrint(
                        buf,
                        "sphere_{d:02}_{d:02}",
                        .{ a + 12, b + 12 },
                    );
                    buf = buf[name.len..];

                    const choose_mat = utils.rnd_num_range(
                        BaseType,
                        0,
                        1,
                    );
                
                    const center = vector.V3f {
                        .x = a + 0.9 * utils.rnd_num(BaseType), 
                        .y = 0.2,
                        .z = b + 0.9 * utils.rnd_num(BaseType),
                    };

                    if (center.sub(threshold).length() > 0.9)
                    {
                        if (choose_mat < 0.8)
                        {
                            // diffuse
                            const albedo = (
                                utils.rnd_vec_range(
                                    vector.Color3f,
                                    0,
                                    1,
                                ).mul(
                                    utils.rnd_vec_range(
                                        vector.Color3f,
                                        0,
                                        1,
                                    )
                                )
                            );

                            mtl_map.putAssumeCapacity(
                                name,
                                material.Lambertian.init(albedo),
                            );
                            worldbuilder.appendAssumeCapacity(
                                ray_hit.Hittable.init(
                                    geometry.Sphere{
                                        .name = name,
                                        .center_worldspace = center,
                                        .radius = 0.2,
                                        .mat = mtl_map.getPtr(name).?,
                                    },
                                ),
                            );
                        }
                        else if (choose_mat < 0.95)
                        {
                            // metal
                            const albedo = utils.rnd_vec_range(
                                vector.Color3f,
                                0.5,
                                1
                            );
                            const fuzz = utils.rnd_num_range(
                                BaseType,
                                0,
                                0.5
                            );

                            mtl_map.putAssumeCapacity(
                                name,
                                material.Material {
                                    .metallic = material.Metallic {
                                        .albedo = vector.Color3f.init(albedo),
                                        .fuzz = fuzz,
                                    }
                                },
                            );

                            worldbuilder.appendAssumeCapacity(
                                ray_hit.Hittable.init(
                                    geometry.Sphere{
                                        .name = name,
                                        .center_worldspace = center,
                                        .radius = 0.2,
                                        .mat = mtl_map.getPtr(name).?
                                    },
                                ),
                            );
                        }
                        else 
                        {
                            // glass
                            mtl_map.putAssumeCapacity(
                                name,
                                material.DielectricReflRefr.init(
                                    vector.Color3f.init(1.0),
                                    1.5,
                                )
                            );
                            worldbuilder.appendAssumeCapacity(
                                ray_hit.Hittable.init(
                                    geometry.Sphere{
                                        .name = name,
                                        .center_worldspace = center,
                                        .radius = 0.2,
                                        .mat = mtl_map.getPtr(name).?
                                    },
                                ),
                            );
                        }
                    }
                }
            }

            // add big spheres
            try mtl_map.put(
                "big_glass",
                material.DielectricReflRefr.init(
                    vector.Color3f.init(1),
                    1.5,
                )
            );
            try worldbuilder.append(
                ray_hit.Hittable.init(
                    geometry.Sphere{
                        .name = "big_glass",
                        .center_worldspace = .{ .x = 0, .y = 1, .z = 0},
                        .radius = 1.0,
                        .mat = mtl_map.getPtr("big_glass").?
                    },
                ),
            );

            try mtl_map.put(
                "big_diffuse",
                material.Lambertian.init(
                    vector.Color3f.init_3(0.4, 0.2, 0.1),
                )
            );
            try worldbuilder.append(
                ray_hit.Hittable.init(
                    geometry.Sphere{
                        .name = "big_diffuse",
                        .center_worldspace = .{ .x = -4, .y = 1, .z = 0},
                        .radius = 1.0,
                        .mat = mtl_map.getPtr("big_diffuse").?
                    },
                ),
            );


            try mtl_map.put(
                "big_metal",
                material.Material {
                    .metallic = .{
                        .albedo = vector.Color3f.init_3(0.7, 0.6, 0.5),
                        .fuzz = 0,
                    }
                }
            );
            try worldbuilder.append(
                ray_hit.Hittable.init(
                    geometry.Sphere{
                        .name = "big_metal",
                        .center_worldspace = .{ .x = 4, .y = 1, .z = 0},
                        .radius = 1.0,
                        .mat = mtl_map.getPtr("big_metal").?
                    },
                ),
            );

            mtl_map.lockPointers();

            return .{
                .allocator = allocator,
                .camera = Camera.init(
                    vector.Point3f.init_3(13, 2, 3),
                    vector.Point3f.init_3(0,0,0),
                    vector.V3f.init_3(0, 1, 0),
                    20,
                    0.6,
                    10,
                    img,
                ),
                .world = try worldbuilder.toOwnedSlice(),
                .materials = mtl_map,
            };
        } 

        pub fn init(
            allocator: std.mem.Allocator,
            img: *raytrace.Image_rgba_u8,
        ) State
        {
             return init_fallible(
                 allocator,
                 img,
             ) catch @panic("ouch");
        }

        pub fn deinit(
            self: @This(),
        ) void
        {
            self.allocator.free(self.world);
        }
    };
    pub var state: ?State = null;

    pub fn render(
        allocator: std.mem.Allocator,
        context: raytrace.RenderContext,
    ) void
    {
        state = state orelse State.init(allocator, context.img);

        state.?.camera.render(
            state.?.world,
            context,
        );
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

test "sample_square"
{
    const low = -0.5;
    const hi = 0.5;

    const mid = 0;
    var crossed_mid = false;

    var i: usize = 0;
    while (i < 10000)
        : (i += 1)
    {
        const p = RNDR.Camera.sample_square();

        errdefer std.debug.print("Error with p: {s}\n", .{ p });

        try std.testing.expect(p.x > low and p.x < hi);
        try std.testing.expect(p.y > low and p.y < hi);

        if (p.x < mid) {
            crossed_mid = true;
        }
    }

    try std.testing.expect(crossed_mid);
}

// const SerializableState = struct {
//     camera: Camera,
//
//
//     pub fn init(
//         allocator: std.mem.Allocator,
//         renderable_state: State,
//     ) SerializableState
//     {
//     }
// };
