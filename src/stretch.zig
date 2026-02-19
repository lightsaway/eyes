// Stretch reminder — floating pill with slide-up entrance, floating bob, and slide-out exit.

const std = @import("std");
const objc = @import("macos/objc.zig");
const appkit = @import("macos/appkit.zig");
const foundation = @import("macos/foundation.zig");
const config = @import("config.zig");
const app_mod = @import("app.zig");
const gifview = @import("macos/gifview.zig");
const pill_layout = @import("pill_layout.zig");

const CGFloat = objc.CGFloat;
const NSRect = objc.NSRect;
const NSPoint = objc.NSPoint;
const NSSize = objc.NSSize;

var stretch_window: objc.id = null;
var stretch_label: objc.id = null;
var gif_view: objc.id = null;

const window_width: CGFloat = 120.0;
const window_height: CGFloat = 80.0;
const target_y: CGFloat = 60.0;

// NSVisualEffectView constants
const NSVisualEffectMaterialHUDWindow: c_long = 13;
const NSVisualEffectBlendingModeBehindWindow: c_long = 0;
const NSVisualEffectStateActive: c_long = 1;

// Slide animation state
const SlidePhase = enum { sliding_in, visible, sliding_out, hidden };
var slide_phase: SlidePhase = .hidden;
var slide_progress: f32 = 0.0;
var screen_x: CGFloat = 0.0;
var cached_screen_width: CGFloat = 0.0;

// Fade/slide state
var fade_timer: objc.id = null;
var fade_current_alpha: CGFloat = 0.0;
const fade_interval: f64 = 0.033;
const max_visible_alpha: CGFloat = 0.95;
const slide_in_duration: f32 = 0.4;
const slide_out_duration: f32 = 0.3;

fn cancelFadeTimer() void {
    if (fade_timer != null) {
        foundation.invalidateTimer(fade_timer);
        fade_timer = null;
    }
}

fn startFadeTimer() void {
    cancelFadeTimer();
    const NSApp = appkit.sharedApplication();
    const delegate = objc.msgSend_id(NSApp, objc.sel("delegate"));
    fade_timer = foundation.scheduledTimer(fade_interval, delegate, objc.sel("stretchFadeTick:"), true);
}

fn easeOut(p: f32) f32 {
    const inv = 1.0 - p;
    return 1.0 - inv * inv;
}

fn easeIn(p: f32) f32 {
    return p * p;
}

pub fn fadeTick() void {
    const dt: f32 = @floatCast(fade_interval);

    switch (slide_phase) {
        .sliding_in => {
            slide_progress += dt / slide_in_duration;
            if (slide_progress >= 1.0) {
                slide_progress = 1.0;
                slide_phase = .visible;
            }
            screen_x = pill_layout.getX(.stretch, cached_screen_width, false);
            pill_layout.repositionAll();
            const t = easeOut(slide_progress);
            const y = -window_height + (target_y + window_height) * @as(CGFloat, @floatCast(t));
            fade_current_alpha = max_visible_alpha * @as(CGFloat, @floatCast(t));
            applyPosition(y, fade_current_alpha);
        },
        .visible => {
            cancelFadeTimer();
        },
        .sliding_out => {
            slide_progress += dt / slide_out_duration;
            if (slide_progress >= 1.0) {
                slide_progress = 1.0;
                slide_phase = .hidden;
                cancelFadeTimer();
                destroyWindow();
                pill_layout.repositionAll();
                return;
            }
            screen_x = pill_layout.getX(.stretch, cached_screen_width, false);
            pill_layout.repositionAll();
            const t = easeIn(slide_progress);
            const y = target_y - (target_y + window_height) * @as(CGFloat, @floatCast(t));
            fade_current_alpha = max_visible_alpha * (1.0 - @as(CGFloat, @floatCast(t)));
            applyPosition(y, fade_current_alpha);
        },
        .hidden => {
            cancelFadeTimer();
        },
    }
}

fn applyPosition(y: CGFloat, alpha: CGFloat) void {
    if (stretch_window != null) {
        appkit.setWindowFrame(stretch_window, NSRect{
            .origin = NSPoint{ .x = screen_x, .y = y },
            .size = NSSize{ .width = window_width, .height = window_height },
        });
        appkit.setAlphaValue(stretch_window, alpha);
    }
}

fn destroyWindow() void {
    if (gif_view != null) {
        gifview.destroy(gif_view);
        gif_view = null;
    }
    if (stretch_window != null) {
        appkit.orderOut(stretch_window);
        objc.release(stretch_window);
        stretch_window = null;
        stretch_label = null;
    }
}

