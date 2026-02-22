// Shared pill core — parameterized floating reminder pill with slide-up/out animation.

const std = @import("std");
const objc = @import("../macos/objc.zig");
const appkit = @import("../macos/appkit.zig");
const foundation = @import("../macos/foundation.zig");
const config = @import("../config.zig");
const app_mod = @import("../app.zig");
const gifview = @import("../macos/gifview.zig");
const pill_layout = @import("pill_layout.zig");

const CGFloat = objc.CGFloat;
const NSRect = objc.NSRect;
const NSPoint = objc.NSPoint;
const NSSize = objc.NSSize;

// NSVisualEffectView constants
const NSVisualEffectMaterialHUDWindow: c_long = 13;
const NSVisualEffectBlendingModeBehindWindow: c_long = 0;
const NSVisualEffectStateActive: c_long = 1;

const SlidePhase = enum { sliding_in, visible, sliding_out, hidden };

const target_y: CGFloat = 60.0;
const fade_interval: f64 = 0.033;
const max_visible_alpha: CGFloat = 0.95;
const slide_in_duration: f32 = 0.4;
const slide_out_duration: f32 = 0.3;

pub const PillConfig = struct {
    pill_type: pill_layout.PillType,
    window_width: CGFloat,
    window_height: CGFloat,
    timer_sel: [*:0]const u8,
    emoji: [*:0]const u8,
    emoji_font_size: CGFloat,
    emoji_y: CGFloat,
    emoji_height: CGFloat,
    alt_emoji: ?[*:0]const u8, // null = rise animation, non-null = toggle animation
    hint_text: [*:0]const u8,
    hint_y: CGFloat,
    accessibility_label: [*:0]const u8,
    accessibility_announcement: [*:0]const u8,
    log_name: [*:0]const u8,
    // Rise animation params (only used if alt_emoji == null)
    rise_per_tick: CGFloat = 6.0,
    rise_max_ticks: u64 = 5,
};

pub const PillState = struct {
    window: objc.id = null,
    emoji_label: objc.id = null,
    gif_view: objc.id = null,
    slide_phase: SlidePhase = .hidden,
    slide_progress: f32 = 0.0,
    screen_x: CGFloat = 0.0,
    cached_screen_width: CGFloat = 0.0,
    fade_timer: objc.id = null,
    fade_current_alpha: CGFloat = 0.0,
};

fn getGifBuf(pill_type: pill_layout.PillType) *const [64]u8 {
    return switch (pill_type) {
        .posture => &app_mod.state.posture_gif,
        .blink => &app_mod.state.blink_gif,
        .hydration => &app_mod.state.hydration_gif,
        .stretch => &app_mod.state.stretch_gif,
    };
}

fn easeOut(p: f32) f32 {
    const inv = 1.0 - p;
    return 1.0 - inv * inv;
}

fn easeIn(p: f32) f32 {
    return p * p;
}

fn cancelFadeTimer(state: *PillState) void {
    if (state.fade_timer != null) {
        foundation.invalidateTimer(state.fade_timer);
        state.fade_timer = null;
    }
}

fn startFadeTimer(state: *PillState, cfg: *const PillConfig) void {
    cancelFadeTimer(state);
    const NSApp = appkit.sharedApplication();
    const delegate = objc.msgSend_id(NSApp, objc.sel("delegate"));
    state.fade_timer = foundation.scheduledTimer(fade_interval, delegate, objc.sel(cfg.timer_sel), true);
}

fn applyPosition(state: *PillState, cfg: *const PillConfig, y: CGFloat, alpha: CGFloat) void {
    if (state.window != null) {
        appkit.setWindowFrame(state.window, NSRect{
            .origin = NSPoint{ .x = state.screen_x, .y = y },
            .size = NSSize{ .width = cfg.window_width, .height = cfg.window_height },
        });
        appkit.setAlphaValue(state.window, alpha);
    }
}

fn destroyWindow(state: *PillState) void {
    if (state.gif_view != null) {
        gifview.destroy(state.gif_view);
        state.gif_view = null;
    }
    if (state.window != null) {
        appkit.orderOut(state.window);
        objc.release(state.window);
        state.window = null;
        state.emoji_label = null;
    }
}

