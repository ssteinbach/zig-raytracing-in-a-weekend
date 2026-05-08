//! Render with each renderer and log the time the render took

const std = @import("std");
const builtin = @import("builtin");

const raytrace = @import("raytrace");

pub fn main(
    init: std.process.Init,
) !void 
{
    const allocator = init.gpa;
    const io = init.io;

    // required to be a part of the context
    var progress = std.atomic.Value(usize).init(0);
    var mode = std.atomic.Value(
        raytrace.RequestedExecutionMode
    ).init(.render);

    const t_start_total = std.Io.Timestamp.now(io, .real);

    defer std.debug.print(
        "Total render time for all {d} tests: {f:.03}s\n",
        .{
            raytrace.RENDERERS.len,
            (
             std.Io.Timestamp.now(io, .real).durationTo(t_start_total)
            ),
        },
    );

    for (raytrace.RENDERERS, 0..)
        |rndr, ind|
    {
        std.debug.print(
            "Renderer {d}: {s} ",
            .{ ind, rndr.desc },
        );

        var img = try raytrace.Image_rgba_u8.init(
            allocator,
            800,
            800,
        );
        defer img.deinit();

        const t_start = std.Io.Timestamp.now(io, .real);
        defer std.debug.print(
            "{f}\n",
            .{
                t_start.durationTo(std.Io.Timestamp.now(io, .real))
            },
        );

        raytrace.render(
            allocator,
            ind,
            .{
                .frame_number = 0,
                .img = &img,
                .progress = &progress,
                .requested_execution_mode = &mode,
            },
        );
    }
}
