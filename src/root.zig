//! Raytracing library

const std = @import("std");
const testing = std.testing;

const image = @import("image.zig");
const vector = @import("vector.zig");
const comath_wrapper = @import("comath_wrapper.zig");

const render_functions = @import("render_functions.zig");
pub const CHECKPOINTS = render_functions.CHECKPOINTS;

test
{
    _ = @import("image.zig");
    _ = @import("vector.zig");
    _ = @import("comath_wrapper.zig");
    _ = @import("ray.zig");
    _ = @import("render_functions.zig");
}

pub const Image_rgba_u8 = image.Image(4, u8);

/// default render function calls the last render function in the list
pub fn render(
    allocator: std.mem.Allocator,
    img: *Image_rgba_u8,
    frame_number: usize,
) void
{
    return CHECKPOINTS[CHECKPOINTS.len - 1](allocator, img, frame_number);
}

test "comath integration"
{
    const v1 = vector.V3f{ .x = 1, .y = 2, .z = 3 };
    const v2 = vector.V3f{ .x = 0.5, .y = 1, .z = 1 };

    const tests = [_]struct{
        expr: []const u8,
        result: vector.V3f,
    }{
        // addition
        .{
            .expr = "v1 + v2",
            .result = .{ .x = 1.5, .y = 3, .z = 4 } 
        },
        // subtraction
        .{
            .expr = "v1 - v2",
            .result = .{ .x = 0.5, .y = 1, .z = 2 } 
        },
        // cross
        .{
            .expr = "v1 ^ v2",
            .result = .{ .x = -1, .y = 0.5, .z = 0 } 
        },
    };

    inline for (tests)
        |t|
    {
        const measured = comath_wrapper.eval(
            t.expr,
            .{ .v1 = v1, .v2 = v2 }
        );

        try vector.expectV3fEqual(t.result, measured);
    }
}
