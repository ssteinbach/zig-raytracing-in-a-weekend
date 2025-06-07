//! Raytracing library

const std = @import("std");
const testing = std.testing;

const image = @import("image.zig");
const vector = @import("vector.zig");
const comath_wrapper = @import("comath_wrapper.zig");

test
{
    _ = @import("image.zig");
    _ = @import("vector.zig");
    _ = @import("comath_wrapper.zig");
    _ = @import("ray.zig");
}

pub const Image_rgba_u8 = image.Image(4, u8);

const render_fn = *const fn(std.mem.Allocator, *Image_rgba_u8, usize) void;

/// fun way of cataloging the history of the renders that this project can make
const CHECKPOINTS:[]const render_fn = &[_]render_fn{
    image_1,
};

/// default render function calls the last render function in the list
pub fn render(
    allocator: std.mem.Allocator,
    img: *Image_rgba_u8,
    frame_number: usize,
) void
{
    return CHECKPOINTS[CHECKPOINTS.len - 1](allocator, img, frame_number);
}

/// main render function - this is where the "main" code from Raytracing in a
/// Weekend goes.
///
/// image 1: testing the image class, making a red-green gradient over the
///          image plane.  I added an offset that pushes hte gradient around
///          to test the imgui integration.
/// 
/// The render functions are named after name of the figures in the book
pub fn image_1(
    _: std.mem.Allocator,
    img: *Image_rgba_u8,
    frame_number: usize,
) void
{
    const cols = img.width;
    const rows = img.height;

    const dim = vector.Color3f.init([_]usize{ cols, rows, 0});

    var x:usize = 0;
    while (x < cols)
        : (x += 1)
    {
        var y:usize = 0;
        while (y < rows)
            : (y += 1)
        {
            var pixel_color_f = comath_wrapper.eval(
                "(((p + f) % dim) / (dim - 1)) * 255.999",
                .{ 
                    .p = vector.Color3f.init([_]usize{x,y,0}),
                    .f = frame_number,
                    .dim = dim,
                }
            );
            pixel_color_f.z = 0;
            const pixel_color = pixel_color_f.as(u8);

            var pixel = img.pixel(x, y);

            pixel[0] = pixel_color.x;
            pixel[1] = pixel_color.y;
            pixel[2] = 0;
            pixel[3] = 255;
        }
    }
}

test "comath integration"
{
    const v1 = vector.V3f{ .x = 1, .y = 2, .z = 3 };
    const v2 = vector.V3f{ .x = 0.5, .y = 1, .z = 1 };

    const tests = [_]struct{
        expr: []const u8,
        result: vector.V3f,
    }{
        .{
            .expr = "v1 + v2",
            .result = .{ .x = 1.5, .y = 3, .z = 4 } 
        },
        .{
            .expr = "v1 - v2",
            .result = .{ .x = 0.5, .y = 1, .z = 2 } 
        },
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
