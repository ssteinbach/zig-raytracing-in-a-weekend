//! example app using the app wrapper

const std = @import("std");
const builtin = @import("builtin");

const raytrace = @import("raytrace");

const ziis = @import("zgui_cimgui_implot_sokol");
const zgui = ziis.zgui;
const zplot = zgui.plot;
const sg = ziis.sokol.gfx;
const app_wrapper = ziis.app_wrapper;

// const build_options = @import("build_options");

const STATE = struct {
    var f: f32 = 0;
    var backup_f: f32 = 0;
    var demo_window_gui = false;
    var demo_window_plot = false;
    const TEX_DIM : [2]i32 = .{ 400, 225 };
    const COLOR_CHANNELS:usize = 4;
    var tex: sg.Image = .{};
    var texid: u64 = 0;
    var frame_number: usize = 0;
    var buffer : raytrace.Image_rgba_u8 = undefined;
    var journal : ?ziis.undo.Journal = null;
    var current_renderer: usize = raytrace.RENDERERS.len - 1;

    /// threading
    var render_thread : std.Thread = undefined;
    var render_thread_is_running= std.atomic.Value(bool).init(false);
    var render_progress = std.atomic.Value(usize).init(0);

    // measuring
    var fps : f64 = 0;
    var mspf : f64 = 0;
    var render_start_t : std.time.Instant = undefined;
    var start_program_t : std.time.Instant = undefined;
};

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
var single_threaded_arena = std.heap.ArenaAllocator.init(
    backing_allocator
);
const allocator = single_threaded_arena.allocator();

/// like calling Imgui::Image but compatible with the texture stuff I'm doing
fn imgui_image(
    texid: u64,
    size: [2]f32,
) void
{
    ziis.cimgui.igImage(
        texid,
        .{ .x = size[0], .y = size[1]},
        .{ .x = 0, .y = 0 },
        .{ .x = 1, .y = 1 },
        .{ .x = 1, .y = 1, .z = 1, .w = 1 },
        .{ .x = 0, .y = 0, .z = 0, .w = 0 },
    );
}

/// draw the UI
fn draw(
) !void 
{
    const vp = zgui.getMainViewport();
    const size = vp.getSize();

    STATE.frame_number = @intFromFloat(@abs(STATE.f));

    var render_status:[]const u8 = "RENDERING";
    var buffer : [128:0]u8 = undefined;

    if (STATE.render_thread_is_running.load(.monotonic) == false) 
    {
        STATE.render_thread.join();

        var data = ziis.sokol.gfx.ImageData{};

        data.subimage[0][0] = ziis.sokol.gfx.asRange(
            STATE.buffer.data
        );

        sg.updateImage( STATE.tex, data);

        render_status = "DONE";

        STATE.render_thread = start_render_thread() catch @panic("can't start thread");
    }

    zgui.setNextWindowPos(.{ .x = 0, .y = 0 });
    zgui.setNextWindowSize(
        .{ 
            .w = size[0],
            .h = size[1],
        }
    );

    if (
        zgui.begin(
            "###FULLSCREEN",
            .{ 
                .flags = .{
                    .no_resize = true, 
                    .no_scroll_with_mouse  = true, 
                    .always_auto_resize = true, 
                    .no_move = true,
                    .no_collapse = true,
                    .no_title_bar = true,
                },
            }
        )
    )
    {
        defer zgui.end();

        const preview = raytrace.RENDERERS[STATE.current_renderer].desc;

        if (
            zgui.beginCombo(
                "Current Renderer",
                .{.preview_value = preview}
            )
        )
        {
            defer zgui.endCombo();

            for (raytrace.RENDERERS, 0..)
                |it, ind|
            {
                const is_selected = ind == STATE.current_renderer;

                const lbl = try std.fmt.bufPrintZ(
                    &buffer,
                    "{d}: {s}",
                    .{ ind, it.desc }
                );

                if (
                    zgui.selectable(
                         lbl,
                        .{ .selected = is_selected } 
                    )
                )
                {
                    STATE.current_renderer = ind;
                }

                if (is_selected)
                {
                    zgui.setItemDefaultFocus();
                }
            }
        }

        zgui.text(
            "Application average {d:.3} ms/frame ({d:.3} FPS)",
            .{ STATE.mspf, STATE.fps, }
        );
        zgui.text(
            "status: {s}: {d} ({d}%)",
            .{
                render_status,
                (try std.time.Instant.now()).since(STATE.render_start_t) / std.time.ns_per_ms,
                STATE.render_progress.load(.monotonic),
            }
        );

        var new = STATE.f;
        if (
            zgui.dragFloat("texture offset", .{ .v = &new })
        ) 
        {
            const cmd = try ziis.undo.SetValue(f32).init(
                    allocator,
                    &STATE.f,
                    new,
                    "texture offset"
            );
            try cmd.do();
            try STATE.journal.?.update_if_new_or_add(cmd);
        }

        for (STATE.journal.?.entries.items, 0..)
            |cmd, ind|
        {
            zgui.bulletText("{d}: {s}", .{ ind, cmd.message });
        }

        zgui.bulletText(
            "Head Entry in STATE.Journal: {?d}",
            .{ STATE.journal.?.maybe_head_entry }
        );

        if (zgui.button("undo", .{}))
        {
            try STATE.journal.?.undo();
        }

        zgui.sameLine(.{});

        if (zgui.button("redo", .{}))
        {
            try STATE.journal.?.redo();
        }

        if (zgui.button("show gui demo", .{}) )
        { 
            STATE.demo_window_gui = ! STATE.demo_window_gui; 
        }
        if (zgui.button("show plot demo", .{}))
        {
            STATE.demo_window_gui = ! STATE.demo_window_plot; 
        }

        if (STATE.demo_window_gui) 
        {
            zgui.showDemoWindow(&STATE.demo_window_gui);
        }
        if (STATE.demo_window_plot) 
        {
            zplot.showDemoWindow(&STATE.demo_window_plot);
        }



        if (zgui.beginTabBar("Panes", .{}))
        {
            defer zgui.endTabBar();

            if (zgui.beginTabItem("Raytracing in a Week Viewer", .{}))
            {
                defer zgui.endTabItem();

                const content_space = zgui.getContentRegionAvail();

                const im_width: f32 = @floatFromInt(STATE.buffer.width);
                const width_rat = content_space[0]/im_width;

                const im_height: f32 = @floatFromInt(STATE.buffer.height);
                const height_rat = content_space[1]/im_height;

                const rat = @min(width_rat, height_rat);

                const c_win = [_]f32{
                    rat*im_width,
                    rat*im_height,
                };

                imgui_image(STATE.texid, c_win);
            }

            if (zgui.beginTabItem("PlotTab", .{}))
            {
                defer zgui.endTabItem();

                if (
                    zgui.beginChild(
                        "Plot", 
                        .{
                            .w = -1,
                            .h = -1,
                        }
                    )
                )
                {
                    defer zgui.endChild();

                    if (
                        zgui.plot.beginPlot(
                            "Test ZPlot Plot",
                            .{ 
                                .w = -1.0,
                                .h = -1.0,
                                .flags = .{ .equal = true },
                            }
                        )
                    ) 
                    {
                        defer zgui.plot.endPlot();

                        zgui.plot.setupAxis(
                            .x1,
                            .{ .label = "input" }
                        );
                        zgui.plot.setupAxis(
                            .y1,
                            .{ .label = "output" }
                        );
                        zgui.plot.setupLegend(
                            .{ 
                                .south = true,
                                .west = true 
                            },
                            .{}
                        );
                        zgui.plot.setupFinish();

                        const xs= [_]f32{0, 1, 2, 3, 4};
                        const ys= [_]f32{0, 1, 2, 3, 6};

                        zplot.plotLine(
                            "test plot",
                            f32, 
                            .{
                                .xv = &xs,
                                .yv = &ys 
                            },
                        );
                    }
                }
            }
        }
    }
}

