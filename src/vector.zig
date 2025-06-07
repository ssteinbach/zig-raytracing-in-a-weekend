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

        /// convienent type error for the comptime ducktyping this struct uses
        inline fn type_error(
            thing: anytype,
        ) void
        {
            @compileError(
                @typeName(@This()) ++ " can only do math over floats,"
                ++ " ints and other " ++ @typeName(@This()) ++ ", not: " 
                ++ @typeName(@TypeOf(thing))
            );
        }

        // unary operators

        /// negate the V3f (ie *= -1)
        pub inline fn neg(
            self: @This(),
        ) VecType
        {
            return .{
                .x = - self.x,
                .y = - self.y,
                .z = - self.z,
            };
        }

        /// return the square root of the V3f
        pub inline fn sqrt(
            self: @This(),
        ) VecType
        {
            return .{
                .x = std.math.sqrt(self.x),
                .y = std.math.sqrt(self.y),
                .z = std.math.sqrt(self.z),
            };
        }

        /// return the absolute value of the V3f
        pub inline fn abs(
            self: @This(),
        ) VecType
        {
            return .{
                .x = @abs(self.x),
                .y = @abs(self.y),
                .z = @abs(self.z),
            };
        }

        // binary operators

        /// add to rhs, constructing an Vec as necessary
        pub inline fn add(
            self: @This(),
            rhs: anytype,
        ) VecType
        {
            return switch (@TypeOf(rhs)) {
                VecType => .{ 
                    .x = self.x + rhs.x ,
                    .y = self.y + rhs.y ,
                    .z = self.z + rhs.z ,
                },
                else => {
                    return self.add(VecType.init(rhs));
                },
            };
        }

        /// subtract rhs from self
        pub inline fn sub(
            self: @This(),
            rhs: anytype,
        ) VecType
        {
            return switch (@TypeOf(rhs)) {
                VecType => .{ 
                    .x = self.x - rhs.x,
                    .y = self.y - rhs.y,
                    .z = self.z - rhs.z,
                },
                else => {
                    return self.sub(VecType.init(rhs));
                },
            };
        }

        /// multiply rhs with self
        pub inline fn mul(
            self: @This(),
            rhs: anytype,
        ) VecType
        {
            return switch (@TypeOf(rhs)) {
                VecType => .{ 
                    .x = self.x * rhs.x,
                    .y = self.y * rhs.y,
                    .z = self.z * rhs.z,
                },
                else => {
                    return self.mul(VecType.init(rhs));
                },
            };
        }

        /// divide self by rhs
        pub inline fn div(
            self: @This(),
            rhs: anytype,
        ) VecType
        {
            return switch (@TypeOf(rhs)) {
                VecType => .{ 
                    .x = self.x / rhs.x,
                    .y = self.y / rhs.y,
                    .z = self.z / rhs.z,
                },
                else => {
                    return self.sub(VecType.init(rhs));
                },
            };
        }

        pub fn mod(
            self: @This(),
            rhs: anytype,
        ) VecType
        {
            return switch (@TypeOf(rhs)) {
                VecType => .{ 
                    .x = @mod(self.x , rhs.x),
                    .y = @mod(self.y , rhs.y),
                    .z = @mod(self.z , rhs.z),
                },
                else => {
                    return self.mod(VecType.init(rhs));
                },
            };
        }

        // binary macros

        /// wrapper around std.math.pow for V3f
        pub inline fn pow(
            self: @This(),
            exp: BaseType,
        ) VecType
        {
            return .{ 
                .x = std.math.pow(BaseType, self.x, exp),
                .y = std.math.pow(BaseType, self.y, exp),
                .z = std.math.pow(BaseType, self.z, exp),
            };
        }

        pub inline fn min(
            self: @This(),
            rhs: anytype,
        ) VecType
        {
            return switch (@TypeOf(rhs)) {
                VecType => .{ 
                    .x = @min(self.x,rhs.x),
                    .y = @min(self.y,rhs.y),
                    .z = @min(self.z,rhs.z),
                },
                else => {
                    return self.min(VecType.init(rhs));
                },
            };
        }

        pub inline fn max(
            self: @This(),
            rhs: anytype,
        ) VecType
        {
            return switch (@TypeOf(rhs)) {
                VecType => .{ 
                    .x = @max(self.x,rhs.x),
                    .y = @max(self.y,rhs.y),
                    .z = @max(self.z,rhs.z),
                },
                else => {
                    return self.max(VecType.init(rhs));
                },
            };
        }

        // binary tests

        /// strict equality
        pub inline fn eql(
            self: @This(),
            rhs: anytype,
        ) bool
        {
            return switch (@TypeOf(rhs)) {
                VecType => (
                    self.x == rhs.x
                    and self.y == rhs.y
                    and self.z == rhs.z
                ),
                else => {
                    return self.eql(VecType.init(rhs));
                },
            };
        }

        /// approximate equality with the EPSILON as the width
        pub inline fn eql_approx(
            self: @This(),
            rhs: anytype,
        ) bool
        {
            return switch (@TypeOf(rhs)) {
                VecType => (
                    self.x < (rhs.x + EPSILON_F)
                    and self.y < (rhs.y + EPSILON_F)
                    and self.z < (rhs.z + EPSILON_F)
                    and self.x > (rhs.x - EPSILON_F)
                    and self.y > (rhs.y - EPSILON_F)
                    and self.z > (rhs.z - EPSILON_F)
                ),
                else => {
                    return self.eql_approx(VecType.init(rhs));
                },
            };
        }

        /// if the V3f is infinite
        pub inline fn is_inf(
            self: @This(),
        ) bool
        {
            return std.math.isInf(self.v);
        }

        /// if the V3f is finite
        pub inline fn is_finite(
            self: @This(),
        ) bool
        {
            return std.math.isFinite(self.v);
        }

        // vector specific functions
 
        /// dot product
        pub fn dot(
            self: @This(),
            rhs: VecType,
        ) BaseType
        {
            return (self.x * rhs.x + self.y * rhs.y + self.z * rhs.z);
        }

        /// cross product
        pub fn cross(
            self: @This(),
            rhs: VecType,
        ) VecType
        {
            return .{
                .x = self.y * rhs.z - self.z * rhs.y,
                .y = self.z * rhs.x - self.x * rhs.z,
                .z = self.x * rhs.y - self.y * rhs.x,
            };
        }

        /// length of the vector
        pub fn length(
            self: @This(),
        ) BaseType
        {
            return std.math.sqrt(self.length_squared());
        }

        /// square of the length 
        pub fn length_squared(
            self: @This(),
        ) BaseType
        {
            return self.dot(self);
        }

        /// normalized form / direction vector of unit length
        pub fn unit_vector(
            self: @This(),
        ) VecType
        {
            return self.div(self.length());
        }

        pub fn as(
            self: @This(),
            comptime other_t: type,
        ) Vec3Of(other_t)
        {

            return switch (@typeInfo(other_t)) {
                .float, .comptime_float => .{
                    .x = @floatCast(self.x),
                    .y = @floatCast(self.y),
                    .z = @floatCast(self.z),
                },
                .int, .comptime_int => .{
                    .x = @intFromFloat(self.x),
                    .y = @intFromFloat(self.y),
                    .z = @intFromFloat(self.z),
                },
                else => @compileError(
                    "Can only be converted to a float or int type not a " 
                    ++ @typeName(T)
                ),

            };
        }
    };
}

