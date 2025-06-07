// @TODO: replace this with a call to raytrace.render() and dump the result
//        to a file on disk

const std = @import("std");

pub fn main() !void {
    std.debug.print(
        "will call raytrace.render() and write an image to disk.  "
        ++ "For now use `zig build viewer` to open the interactive viewer.\n",
        .{}
    );
}