fn cleanup () void
{
    // make sure the last render finishes
    STATE.render_thread.join();

    if (STATE.journal)
        |*definitely_journal|
    {
        definitely_journal.deinit();
    }

    STATE.buffer.deinit();

    raytrace.cleanup();

    single_threaded_arena.deinit();

    if (IS_WASM == false)
    {
        const result = gpa.deinit();
        if (result == .leak) 
        {
            std.debug.print("leak!", .{});
        }
    }
}

fn start_render_thread(
) !std.Thread
{
    return try std.Thread.spawn(.{}, render, .{});
}

/// starts up the render thread
fn render(
) void
{
    STATE.render_thread_is_running.store(true, .monotonic);
    const t_start = std.time.Instant.now() catch @panic("not supported");
    STATE.render_start_t = t_start;

    raytrace.render(
        allocator,
        &STATE.buffer,
        STATE.frame_number,
        STATE.current_renderer,
        &STATE.render_progress,
    );

    const t_end = std.time.Instant.now() catch @panic("not supported");
    const dur = t_end.since(t_start);
    STATE.mspf = @floatFromInt(dur / std.time.ns_per_ms);
    STATE.fps =  std.time.ns_per_s / @as(f64, @floatFromInt(dur));

    STATE.render_thread_is_running.store(false, .monotonic);
}

pub fn init(
) void
{ 
    STATE.tex = sg.makeImage(
        .{
            .width = STATE.TEX_DIM[0],
            .height = STATE.TEX_DIM[1],
            .usage = .STREAM,
            .pixel_format = .RGBA8,
        }
    );

    STATE.texid = ziis.sokol.imgui.imtextureid(STATE.tex);

    STATE.buffer = raytrace.Image_rgba_u8.init(
        allocator,
        STATE.TEX_DIM[0],
        STATE.TEX_DIM[1]
    ) catch @panic("couldn't make image");

    STATE.start_program_t = std.time.Instant.now() catch @panic("yikes");

    STATE.render_thread = start_render_thread() catch @panic("ouch!");
}

pub fn main(
) void 
{
    STATE.journal = ziis.undo.Journal.init(
       allocator,
        5
    ) catch null;

    app_wrapper.sokol_main(
        .{
            .title = "Raytracing in a Weekend (Zig + Comath + Imgui)",
            .draw = draw, 
            .maybe_pre_zgui_shutdown_cleanup = cleanup,
            .maybe_post_zgui_init = init,
        },
    );
}
