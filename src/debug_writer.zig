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

    _ = try file_writer.write(try world.commit());
}
