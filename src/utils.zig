//! utility functions for Raytracing in a Weekend

const std = @import("std");
const comath_wrapper = @import("comath_wrapper");
const vector = @import("vector.zig");

const BaseType = vector.V3f.BaseType;
const INF = std.math.inf(BaseType);

var prng = std.Random.DefaultPrng.init(0);
pub const rand = prng.random();

// [0, 1)
pub fn rnd_num(
    comptime T: type,
) T 
{
    return switch (@typeInfo(T)) {
        .float, .comptime_float, => return rand.float(T),
        .int, .comptime_int, => return rand.float(T),
        .@"struct" => switch (T) {
            vector.V3f => vector.V3f{
                .x = rand.float(vector.V3f.BaseType),
                .y = rand.float(vector.V3f.BaseType),
                .z = rand.float(vector.V3f.BaseType),
            },
            else => @compileError(
                    "Can only generate random ints, floats, and V3f, not: " 
                    ++ @typeName(T)
            ),
        },
        else => @compileError(
            "Can only generate random ints, floats, and V3f, not: " 
            ++ @typeName(T)
        ),
    };
}

pub fn rnd_num_range(
    comptime T: type,
    low_inclusive: f32,
    high_exclusive: f32,
) T
{
    return comath_wrapper.lerp(rnd_num(T), low_inclusive, high_exclusive);
}

pub const Interval = struct {
    start: BaseType = INF,
    end: BaseType = -INF,
    
    pub const EMPTY: Interval = .{ .start = INF, .end = -INF};
    pub const EVERYTHING: Interval = .{ .start = -INF, .end = INF};
    pub const UNIT_RIGHT_INCLUSIVE: Interval = .{ .start = 0, .end = 1 };
    pub const UNIT_RIGHT_EXCLUSIVE: Interval = .{ .start = 0, .end = 0.99999 };
    pub const ZERO_TO_INF: Interval = .{ .start = 0, .end = INF };

    pub fn size(
        self: @This(),
    ) BaseType
    {
        // assumes that end > start
        return self.end - self.start;
    }
    
    pub fn contains(
        self: @This(),
        ord: anytype,
    ) bool
    {
        return switch (@typeInfo(@TypeOf(ord))) {
            .@"struct" => (
                self.start <= ord.x and ord.x <= self.end
                and self.start <= ord.y and ord.y <= self.end
                and self.start <= ord.z and ord.z <= self.end
            ),
            .@"float", .@"int", .comptime_float, .comptime_int => (
                self.start <= ord and self.end >= ord
            ),
            else => @compileError(
                "cannot compare to things of type: " 
                ++ @typeName(@TypeOf(ord))
            ),
        };
    }

    pub fn surrounds(
        self: @This(),
        ord: BaseType,
    ) bool
    {
        return switch (@typeInfo(@TypeOf(ord))) {
            .@"struct" => (
                self.start < ord.x and ord.x < self.end
                and self.start < ord.y and ord.y < self.end
                and self.start < ord.z and ord.z < self.end
            ),
            .@"float", .@"int", .comptime_float, .comptime_int => (
                self.start < ord and ord < self.end
            ),
            else => @compileError(
                "cannot compare to things of type: " 
                ++ @typeName(@TypeOf(ord))
            ),
        };
    }

    pub fn clamp(
        self: @This(),
        ord: anytype,
    ) @TypeOf(ord)
    {
        return switch (@typeInfo(@TypeOf(ord))) {
            .@"struct" => ord.max(self.start).min(self.end),
            .@"float", .@"int", .comptime_float, .comptime_int => (
                @min(@max(ord, self.end), self.start)
            ),
            else => @compileError(
                "cannot clamp things of type: " ++ @typeName(@TypeOf(ord))
            ),
        };
    }
};