pub const V3f = Vec3Of(f32);
pub const Color3f = V3f;
pub const Point3f = V3f;

/// compare two vectors.  Create an vectors from expected if it is not
/// already one.  NaN == NaN is true.
pub fn expectV3fEqual(
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
                "Error: can only compare an V3f to a float, int, or "
                ++ "other V3f.  Got a: " ++ @typeName(@TypeOf(expected_in))
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
                // EPSILON_F,
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
        try expectV3fEqual(v, V3f.init(v));
    }

    // nan check
    {
        const nan = std.math.nan(f32);
        std.debug.print("hi vec: {s}\n", .{ V3f.init(nan) });
        try std.testing.expectEqual(true, V3f.init(nan).is_nan());
    }
}

pub inline fn min(
    lhs: anytype,
    rhs: @TypeOf(lhs),
) @TypeOf(lhs)
{
    return switch (@typeInfo(@TypeOf(lhs))) {
        .@"struct" => lhs.min(rhs),
        else => std.math.min(lhs, rhs),
    };
}

pub inline fn max(
    lhs: anytype,
    rhs: @TypeOf(lhs),
) @TypeOf(lhs)
{
    return switch (@typeInfo(@TypeOf(lhs))) {
        .@"struct" => lhs.max(rhs),
        else => std.math.max(lhs, rhs),
    };
}

pub inline fn eql(
    lhs: anytype,
    rhs: @TypeOf(lhs),
) bool
{
    return switch (@typeInfo(@TypeOf(lhs))) {
        .@"struct" => lhs.eql(rhs),
        else => lhs == rhs,
    };
}

