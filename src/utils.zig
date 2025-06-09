//! utility functions for Raytracing in a Weekend

const std = @import("std");
const comath_wrapper = @import("comath_wrapper");

var prng = std.rand.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        std.posix.getrandom(std.mem.asBytes(&seed)) catch @panic("ack");
        break :blk seed;
    });
pub const rand = prng.random();

// [0, 1)
pub fn rnd_num(
) void 
{
    return rand.float(f32);
}

pub fn rnd_num_range(
    low_inclusive: f32,
    high_exclusive: f32,
) void 
{
    return comath_wrapper.lerp(rnd_num(), low_inclusive, high_exclusive);
}
