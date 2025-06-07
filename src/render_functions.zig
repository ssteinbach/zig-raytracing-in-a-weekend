//! the "main" functions from RiaW

const std = @import("std");
const raytrace = @import("root.zig");
const vector = @import("vector.zig");
const comath_wrapper = @import("comath_wrapper.zig");

/// pointer to a render function
pub const render_fn = *const fn(
    std.mem.Allocator,
    *raytrace.Image_rgba_u8,
    usize,
) void;

/// fun way of cataloging the history of the renders that this project can make
pub const CHECKPOINTS:[]const render_fn = &[_]render_fn{
    image_1,
};

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
    img: *raytrace.Image_rgba_u8,
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