pub inline fn eql_approx(
    lhs: anytype,
    rhs: @TypeOf(lhs),
) bool
{
    return switch (@typeInfo(@TypeOf(lhs))) {
        .@"struct" => lhs.eql_approx(rhs),
        else => std.math.approxEqAbs(@TypeOf(lhs), lhs, rhs, EPSILON_F),
    };
}

const basic_math = struct {
    // unary
    pub inline fn neg(in: anytype) @TypeOf(in) { return 0-in; }
    pub inline fn sqrt(in: anytype) @TypeOf(in) { return std.math.sqrt(in); }
    pub inline fn abs(in: anytype) @TypeOf(in) { return @abs(in); }
    pub inline fn normalized(in: anytype) @TypeOf(in) { return in; }

    // binary
    pub inline fn add(lhs: anytype, rhs: anytype) @TypeOf(lhs) { return lhs + rhs; }
    pub inline fn sub(lhs: anytype, rhs: anytype) @TypeOf(lhs) { return lhs - rhs; }
    pub inline fn mul(lhs: anytype, rhs: anytype) @TypeOf(lhs) { return lhs * rhs; }
    pub inline fn div(lhs: anytype, rhs: anytype) @TypeOf(lhs) { return lhs / rhs; }

    // binary macros
    pub inline fn min(lhs: anytype, rhs: anytype) @TypeOf(lhs) { return @min(lhs, rhs); }
    pub inline fn max(lhs: anytype, rhs: anytype) @TypeOf(lhs) { return @max(lhs, rhs); }

    // binline fnary tests
    pub inline fn eql(lhs: anytype, rhs: anytype) bool { return lhs == rhs; }
    pub inline fn eql_approx(lhs: anytype, rhs: anytype) bool { return std.math.approxEqAbs(V3f.BaseType, lhs, rhs, EPSILON_F); }
};

test "Base V3f: Unary Operator Tests"
{
    const TestCase = struct {
        in: V3f.BaseType,
    };
    const tests = &[_]TestCase{
        .{ .in =  1 },
        .{ .in =  -1 },
        .{ .in = 25 },
        .{ .in = 64.34 },
        .{ .in =  5.345 },
        .{ .in =  -5.345 },
        .{ .in =  0 },
        .{ .in =  -0.0 },
        .{ .in =  std.math.inf(V3f.BaseType) },
        .{ .in =  -std.math.inf(V3f.BaseType) },
        .{ .in =  std.math.nan(V3f.BaseType) },
    };

    inline for (&.{ "neg", "sqrt", "abs",})
        |op|
    {
        for (tests)
            |t|
        {
            const expected_in = (@field(basic_math, op)(t.in));
            const expected = V3f.init(expected_in);

            const in = V3f.init(t.in);
            const measured = @field(V3f, op)(in);

            errdefer std.debug.print(
                "Error with test: \n" ++ @typeName(V3f) ++ "." ++ op 
                ++ ":\n iteration: {any}\nin: {d}\nexpected_in: {d}\n"
                ++ "expected: {d}\nmeasured_in: {s}\nmeasured: {s}\n",
                .{ t, t.in, expected_in, expected, in, measured },
            );

            try expectV3fEqual(expected, measured);
            std.debug.print("unary: {s} {s}\n", .{ op, measured });
        }
    }
}

test "Base V3f: Binary Function Tests"
{
    const TestCase = struct {
        lhs: V3f.BaseType,
        rhs: V3f.BaseType,
    };
    const tests = &[_]TestCase{
        .{ .lhs =  1, .rhs =  1 },
        .{ .lhs = -1, .rhs =  1 },
        .{ .lhs =  1, .rhs = -1 },
        .{ .lhs = -1, .rhs = -1 },
        .{ .lhs = -1.2, .rhs = -1001.45 },
        .{ .lhs =  0, .rhs =  5.345 },
    };

    inline for (&.{ "min", "max", "eql", "eql_approx" })
        |op|
    {
        for (tests)
            |t|
        {
            const lhs = V3f.init(t.lhs);
            const rhs = V3f.init(t.rhs);

            const expected_raw = (
                @field(basic_math, op)(t.lhs, t.rhs) 
            );

            const measured = @field(@This(), op)(lhs, rhs);

            const is_ord = @TypeOf(measured) == V3f;

            const expected = if (is_ord) V3f.init(
                expected_raw
            ) else expected_raw;

            if (is_ord) {
                errdefer std.debug.print(
                    "Error with test: " ++ @typeName(V3f) ++ "." ++ op ++ 
                    ": iteration: {any}\nexpected: {d}\nmeasured: {s}\n",
                    .{ t, expected, measured },
                );
            } else {
                errdefer std.debug.print(
                    "Error with test: " ++ @typeName(V3f) ++ "." ++ op ++ 
                    ": iteration: {any}\nexpected: {any}\nmeasured: {any}\n",
                    .{ t, expected, measured },
                );
            }

            if (is_ord) {
                try expectV3fEqual(expected, measured);
            }
            else {
                try std.testing.expectEqual(expected, measured);
            }

            std.debug.print(
                "binary {s} {s} {s} = {any}\n",
                .{ lhs,op,rhs, measured }
            );
        }
    }
}

