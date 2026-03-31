// Linux pill core — floating reminder pill with slide-up/out animation using GTK3.

const std = @import("std");
const gtk = @import("../gtk.zig");
const c = gtk.c;
const app_mod = @import("../../app.zig");
const pill_layout = @import("pill_layout.zig");

const SlidePhase = enum { sliding_in, visible, sliding_out, hidden };

const target_y: f64 = 60.0;
const max_alpha: f64 = 0.95;
const slide_in_duration: f32 = 0.4;
const slide_out_duration: f32 = 0.3;

pub const PillConfig = struct {
    pill_type: pill_layout.PillType,
    window_width: f64,
    window_height: f64,
    emoji: [*:0]const u8,
    emoji_font_size: f64,
    emoji_y: f64,
    emoji_height: f64,
    alt_emoji: ?[*:0]const u8,
    hint_text: [*:0]const u8,
    hint_y: f64,
    accessibility_label: [*:0]const u8,
    accessibility_announcement: [*:0]const u8,
    log_name: [*:0]const u8,
    rise_per_tick: f64 = 6.0,
    rise_max_ticks: u64 = 5,
};

pub const PillState = struct {
    window: ?*c.GtkWidget = null,
    drawing_area: ?*c.GtkWidget = null,
    slide_phase: SlidePhase = .hidden,
    slide_progress: f32 = 0.0,
    screen_x: f64 = 0.0,
    screen_width: f64 = 0.0,
    screen_height: f64 = 0.0,
    fade_timer: c_uint = 0,
    emoji_offset_y: f64 = 0.0, // for rise animation
    show_alt: bool = false, // for toggle animation
    config: ?*const PillConfig = null,
};

fn easeOut(t: f32) f32 {
    return 1.0 - (1.0 - t) * (1.0 - t);
}

fn easeIn(t: f32) f32 {
    return t * t;
}

fn drawPill(widget: ?*c.GtkWidget, cr: ?*c.cairo_t, user_data: ?*anyopaque) callconv(.c) c.gboolean {
    _ = widget;
    const state: *PillState = @ptrCast(@alignCast(user_data));
    const cfg = state.config orelse return 0;
    const w = cfg.window_width;
    const h = cfg.window_height;
    const r = 16.0;

    // Rounded rectangle background
    c.cairo_new_sub_path(cr);
    c.cairo_arc(cr, w - r, r, r, -gtk.M_PI / 2.0, 0);
    c.cairo_arc(cr, w - r, h - r, r, 0, gtk.M_PI / 2.0);
    c.cairo_arc(cr, r, h - r, r, gtk.M_PI / 2.0, gtk.M_PI);
    c.cairo_arc(cr, r, r, r, gtk.M_PI, 3.0 * gtk.M_PI / 2.0);
    c.cairo_close_path(cr);
    c.cairo_set_source_rgba(cr, 0.1, 0.1, 0.12, 0.92);
    c.cairo_fill(cr);

    // Emoji
    {
        const emoji = if (state.show_alt and cfg.alt_emoji != null) cfg.alt_emoji.? else cfg.emoji;
        c.cairo_set_font_size(cr, cfg.emoji_font_size);
        c.cairo_select_font_face(cr, "Sans", c.CAIRO_FONT_SLANT_NORMAL, c.CAIRO_FONT_WEIGHT_NORMAL);
        c.cairo_set_source_rgba(cr, 1.0, 1.0, 1.0, 0.95);

        var extents: c.cairo_text_extents_t = undefined;
        c.cairo_text_extents(cr, emoji, &extents);
        c.cairo_move_to(cr, (w - extents.width) / 2.0, cfg.emoji_y + cfg.emoji_height / 2.0 + extents.height / 2.0 - state.emoji_offset_y);
        c.cairo_show_text(cr, emoji);
    }

    // Hint text
    {
        c.cairo_set_font_size(cr, 12.0);
        c.cairo_select_font_face(cr, "Sans", c.CAIRO_FONT_SLANT_NORMAL, c.CAIRO_FONT_WEIGHT_NORMAL);
        c.cairo_set_source_rgba(cr, 1.0, 1.0, 1.0, 0.6);

        var extents: c.cairo_text_extents_t = undefined;
        c.cairo_text_extents(cr, cfg.hint_text, &extents);
        c.cairo_move_to(cr, (w - extents.width) / 2.0, cfg.hint_y);
        c.cairo_show_text(cr, cfg.hint_text);
    }

    return 0;
}

fn slideTickCallback(user_data: ?*anyopaque) callconv(.c) c.gboolean {
    const state: *PillState = @ptrCast(@alignCast(user_data));
    const cfg = state.config orelse return 0;

    switch (state.slide_phase) {
        .sliding_in => {
            state.slide_progress += 1.0 / (slide_in_duration * 60.0);
            if (state.slide_progress >= 1.0) {
                state.slide_progress = 1.0;
                state.slide_phase = .visible;
            }
            updatePosition(state, cfg);
        },
        .sliding_out => {
            state.slide_progress += 1.0 / (slide_out_duration * 60.0);
            if (state.slide_progress >= 1.0) {
                state.slide_phase = .hidden;
                if (state.window) |w| {
                    c.gtk_widget_destroy(w);
                    state.window = null;
                    state.drawing_area = null;
                }
                state.fade_timer = 0;
                return 0;
            }
            updatePosition(state, cfg);
        },
        .visible => {
            // Subtle bob animation
            const time: f64 = @floatFromInt(c.g_get_monotonic_time());
            const bob = @sin(time / 500000.0) * 2.0;
            if (state.window) |w| {
                const y: c_int = @intFromFloat(state.screen_height - target_y - cfg.window_height + bob);
                c.gtk_window_move(@ptrCast(w), @intFromFloat(state.screen_x), y);
            }
        },
        .hidden => {
            state.fade_timer = 0;
            return 0;
        },
    }
    return 1;
}

