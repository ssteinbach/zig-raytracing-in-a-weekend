//! example app using the app wrapper

const std = @import("std");
const builtin = @import("builtin");

const raytrace = @import("raytrace");

const ziis = @import("zgui_cimgui_implot_sokol");
const sokol = ziis.sokol;
const zgui = ziis.zgui;
const zplot = zgui.plot;
const sg = ziis.sokol.gfx;
const sgl = ziis.sokol.gl;
//------------------------------------------------------------------------------
//  shapes.zig
//
//  Simple sokol.shape demo.
//------------------------------------------------------------------------------
const slog = sokol.log;
const sapp = sokol.app;
const sglue = sokol.glue;
const sdtx = sokol.debugtext;
const sshape = sokol.shape;
const vec3 = @import("math.zig").Vec3;
const mat4 = @import("math.zig").Mat4;
const assert = @import("std").debug.assert;
const shd = @import("shaders/shapes.glsl.zig");

const img22 = @import("raytrace").render_functions.img22;

const Shape = struct {
    pos: vec3 = vec3.zero(),
    draw: sshape.ElementRange = .{},
};

// const NUM_SHAPES = 5;

const IS_WASM = builtin.target.cpu.arch.isWasm();

/// the GPA - useful for detecting leaks, but ONLY works in non EMCC builds
var gpa = (
    if (IS_WASM) null 
    else std.heap.GeneralPurposeAllocator(.{}){}
);
const backing_allocator = (
    if (IS_WASM) std.heap.c_allocator 
    else gpa.allocator()
);
// var single_threaded_arena = std.heap.ArenaAllocator.init(
//     backing_allocator
// );
// const allocator = single_threaded_arena.allocator();
const allocator = gpa.allocator();

const state = struct {
    var pass_action: sg.PassAction = .{};
    var pip: sg.Pipeline = .{};
    var bind: sg.Bindings = .{};
    var vs_params: shd.VsParams = undefined;
    // var shapes: [NUM_SHAPES]Shape = .{
    //     .{ .pos = .{ .x = -1, .y = 1, .z = 0 } },
    //     .{ .pos = .{ .x = 1, .y = 1, .z = 0 } },
    //     .{ .pos = .{ .x = -2, .y = -1, .z = 0 } },
    //     .{ .pos = .{ .x = 2, .y = -1, .z = 0 } },
    //     .{ .pos = .{ .x = 0, .y = -1, .z = 0 } },
    // };
    var dyn_shapes: []Shape = &.{};
    var rx: f32 = 0.0;
    var ry: f32 = 0.0;
    var rndr_state : img22.RNDR.State = undefined;

    const view = mat4.lookat(.{ .x = 0.0, .y = 1.5, .z = 6.0 }, vec3.zero(), vec3.up());
};

const TEX_DIM : [2]i32 = .{ 400, 225 };

