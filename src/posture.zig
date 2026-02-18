// Posture reminder — modern floating pill at bottom-center with rising arrow and fade animations.

const std = @import("std");
const objc = @import("macos/objc.zig");
const appkit = @import("macos/appkit.zig");
const foundation = @import("macos/foundation.zig");

const CGFloat = objc.CGFloat;
const NSRect = objc.NSRect;
const NSPoint = objc.NSPoint;
const NSSize = objc.NSSize;

var posture_window: objc.id = null;
var arrow_label: objc.id = null;

const window_width: CGFloat = 160.0;
const window_height: CGFloat = 120.0;

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

pub fn fadeTick() void {
    if (fade_current_alpha < fade_target_alpha) {
        fade_current_alpha = @min(fade_current_alpha + fade_step, fade_target_alpha);
    } else if (fade_current_alpha > fade_target_alpha) {
        fade_current_alpha = @max(fade_current_alpha - fade_step, fade_target_alpha);
    }

    if (posture_window != null) {
        appkit.setAlphaValue(posture_window, fade_current_alpha);
    }

    if (fade_current_alpha == fade_target_alpha) {
        cancelFadeTimer();
        if (fade_on_complete == .hide_after) {
            fade_on_complete = .none;
            destroyWindow();
        }
    }
}

fn destroyWindow() void {
    if (posture_window != null) {
        appkit.orderOut(posture_window);
        objc.release(posture_window);
        posture_window = null;
        arrow_label = null;
    }
}

pub fn showPostureReminder() void {
    if (fade_on_complete == .hide_after) {
        cancelFadeTimer();
        fade_on_complete = .none;
        destroyWindow();
    }

    if (posture_window != null) return;

    std.log.info("Posture: showing reminder", .{});

    const screen = appkit.mainScreen();
    const screen_rect = appkit.screenFrame(screen);
    const x = (screen_rect.size.width - window_width) / 2.0;

    const window = appkit.createWindow(
        NSRect{
            .origin = NSPoint{ .x = x, .y = 60.0 },
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

    // Arrow label — starts low, will rise
    const label = appkit.createLabel("\xe2\x86\x91"); // "↑"
    appkit.setFont(label, appkit.systemFont(52.0));
    appkit.setTextColor(label, appkit.whiteColor());
    appkit.setAlignment(label, appkit.NSTextAlignmentCenter);
    appkit.setViewFrame(label, NSRect{
        .origin = NSPoint{ .x = 0.0, .y = 8.0 },
        .size = NSSize{ .width = window_width, .height = 64.0 },
    });
    appkit.addSubview(effect_view, label);
    arrow_label = label;

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

    // Start fade in
    fade_current_alpha = 0.0;
    fade_target_alpha = max_visible_alpha;
    fade_on_complete = .none;
    startFadeTimer();

    appkit.playSystemSound("Pop");
}

pub fn hidePostureReminder() void {
    if (posture_window == null) return;

    std.log.info("Posture: hiding reminder", .{});

    // Start fade out
    fade_target_alpha = 0.0;
    fade_on_complete = .hide_after;
    startFadeTimer();
}

pub fn updatePostureAnimation(tick: u32) void {
    const label: objc.id = arrow_label orelse return;

    // Arrow rises gradually: starts at y=8, moves up ~6px per tick
    const clamped: u64 = @min(tick, 5);
    const rise: CGFloat = @floatFromInt(clamped * 6);
    appkit.setViewFrame(label, NSRect{
        .origin = NSPoint{ .x = 0.0, .y = 8.0 + rise },
        .size = NSSize{ .width = window_width, .height = 64.0 },
    });

    // Note: breathing alpha is now handled by the fade system,
    // so we don't manually set alpha here during the visible phase
}

pub fn isVisible() bool {
    return posture_window != null;
}
