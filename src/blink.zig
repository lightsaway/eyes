// Blink reminder — floating pill at bottom-center with blinking eye animation.

const std = @import("std");
const objc = @import("macos/objc.zig");
const appkit = @import("macos/appkit.zig");

const CGFloat = objc.CGFloat;
const NSRect = objc.NSRect;
const NSPoint = objc.NSPoint;
const NSSize = objc.NSSize;

var blink_window: objc.id = null;
var eye_label: objc.id = null;

const window_width: CGFloat = 120.0;
const window_height: CGFloat = 80.0;

// NSVisualEffectView constants
const NSVisualEffectMaterialHUDWindow: c_long = 13;
const NSVisualEffectBlendingModeBehindWindow: c_long = 0;
const NSVisualEffectStateActive: c_long = 1;

pub fn showBlinkReminder() void {
    if (blink_window != null) return;

    std.log.info("Blink: showing reminder", .{});

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

    // Eye label — alternates between open and closed
    const label = appkit.createLabel("\xf0\x9f\x91\x81"); // "👁"
    appkit.setFont(label, appkit.systemFont(36.0));
    appkit.setTextColor(label, appkit.whiteColor());
    appkit.setAlignment(label, appkit.NSTextAlignmentCenter);
    appkit.setViewFrame(label, NSRect{
        .origin = NSPoint{ .x = 0.0, .y = 20.0 },
        .size = NSSize{ .width = window_width, .height = 44.0 },
    });
    appkit.addSubview(effect_view, label);
    eye_label = label;

    // Small hint text
    const hint = appkit.createLabel("blink");
    appkit.setFont(hint, appkit.systemFont(11.0));
    appkit.setTextColor(hint, appkit.colorWithRGBA(1.0, 1.0, 1.0, 0.6));
    appkit.setAlignment(hint, appkit.NSTextAlignmentCenter);
    appkit.setViewFrame(hint, NSRect{
        .origin = NSPoint{ .x = 0.0, .y = 4.0 },
        .size = NSSize{ .width = window_width, .height = 16.0 },
    });
    appkit.addSubview(effect_view, hint);

    appkit.orderFront(window);
    blink_window = window;

    // Fade in
    appkit.setAlphaValue(window, 0.95);

    appkit.playSystemSound("Pop");
}

pub fn hideBlinkReminder() void {
    if (blink_window != null) {
        std.log.info("Blink: hiding reminder", .{});
        appkit.orderOut(blink_window);
        objc.release(blink_window);
        blink_window = null;
        eye_label = null;
    }
}

pub fn updateBlinkAnimation(tick_val: u32) void {
    const label: objc.id = eye_label orelse return;
    const win: objc.id = blink_window orelse return;

    // Alternate between open eye and closed
    if (tick_val % 2 == 0) {
        appkit.setStringValue(label, "\xf0\x9f\x91\x81"); // "👁"
    } else {
        appkit.setStringValue(label, "\xe2\x80\x94"); // "—"
    }

    // Breathing alpha
    const alpha: CGFloat = if (tick_val % 2 == 0) 0.95 else 0.75;
    appkit.setAlphaValue(win, alpha);

    std.log.info("Blink: animation tick={d}", .{tick_val});
}

pub fn isVisible() bool {
    return blink_window != null;
}
