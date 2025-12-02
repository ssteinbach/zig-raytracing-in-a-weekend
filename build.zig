const std = @import("std");

const ziis = @import("zgui_cimgui_implot_sokol");

const BuildState = struct {
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    dep_ziis: *std.Build.Dependency,
    lib_mod: *std.Build.Module,
    check_step: *std.Build.Step,
    test_step: *std.Build.Step,
};

/// build an executable in this library
pub fn executable(
    b: *std.Build,
    comptime name: []const u8,
    main_filepath: []const u8,
    state: BuildState,
) !void
{
    const exe_mod = b.createModule(
        .{
            .root_source_file = b.path(main_filepath),
            .target = state.target,
            .optimize = state.optimize,
        }
    );
    exe_mod.addImport(
        "zgui_cimgui_implot_sokol",
        state.dep_ziis.module("zgui_cimgui_implot_sokol")
    );

    exe_mod.addImport("raytrace", state.lib_mod);

    const exe_unit_tests = b.addTest(
        .{
            .root_module = exe_mod,
        }
    );
    state.test_step.dependOn(&exe_unit_tests.step);

    if (state.target.result.cpu.arch.isWasm())
    {
        try ziis.build_wasm(
            b,
            .{
                .app_name = name,
                .mod_main = exe_mod,
                .dep_ziis_builder = state.dep_ziis.builder,
                .target = state.target,
                .optimize = state.optimize,
                .dep_c_libs = &.{},
            },
        );
    }
    else
    {
        try build_native(
            b,
            name,
            exe_mod,
            state.check_step,
        );
    }
}

pub fn build(
    b: *std.Build
) !void 
{
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const test_step = b.step("test", "Run unit tests");
    const check_step = b.step("check", "check if it compiles");

    const lib_mod = b.createModule(
        .{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = optimize,
        }
    );

    const comath_dep = b.dependency(
        "comath",
        .{},
    );

    lib_mod.addImport("comath", comath_dep.module("comath"));

    // library artifact
    const lib = b.addLibrary(
        .{
            .linkage = .static,
            .name = "raytrace",
            .root_module = lib_mod,
        }
    );

    check_step.dependOn(&lib.step);

    const lib_unit_tests = b.addTest(
        .{
            .root_module = lib_mod,
        }
    );

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);
    test_step.dependOn(&run_lib_unit_tests.step);

    b.installArtifact(lib);

    const state = BuildState{
        .target = target,
        .optimize = optimize,
        .dep_ziis = b.dependency(
            "zgui_cimgui_implot_sokol",
            .{
                .optimize = optimize,
                .target = target,
            }
        ),
        .lib_mod = lib_mod,
        .check_step = check_step,
        .test_step = test_step,
    };

    // commandline renderer
    {
        try executable(
            b,
            "render",
            "src/main.zig",
            state,
        );
    }

    // gui viewer
    {
        try executable(
            b,
            "viewer",
            "src/viewer.zig",
            state
        );
    }

    // executable program that writes the scene to USD for debugging
    {
        try executable(
            b,
            "debug_writer",
            "src/debug_writer.zig",
            state
        );
    }
}

/// builds an executable for non-wasm architecture
fn build_native(
    b: *std.Build,
    comptime name: []const u8,
    mod: *std.Build.Module,
    check_step: *std.Build.Step,
) !void 
{
    const exe = b.addExecutable(
        .{
            .name = name,
            .root_module = mod,
        },
    );
    check_step.dependOn(&exe.step);
    b.installArtifact(exe);
    var run_step = b.step(
        name++"-run",
        "Run the " ++ name ++ " app.",
    );

    const run_cmd = b.addRunArtifact(exe);
    if (b.args) 
        |args| 
    {
        run_cmd.addArgs(args);
    }

    run_step.dependOn(&run_cmd.step);
}