pub fn fadeTick(state: *PillState, cfg: *const PillConfig) void {
    const dt: f32 = @floatCast(fade_interval);

    switch (state.slide_phase) {
        .sliding_in => {
            state.slide_progress += dt / slide_in_duration;
            if (state.slide_progress >= 1.0) {
                state.slide_progress = 1.0;
                state.slide_phase = .visible;
            }
            state.screen_x = pill_layout.getX(cfg.pill_type, state.cached_screen_width, false);
            pill_layout.repositionAll();
            const t = easeOut(state.slide_progress);
            const y = -cfg.window_height + (target_y + cfg.window_height) * @as(CGFloat, @floatCast(t));
            state.fade_current_alpha = max_visible_alpha * @as(CGFloat, @floatCast(t));
            applyPosition(state, cfg, y, state.fade_current_alpha);
        },
        .visible => {
            cancelFadeTimer(state);
        },
        .sliding_out => {
            state.slide_progress += dt / slide_out_duration;
            if (state.slide_progress >= 1.0) {
                state.slide_progress = 1.0;
                state.slide_phase = .hidden;
                cancelFadeTimer(state);
                destroyWindow(state);
                pill_layout.repositionAll();
                return;
            }
            state.screen_x = pill_layout.getX(cfg.pill_type, state.cached_screen_width, false);
            pill_layout.repositionAll();
            const t = easeIn(state.slide_progress);
            const y = target_y - (target_y + cfg.window_height) * @as(CGFloat, @floatCast(t));
            state.fade_current_alpha = max_visible_alpha * (1.0 - @as(CGFloat, @floatCast(t)));
            applyPosition(state, cfg, y, state.fade_current_alpha);
        },
        .hidden => {
            cancelFadeTimer(state);
        },
    }
}

pub fn show(state: *PillState, cfg: *const PillConfig) void {
    if (state.slide_phase == .sliding_out) {
        cancelFadeTimer(state);
        destroyWindow(state);
    }

    if (state.window != null) return;

    std.log.info("{s}: showing reminder", .{cfg.log_name});

    const screen = appkit.mainScreen();
    const screen_rect = appkit.screenFrame(screen);
    state.cached_screen_width = screen_rect.size.width;
    state.screen_x = pill_layout.getX(cfg.pill_type, state.cached_screen_width, true);

    const window = appkit.createWindow(
        NSRect{
            .origin = NSPoint{ .x = state.screen_x, .y = -cfg.window_height },
            .size = NSSize{ .width = cfg.window_width, .height = cfg.window_height },
        },
        appkit.NSWindowStyleMaskBorderless,
        appkit.NSBackingStoreBuffered,
        false,
    );

    appkit.setWindowLevel(window, appkit.NSFloatingWindowLevel);
    appkit.setWindowBackgroundColor(window, appkit.clearColor());
    appkit.setOpaque(window, false);
    appkit.setAlphaValue(window, 0.0);
    appkit.setWindowCollectionBehavior(window, appkit.NSWindowCollectionBehaviorCanJoinAllSpaces | appkit.NSWindowCollectionBehaviorStationary);
    appkit.setIgnoresMouseEvents(window, true);

    const content = appkit.contentView(window);
    appkit.setWantsLayer(content, true);

    // Frosted glass background via NSVisualEffectView
    const NSVisualEffectView = objc.getClass("NSVisualEffectView");
    const effect_view = objc.init(objc.alloc(NSVisualEffectView));
    appkit.setViewFrame(effect_view, NSRect{
        .origin = NSPoint{ .x = 0.0, .y = 0.0 },
        .size = NSSize{ .width = cfg.window_width, .height = cfg.window_height },
    });
    objc.msgSend_void1(effect_view, objc.sel("setMaterial:"), NSVisualEffectMaterialHUDWindow);
    objc.msgSend_void1(effect_view, objc.sel("setBlendingMode:"), NSVisualEffectBlendingModeBehindWindow);
    objc.msgSend_void1(effect_view, objc.sel("setState:"), NSVisualEffectStateActive);
    appkit.setWantsLayer(effect_view, true);

    const effect_layer = objc.msgSend_id(effect_view, objc.sel("layer"));
    if (effect_layer != null) {
        objc.msgSend_void1(effect_layer, objc.sel("setCornerRadius:"), @as(CGFloat, 20.0));
        objc.msgSend_void1(effect_layer, objc.sel("setMasksToBounds:"), @as(c_char, 1));
    }
    appkit.addSubview(content, effect_view);

    // Emoji/GIF area
    const emoji_frame = NSRect{
        .origin = NSPoint{ .x = 0.0, .y = cfg.emoji_y },
        .size = NSSize{ .width = cfg.window_width, .height = cfg.emoji_height },
    };

    if (config.gifString(getGifBuf(cfg.pill_type))) |gif_name| {
        const home = std.posix.getenv("HOME") orelse "";
        var path_buf: [512]u8 = undefined;
        const slice = std.fmt.bufPrint(path_buf[0 .. path_buf.len - 1], "{s}/.config/eyes/{s}", .{ home, gif_name }) catch null;
        if (slice) |s| {
            path_buf[s.len] = 0;
            const path: [:0]const u8 = path_buf[0..s.len :0];
            const gv = gifview.create(path, emoji_frame);
            if (gv != null) {
                appkit.addSubview(effect_view, gv);
                state.gif_view = gv;
            }
        }
    }

    if (state.gif_view == null) {
        const label = appkit.createLabel(cfg.emoji);
        appkit.setFont(label, appkit.systemFont(cfg.emoji_font_size));
        appkit.setTextColor(label, appkit.whiteColor());
        appkit.setAlignment(label, appkit.NSTextAlignmentCenter);
        appkit.setViewFrame(label, emoji_frame);
        appkit.addSubview(effect_view, label);
        state.emoji_label = label;
    }

    // Small hint text
    const dark = appkit.isDarkMode();
    const hint_color = if (dark) appkit.colorWithRGBA(1.0, 1.0, 1.0, 0.6) else appkit.colorWithRGBA(0.0, 0.0, 0.0, 0.6);
    const hint = appkit.createLabel(cfg.hint_text);
    appkit.setFont(hint, appkit.systemFont(11.0));
    appkit.setTextColor(hint, hint_color);
    appkit.setAlignment(hint, appkit.NSTextAlignmentCenter);
    appkit.setViewFrame(hint, NSRect{
        .origin = NSPoint{ .x = 0.0, .y = cfg.hint_y },
        .size = NSSize{ .width = cfg.window_width, .height = 16.0 },
    });
    appkit.addSubview(effect_view, hint);

    appkit.orderFront(window);
    state.window = window;

    // Accessibility
    appkit.setAccessibilityRole(window, "AXWindow");
    appkit.setAccessibilityLabel(window, cfg.accessibility_label);
    appkit.postAccessibilityAnnouncement(cfg.accessibility_announcement);

    // Start slide-in animation
    state.slide_phase = .sliding_in;
    state.slide_progress = 0.0;
    state.fade_current_alpha = 0.0;
    startFadeTimer(state, cfg);

    pill_layout.repositionAll();

    appkit.playSystemSound("Pop");
}

