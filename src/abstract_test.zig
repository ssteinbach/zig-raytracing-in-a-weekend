const std = @import("std");

const Vec = struct {
    x: f32,
    y: f32,

    pub fn format(
        self: @This(),
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void 
    {
        try writer.print(
            "vec({d}, {d})",
            .{ self.x, self.y },
        );
    }
};

const Ray = struct {
    o: Vec,
    s: Vec,

    pub fn format(
        self: @This(),
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) !void 
    {
        try writer.print(
            "ray(o: {s}, s: {s})",
            .{ self.o, self.s },
        );
    }
};

const Square = struct {
    center: Vec,
    dim: Vec,

    pub fn hit(self: @This(), r: Ray) ?f32
    {
        std.debug.print(
            "hit test against square: c: {s} dim: {d} and ray: {s}\n",
            .{ 
                self.center, self.dim,
                r,
            }
        );

        return null;
    }
};

const Disk = struct {
    center: Vec,
    radius: f32,

    pub fn hit(self: @This(), r: Ray) ?f32
    {
        std.debug.print(
            "hit test against sphere: c: {s} r: {d} and ray: {s}\n",
            .{ 
                self.center, self.radius,
                r,
            }
        );

        return null;
    }
};

const Hittable = struct {
    context: *const anyopaque,
    _hit : *const fn (context: *const anyopaque, r: Ray) ?f32,
    // _format: *fn (context: *anyopaque, writer: anytype) error{anyerror}!void,

    pub fn hit(
        self: @This(),
        r: Ray
    ) ?f32
    {
        return self._hit(self.context, r);
    }

    pub fn init(
        target: anytype
    ) Hittable
    {
        return make_hittable_wrapper_struct(@TypeOf(target.*)).init(target);
    }

    fn make_hittable_wrapper_struct(
        comptime T: type,
    ) type
    {
        return struct {
            source_type: T,

            pub fn from_anyopaque(
                context: *const anyopaque,
            ) *const T
            {
                return @alignCast(@ptrCast(context));
            }

            pub fn hit_wrapper(
                context: *const anyopaque,
                r: Ray,
            ) ?f32
            {
                const target_ptr = from_anyopaque(context);

                return target_ptr.*.hit(r);
            }

            pub fn format(
                context: *const anyopaque,
                writer: anytype,
            ) !void 
            {
                _ = context;
                std.debug.print("writer is: {any}\n", .{ writer });
                // return from_anyopaque(context).*.writer("{s}", .{}, writer);
            }

            pub fn init(
                instance: *const T,
            ) Hittable
            {
                return .{
                    .context = instance,
                    ._hit = hit_wrapper,
                    // ._format = format,
                };
            }

        };
    }
};

test "testing out generic patterns"
{
    if (true) {
        return error.SkipZigTest;
    }

    const allocator = std.testing.allocator;

    const v1 = Vec{ .x = 0, .y = 0 };
    const v2 = Vec{ .x = 1, .y = 1 };
    const d = Disk{ .center = v1, .radius = 5 };
    const s = Square{ .center = v2, .dim = v2 };
    // const r = Ray{ .o = v1, .s = v2 };

    var entities = std.ArrayList(Hittable).init(allocator);
    defer entities.deinit();

    try entities.append(Hittable.init(&d));
    try entities.append(Hittable.init(&s));

    for (entities.items)
        |ent|
    {
        _ = ent;
        // std.debug.print(
        //     "testing ent: {s} with ray {s}\n  result: {?d}\n",
        //     .{ ent, r, ent.hit(r) },
        // );
    }
}
