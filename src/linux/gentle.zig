// Linux gentle mode — translucent top banner with slide-down animation.

const std = @import("std");
const gtk = @import("gtk.zig");
const c = gtk.c;
const app_mod = @import("../app.zig");

const banner_width: f64 = 600.0;
const banner_height: f64 = 80.0;

var banner_window: ?*c.GtkWidget = null;
var drawing_area: ?*c.GtkWidget = null;

const SlidePhase = enum { sliding_in, visible, sliding_out, hidden };
var slide_phase: SlidePhase = .hidden;
var slide_progress: f32 = 0.0;
var slide_timer: c_uint = 0;
var screen_width: f64 = 0.0;

// Break messages
const messages = [_][*:0]const u8{
    "Look at something 20 feet away",
    "Let your eyes relax and refocus",
    "Blink slowly a few times",
    "Close your eyes for a moment",
};
var message_idx: usize = 0;

fn easeOut(t: f32) f32 {
    return 1.0 - (1.0 - t) * (1.0 - t);
}

fn easeIn(t: f32) f32 {
    return t * t;
}

fn drawBanner(_: ?*c.GtkWidget, cr: ?*c.cairo_t, _: ?*anyopaque) callconv(.c) c.gboolean {
    // Rounded rectangle background
    const w = banner_width;
    const h = banner_height;
    const r = 16.0; // corner radius

    c.cairo_new_sub_path(cr);
    c.cairo_arc(cr, w - r, r, r, -gtk.M_PI / 2.0, 0);
    c.cairo_arc(cr, w - r, h - r, r, 0, gtk.M_PI / 2.0);
    c.cairo_arc(cr, r, h - r, r, gtk.M_PI / 2.0, gtk.M_PI);
    c.cairo_arc(cr, r, r, r, gtk.M_PI, 3.0 * gtk.M_PI / 2.0);
    c.cairo_close_path(cr);
    c.cairo_set_source_rgba(cr, 0.1, 0.1, 0.12, 0.92);
    c.cairo_fill(cr);

    // Countdown text
    const s = &app_mod.state;
    {
        const secs: u32 = if (s.break_seconds_remaining < 0) 0 else @intCast(s.break_seconds_remaining);
        var buf: [8]u8 = .{0} ** 8;
        _ = std.fmt.bufPrint(&buf, "{d}s", .{secs}) catch {};
        const text: [*:0]const u8 = @ptrCast(&buf);

        c.cairo_select_font_face(cr, "Sans", c.CAIRO_FONT_SLANT_NORMAL, c.CAIRO_FONT_WEIGHT_BOLD);
        c.cairo_set_font_size(cr, 28.0);
        c.cairo_set_source_rgba(cr, 0.3, 0.7, 1.0, 1.0);
        c.cairo_move_to(cr, 24.0, 50.0);
        c.cairo_show_text(cr, text);
    }

    // Message
    {
        const msg = messages[message_idx % messages.len];
        c.cairo_set_font_size(cr, 16.0);
        c.cairo_select_font_face(cr, "Sans", c.CAIRO_FONT_SLANT_NORMAL, c.CAIRO_FONT_WEIGHT_NORMAL);
        c.cairo_set_source_rgba(cr, 1.0, 1.0, 1.0, 0.8);
        c.cairo_move_to(cr, 100.0, 48.0);
        c.cairo_show_text(cr, msg);
    }

    return 0;
}

fn slideTickCallback(_: ?*anyopaque) callconv(.c) c.gboolean {
    switch (slide_phase) {
        .sliding_in => {
            slide_progress += 0.05;
            if (slide_progress >= 1.0) {
                slide_progress = 1.0;
                slide_phase = .visible;
                slide_timer = 0;
                return 0; // stop timer
            }
            updateBannerPosition();
        },
        .sliding_out => {
            slide_progress += 0.07;
            if (slide_progress >= 1.0) {
                slide_phase = .hidden;
                if (banner_window) |w| {
                    c.gtk_widget_destroy(w);
                    banner_window = null;
                    drawing_area = null;
                }
                slide_timer = 0;
                return 0;
            }
            updateBannerPosition();
        },
        else => {
            slide_timer = 0;
            return 0;
        },
    }
    return 1; // continue
}