pub fn hide(state: *PillState, cfg: *const PillConfig) void {
    if (state.window == null) return;

    std.log.info("{s}: hiding reminder", .{cfg.log_name});

    state.slide_phase = .sliding_out;
    state.slide_progress = 0.0;
    startFadeTimer(state, cfg);

    pill_layout.repositionAll();
}

pub fn updateAnimation(state: *PillState, cfg: *const PillConfig, tick_val: u32) void {
    if (state.window == null or state.slide_phase != .visible) return;

    // Recalculate x in case other pills appeared/disappeared
    state.screen_x = pill_layout.getX(cfg.pill_type, state.cached_screen_width, false);

    // Floating bob: subtle 3px vertical oscillation
    const t: f32 = @floatFromInt(tick_val);
    const bob_offset: CGFloat = @floatCast(@sin(t * 0.5) * 3.0);
    applyPosition(state, cfg, target_y + bob_offset, max_visible_alpha);

    const label: objc.id = state.emoji_label orelse return;

    if (cfg.alt_emoji) |alt| {
        // Toggle animation: alternate between two emojis
        if (tick_val % 2 == 0) {
            appkit.setStringValue(label, cfg.emoji);
        } else {
            appkit.setStringValue(label, alt);
        }
    } else {
        // Rise animation: emoji moves up gradually
        const clamped: u64 = @min(tick_val, cfg.rise_max_ticks);
        const rise: CGFloat = @floatFromInt(clamped);
        appkit.setViewFrame(label, NSRect{
            .origin = NSPoint{ .x = 0.0, .y = cfg.emoji_y + rise * cfg.rise_per_tick },
            .size = NSSize{ .width = cfg.window_width, .height = cfg.emoji_height },
        });
    }
}

pub fn repositionIfNeeded(state: *PillState, cfg: *const PillConfig) void {
    if (state.window == null) return;
    const new_x = pill_layout.getX(cfg.pill_type, state.cached_screen_width, false);
    if (new_x != state.screen_x) {
        state.screen_x = new_x;
        if (state.slide_phase == .visible) {
            applyPosition(state, cfg, target_y, max_visible_alpha);
        }
    }
}

pub fn isVisible(state: *const PillState) bool {
    return state.window != null;
}
