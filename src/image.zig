const std = @import("std");
const vector = @import("vector.zig");
const util = @import("utils.zig");

pub fn Image(
    channels:usize,
    data_type: type,
) type
{
    return struct {
        /// data types
        const CHANNELS = channels;

        allocator: std.mem.Allocator,

        /// underlying memory
        data : []data_type,
        width: usize,
        height: usize,

        /// initializes an image
        pub fn init(
            allocator: std.mem.Allocator,
            width:usize,
            height:usize,
        ) !@This()
        {
            return .{
                .data = try allocator.alloc(
                    data_type,
                    width*height*channels
                ),
                .width = width,
                .height = height,
                .allocator = allocator,

            };
        }

        pub fn deinit(
            self: @This(),
        ) void
        {
            self.allocator.free(self.data);
        }

        pub fn pixel(
            self: *@This(),
            x: usize,
            y: usize,
        ) []data_type
        {
            const start = x * channels + y * self.width * channels;
            return self.data[start..start+channels];
        }

        pub fn write_pixel(
            self: *@This(),
            /// pixel coordinate
            i: usize, 
            /// pixel coordinate
            j: usize,
            /// c is assumed to be [0, 1)
            c: vector.Color3f,
        ) void
        {
            var px = self.pixel(i, j);

            // scale and convert to output pixel foormat
            // from [0, 1) to [0, 255)
            const pixel_color = util.Interval.UNIT_RIGHT_EXCLUSIVE.clamp(
                c
            ) .mul(256).as(u8);

            px[0] = pixel_color.x;
            px[1] = pixel_color.y;
            px[2] = pixel_color.z;
            px[3] = 255;
        }
    };
}
