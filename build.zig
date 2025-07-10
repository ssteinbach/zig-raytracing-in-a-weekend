const std = @import("std");

const BuildState = struct {
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    dep_ziis: *std.Build.Dependency,
    lib_mod: *std.Build.Module,
    check_step: *std.Build.Step,
    test_step: *std.Build.Step,
};

pub fn executable(
    b: *std.Build,
    name: []const u8,
    main_filepath: []const u8,
    state: BuildState,
) void
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

        const exe = b.addExecutable(
            .{
                .name = "viewer",
                .root_module = exe_mod,
            }
        );
        state.check_step.dependOn(&exe.step);

        b.installArtifact(exe);

        const run_cmd = b.addRunArtifact(exe);

        run_cmd.step.dependOn(b.getInstallStep());

        if (b.args) 
            |args| 
        {
            run_cmd.addArgs(args);
        }

        const run_step = b.step(
            name,
            "Run the viewer"
        );
        run_step.dependOn(&run_cmd.step);

        const exe_unit_tests = b.addTest(
            .{
                .root_module = exe_mod,
            }
        );

        const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);
        state.test_step.dependOn(&run_exe_unit_tests.step);
}

pub fn build(
    b: *std.Build
) void 
{
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const test_step = b.step("test", "Run unit tests");
    const check_step = b.step(
        "check",
        "check if it compiles"
    );

    const lib_mod = b.createModule(
        .{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = optimize,
        }
    );

    const comath_dep = b.dependency(
        "comath",
        .{
            .optimize = optimize,
            .target = target,
        }
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

    // commandline renderer
    {
        // @TODO: replace this with a call to the raytracer that dumps to a
        //        file
        const exe_mod = b.createModule(
            .{
                .root_source_file = b.path("src/main.zig"),
                .target = target,
                .optimize = optimize,
            }
        );

        exe_mod.addImport("raytrace", lib_mod);

        const exe = b.addExecutable(
            .{
                .name = "render",
                .root_module = exe_mod,
            }
        );

        check_step.dependOn(&exe.step);

        b.installArtifact(exe);

        const run_cmd = b.addRunArtifact(exe);

        run_cmd.step.dependOn(b.getInstallStep());

        if (b.args) 
            |args| 
        {
            run_cmd.addArgs(args);
        }

        const run_step = b.step("run", "Run the renderer");
        run_step.dependOn(&run_cmd.step);

        const exe_unit_tests = b.addTest(
            .{
                .root_module = exe_mod,
            }
        );

        const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);
        test_step.dependOn(&run_exe_unit_tests.step);
    }


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

    // gui viewer
    {
        executable(
            b,
            "viewer",
            "src/viewer.zig",
            state
        );
    }

    {
        executable(
            b,
            "viewer3d",
            "src/viewer3d.zig",
            state
        );
    }
}
