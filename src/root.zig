//! By convention, root.zig is the root source file when making a library. If
//! you are making an executable, the convention is to delete this file and
//! start with main.zig instead.
const std = @import("std");
const testing = std.testing;

const image = @import("image.zig");

pub const Image_rgba_u8 = image.Image(4, u8);

pub export fn add(a: i32, b: i32) i32 {
    return a + b;
}

test "basic add functionality" {
    try testing.expect(add(3, 7) == 10);
}

pub fn render(
    _: std.mem.Allocator,
    img: *Image_rgba_u8,
    frame_number: usize,
) void
{
    const cols = img.width;
    const rows = img.height;
    // const channels = pixel_buffer[0][0].len;

    const iw_m_one: f64 = @floatFromInt(cols - 1);
    const ih_m_one: f64 = @floatFromInt(rows - 1);

    var x:usize = 0;
    while (x < cols)
        : (x += 1)
    {
        const fx: f64 = @floatFromInt(
            @mod(x + frame_number, cols)
        );
        var y:usize = 0;
        while (y < rows)
            : (y += 1)
        {
            const fy: f64 = @floatFromInt(
                @mod(y + frame_number, rows)
            );

            const r = fx / iw_m_one;
            const g = fy / ih_m_one;
            const b:f64 = 0.0;

            var pixel = img.pixel(x, y);

            pixel[0] = @intFromFloat(255.999 * r);
            pixel[1] = @intFromFloat(255.999 * g);
            pixel[2] = @intFromFloat(255.999 * b);
            pixel[3] = 255;
        }
    }
}

test
{
    _ = @import("image.zig");
    _ = @import("vector.zig");
}
