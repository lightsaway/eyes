// Gentle mode — translucent banner at top of screen instead of fullscreen overlay.

const std = @import("std");
const objc = @import("macos/objc.zig");
const appkit = @import("macos/appkit.zig");
const foundation = @import("macos/foundation.zig");
const app_mod = @import("app.zig");

const CGFloat = objc.CGFloat;
const NSRect = objc.NSRect;
const NSPoint = objc.NSPoint;
const NSSize = objc.NSSize;

var banner_window: objc.id = null;
var countdown_label: objc.id = null;
var message_label: objc.id = null;

const banner_width: CGFloat = 600.0;
const banner_height: CGFloat = 80.0;

// NSVisualEffectView constants
const NSVisualEffectMaterialHUDWindow: c_long = 13;
const NSVisualEffectBlendingModeBehindWindow: c_long = 0;
const NSVisualEffectStateActive: c_long = 1;

// Fade state
const FadeOnComplete = enum { none, hide_after };
var fade_timer: objc.id = null;
var fade_current_alpha: CGFloat = 0.0;
var fade_target_alpha: CGFloat = 0.0;
var fade_on_complete: FadeOnComplete = .none;
const fade_step: CGFloat = 0.05;
const fade_interval: f64 = 0.033;
const max_visible_alpha: CGFloat = 0.95;

const messages = [_][*:0]const u8{
    "Look at something 20 feet away",
    "Rest your eyes for a moment",
    "Focus on a distant object",
    "Give your eyes a break",
    "Look away from the screen",
    "Time to relax your eyes",
};

fn pickMessage() [*:0]const u8 {
    const idx = @as(usize, @intCast(@mod(std.time.timestamp(), messages.len)));
    return messages[idx];
}

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
    fade_timer = foundation.scheduledTimer(fade_interval, delegate, objc.sel("gentleFadeTick:"), true);
}

fn destroyWindow() void {
    if (banner_window != null) {
        appkit.orderOut(banner_window);
        objc.release(banner_window);
        banner_window = null;
        countdown_label = null;
        message_label = null;
    }
}

pub fn fadeTick() void {
    if (fade_current_alpha < fade_target_alpha) {
        fade_current_alpha = @min(fade_current_alpha + fade_step, fade_target_alpha);
    } else if (fade_current_alpha > fade_target_alpha) {
        fade_current_alpha = @max(fade_current_alpha - fade_step, fade_target_alpha);
    }

    if (banner_window != null) {
        appkit.setAlphaValue(banner_window, fade_current_alpha);
    }

    if (fade_current_alpha == fade_target_alpha) {
        cancelFadeTimer();
        if (fade_on_complete == .hide_after) {
            fade_on_complete = .none;
            destroyWindow();
        }
    }
}

pub fn showGentleBanner(state: *app_mod.AppState) void {
    if (fade_on_complete == .hide_after) {
        cancelFadeTimer();
        fade_on_complete = .none;
        destroyWindow();
    }

    if (banner_window != null) return;

    std.log.info("Gentle: showing banner", .{});

    const screen = appkit.mainScreen();
    const screen_rect = appkit.screenFrame(screen);
    const x = (screen_rect.size.width - banner_width) / 2.0;
    const y = screen_rect.size.height - banner_height - 40.0; // near top

    const window = appkit.createWindow(
        NSRect{
            .origin = NSPoint{ .x = x, .y = y },
            .size = NSSize{ .width = banner_width, .height = banner_height },
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
        .size = NSSize{ .width = banner_width, .height = banner_height },
    });
    objc.msgSend_void1(effect_view, objc.sel("setMaterial:"), NSVisualEffectMaterialHUDWindow);
    objc.msgSend_void1(effect_view, objc.sel("setBlendingMode:"), NSVisualEffectBlendingModeBehindWindow);
    objc.msgSend_void1(effect_view, objc.sel("setState:"), NSVisualEffectStateActive);
    appkit.setWantsLayer(effect_view, true);

    // Round corners
    const effect_layer = objc.msgSend_id(effect_view, objc.sel("layer"));
    if (effect_layer != null) {
        objc.msgSend_void1(effect_layer, objc.sel("setCornerRadius:"), @as(CGFloat, 16.0));
        objc.msgSend_void1(effect_layer, objc.sel("setMasksToBounds:"), @as(c_char, 1));
    }
    appkit.addSubview(content, effect_view);

    // Message label (left side)
    const dark = appkit.isDarkMode();
    const text_color = if (dark) appkit.whiteColor() else appkit.blackColor();
    const msg_text = pickMessage();
    const msg = appkit.createLabel(msg_text);
    appkit.setFont(msg, appkit.systemFont(18.0));
    appkit.setTextColor(msg, text_color);
    appkit.setAlignment(msg, appkit.NSTextAlignmentCenter);
    appkit.setViewFrame(msg, NSRect{
        .origin = NSPoint{ .x = 20.0, .y = 20.0 },
        .size = NSSize{ .width = 400.0, .height = 40.0 },
    });
    appkit.addSubview(effect_view, msg);
    message_label = msg;

    // Countdown label (right side)
    var time_buf = state.formatBreakRemaining();
    const time_str: [*:0]const u8 = @ptrCast(&time_buf);
    const countdown = appkit.createLabel(time_str);
    appkit.setFont(countdown, appkit.monospacedSystemFont(36.0, appkit.NSFontWeightUltraLight));
    appkit.setTextColor(countdown, text_color);
    appkit.setAlignment(countdown, appkit.NSTextAlignmentCenter);
    appkit.setViewFrame(countdown, NSRect{
        .origin = NSPoint{ .x = 430.0, .y = 10.0 },
        .size = NSSize{ .width = 150.0, .height = 60.0 },
    });
    appkit.addSubview(effect_view, countdown);
    countdown_label = countdown;

    appkit.orderFront(window);
    banner_window = window;

    // Accessibility
    appkit.setAccessibilityRole(window, "AXWindow");
    appkit.setAccessibilityLabel(window, "Break reminder banner");
    appkit.postAccessibilityAnnouncement("Break time. Look at something 20 feet away.");

    // Start fade in
    fade_current_alpha = 0.0;
    fade_target_alpha = max_visible_alpha;
    fade_on_complete = .none;
    startFadeTimer();

    appkit.playSystemSound("Tink");
}

pub fn hideGentleBanner() void {
    if (banner_window == null) return;

    std.log.info("Gentle: hiding banner", .{});

    fade_target_alpha = 0.0;
    fade_on_complete = .hide_after;
    startFadeTimer();
}

pub fn updateGentleBanner(state: *app_mod.AppState) void {
    var time_buf = state.formatBreakRemaining();
    const time_str: [*:0]const u8 = @ptrCast(&time_buf);

    if (countdown_label != null) {
        appkit.setStringValue(countdown_label, time_str);
    }
}

pub fn isVisible() bool {
    return banner_window != null;
}
