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

    const t_start_total = try std.time.Instant.now();
    defer std.debug.print(
        "Total render time for all {d} tests: {d:.03}s\n",
        .{
            raytrace.RENDERERS.len,
            (
             @as(f64, 
                 @floatFromInt(
                     (std.time.Instant.now() catch t_start_total).since(t_start_total) 
                 )
             )
             / @as(f64, @floatFromInt(std.time.ns_per_s))
            ),
        },
    );

    var da = std.heap.DebugAllocator(.{}){};
    defer _ = da.deinit();
    const allocator = da.allocator();

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
