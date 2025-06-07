//! Vector struct and comath support

const std = @import("std");

pub const EPSILON_F = 0.000001;

pub fn Vec3Of(
    comptime T: type
) type
{
    return struct {
        x: T = 0,
        y: T = 0,
        z: T = 0,

        pub const BaseType = T;
        pub const VecType = @This();

        pub const ZERO : VecType = VecType.init(0);
        pub const ONE : VecType = VecType.init(1);
        pub const INF : VecType = VecType.init(std.math.inf(T));
        pub const INF_NEG : VecType = VecType.init(-std.math.inf(T));
        pub const NAN : VecType = VecType.init(std.math.nan(T));
        pub const EPSILON = VecType.init(EPSILON_F);

        /// build a vector out of the incoming value, casting as necessary
        pub inline fn init(
            value: anytype,
        ) VecType
        {
            return switch (@typeInfo(@TypeOf(value))) {
                .float, .comptime_float => .{
                    .x = @floatCast(value),
                    .y = @floatCast(value),
                    .z = @floatCast(value),
                },
                .int, .comptime_int => .{ 
                    .x = @floatFromInt(value),
                    .y = @floatFromInt(value),
                    .z = @floatFromInt(value),
                },
                .@"struct" => .{
                    .x = value.x,
                    .y = value.y,
                    .z = value.z,
                },
                .array => .{
                    .x = value[0],
                    .y = value[1],
                    .z = value[2],
                },
                else => @compileError(
                    "Can only be constructed from a float, int, struct, "
                    ++ "or array, not a " 
                    ++ @typeName(@TypeOf(value))
                ),
            };
        }

        /// if the vector is a NaN
        pub inline fn is_nan(
            self: @This(),
        ) bool
        {
            inline for (std.meta.fields(VecType))
                |f|
            {
                if (std.math.isNan(@field(self, f.name))) 
                {
                    return true;
                }
            }

            return false;
        }

        pub fn format(
            self: @This(),
            // fmt
            comptime _: []const u8,
            // options
            _: std.fmt.FormatOptions,
            writer: anytype,
        ) !void 
        {
            try writer.print(
                "V3f{{ {d}, {d}, {d} }}",
                .{ self.x, self.y, self.z }
            );
        }
    };
}

pub const V3f = Vec3Of(f32);

/// compare two vectors.  Create an vectors from expected if it is not
/// already one.  NaN == NaN is true.
pub fn expectOrdinateEqual(
    expected_in: anytype,
    measured_in: anyerror!V3f,
) !void
{
    const expected = switch(@TypeOf(expected_in)) {
        V3f => expected_in,
        else => switch(@typeInfo(@TypeOf(expected_in))) {
            .comptime_int, .int, .comptime_float, .float, .@"struct", .array => (
                V3f.init(expected_in)
            ),
            else => @compileError(
                "Error: can only compare an Ordinate to a float, int, or "
                ++ "other Ordinate.  Got a: " ++ @typeName(@TypeOf(expected_in))
            ),
        },
    };

    const measured = (
        measured_in catch |err| return err
    );

    if (expected.is_nan() and measured.is_nan()) {
        return;
    }

    inline for (std.meta.fields(V3f))
        |f|
    {
        errdefer std.log.err(
            "field: " ++ f.name ++ " did not match.", .{}
        );
        switch (@typeInfo(f.type)) {
            .int, .comptime_int => try std.testing.expectEqual(
                @field(expected, f.name),
                @field(measured, f.name),
            ),
            .float, .comptime_float => try std.testing.expectApproxEqAbs(
                @field(expected, f.name),
                @field(measured, f.name),
                // util.EPSILON_F,
                1e-3,
            ),
            inline else => @compileError(
                "Do not know how to handle fields of type: " ++ f.type
            ),
        }
    }
}

test "Vec Init"
{
    inline for (
        &.{
            3,
            3.14159,
            .{ .x = 3, .y = 1, .z = 2 },
            [_]f32{ 1, 4, 5, 6, },
        }
    )
        |v|
    {
        std.debug.print("hi vec: {s}\n", .{ V3f.init(v) });
        try expectOrdinateEqual(v, V3f.init(v));
    }
}
