// Posture reminder — floating pill with slide-up entrance, floating bob, and slide-out exit.

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

var posture_window: objc.id = null;
var arrow_label: objc.id = null;
var gif_view: objc.id = null;

const window_width: CGFloat = 160.0;
const window_height: CGFloat = 120.0;
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
const slide_in_duration: f32 = 0.4; // seconds
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
    fade_timer = foundation.scheduledTimer(fade_interval, delegate, objc.sel("postureFadeTick:"), true);
}

/// Ease-out: t = 1 - (1-p)^2
fn easeOut(p: f32) f32 {
    const inv = 1.0 - p;
    return 1.0 - inv * inv;
}

/// Ease-in: t = p^2
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
            // Recalculate x every frame so all pills stay in sync
            screen_x = pill_layout.getX(.posture, cached_screen_width, false);
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
                // Reposition remaining pills now that we're gone
                pill_layout.repositionAll();
                return;
            }
            screen_x = pill_layout.getX(.posture, cached_screen_width, false);
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
    if (posture_window != null) {
        appkit.setWindowFrame(posture_window, NSRect{
            .origin = NSPoint{ .x = screen_x, .y = y },
            .size = NSSize{ .width = window_width, .height = window_height },
        });
        appkit.setAlphaValue(posture_window, alpha);
    }
}

fn destroyWindow() void {
    if (gif_view != null) {
        gifview.destroy(gif_view);
        gif_view = null;
    }
    if (posture_window != null) {
        appkit.orderOut(posture_window);
        objc.release(posture_window);
        posture_window = null;
        arrow_label = null;
    }
}

pub fn showPostureReminder() void {
    if (slide_phase == .sliding_out) {
        cancelFadeTimer();
        destroyWindow();
    }

    if (posture_window != null) return;

    std.log.info("Posture: showing reminder", .{});

    const screen = appkit.mainScreen();
    const screen_rect = appkit.screenFrame(screen);
    cached_screen_width = screen_rect.size.width;
    screen_x = pill_layout.getX(.posture, cached_screen_width, true);

    // Start below screen edge
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

    // Round corners on the effect view
    const effect_layer = objc.msgSend_id(effect_view, objc.sel("layer"));
    if (effect_layer != null) {
        objc.msgSend_void1(effect_layer, objc.sel("setCornerRadius:"), @as(CGFloat, 20.0));
        objc.msgSend_void1(effect_layer, objc.sel("setMasksToBounds:"), @as(c_char, 1));
    }
    appkit.addSubview(content, effect_view);

    // Emoji/GIF area
    const emoji_frame = NSRect{
        .origin = NSPoint{ .x = 0.0, .y = 8.0 },
        .size = NSSize{ .width = window_width, .height = 64.0 },
    };

    if (config.gifString(&app_mod.state.posture_gif)) |gif_name| {
        // Try to load GIF from ~/.config/eyes/{gif_name}
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
        // Fallback: arrow label
        const label = appkit.createLabel("\xe2\x86\x91"); // "↑"
        appkit.setFont(label, appkit.systemFont(52.0));
        appkit.setTextColor(label, appkit.whiteColor());
        appkit.setAlignment(label, appkit.NSTextAlignmentCenter);
        appkit.setViewFrame(label, emoji_frame);
        appkit.addSubview(effect_view, label);
        arrow_label = label;
    }

    // Small hint text
    const dark = appkit.isDarkMode();
    const hint_color = if (dark) appkit.colorWithRGBA(1.0, 1.0, 1.0, 0.6) else appkit.colorWithRGBA(0.0, 0.0, 0.0, 0.6);
    const hint = appkit.createLabel("straighten up");
    appkit.setFont(hint, appkit.systemFont(11.0));
    appkit.setTextColor(hint, hint_color);
    appkit.setAlignment(hint, appkit.NSTextAlignmentCenter);
    appkit.setViewFrame(hint, NSRect{
        .origin = NSPoint{ .x = 0.0, .y = 76.0 },
        .size = NSSize{ .width = window_width, .height = 16.0 },
    });
    appkit.addSubview(effect_view, hint);

    appkit.orderFront(window);
    posture_window = window;

    // Accessibility
    appkit.setAccessibilityRole(window, "AXWindow");
    appkit.setAccessibilityLabel(window, "Posture reminder");
    appkit.postAccessibilityAnnouncement("Straighten up. Check your posture.");

    // Start slide-in animation
    slide_phase = .sliding_in;
    slide_progress = 0.0;
    fade_current_alpha = 0.0;
    startFadeTimer();

    // Reposition other visible pills immediately
    pill_layout.repositionAll();

    appkit.playSystemSound("Pop");
}

pub fn hidePostureReminder() void {
    if (posture_window == null) return;

    std.log.info("Posture: hiding reminder", .{});

    // Start slide-out
    slide_phase = .sliding_out;
    slide_progress = 0.0;
    startFadeTimer();

    // Reposition remaining pills immediately
    pill_layout.repositionAll();
}

pub fn updatePostureAnimation(tick_val: u32) void {
    if (posture_window == null or slide_phase != .visible) return;

    // Recalculate x in case other pills appeared/disappeared
    screen_x = pill_layout.getX(.posture, cached_screen_width, false);

    // Floating bob: subtle 3px vertical oscillation
    const t: f32 = @floatFromInt(tick_val);
    const bob_offset: CGFloat = @floatCast(@sin(t * 0.5) * 3.0);
    applyPosition(target_y + bob_offset, max_visible_alpha);

    // Arrow rises gradually
    const label: objc.id = arrow_label orelse return;
    const clamped: u64 = @min(tick_val, 5);
    const rise: CGFloat = @floatFromInt(clamped * 6);
    appkit.setViewFrame(label, NSRect{
        .origin = NSPoint{ .x = 0.0, .y = 8.0 + rise },
        .size = NSSize{ .width = window_width, .height = 64.0 },
    });
}

pub fn repositionIfNeeded() void {
    if (posture_window == null) return;
    const new_x = pill_layout.getX(.posture, cached_screen_width, false);
    if (new_x != screen_x) {
        screen_x = new_x;
        // Only snap position if fully visible (sliding pills update via fadeTick)
        if (slide_phase == .visible) {
            applyPosition(target_y, max_visible_alpha);
        }
    }
}

pub fn isVisible() bool {
    return posture_window != null;
}