export fn init(
) void 
{
    var img =  raytrace.Image_rgba_u8.init(
        allocator,
        TEX_DIM[0],
        TEX_DIM[1]
    ) catch @panic("couldn't make image");

    img22.RNDR.init(allocator, &img);
    state.rndr_state = img22.RNDR.state.?;

    sg.setup(
        .{
            .environment = sglue.environment(),
            .logger = .{
                .func = slog.func 
            },
        },
        );

    sgl.setup(
        .{
            .logger = .{
                .func = slog.func,
            },
        },
    );

    var sdtx_desc: sdtx.Desc = .{
        .logger = .{ .func = slog.func },
    };
    sdtx_desc.fonts[0] = sdtx.fontOric();
    sdtx.setup(sdtx_desc);

    // pass-action for clearing to black
    state.pass_action.colors[0] = .{
        .load_action = .CLEAR,
        .clear_value = .{ .r = 0, .g = 0, .b = 0, .a = 1 },
    };

    // shader- and pipeline-object
    state.pip = sg.makePipeline(.{
        .shader = sg.makeShader(shd.shapesShaderDesc(sg.queryBackend())),
        .layout = init: {
            var l = sg.VertexLayoutState{};
            l.buffers[0] = sshape.vertexBufferLayoutState();
            l.attrs[shd.ATTR_shapes_position] = sshape.positionVertexAttrState();
            l.attrs[shd.ATTR_shapes_normal] = sshape.normalVertexAttrState();
            l.attrs[shd.ATTR_shapes_texcoord] = sshape.texcoordVertexAttrState();
            l.attrs[shd.ATTR_shapes_color0] = sshape.colorVertexAttrState();
            break :init l;
        },
        .index_type = .UINT16,
        .cull_mode = .NONE,
        .depth = .{
            .compare = .LESS_EQUAL,
            .write_enabled = true,
        },
    });

    // generate shape geometries
    var vertices: [60 * 1024]sshape.Vertex = undefined;
    var indices: [160 * 1024]u16 = undefined;
    var buf: sshape.Buffer = .{
        .vertices = .{ .buffer = sshape.asRange(&vertices) },
        .indices = .{ .buffer = sshape.asRange(&indices) },
    };
    // buf = sshape.buildBox(
    //     buf,
    //     .{
    //         .width = 1.0,
    //         .height = 1.0,
    //         .depth = 1.0,
    //         .tiles = 10,
    //         .random_colors = true,
    //     }
    // );
    // state.shapes[0].draw = sshape.elementRange(buf);
    // buf = sshape.buildPlane(
    //     buf,
    //     .{
    //         .width = 1.0,
    //         .depth = 1.0,
    //         .tiles = 10,
    //         .random_colors = true,
    //     }
    // );
    // state.shapes[1].draw = sshape.elementRange(buf);
    buf = sshape.buildSphere(buf, .{
        .radius = 0.75,
        .slices = 36,
        .stacks = 20,
        .random_colors = true,
    });
    // state.shapes[2].draw = sshape.elementRange(buf);
    // buf = sshape.buildCylinder(buf, .{
    //     .radius = 0.5,
    //     .height = 1.5,
    //     .slices = 36,
    //     .stacks = 10,
    //     .random_colors = true,
    // });
    // state.shapes[3].draw = sshape.elementRange(buf);
    // buf = sshape.buildTorus(buf, .{
    //     .radius = 0.5,
    //     .ring_radius = 0.3,
    //     .rings = 36,
    //     .sides = 18,
    //     .random_colors = true,
    // });
    // state.shapes[4].draw = sshape.elementRange(buf);

    var shapebuilder = std.ArrayList(Shape).init(allocator);

    std.debug.print("\nprebuilt\n", .{});
    for (state.rndr_state.world)
        |hittable|
    {
        switch (hittable)
        {
            .sphere => |sph| {
                std.debug.print("adding sphere: {d}\n", .{ sph.radius});
                const slices = 36;
                const stacks = 20;
                buf = if (sph.radius < 10) (
                    sshape.buildSphere(
                        buf,
                        .{
                            .radius = sph.radius,
                            .slices = slices,
                            .stacks = stacks,
                            .random_colors = true,
                        },
                    )
                )
                else (
                    sshape.buildSphere(
                        buf,
                        .{
                            .radius = sph.radius,
                            .slices = slices * 4,
                            .stacks = stacks * 4,
                            .random_colors = true,
                        },
                    )
                );
                shapebuilder.append(
                    .{ 
                        .pos = .{
                            .x = sph.center_worldspace.x,
                            .y = sph.center_worldspace.y,
                            .z = sph.center_worldspace.z,
                        },
                        .draw = sshape.elementRange(buf),
                    },
                ) catch @panic("arg");

            },
            // else => {
            //     std.debug.print("unknown thing\n", .{});
            // }
        }
    }

    // camera
    buf = sshape.buildSphere(
        buf,
        .{
            .radius = 0.25,
            .slices = 16,
            .stacks = 5,
            .random_colors = false,
        },
    );
    shapebuilder.append(
        .{ 
            .pos = .{
                .x = state.rndr_state.camera.center.x,
                .y = state.rndr_state.camera.center.y,
                .z = state.rndr_state.camera.center.z,
            },
            .draw = sshape.elementRange(buf),
        },
    ) catch @panic("arg");

    // buf = sshape.buildSphere(
    //     buf,
    //     .{
    //         .radius = 1.25,
    //         .slices = 16,
    //         .stacks = 5,
    //         .random_colors = false,
    //     },
    // );
    // shapebuilder.append(
    //     .{ 
    //         .pos = .{
    //             .x = state.rndr_state.camera.look_at.x,
    //             .y = state.rndr_state.camera.look_at.y,
    //             .z = state.rndr_state.camera.look_at.z,
    //         },
    //         .draw = sshape.elementRange(buf),
    //     },
    // ) catch @panic("arg");

    // assert(buf.valid);
    std.debug.print("\nbuilt\n", .{});

    state.dyn_shapes = shapebuilder.toOwnedSlice() catch @panic("blurg");

    // one vertex- and index-buffer for all shapes
    state.bind.vertex_buffers[0] = sg.makeBuffer(sshape.vertexBufferDesc(buf));
    state.bind.index_buffer = sg.makeBuffer(sshape.indexBufferDesc(buf));
}

