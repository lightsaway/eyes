// Linux fullscreen break overlay — GTK3 window with cairo countdown ring.

const std = @import("std");
const gtk = @import("gtk.zig");
const c = gtk.c;
const app_mod = @import("../app.zig");

const M_PI = gtk.M_PI;

// Multi-monitor overlay state
const MAX_SCREENS = 8;
var overlay_windows: [MAX_SCREENS]?*c.GtkWidget = .{null} ** MAX_SCREENS;
var drawing_areas: [MAX_SCREENS]?*c.GtkWidget = .{null} ** MAX_SCREENS;
var screen_count: usize = 0;

// Ring geometry
const ring_radius: f64 = 80.0;
const ring_line_width: f64 = 8.0;

// Break messages (rotate through)
const messages = [_][*:0]const u8{
    "Look at something 20 feet away",
    "Let your eyes relax and refocus",
    "Blink slowly a few times",
    "Close your eyes for a moment",
    "Rest your eyes \xe2\x80\x94 you've earned it",
    "Focus on a distant object",
};

const stretch_prompts = [_][*:0]const u8{
    "Roll your shoulders back",
    "Stretch your neck gently",
    "Stand up and stretch",
    "Take a deep breath",
    "Shake out your hands",
    "Stretch your arms overhead",
};

var message_idx: usize = 0;

fn drawOverlay(_: ?*c.GtkWidget, cr: ?*c.cairo_t, _: ?*anyopaque) callconv(.c) c.gboolean {
    const width: f64 = @floatFromInt(c.gtk_widget_get_allocated_width(@ptrCast(drawing_areas[0])));
    const height: f64 = @floatFromInt(c.gtk_widget_get_allocated_height(@ptrCast(drawing_areas[0])));

    // Dark semi-transparent background
    c.cairo_set_source_rgba(cr, 0.05, 0.05, 0.08, 0.88);
    c.cairo_paint(cr);

    const cx = width / 2.0;
    const cy = height / 2.0 - 30.0;

    // Background ring (dim)
    c.cairo_set_line_width(cr, ring_line_width);
    c.cairo_set_line_cap(cr, c.CAIRO_LINE_CAP_ROUND);
    c.cairo_set_source_rgba(cr, 1.0, 1.0, 1.0, 0.15);
    c.cairo_arc(cr, cx, cy, ring_radius, 0, 2.0 * M_PI);
    c.cairo_stroke(cr);

    // Progress ring
    const s = &app_mod.state;
    const duration: f64 = @floatFromInt(if (s.is_big_break) s.big_break_duration_secs else s.break_duration_secs);
    const remaining: f64 = @floatFromInt(@max(@as(i32, 0), s.break_seconds_remaining));
    const progress = if (duration > 0) 1.0 - (remaining / duration) else 1.0;

    c.cairo_set_source_rgba(cr, 0.3, 0.7, 1.0, 1.0);
    c.cairo_arc(cr, cx, cy, ring_radius, -M_PI / 2.0, -M_PI / 2.0 + 2.0 * M_PI * progress);
    c.cairo_stroke(cr);

    // Ring glow
    c.cairo_set_source_rgba(cr, 0.3, 0.7, 1.0, 0.2);
    c.cairo_set_line_width(cr, ring_line_width + 6.0);
    c.cairo_arc(cr, cx, cy, ring_radius, -M_PI / 2.0, -M_PI / 2.0 + 2.0 * M_PI * progress);
    c.cairo_stroke(cr);

    // Countdown text
    {
        const secs: u32 = if (s.break_seconds_remaining < 0) 0 else @intCast(s.break_seconds_remaining);
        var buf: [8]u8 = .{0} ** 8;
        _ = std.fmt.bufPrint(&buf, "{d}", .{secs}) catch {};
        const text: [*:0]const u8 = @ptrCast(&buf);

        c.cairo_select_font_face(cr, "Sans", c.CAIRO_FONT_SLANT_NORMAL, c.CAIRO_FONT_WEIGHT_BOLD);
        c.cairo_set_font_size(cr, 48.0);
        c.cairo_set_source_rgba(cr, 1.0, 1.0, 1.0, 0.95);

        var extents: c.cairo_text_extents_t = undefined;
        c.cairo_text_extents(cr, text, &extents);
        c.cairo_move_to(cr, cx - extents.width / 2.0, cy + extents.height / 2.0);
        c.cairo_show_text(cr, text);
    }

    // Message text
    {
        const msg = messages[message_idx % messages.len];
        c.cairo_set_font_size(cr, 18.0);
        c.cairo_select_font_face(cr, "Sans", c.CAIRO_FONT_SLANT_NORMAL, c.CAIRO_FONT_WEIGHT_NORMAL);
        c.cairo_set_source_rgba(cr, 1.0, 1.0, 1.0, 0.7);

        var extents: c.cairo_text_extents_t = undefined;
        c.cairo_text_extents(cr, msg, &extents);
        c.cairo_move_to(cr, cx - extents.width / 2.0, cy + ring_radius + 50.0);
        c.cairo_show_text(cr, msg);
    }

    // Stretch prompt
    {
        const prompt_idx: usize = @intCast(@mod(@divTrunc(s.break_seconds_remaining, 3), @as(i32, @intCast(stretch_prompts.len))));
        const prompt = stretch_prompts[prompt_idx];
        c.cairo_set_font_size(cr, 14.0);
        c.cairo_set_source_rgba(cr, 1.0, 1.0, 1.0, 0.45);

        var extents: c.cairo_text_extents_t = undefined;
        c.cairo_text_extents(cr, prompt, &extents);
        c.cairo_move_to(cr, cx - extents.width / 2.0, cy + ring_radius + 80.0);
        c.cairo_show_text(cr, prompt);
    }

    return 0; // FALSE
}

