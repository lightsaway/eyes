// Hydration reminder — floating pill with slide-up entrance, floating bob, and slide-out exit.

const std = @import("std");
const objc = @import("macos/objc.zig");
const appkit = @import("macos/appkit.zig");
const foundation = @import("macos/foundation.zig");
const config = @import("config.zig");
const app_mod = @import("app.zig");
const gifview = @import("macos/gifview.zig");

const CGFloat = objc.CGFloat;
const NSRect = objc.NSRect;
const NSPoint = objc.NSPoint;
const NSSize = objc.NSSize;

var hydration_window: objc.id = null;
var water_label: objc.id = null;
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
    fade_timer = foundation.scheduledTimer(fade_interval, delegate, objc.sel("hydrationFadeTick:"), true);
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
                return;
            }
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
    if (hydration_window != null) {
        appkit.setWindowFrame(hydration_window, NSRect{
            .origin = NSPoint{ .x = screen_x, .y = y },
            .size = NSSize{ .width = window_width, .height = window_height },
        });
        appkit.setAlphaValue(hydration_window, alpha);
    }
}

fn destroyWindow() void {
    if (gif_view != null) {
        gifview.destroy(gif_view);
        gif_view = null;
    }
    if (hydration_window != null) {
        appkit.orderOut(hydration_window);
        objc.release(hydration_window);
        hydration_window = null;
        water_label = null;
    }
}

pub fn showHydrationReminder() void {
    if (slide_phase == .sliding_out) {
        cancelFadeTimer();
        destroyWindow();
    }

    if (hydration_window != null) return;

    std.log.info("Hydration: showing reminder", .{});

    const screen = appkit.mainScreen();
    const screen_rect = appkit.screenFrame(screen);
    screen_x = (screen_rect.size.width - window_width) / 2.0;

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

    if (config.gifString(&app_mod.state.hydration_gif)) |gif_name| {
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
        const label = appkit.createLabel("\xf0\x9f\x92\xa7"); // "💧"
        appkit.setFont(label, appkit.systemFont(36.0));
        appkit.setTextColor(label, appkit.whiteColor());
        appkit.setAlignment(label, appkit.NSTextAlignmentCenter);
        appkit.setViewFrame(label, emoji_frame);
        appkit.addSubview(effect_view, label);
        water_label = label;
    }

    // Small hint text
    const dark = appkit.isDarkMode();
    const hint_color = if (dark) appkit.colorWithRGBA(1.0, 1.0, 1.0, 0.6) else appkit.colorWithRGBA(0.0, 0.0, 0.0, 0.6);
    const hint = appkit.createLabel("drink water");
    appkit.setFont(hint, appkit.systemFont(11.0));
    appkit.setTextColor(hint, hint_color);
    appkit.setAlignment(hint, appkit.NSTextAlignmentCenter);
    appkit.setViewFrame(hint, NSRect{
        .origin = NSPoint{ .x = 0.0, .y = 4.0 },
        .size = NSSize{ .width = window_width, .height = 16.0 },
    });
    appkit.addSubview(effect_view, hint);

    appkit.orderFront(window);
    hydration_window = window;

    // Accessibility
    appkit.setAccessibilityRole(window, "AXWindow");
    appkit.setAccessibilityLabel(window, "Hydration reminder");
    appkit.postAccessibilityAnnouncement("Drink water. Stay hydrated.");

    // Start slide-in
    slide_phase = .sliding_in;
    slide_progress = 0.0;
    fade_current_alpha = 0.0;
    startFadeTimer();

    appkit.playSystemSound("Pop");
}

pub fn hideHydrationReminder() void {
    if (hydration_window == null) return;

    std.log.info("Hydration: hiding reminder", .{});

    slide_phase = .sliding_out;
    slide_progress = 0.0;
    startFadeTimer();
}

pub fn updateHydrationAnimation(tick_val: u32) void {
    if (hydration_window == null or slide_phase != .visible) return;

    // Floating bob
    const t: f32 = @floatFromInt(tick_val);
    const bob_offset: CGFloat = @floatCast(@sin(t * 0.5) * 3.0);
    applyPosition(target_y + bob_offset, max_visible_alpha);

    // Alternate between water droplet and faucet
    const label: objc.id = water_label orelse return;
    if (tick_val % 2 == 0) {
        appkit.setStringValue(label, "\xf0\x9f\x92\xa7"); // "💧"
    } else {
        appkit.setStringValue(label, "\xf0\x9f\x9a\xb0"); // "🚰"
    }
}

pub fn isVisible() bool {
    return hydration_window != null;
}