fn updatePosition(state: *PillState, cfg: *const PillConfig) void {
    const w = state.window orelse return;
    const offscreen_y = state.screen_height + 10.0;
    const final_y = state.screen_height - target_y - cfg.window_height;

    var y: f64 = undefined;
    switch (state.slide_phase) {
        .sliding_in => {
            y = offscreen_y + (final_y - offscreen_y) * @as(f64, easeOut(state.slide_progress));
        },
        .sliding_out => {
            y = final_y + (offscreen_y - final_y) * @as(f64, easeIn(state.slide_progress));
        },
        else => {
            y = final_y;
        },
    }
    c.gtk_window_move(@ptrCast(w), @intFromFloat(state.screen_x), @intFromFloat(y));
}

pub fn show(state: *PillState, cfg: *const PillConfig) void {
    state.config = cfg;

    // Get screen dimensions
    const display = c.gdk_display_get_default() orelse return;
    const monitor = c.gdk_display_get_primary_monitor(display) orelse c.gdk_display_get_monitor(display, 0);
    if (monitor == null) return;
    var geom: c.GdkRectangle = undefined;
    c.gdk_monitor_get_geometry(monitor, &geom);
    state.screen_width = @floatFromInt(geom.width);
    state.screen_height = @floatFromInt(geom.height);
    state.screen_x = pill_layout.getX(cfg.pill_type, state.screen_width, true);

    // Create window
    const window = c.gtk_window_new(c.GTK_WINDOW_TOPLEVEL);
    c.gtk_window_set_decorated(@ptrCast(window), 0);
    c.gtk_window_set_skip_taskbar_hint(@ptrCast(window), 1);
    c.gtk_window_set_skip_pager_hint(@ptrCast(window), 1);
    c.gtk_window_set_keep_above(@ptrCast(window), 1);
    c.gtk_window_set_accept_focus(@ptrCast(window), 0);
    c.gtk_window_set_type_hint(@ptrCast(window), c.GDK_WINDOW_TYPE_HINT_NOTIFICATION);
    c.gtk_widget_set_size_request(window, @intFromFloat(cfg.window_width), @intFromFloat(cfg.window_height));

    // RGBA visual
    const screen = c.gtk_widget_get_screen(window);
    const visual = c.gdk_screen_get_rgba_visual(screen);
    if (visual != null) c.gtk_widget_set_visual(window, visual);
    c.gtk_widget_set_app_paintable(window, 1);

    // Drawing area
    const da = c.gtk_drawing_area_new();
    _ = c.g_signal_connect_data(@ptrCast(da), "draw", @ptrCast(&drawPill), @ptrCast(state), null, 0);
    c.gtk_container_add(@ptrCast(window), da);

    state.window = window;
    state.drawing_area = da;
    state.emoji_offset_y = 0.0;
    state.show_alt = false;

    // Position offscreen
    c.gtk_window_move(@ptrCast(window), @intFromFloat(state.screen_x), @intFromFloat(state.screen_height + 10.0));
    c.gtk_widget_show_all(window);

    // Start slide-in
    state.slide_phase = .sliding_in;
    state.slide_progress = 0.0;
    if (state.fade_timer != 0) _ = c.g_source_remove(state.fade_timer);
    state.fade_timer = c.g_timeout_add(16, @ptrCast(&slideTickCallback), @ptrCast(state));

    std.log.info("{s} reminder shown", .{cfg.log_name});
}

pub fn hide(state: *PillState, cfg: *const PillConfig) void {
    _ = cfg;
    if (state.slide_phase == .hidden) return;

    state.slide_phase = .sliding_out;
    state.slide_progress = 0.0;
    if (state.fade_timer != 0) _ = c.g_source_remove(state.fade_timer);
    state.fade_timer = c.g_timeout_add(16, @ptrCast(&slideTickCallback), @ptrCast(state));
}

pub fn fadeTick(_: *PillState, _: *const PillConfig) void {
    // Handled by slide timer
}

pub fn updateAnimation(state: *PillState, cfg: *const PillConfig, tick_val: u32) void {
    if (cfg.alt_emoji != null) {
        // Toggle animation — alternate between emojis
        state.show_alt = (tick_val % 2 == 1);
    } else {
        // Rise animation
        if (tick_val <= @as(u32, @intCast(cfg.rise_max_ticks))) {
            state.emoji_offset_y = @as(f64, @floatFromInt(tick_val)) * cfg.rise_per_tick;
        }
    }
    if (state.drawing_area) |da| {
        c.gtk_widget_queue_draw(da);
    }
}

pub fn repositionIfNeeded(state: *PillState, cfg: *const PillConfig) void {
    if (state.window == null or state.slide_phase == .hidden) return;

    const new_x = pill_layout.getX(cfg.pill_type, state.screen_width, false);
    if (new_x != state.screen_x) {
        state.screen_x = new_x;
        updatePosition(state, cfg);
    }
}

pub fn isVisible(state: *PillState) bool {
    return state.slide_phase != .hidden;
}