fn updateBannerPosition() void {
    const w = banner_window orelse return;
    const x: c_int = @intFromFloat((screen_width - banner_width) / 2.0);

    const target_y: f64 = 20.0;
    const offscreen_y: f64 = -banner_height - 10.0;

    var y: f64 = undefined;
    switch (slide_phase) {
        .sliding_in => {
            y = offscreen_y + (target_y - offscreen_y) * @as(f64, easeOut(slide_progress));
        },
        .sliding_out => {
            y = target_y + (offscreen_y - target_y) * @as(f64, easeIn(slide_progress));
        },
        .visible => {
            y = target_y;
        },
        .hidden => return,
    }

    c.gtk_window_move(@ptrCast(w), x, @intFromFloat(y));
}

pub fn showGentleBanner(_: *app_mod.AppState) void {
    message_idx +%= 1;

    // Get screen dimensions
    const display = c.gdk_display_get_default();
    if (display == null) return;
    const monitor = c.gdk_display_get_primary_monitor(display) orelse c.gdk_display_get_monitor(display, 0);
    if (monitor == null) return;
    var geom: c.GdkRectangle = undefined;
    c.gdk_monitor_get_geometry(monitor, &geom);
    screen_width = @floatFromInt(geom.width);

    // Create banner window
    const window = c.gtk_window_new(c.GTK_WINDOW_TOPLEVEL);
    c.gtk_window_set_decorated(@ptrCast(window), 0);
    c.gtk_window_set_skip_taskbar_hint(@ptrCast(window), 1);
    c.gtk_window_set_skip_pager_hint(@ptrCast(window), 1);
    c.gtk_window_set_keep_above(@ptrCast(window), 1);
    c.gtk_window_set_accept_focus(@ptrCast(window), 0);
    c.gtk_window_set_type_hint(@ptrCast(window), c.GDK_WINDOW_TYPE_HINT_NOTIFICATION);
    c.gtk_widget_set_size_request(window, @intFromFloat(banner_width), @intFromFloat(banner_height));

    // RGBA visual
    const screen = c.gtk_widget_get_screen(window);
    const visual = c.gdk_screen_get_rgba_visual(screen);
    if (visual != null) c.gtk_widget_set_visual(window, visual);
    c.gtk_widget_set_app_paintable(window, 1);

    const da = c.gtk_drawing_area_new();
    gtk.connectSignal(@ptrCast(da), "draw", @ptrCast(&drawBanner), null);
    c.gtk_container_add(@ptrCast(window), da);

    banner_window = window;
    drawing_area = da;

    // Position offscreen and start slide-in
    const x: c_int = @intFromFloat((screen_width - banner_width) / 2.0);
    c.gtk_window_move(@ptrCast(window), x, @intFromFloat(-banner_height - 10.0));
    c.gtk_widget_show_all(window);

    slide_phase = .sliding_in;
    slide_progress = 0.0;
    if (slide_timer != 0) _ = c.g_source_remove(slide_timer);
    slide_timer = c.g_timeout_add(16, &slideTickCallback, null); // ~60fps
}

pub fn hideGentleBanner() void {
    if (slide_phase == .hidden) return;

    slide_phase = .sliding_out;
    slide_progress = 0.0;
    if (slide_timer != 0) _ = c.g_source_remove(slide_timer);
    slide_timer = c.g_timeout_add(16, &slideTickCallback, null);
}

pub fn updateGentleBanner(_: *app_mod.AppState) void {
    if (drawing_area) |da| {
        c.gtk_widget_queue_draw(da);
    }
}

pub fn fadeTick() void {
    // Handled by slide timer
}

pub fn isVisible() bool {
    return slide_phase != .hidden;
}