test "Base V3f: Binary Operator Tests"
{
    const values = [_]V3f.BaseType{
        0,
        1,
        1.2,
        5.345,
        3.14159,
        std.math.pi,
        // 0.45 not exactly representable in binary floating point numbers
        1001.45,
        std.math.inf(V3f.BaseType),
        std.math.nan(V3f.BaseType),
    };

    const signs = [_]V3f.BaseType{ -1, 1 };

    inline for (&.{ "add", "sub", "mul", "div", })
        |op|
    {
        for (values)
            |lhs_v|
        {
            for (signs)
                |s_lhs|
            {
                for (values)
                    |rhs_v|
                {
                    for (signs) 
                        |s_rhs|
                    {
                        const lhs_sv = s_lhs * lhs_v;
                        const rhs_sv = s_rhs * rhs_v;

                        const expected = V3f.init(
                           @field(basic_math, op)(
                               lhs_sv,
                               rhs_sv
                            ) 
                        );

                        const lhs_o = V3f.init(lhs_sv);
                        const rhs_o = V3f.init(rhs_sv);

                        const measured = (
                            @field(V3f, op)(lhs_o, rhs_o)
                        );

                        errdefer std.debug.print(
                            "Error with test: " ++ @typeName(V3f) 
                            ++ "." ++ op ++ ": \nlhs: {d} * {d} rhs: {d} * {d}\n"
                            ++ "lhs_sv: {d} rhs_sv: {d}\n"
                            ++ "{s} " ++ op ++ " {s}\n"
                            ++ "expected: {d}\nmeasured: {s}\n",
                            .{
                                s_lhs, lhs_v,
                                s_rhs, rhs_v,
                                lhs_sv, rhs_sv,
                                lhs_o, rhs_o,
                                expected, measured,
                            },
                        );

                        try expectV3fEqual(
                            expected,
                            measured
                        );

                        std.debug.print(
                            "binary {s} {s} {s} => {any}\n",
                            .{lhs_o, op, rhs_o, measured},
                        );
                    }
                }
            }
        }
    }
}

test "cross product"
{
    const v1 = V3f{ .x = 1, .y = 0, .z = 1, };
    const v2 = V3f{ .x = 0, .y = 1, .z = 1, };

    const measured = v1.cross(v2);

    try expectV3fEqual(
        V3f{.x = -1, .y = -1, .z = 1},
        measured
    );
}

test "dot product"
{
    const v1 = V3f{ .x = 1, .y = 0, .z = 1, };
    const v2 = V3f{ .x = 0, .y = 1, .z = 1, };

    const measured = v1.dot(v2);

    try std.testing.expectEqual(
        1,
        measured
    );
}

test "length"
{
    for (
        [_]struct{
            v: V3f, result: V3f.BaseType
        }{
            .{ .v = V3f{ .x = 3, .y = 4, .z = 0 }, .result = 5 },
            .{ .v = V3f{ .x = 0, .y = 4, .z = 3 }, .result = 5 },
            .{ .v = V3f{ .x = 2, .y = 2, .z = 1 }, .result = 3 },
            .{ .v = V3f{ .x = 2, .y = 1, .z = 2 }, .result = 3 },
            .{ .v = V3f{ .x = 1, .y = 2, .z = 2 }, .result = 3 },
            .{ .v = V3f{ .x = -1, .y = -2, .z = 2 }, .result = 3 },
        }
    ) |t|
    {
        const measured = t.v.length();
        try std.testing.expectEqual(t.result, measured);

        const measured_sq = t.v.length_squared();
        try std.testing.expectEqual(
            t.result * t.result,
            measured_sq
        );
    }
}
