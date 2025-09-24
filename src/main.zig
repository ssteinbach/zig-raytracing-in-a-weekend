//! Render with each renderer and log the time the render took

const std = @import("std");

const raytrace = @import("raytrace");

pub fn main(
) !void 
{
    var progress = std.atomic.Value(usize).init(0);
    var mode = std.atomic.Value(
        raytrace.RequestedExecutionMode
    ).init(.render);

    for (raytrace.RENDERERS, 0..)
        |rndr, ind|
    {
        var da = std.heap.DebugAllocator(.{}){};
        defer _ = da.deinit();
        const allocator = da.allocator();

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

        const t_start = try std.time.Instant.now();
        defer std.debug.print(
            "{d}ms\n",
            .{
                (std.time.Instant.now() catch t_start).since(t_start) 
                    / std.time.ns_per_ms
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
