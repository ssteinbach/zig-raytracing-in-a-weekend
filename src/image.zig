const std = @import("std");

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
                .data = try allocator.alloc(data_type, width*height*channels),
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
    };
}
