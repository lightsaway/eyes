// Fullscreen break overlay window.

const std = @import("std");
const objc = @import("macos/objc.zig");
const appkit = @import("macos/appkit.zig");
const app_mod = @import("app.zig");

const CGFloat = objc.CGFloat;
const NSRect = objc.NSRect;
const NSPoint = objc.NSPoint;
const NSSize = objc.NSSize;

// Overlay state
var overlay_window: objc.id = null;
var countdown_label: objc.id = null;
var message_label: objc.id = null;

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

pub fn showOverlay(state: *app_mod.AppState) void {
    if (overlay_window != null) return;

    // Get main screen frame
    const screen = appkit.mainScreen();
    const screen_rect = appkit.screenFrame(screen);

    // Create borderless fullscreen window
    const window = appkit.createWindow(
        screen_rect,
        appkit.NSWindowStyleMaskBorderless,
        appkit.NSBackingStoreBuffered,
        false,
    );

    // Configure window for overlay behavior
    appkit.setWindowLevel(window, appkit.NSScreenSaverWindowLevel);
    appkit.setWindowBackgroundColor(window, appkit.colorWithRGBA(0.0, 0.0, 0.0, 0.85));
    appkit.setOpaque(window, false);
    appkit.setWindowCollectionBehavior(window, appkit.NSWindowCollectionBehaviorCanJoinAllSpaces | appkit.NSWindowCollectionBehaviorStationary);
    appkit.setIgnoresMouseEvents(window, false);

    // Create content view
    const content = appkit.contentView(window);
    appkit.setWantsLayer(content, true);

    const center_x = screen_rect.size.width / 2.0;
    const center_y = screen_rect.size.height / 2.0;

    // Message label (above countdown)
    const msg = appkit.createLabel(pickMessage());
    appkit.setFont(msg, appkit.systemFont(28.0));
    appkit.setTextColor(msg, appkit.whiteColor());
    appkit.setAlignment(msg, appkit.NSTextAlignmentCenter);
    appkit.setViewFrame(msg, NSRect{
        .origin = NSPoint{ .x = center_x - 300.0, .y = center_y + 40.0 },
        .size = NSSize{ .width = 600.0, .height = 40.0 },
    });
    appkit.addSubview(content, msg);
    message_label = msg;

    // Countdown label
    var time_buf = state.formatBreakRemaining();
    const time_str: [*:0]const u8 = @ptrCast(&time_buf);
    const countdown = appkit.createLabel(time_str);
    appkit.setFont(countdown, appkit.monospacedSystemFont(120.0, appkit.NSFontWeightUltraLight));
    appkit.setTextColor(countdown, appkit.whiteColor());
    appkit.setAlignment(countdown, appkit.NSTextAlignmentCenter);
    appkit.setViewFrame(countdown, NSRect{
        .origin = NSPoint{ .x = center_x - 200.0, .y = center_y - 100.0 },
        .size = NSSize{ .width = 400.0, .height = 140.0 },
    });
    appkit.addSubview(content, countdown);
    countdown_label = countdown;

    // Get delegate for button targets
    const NSApp = appkit.sharedApplication();
    const delegate = objc.msgSend_id(NSApp, objc.sel("delegate"));

    // Skip button
    const skip_btn = appkit.createButton("Skip", delegate, objc.sel("skipBreak:"));
    appkit.setViewFrame(skip_btn, NSRect{
        .origin = NSPoint{ .x = center_x - 130.0, .y = center_y - 170.0 },
        .size = NSSize{ .width = 80.0, .height = 32.0 },
    });
    appkit.addSubview(content, skip_btn);

    // +1 min button
    const delay1_btn = appkit.createButton("+1 min", delegate, objc.sel("delay1Min:"));
    appkit.setViewFrame(delay1_btn, NSRect{
        .origin = NSPoint{ .x = center_x - 40.0, .y = center_y - 170.0 },
        .size = NSSize{ .width = 80.0, .height = 32.0 },
    });
    appkit.addSubview(content, delay1_btn);

    // +5 min button
    const delay5_btn = appkit.createButton("+5 min", delegate, objc.sel("delay5Min:"));
    appkit.setViewFrame(delay5_btn, NSRect{
        .origin = NSPoint{ .x = center_x + 50.0, .y = center_y - 170.0 },
        .size = NSSize{ .width = 80.0, .height = 32.0 },
    });
    appkit.addSubview(content, delay5_btn);

    appkit.makeKeyAndOrderFront(window);
    overlay_window = window;

    // Play a gentle sound
    appkit.playSystemSound("Tink");
}

pub fn hideOverlay() void {
    if (overlay_window != null) {
        appkit.orderOut(overlay_window);
        objc.release(overlay_window);
        overlay_window = null;
        countdown_label = null;
        message_label = null;
    }
}

pub fn updateOverlay(state: *app_mod.AppState) void {
    if (countdown_label != null) {
        var time_buf = state.formatBreakRemaining();
        const time_str: [*:0]const u8 = @ptrCast(&time_buf);
        appkit.setStringValue(countdown_label, time_str);
    }
}