pub fn showStretchReminder() void {
    if (slide_phase == .sliding_out) {
        cancelFadeTimer();
        destroyWindow();
    }

    if (stretch_window != null) return;

    std.log.info("Stretch: showing reminder", .{});

    const screen = appkit.mainScreen();
    const screen_rect = appkit.screenFrame(screen);
    cached_screen_width = screen_rect.size.width;
    screen_x = pill_layout.getX(.stretch, cached_screen_width, true);

    const window = appkit.createWindow(
        NSRect{
            .origin = NSPoint{ .x = screen_x, .y = -window_height },
            .size = NSSize{ .width = window_width, .height = window_height },
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
        .size = NSSize{ .width = window_width, .height = window_height },
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
        .origin = NSPoint{ .x = 0.0, .y = 20.0 },
        .size = NSSize{ .width = window_width, .height = 44.0 },
    };

    if (config.gifString(&app_mod.state.stretch_gif)) |gif_name| {
        const home = std.posix.getenv("HOME") orelse "";
        var path_buf: [512]u8 = undefined;
        const slice = std.fmt.bufPrint(path_buf[0 .. path_buf.len - 1], "{s}/.config/eyes/{s}", .{ home, gif_name }) catch null;
        if (slice) |s| {
            path_buf[s.len] = 0;
            const path: [:0]const u8 = path_buf[0..s.len :0];
            const gv = gifview.create(path, emoji_frame);
            if (gv != null) {
                appkit.addSubview(effect_view, gv);
                gif_view = gv;
            }
        }
    }

    if (gif_view == null) {
        const label = appkit.createLabel("\xf0\x9f\x99\x86"); // "🙆"
        appkit.setFont(label, appkit.systemFont(36.0));
        appkit.setTextColor(label, appkit.whiteColor());
        appkit.setAlignment(label, appkit.NSTextAlignmentCenter);
        appkit.setViewFrame(label, emoji_frame);
        appkit.addSubview(effect_view, label);
        stretch_label = label;
    }

    // Small hint text
    const dark = appkit.isDarkMode();
    const hint_color = if (dark) appkit.colorWithRGBA(1.0, 1.0, 1.0, 0.6) else appkit.colorWithRGBA(0.0, 0.0, 0.0, 0.6);
    const hint = appkit.createLabel("stretch");
    appkit.setFont(hint, appkit.systemFont(11.0));
    appkit.setTextColor(hint, hint_color);
    appkit.setAlignment(hint, appkit.NSTextAlignmentCenter);
    appkit.setViewFrame(hint, NSRect{
        .origin = NSPoint{ .x = 0.0, .y = 4.0 },
        .size = NSSize{ .width = window_width, .height = 16.0 },
    });
    appkit.addSubview(effect_view, hint);

    appkit.orderFront(window);
    stretch_window = window;

    // Accessibility
    appkit.setAccessibilityRole(window, "AXWindow");
    appkit.setAccessibilityLabel(window, "Stretch reminder");
    appkit.postAccessibilityAnnouncement("Time to stretch your body.");

    // Start slide-in
    slide_phase = .sliding_in;
    slide_progress = 0.0;
    fade_current_alpha = 0.0;
    startFadeTimer();

    pill_layout.repositionAll();

    appkit.playSystemSound("Pop");
}

pub fn hideStretchReminder() void {
    if (stretch_window == null) return;

    std.log.info("Stretch: hiding reminder", .{});

    slide_phase = .sliding_out;
    slide_progress = 0.0;
    startFadeTimer();

    pill_layout.repositionAll();
}

pub fn updateStretchAnimation(tick_val: u32) void {
    if (stretch_window == null or slide_phase != .visible) return;

    // Recalculate x in case other pills appeared/disappeared
    screen_x = pill_layout.getX(.stretch, cached_screen_width, false);

    // Floating bob
    const t: f32 = @floatFromInt(tick_val);
    const bob_offset: CGFloat = @floatCast(@sin(t * 0.5) * 3.0);
    applyPosition(target_y + bob_offset, max_visible_alpha);

    // Alternate between person gesturing OK and person raising hand
    const label: objc.id = stretch_label orelse return;
    if (tick_val % 2 == 0) {
        appkit.setStringValue(label, "\xf0\x9f\x99\x86"); // "🙆"
    } else {
        appkit.setStringValue(label, "\xf0\x9f\x99\x8b"); // "🙋"
    }
}

pub fn repositionIfNeeded() void {
    if (stretch_window == null) return;
    const new_x = pill_layout.getX(.stretch, cached_screen_width, false);
    if (new_x != screen_x) {
        screen_x = new_x;
        if (slide_phase == .visible) {
            applyPosition(target_y, max_visible_alpha);
        }
    }
}

pub fn isVisible() bool {
    return stretch_window != null;
}