fn createOverlayWindow(x: c_int, y: c_int, w: c_int, h: c_int, idx: usize) void {
    const window = c.gtk_window_new(c.GTK_WINDOW_TOPLEVEL);
    c.gtk_window_set_decorated(@ptrCast(window), 0);
    c.gtk_window_set_skip_taskbar_hint(@ptrCast(window), 1);
    c.gtk_window_set_skip_pager_hint(@ptrCast(window), 1);
    c.gtk_window_set_keep_above(@ptrCast(window), 1);
    c.gtk_window_set_type_hint(@ptrCast(window), c.GDK_WINDOW_TYPE_HINT_DOCK);
    c.gtk_widget_set_size_request(window, w, h);
    c.gtk_window_move(@ptrCast(window), x, y);
    c.gtk_window_resize(@ptrCast(window), w, h);

    // Enable RGBA visual for transparency
    const screen = c.gtk_widget_get_screen(window);
    const visual = c.gdk_screen_get_rgba_visual(screen);
    if (visual != null) {
        c.gtk_widget_set_visual(window, visual);
    }
    c.gtk_widget_set_app_paintable(window, 1);

    // Drawing area for cairo rendering
    const da = c.gtk_drawing_area_new();
    gtk.connectSignal(@ptrCast(da), "draw", @ptrCast(&drawOverlay), null);
    c.gtk_container_add(@ptrCast(window), da);

    overlay_windows[idx] = window;
    drawing_areas[idx] = da;
}

pub fn showOverlay(_: *app_mod.AppState) void {
    // Pick a new message
    message_idx +%= 1;

    // Create overlay windows for each monitor
    const display = c.gdk_display_get_default();
    if (display == null) return;

    const n_monitors = c.gdk_display_get_n_monitors(display);
    screen_count = @intCast(@min(n_monitors, MAX_SCREENS));

    for (0..screen_count) |i| {
        const monitor = c.gdk_display_get_monitor(display, @intCast(i));
        if (monitor == null) continue;

        var geom: c.GdkRectangle = undefined;
        c.gdk_monitor_get_geometry(monitor, &geom);

        createOverlayWindow(geom.x, geom.y, geom.width, geom.height, i);
        c.gtk_widget_show_all(overlay_windows[i].?);
    }

    // If no monitors detected, create a single fullscreen window
    if (screen_count == 0) {
        screen_count = 1;
        const window = c.gtk_window_new(c.GTK_WINDOW_TOPLEVEL);
        c.gtk_window_set_decorated(@ptrCast(window), 0);
        c.gtk_window_set_keep_above(@ptrCast(window), 1);
        c.gtk_window_fullscreen(@ptrCast(window));
        c.gtk_widget_set_app_paintable(window, 1);

        const screen = c.gtk_widget_get_screen(window);
        const visual = c.gdk_screen_get_rgba_visual(screen);
        if (visual != null) c.gtk_widget_set_visual(window, visual);

        const da = c.gtk_drawing_area_new();
        gtk.connectSignal(@ptrCast(da), "draw", @ptrCast(&drawOverlay), null);
        c.gtk_container_add(@ptrCast(window), da);

        overlay_windows[0] = window;
        drawing_areas[0] = da;
        c.gtk_widget_show_all(window);
    }
}

pub fn hideOverlay() void {
    for (0..screen_count) |i| {
        if (overlay_windows[i]) |w| {
            c.gtk_widget_destroy(w);
            overlay_windows[i] = null;
            drawing_areas[i] = null;
        }
    }
    screen_count = 0;
}

pub fn updateOverlay(_: *app_mod.AppState) void {
    // Trigger redraw on all overlay windows
    for (0..screen_count) |i| {
        if (drawing_areas[i]) |da| {
            c.gtk_widget_queue_draw(da);
        }
    }
}

pub fn fadeTick() void {
    // GTK handles alpha natively — no manual fade needed
}

pub fn enableStrictMode() void {
    // On X11, grab keyboard and pointer to prevent interaction
    // Wayland does not support input grabs — this is a known limitation
    for (0..screen_count) |i| {
        if (overlay_windows[i]) |w| {
            const gdk_window = c.gtk_widget_get_window(w);
            if (gdk_window != null) {
                const seat = c.gdk_display_get_default_seat(c.gdk_display_get_default());
                if (seat != null) {
                    _ = c.gdk_seat_grab(seat, gdk_window, c.GDK_SEAT_CAPABILITY_ALL, 1, null, null, null, null);
                }
            }
        }
    }
}

pub fn disableStrictMode() void {
    const seat = c.gdk_display_get_default_seat(c.gdk_display_get_default());
    if (seat != null) {
        c.gdk_seat_ungrab(seat);
    }
}
