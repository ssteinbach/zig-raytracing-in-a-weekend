//! Raytracing library
const std = @import("std");

const image = @import("image.zig");
const vector = @import("vector.zig");
const comath_wrapper = @import("comath_wrapper.zig");

pub const render_functions = @import("render_functions.zig");
pub const RENDERERS = render_functions.RENDERERS;

pub const geometry = @import("geometry.zig");
pub const ray = @import("ray.zig");

test
{
    _ = @import("image.zig");
    _ = @import("vector.zig");
    _ = @import("comath_wrapper.zig");
    _ = @import("ray.zig");
    _ = @import("render_functions.zig");
    _ = @import("abstract_test.zig");
}

pub const Image_rgba_u8 = image.Image(4, u8);

/// execution mode indicator enum for the renderer
pub const RequestedExecutionMode = enum (i8) {
    stop,
    render,
    // pause when done?
};

/// context for the renderer to operate in
pub const RenderContext = struct {
    /// image buffer to render into
    img: *Image_rgba_u8,
    /// variable parameter for stuff
    frame_number: usize,
    /// progress atomic value
    progress: *std.atomic.Value(usize),
    /// Control signal for the ui to tell the renderer to continue, cancel, etc.
    requested_execution_mode: *std.atomic.Value(RequestedExecutionMode),
};

/// default render function calls the last render function in the list
pub fn render(
    allocator: std.mem.Allocator,
    current_renderer: usize,
    context: RenderContext,
) void
{
    render_functions.RENDERERS[current_renderer]._render(
        allocator,
        context,
    );
}

pub fn cleanup(
) void
{
    for (render_functions.RENDERERS)
        |rndr|
    {
        if (rndr._maybe_deinit)
            |deinit|
        {
            deinit();
        }
    }
}

test "comath integration"
{
    const tv1 = vector.V3f{ .x = 1, .y = 2, .z = 3 };
    const tv2 = vector.V3f{ .x = 0.5, .y = 1, .z = 1 };

    const tests = [_]struct{
        expr: []const u8,
        result: vector.V3f,
    }{
        // addition
        .{
            .expr = "tv1 + tv2",
            .result = .{ .x = 1.5, .y = 3, .z = 4 } 
        },
        // subtraction
        .{
            .expr = "tv1 - tv2",
            .result = .{ .x = 0.5, .y = 1, .z = 2 } 
        },
        // cross
        .{
            .expr = "tv1 ^ tv2",
            .result = .{ .x = -1, .y = 0.5, .z = 0 } 
        },
    };

    inline for (tests)
        |t|
    {
        const measured = comath_wrapper.eval(
            t.expr,
            .{ .tv1 = tv1, .tv2 = tv2 }
        );

        try vector.expectV3fEqual(t.result, measured);
    }
}

test "function call"
{
    const result = comath_wrapper.eval(
        "v3(0.5, 0.25, 1.25) + v3(-1, -2, 3) ^ v2(3, 2)",
        .{},
    );

    try std.testing.expectEqual(
        vector.V3f{ .x = -5.5, .y = 9.25, .z = 5.25 },
        result
    );
}
