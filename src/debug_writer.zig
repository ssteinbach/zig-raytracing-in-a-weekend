//! Write out a usda scene

const std = @import("std");

const raytrace = @import("raytrace");

const PREFIX = "#usda 1.0\n";

const BASIS_CURVE_PREFIX = \\
    \\ uniform token type = "linear"
    \\ int[] curveVertexCounts = [{d}]
    \\ float[] widths = [1.5] (interpolation = "constant") 
    \\ color3f[] primvars:displayColor = [(1, 0, 0)]
    \\
 ;

pub fn write_sphere(
    writer: *std.Io.Writer,
    sph: raytrace.geometry.Sphere,
) !void
{
    var buf:[1024]u8 = undefined;

    try BlockWriter.open(
        writer,
        try std.fmt.bufPrint(
            &buf,
            "def Xform \"{s}\"",
            .{ sph.name, },
        ),
    );
    defer BlockWriter.close(writer);

    try BlockWriter.open(
        writer,
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
    _ = try writer.write(
        try std.fmt.bufPrint(
            &buf,
            "    uniform token[] xformOpOrder = [\"xformOp:translate\"]\n",
            .{},
        ),
    );

    try BlockWriter.open(
        writer,
        try std.fmt.bufPrint(
            &buf,
            "def Sphere \"{s}\"\n",
            .{
                "Geom"
            },
        ),

    );
    defer BlockWriter.close(writer);

    _ = try writer.write(
        try std.fmt.bufPrint(
            &buf,
            "double radius = {d}\n",
            .{ sph.radius },
        ),
    );
}

/// write a block of rays as lines into the writer as usda
pub fn write_rays(
    writer: *std.Io.Writer,
    /// name of the ray bundle, IE "Camera Rays"
    name: []const u8,
    /// rays to write
    rays: []const raytrace.ray.Ray,
) !void
{
    var buf = std.mem.zeroes([10*1024]u8);

    try BlockWriter.open(
        writer,
        try std.fmt.bufPrint(
            &buf,
            "def Xform \"{s}\"",
            .{ name },
        ),

    );
    defer BlockWriter.close(writer);

    _ = try writer.write(
        try std.fmt.bufPrint(
            &buf,
            "double3 xformOp:translate = ({d}, {d}, {d})\n",
            .{ 0,0,0 },
        ),
    );
    _ = try writer.write(
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
    try BlockWriter.open(
        writer,
        try std.fmt.bufPrint(
            &buf,
            "def BasisCurves \"Tubes\"\n",
            .{},
        ),

    );
    defer BlockWriter.close(writer);

    _ = try writer.write(
        try std.fmt.bufPrint(
            &buf,
            BASIS_CURVE_PREFIX,
            .{ rays.len * 2 },
        ),
    );

    {
        try SquareBlockWriter.open(writer, "point3f[] points = ");
        defer SquareBlockWriter.close(writer);

        for (rays)
            |r|
        {
            const end = r.origin.add(r.dir);
            _ = try writer.write(
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
    }
}

/// a block of text with a prefix + {\n and suffix }\n
const BlockWriter = struct {
    /// open a block with a prefix ie PREFIX {
    pub fn open(
        writer: *std.Io.Writer,
        header: []const u8,
    ) !void
    {
        _ = try writer.write(header);
        _ = try writer.write("\n{\n");
    }

    /// close a block with }\n
    pub fn close(
        writer: *std.Io.Writer,
    ) void
    {
        _ = writer.write("}\n") catch unreachable;
    }
};

const SquareBlockWriter = struct {
    /// open a block with a prefix ie PREFIX {
    pub fn open(
        writer: *std.Io.Writer,
        header: []const u8,
    ) !void
    {
        _ = try writer.write(header);
        _ = try writer.write("\n[\n");
    }

    /// close a block with }\n
    pub fn close(
        writer: *std.Io.Writer,
    ) void
    {
        _ = writer.write("]\n") catch unreachable;
    }
};

pub fn main(
    init: std.process.Init,
) !void
{
    const allocator = init.arena.allocator();
    const io = init.io;

    var img =  raytrace.Image_rgba_u8.init(
        allocator,
        400,
        400,
    ) catch @panic("couldn't make image");

    raytrace.render_functions.img23.RNDR.init(allocator, &img);

    const state = raytrace.render_functions.img23.RNDR.state.?;

    // file to write to
    const file = try std.Io.Dir.cwd().createFile(
        io,
        "debug.usda",
        .{},
    );
    defer file.close(io);

    var buf:[4096]u8 = undefined;
    var file_writer = file.writer(io, &buf);
    defer file_writer.flush() catch unreachable;

    _ = try file_writer.interface.write(PREFIX);

    try BlockWriter.open(
        &file_writer.interface,
        "def Xform \"World\"",
    );
    {

        for (state.world)
            |hittable|
        {
            switch (hittable) {
                .sphere => |sph| try write_sphere(
                    &file_writer.interface,
                    sph,
                ),
            }
        }

        {
            const rays = try state.camera.rays_for_pixel(
                allocator,
                200,
                200,
            );

            try write_rays(
                &file_writer.interface,
                "CameraRays",
                rays,
            );
        }

        try write_sphere(
            &file_writer.interface,
            .{
                .name = "Camera",
                .center_worldspace = state.camera.center,
                .radius = 0.25,
            },
        );

        try write_rays(
            &file_writer.interface,
            "CameraLookat",
            &.{
                .{
                    .origin = state.camera.center,
                    .dir = state.camera.look_at.sub(state.camera.center),
                },
            },
        );
    }
    BlockWriter.close(&file_writer.interface);
}
