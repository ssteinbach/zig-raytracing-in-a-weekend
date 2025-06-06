//! example app using teh app wrapper

const std = @import("std");
const builtin = @import("builtin");

const ziis = @import("zgui_cimgui_implot_sokol");
const zgui = ziis.zgui;
const zplot = zgui.plot;
const app_wrapper = ziis.app_wrapper;
const sg = ziis.sokol.gfx;

const build_options = @import("build_options");

var f: f32 = 0;
var backup_f: f32 = 0;
var demo_window_gui = false;
var demo_window_plot = false;

var journal : ?ziis.undo.Journal = null;

const IS_WASM = builtin.target.cpu.arch.isWasm();

/// the GPA - useful for detecting leaks, but ONLY works in non EMCC builds
var gpa = (
    if (IS_WASM) null 
    else std.heap.GeneralPurposeAllocator(.{}){}
);
const allocator = (
    if (IS_WASM) std.heap.c_allocator 
    else gpa.allocator()
);

const GFXSTATE = struct {
    var setup: bool = false;
    var texid: u64 = 0;
    var tex: sg.Image = .{};
};

fn init(
) void
{
    const tex = sg.makeImage(
        .{
            .width = 4,
            .height = 4,
            .data = init: {
                var data = ziis.sokol.gfx.ImageData{};
                data.subimage[0][0] = ziis.sokol.gfx.asRange(
                    &[4 * 4]u32{
                        0xFFFFFFFF, 0xFF000000, 0xFFFFFFFF, 0xFF000000,
                        0xFF000000, 0xFFFFFFFF, 0xFF000000, 0xFFFFFFFF,
                        0xFFFFFFFF, 0xFF000000, 0xFFFFFFFF, 0xFF000000,
                        0xFF000000, 0xFFFFFFFF, 0xFF000000, 0xFFFFFFFF,
                    }
                );
                break :init data;
            },
        }
    );

    GFXSTATE.tex = tex;
    GFXSTATE.texid = ziis.sokol.imgui.imtextureid(tex);
}

/// draw the UI
fn draw(
) !void 
{
    const vp = zgui.getMainViewport();
    const size = vp.getSize();


    if (GFXSTATE.setup == false) 
    {
        init();
        GFXSTATE.setup = true;
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

        var new = f;
        if (zgui.dragFloat("test float", .{ .v = &new })) {
            const cmd = try ziis.undo.SetValue(f32).init(
                    allocator,
                    &f,
                    new,
                    "test float"
            );
            try cmd.do();
            try journal.?.update_if_new_or_add(cmd);
        }

        for (journal.?.entries.items, 0..)
            |cmd, ind|
        {
            zgui.bulletText("{d}: {s}", .{ ind, cmd.message });
        }

        zgui.bulletText("Head Entry in Journal: {?d}", .{ journal.?.maybe_head_entry });

        if (zgui.button("undo", .{}))
        {
            try journal.?.undo();
        }

        zgui.sameLine(.{});

        if (zgui.button("redo", .{}))
        {
            try journal.?.redo();
        }

        if (zgui.button("show gui demo", .{}) )
        { 
            demo_window_gui = ! demo_window_gui; 
        }
        if (zgui.button("show plot demo", .{}))
        {
            demo_window_gui = ! demo_window_plot; 
        }

        if (demo_window_gui) 
        {
            zgui.showDemoWindow(&demo_window_gui);
        }
        if (demo_window_plot) 
        {
            zplot.showDemoWindow(&demo_window_plot);
        }

        if (
            zgui.beginChild(
                "Image", 
                .{
                    .w = -1,
                    .h = -1,
                }
            )
        )
        {
            defer zgui.endChild();

            zgui.text("texid: tex.id: {d} imtextureid call: {d} image state: {any}", .{ GFXSTATE.tex.id, GFXSTATE.texid, sg.queryImageInfo(GFXSTATE.tex) });

            // ziis.sokol.imgui.Image(GFXSTATE.texid, .{});

            const wsize = zgui.getWindowSize();

            ziis.cimgui.igImage(
                GFXSTATE.texid,
                .{ .x = wsize[0], .y = wsize[1]},
                .{ .x = 0, .y = 0 },
                .{ .x = 1, .y = 1 },
                .{ .x = 1, .y = 1, .z = 1, .w = 1 },
                .{ .x = 0, .y = 0, .z = 0, .w = 0 },
            );
        }
    }
}

fn cleanup () void
{
    if (journal)
        |*definitely_journal|
    {
        definitely_journal.deinit();
    }

    if (IS_WASM == false)
    {
        const result = gpa.deinit();
        if (result == .leak) 
        {
            std.debug.print("leak!", .{});
        }
    }
}

pub fn main(
) void 
{
    journal = ziis.undo.Journal.init(
       allocator,
        5
    ) catch null;

    app_wrapper.sokol_main(
        .{
            .draw = draw, 
            .cleanup = cleanup,
        },
    );
}