export fn frame(
) void 
{
    // help text
    sdtx.canvas(sapp.widthf() * 0.5, sapp.heightf() * 0.5);
    sdtx.pos(0.5, 0.5);
    sdtx.puts("press key to switch draw mode:\n\n");
    sdtx.puts("  1: vertex normals\n");
    sdtx.puts("  2: texture coords\n");
    sdtx.puts("  3: vertex colors\n");

    // view-project matrix
    const proj = mat4.persp(60.0, sapp.widthf() / sapp.heightf(), 0.01, 10.0);
    const view_proj = mat4.mul(proj, state.view);

    // model-rotation matrix
    const dt: f32 = @floatCast(sapp.frameDuration() * 60);
    state.rx += 1.0 * dt;
    state.ry += 1.0 * dt;
    const rxm = mat4.rotate(state.rx, .{ .x = 1, .y = 0, .z = 0 });
    const rym = mat4.rotate(state.ry, .{ .x = 0, .y = 1, .z = 0 });
    const rm = mat4.mul(rxm, rym);

    // render shapes...
    sg.beginPass(.{ .action = state.pass_action, .swapchain = sglue.swapchain() });
    sg.applyPipeline(state.pip);
    sg.applyBindings(state.bind);

    for (state.dyn_shapes) 
        |shape| 
    {
        // per-shape model-view-projection matrix
        const model = mat4.mul(mat4.translate(shape.pos), rm);
        state.vs_params.mvp = mat4.mul(view_proj, model);
        sg.applyUniforms(shd.UB_vs_params, sg.asRange(&state.vs_params));
        sg.draw(shape.draw.base_element, shape.draw.num_elements, 1);
    }

    sdtx.draw();

    {
        {
            sgl.beginLines();
            // from the camera
            sgl.v3f(
                state.rndr_state.camera.center.x,
                state.rndr_state.camera.center.y,
                state.rndr_state.camera.center.z,
            );
            sgl.v3f(
                state.rndr_state.camera.look_at.x,
                state.rndr_state.camera.look_at.y,
                state.rndr_state.camera.look_at.z,
            );
            defer sgl.end();
        }
        sgl.draw();
    }
    sg.endPass();
    sg.commit();

}

export fn input(
    event: ?*const sapp.Event,
) void 
{
    const ev = event.?;
    if (ev.type == .KEY_DOWN) {
        state.vs_params.draw_mode = switch (ev.key_code) {
            ._1 => 0.0,
            ._2 => 1.0,
            ._3 => 2.0,
            else => state.vs_params.draw_mode,
        };
    }
}

export fn cleanup(
) void 
{
    sdtx.shutdown();
    sg.shutdown();
}

pub fn main(
) void 
{
    sapp.run(
        .{
            .init_cb = init,
            .frame_cb = frame,
            .event_cb = input,
            .cleanup_cb = cleanup,
            .width = 800,
            .height = 600,
            .sample_count = 4,
            .icon = .{ .sokol_default = true },
            .window_title = "shapes.zig",
            .logger = .{ .func = slog.func },
        }
    );
}
