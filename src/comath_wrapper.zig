//! Wrapper around the comath library for the Zig/RiaW project.  Exposes an 
//! eval function to convert math expressions at compile time from strings like
//! "a+b / c" into function calls, ie `(a.add(b.div(c))`.

const std = @import("std");

const comath = @import("comath");
const vector = @import("vector.zig");
const ray = @import("ray.zig");

/// Comath Context for the Zig/RiaW project.  Comath allows for compile time
/// operator overloading for math expressions like "a + b / c".
const CTX = (
    comath.ctx.fnMethod(
        comath.ctx.simple(
            comath.ctx.namespace(
                .{
                    .v3 = vector.V3f.init_3,
                    .v2 = vector.V3f.init_2,
                },
            )
        ),
        .{
            .@"+" = "add",
            .@"-" = &.{"sub", "negate", "neg"},
            .@"*" = "mul",
            .@"/" = "div",
            .@"<" = "lt",
            .@"<=" = "lteq",
            .@">" = "gt",
            .@">=" = "gteq",
            .@"==" = "eq",
            .@"cos" = "cos",
            .@"." = "dot",
            .@"^" = "cross",
            .@"%" = "mod",
        },
    )
);

/// convert the string expr into a series of function calls at compile time
/// ie "a + b" -> `a.add(b)`
pub inline fn eval(
    /// math expression ie: "a + b - c"
    comptime expr: []const u8, 
    /// inputs ie: .{ .a = first_thing, .b = 12, .c = other_thing }
    inputs: anytype,
) comath.Eval(expr, @TypeOf(CTX), @TypeOf(inputs))
{
    @setEvalBranchQuota(100000);
    return comath.eval(
        expr, CTX, inputs
    ) catch @compileError(
        "couldn't comath: " ++ expr ++ "."
    );
}

test "comath test"
{
    const TestType = struct{
        val: f32,

        pub fn lt(
            self: @This(),
            rhs: f32,
        ) bool {
            return self.val < rhs;
        }

        pub fn add(
            self: @This(),
            rhs: f32,
        ) @This() {
            return .{ .val = self.val + rhs };
        }
    };

    const lhs = TestType{ .val = 12 };

    try std.testing.expectEqual(
        TestType{ .val = 15 },
        eval("lhs + v", .{ .lhs = lhs, .v = 3 }),
    );

    // @TODO: these require building the context out further to support these
    //        operators.

    // try std.testing.expectEqual(
    //     false,
    //     eval("lhs < v", .{ .lhs  = lhs, .v = 3 }),
    // );
    //
    // try std.testing.expectEqual(
    //     true,
    //     eval("lhs < v", .{ .lhs  = lhs, .v = 15 }),
    // );

    // try std.testing.expectEqual(
    //     true,
    //     eval("lhs > v", .{ .lhs  = lhs, .v = 3 }),
    // );
    //
    // try std.testing.expectEqual(
    //     false,
    //     eval("lhs > v", .{ .lhs  = lhs, .v = 15 }),
    // );

    // try std.testing.expectEqual(
    //     false,
    //     eval("lhs == v", .{ .lhs  = lhs, .v = 15 }),
    // );

    // try std.testing.expectEqual(
    //     false,
    //     eval("lhs <= v", .{ .lhs  = lhs, .v = 3 }),
    // );
}

/// lerp from a to b by amount u, [0, 1]
pub fn lerp(
    u: anytype,
    a: anytype,
    b: @TypeOf(a),
) @TypeOf(a) 
{
    return eval(
        "(a * ((-u) + 1.0)) + (b * u)",
        .{
            .a = a,
            .b = b,
            .u = u,
        }
    );
}

test "method test"
{
    const result = eval(
        "v3(1,2,3).unit_vector().length()",
        .{}
    );

    try std.testing.expectApproxEqAbs(1, result, 0.0001);
}
