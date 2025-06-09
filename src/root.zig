//! Raytracing library
const std = @import("std");
const testing = std.testing;

const image = @import("image.zig");
const vector = @import("vector.zig");
const comath_wrapper = @import("comath_wrapper.zig");

const render_functions = @import("render_functions.zig");
pub const CHECKPOINTS = render_functions.CHECKPOINTS;
pub const CHECKPOINT_NAMES = render_functions.CHECKPOINT_NAMES;

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

/// default render function calls the last render function in the list
pub fn render(
    allocator: std.mem.Allocator,
    img: *Image_rgba_u8,
    frame_number: usize,
    current_renderer: usize,
) void
{
    return CHECKPOINTS[current_renderer](allocator, img, frame_number);
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
