//! By convention, root.zig is the root source file when making a library. If
//! you are making an executable, the convention is to delete this file and
//! start with main.zig instead.
const std = @import("std");
const testing = std.testing;

const image = @import("image.zig");
const vector = @import("vector.zig");
const comath_wrapper = @import("comath_wrapper.zig");

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
    _ = @import("comath_wrapper.zig");
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
