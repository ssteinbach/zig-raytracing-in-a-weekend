const std = @import("std");

const raytrace = @import("raytrace");

const TextWriter = std.ArrayList(u8).Writer;

// def Xform "hello"
// {
//     def Sphere "world"
//     {
//     }
// }

const PREFIX = "#usda 1.0\n";

const BASIS_CURVE_TEMPLATE = \\
    \\ uniform token type = "linear"
    \\ int[] curveVertexCounts = [{d}]
    \\ float[] widths = [1.5] (interpolation = "constant") 
    \\ color3f[] primvars:displayColor = [(1, 0, 0)]
    \\ point3f[] points = [
    \\ {s}
    \\ ]
    \\
 ;

pub fn write_sphere(
    allocator: std.mem.Allocator,
    parent_writer: *TextWriter,
    sph: raytrace.geometry.Sphere,
) !void
{
    var buf = std.mem.zeroes([1024]u8);


    var xform = try BlockWriter.init(
        allocator,
        try std.fmt.bufPrint(
            &buf,
            "def Xform \"{?s}\"",
            .{
                sph.name
            },
        ),

    );
    defer xform.deinit();

    var xform_w = xform.writer();
    _ = try xform_w.write(
        try std.fmt.bufPrint(
            &buf,
            "double3 xformOp:translate = ({d}, {d}, {d})\n",
            .{
                sph.center_worldspace.x,
                sph.center_worldspace.y,
                sph.center_worldspace.z 
            },
        ),
    );
    _ = try xform_w.write(
        try std.fmt.bufPrint(
            &buf,
            "    uniform token[] xformOpOrder = [\"xformOp:translate\"]\n",
            .{},
        ),
    );

    var sphere = try BlockWriter.init(
        allocator,
        try std.fmt.bufPrint(
            &buf,
            "def Sphere \"{?s}\"\n",
            .{
                "Geom"
            },
        ),

    );
    defer sphere.deinit();

    var sphere_w = sphere.writer();

    _ = try sphere_w.write(
        try std.fmt.bufPrint(
            &buf,
            "double radius = {d}\n",
            .{ sph.radius },
        ),
    );

    _ = try xform_w.write(try sphere.commit());

    _ = try parent_writer.write(try xform.commit());
}

pub fn write_rays(
    allocator: std.mem.Allocator,
    parent_writer: *TextWriter,
    rays: []const raytrace.ray.Ray,
    name: []const u8,
) !void
{
    var buf = std.mem.zeroes([10*1024]u8);

    var xform = try BlockWriter.init(
        allocator,
        try std.fmt.bufPrint(
            &buf,
            "def Xform \"{?s}\"",
            .{ name },
        ),

    );
    defer xform.deinit();

    var xform_w = xform.writer();
    _ = try xform_w.write(
        try std.fmt.bufPrint(
            &buf,
            "double3 xformOp:translate = ({d}, {d}, {d})\n",
            .{ 0,0,0 },
        ),
    );
    _ = try xform_w.write(
        try std.fmt.bufPrint(
            &buf,
            "    uniform token[] xformOpOrder = [\"xformOp:translate\"]\n",
            .{},
        ),
    );

        //     def BasisCurves "ConstantWidth" (){
        //     uniform token[] xformOpOrder = ["xformOp:translate"]
        //     float3 xformOp:translate = (3, 0, 0)
        //
        //     uniform token type = "linear"
        //     int[] curveVertexCounts = [7]
        //     point3f[] points = [(0, 0, 0), (1, 1, 0), (1, 2, 0), (0, 3, 0), (-1, 4, 0), (-1, 5, 0), (0, 6, 0)]
        //     float[] widths = [.5] (interpolation = "constant") 
        //     color3f[] primvars:displayColor = [(1, 0, 0)]
        // }
    var linear_curves = try BlockWriter.init(
        allocator,
        try std.fmt.bufPrint(
            &buf,
            "def BasisCurves \"Tubes\"\n",
            .{},
        ),

    );
    defer linear_curves.deinit();

    var linear_curve_w = linear_curves.writer();

    var points = std.ArrayList(u8).init(allocator);
    defer points.deinit();
    var p_w = points.writer();
    for (rays)
        |r|
    {
        const end = r.origin.add(r.dir);
        _ = try p_w.write(
            try std.fmt.bufPrint(
                &buf,
                "({d}, {d}, {d}), ({d}, {d}, {d}), \n",
                .{
                    r.origin.x,
                    r.origin.y,
                    r.origin.z,
                    end.x,
                    end.y,
                    end.z,
            },
            ),
        );
    }

    _ = try linear_curve_w.write(
        try std.fmt.bufPrint(
            &buf,
            BASIS_CURVE_TEMPLATE,
            .{ rays.len * 2 , points.items },
        ),
    );

    _ = try xform_w.write(try linear_curves.commit());

    _ = try parent_writer.write(try xform.commit());
}

/// a block of text with a prefix + {\n and suffix }\n
const BlockWriter = struct {
    allocator: std.mem.Allocator,
    content_builder: std.ArrayList(u8),

    pub fn init(
        allocator: std.mem.Allocator,
        header: []const u8,
    ) !@This()
    {
        var content = std.ArrayList(u8).init(allocator);
        var writer_ = content.writer();

        _ = try writer_.write(header);
        _ = try writer_.write("\n{\n");

        return .{
            .allocator = allocator,
            .content_builder = content,
        };
    }

    /// close the block with a } and return the content (BlockWriter still owns
    /// the memory).
    pub fn commit(
        self: *@This(),
    ) ![]const u8
    {
        _ = try self.content_builder.writer().write("}\n");
        return self.content_builder.items;
    }

    pub fn writer(
        self: *@This(),
    ) TextWriter
    {
        return self.content_builder.writer();
    }

    pub fn deinit(
        self: @This(),
    ) void
    {
        self.content_builder.deinit();
    }
};

pub fn main(
) !void
{
    var gpa = (std.heap.GeneralPurposeAllocator(.{}){});
    const allocator = gpa.allocator();

    var img =  raytrace.Image_rgba_u8.init(
        allocator,
        400,
        400,
    ) catch @panic("couldn't make image");

    raytrace.render_functions.img22.RNDR.init(allocator, &img);
    const state = raytrace.render_functions.img22.RNDR.state.?;

    // file to write to
    const file = try std.fs.cwd().createFile(
        "debug.usda",
        .{},
    );
    defer file.close();

    var file_writer = file.writer();

    _ = try file_writer.write(PREFIX);

    var world = try BlockWriter.init(
        allocator,
        "def Xform \"World\""
    );
    defer world.deinit();

    var world_writer = world.writer();

    for (state.world)
        |hittable|
    {
        switch (hittable) {
            .sphere => |sph| try write_sphere(
                allocator,
                &world_writer,
                sph,
            ),
        }
    }

    const rays = try state.camera.rays_for_pixel(
        allocator,
        200,
        200,
    );

    try write_rays(
        allocator,
        &world_writer,
        rays,
        "CameraRays",
    );

    try write_sphere(
        allocator,
        &world_writer,
        .{
            .name = "Camera",
            .center_worldspace = state.camera.center,
            .radius = 0.25,
        },
    );

    try write_rays(
        allocator,
        &world_writer,
        &.{
            .{
                .origin = state.camera.center,
                .dir = state.camera.look_at.sub(state.camera.center),
            },
        },
        "CameraLookat",
    );


    _ = try file_writer.write(try world.commit());
}
