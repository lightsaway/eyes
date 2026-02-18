// Fullscreen break overlay window — supports multiple monitors with fade animations.

const std = @import("std");
const objc = @import("macos/objc.zig");
const appkit = @import("macos/appkit.zig");
const foundation = @import("macos/foundation.zig");
const app_mod = @import("app.zig");
const cg = @import("macos/coregraphics.zig");

const CGFloat = objc.CGFloat;
const NSRect = objc.NSRect;
const NSPoint = objc.NSPoint;
const NSSize = objc.NSSize;

// Multi-monitor overlay state
const MAX_SCREENS = 8;
var overlay_windows: [MAX_SCREENS]objc.id = .{null} ** MAX_SCREENS;
var countdown_labels: [MAX_SCREENS]objc.id = .{null} ** MAX_SCREENS;
var message_labels: [MAX_SCREENS]objc.id = .{null} ** MAX_SCREENS;
var stretch_labels: [MAX_SCREENS]objc.id = .{null} ** MAX_SCREENS;
var progress_labels: [MAX_SCREENS]objc.id = .{null} ** MAX_SCREENS;
var screen_count: usize = 0;

// Fade state
const FadeOnComplete = enum { none, hide_after };
var fade_timer: objc.id = null;
var fade_current_alpha: CGFloat = 0.0;
var fade_target_alpha: CGFloat = 0.0;
var fade_on_complete: FadeOnComplete = .none;
const fade_step: CGFloat = 0.05;
const fade_interval: f64 = 0.033; // ~30fps

// Strict mode event tap state
var strict_tap: ?*anyopaque = null;
var strict_source: ?*anyopaque = null;

const messages = [_][*:0]const u8{
    "Look at something 20 feet away",
    "Rest your eyes for a moment",
    "Focus on a distant object",
    "Give your eyes a break",
    "Look away from the screen",
    "Time to relax your eyes",
};

const stretch_prompts = [_][*:0]const u8{
    "Roll your shoulders back slowly",
    "Stretch your arms above your head",
    "Gently tilt your head side to side",
    "Stretch your wrists and fingers",
    "Stand up and take a deep breath",
    "Touch your toes or stretch your back",
    "Rotate your ankles in circles",
    "Squeeze your shoulder blades together",
};

var stretch_index: usize = 0;

// Sound name lookup: 0=None, 1=Tink, 2=Pop, 3=Glass, 4=Purr, 5=Hero
const sound_names = [_]?[*:0]const u8{
    null,
    "Tink",
    "Pop",
    "Glass",
    "Purr",
    "Hero",
};

fn pickMessage() [*:0]const u8 {
    const idx = @as(usize, @intCast(@mod(std.time.timestamp(), messages.len)));
    return messages[idx];
}

fn pickStretch() [*:0]const u8 {
    const prompt = stretch_prompts[stretch_index % stretch_prompts.len];
    stretch_index +%= 1;
    return prompt;
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
    fade_timer = foundation.scheduledTimer(fade_interval, delegate, objc.sel("overlayFadeTick:"), true);
}

fn applyAlpha(alpha: CGFloat) void {
    for (0..screen_count) |i| {
        if (overlay_windows[i] != null) {
            appkit.setAlphaValue(overlay_windows[i], alpha);
        }
    }
}

pub fn fadeTick() void {
    if (fade_current_alpha < fade_target_alpha) {
        fade_current_alpha = @min(fade_current_alpha + fade_step, fade_target_alpha);
    } else if (fade_current_alpha > fade_target_alpha) {
        fade_current_alpha = @max(fade_current_alpha - fade_step, fade_target_alpha);
    }

    applyAlpha(fade_current_alpha);

    if (fade_current_alpha == fade_target_alpha) {
        cancelFadeTimer();
        if (fade_on_complete == .hide_after) {
            fade_on_complete = .none;
            destroyWindows();
        }
    }
}

fn destroyWindows() void {
    for (0..screen_count) |i| {
        if (overlay_windows[i] != null) {
            appkit.orderOut(overlay_windows[i]);
            objc.release(overlay_windows[i]);
            overlay_windows[i] = null;
            countdown_labels[i] = null;
            message_labels[i] = null;
            stretch_labels[i] = null;
            progress_labels[i] = null;
        }
    }
    screen_count = 0;
}

// Strict mode: block keyboard/mouse during break
fn strictTapCallback(_: ?*anyopaque, event_type: cg.CGEventType, _: ?*anyopaque, _: ?*anyopaque) callconv(.c) ?*anyopaque {
    // Block keyboard and mouse events by returning null
    _ = event_type;
    return null;
}

pub fn enableStrictMode() void {
    if (strict_tap != null) return;

    // Block key down, key up, mouse down/up, scroll
    const event_mask: u64 = (@as(u64, 1) << cg.kCGEventKeyDown) |
        (@as(u64, 1) << cg.kCGEventKeyUp) |
        (@as(u64, 1) << cg.kCGEventLeftMouseDown) |
        (@as(u64, 1) << cg.kCGEventLeftMouseUp) |
        (@as(u64, 1) << cg.kCGEventRightMouseDown) |
        (@as(u64, 1) << cg.kCGEventRightMouseUp) |
        (@as(u64, 1) << cg.kCGEventScrollWheel);

    const tap = cg.CGEventTapCreate(
        @intFromEnum(cg.CGEventTapLocation.cgSessionEventTap),
        @intFromEnum(cg.CGEventTapPlacement.headInsertEventTap),
        @intFromEnum(cg.CGEventTapOptions.defaultTap), // defaultTap = can modify/block
        event_mask,
        &strictTapCallback,
        null,
    );

    if (tap == null) {
        std.log.warn("Strict mode: failed to create event tap", .{});
        return;
    }

    const source = cg.CFMachPortCreateRunLoopSource(null, tap, 0);
    if (source == null) {
        std.log.warn("Strict mode: failed to create run loop source", .{});
        return;
    }

    cg.CFRunLoopAddSource(cg.CFRunLoopGetCurrent(), source, cg.kCFRunLoopCommonModes);
    cg.CGEventTapEnable(tap, true);

    strict_tap = tap;
    strict_source = source;
    std.log.info("Strict mode: enabled", .{});
}

pub fn disableStrictMode() void {
    if (strict_tap) |tap| {
        cg.CGEventTapEnable(tap, false);
        cg.CFMachPortInvalidate(tap);
        cg.CFRelease(tap);
        strict_tap = null;
    }
    if (strict_source) |source| {
        cg.CFRunLoopSourceInvalidate(source);
        cg.CFRelease(source);
        strict_source = null;
    }
    std.log.info("Strict mode: disabled", .{});
}

pub fn showOverlay(state: *app_mod.AppState) void {
    // Cancel any in-progress fade-out
    if (fade_on_complete == .hide_after) {
        cancelFadeTimer();
        fade_on_complete = .none;
        destroyWindows();
    }

    if (overlay_windows[0] != null) return;

    const screens_array = appkit.screens();
    const num_screens = appkit.arrayCount(screens_array);
    if (num_screens == 0) return;

    const main_screen = appkit.mainScreen();
    const msg_text = pickMessage();
    const stretch_text = pickStretch();
    var time_buf = state.formatBreakRemaining();
    const time_str: [*:0]const u8 = @ptrCast(&time_buf);

    const NSApp = appkit.sharedApplication();
    const delegate = objc.msgSend_id(NSApp, objc.sel("delegate"));

    const is_strict = state.strict_mode;
    const dark = appkit.isDarkMode();
    const bg_color = if (dark) appkit.colorWithRGBA(0.0, 0.0, 0.0, 0.85) else appkit.colorWithRGBA(1.0, 1.0, 1.0, 0.85);
    const text_color = if (dark) appkit.whiteColor() else appkit.blackColor();
    const sub_color = if (dark) appkit.colorWithRGBA(1.0, 1.0, 1.0, 0.7) else appkit.colorWithRGBA(0.0, 0.0, 0.0, 0.7);
    const progress_color = if (dark) appkit.colorWithRGBA(1.0, 1.0, 1.0, 0.4) else appkit.colorWithRGBA(0.0, 0.0, 0.0, 0.4);

    const count = @min(num_screens, MAX_SCREENS);
    screen_count = count;

    // Build initial progress bar
    var progress_buf: [64]u8 = .{0} ** 64;
    _ = formatProgressBar(&progress_buf, state.break_seconds_remaining, state.break_duration_secs);

    for (0..count) |i| {
        const screen = appkit.arrayObjectAtIndex(screens_array, @intCast(i));
        const screen_rect = appkit.screenFrame(screen);
        const is_main = (screen == main_screen);

        const window = appkit.createWindow(
            screen_rect,
            appkit.NSWindowStyleMaskBorderless,
            appkit.NSBackingStoreBuffered,
            false,
        );

        appkit.setWindowLevel(window, appkit.NSScreenSaverWindowLevel);
        appkit.setWindowBackgroundColor(window, bg_color);
        appkit.setOpaque(window, false);
        appkit.setAlphaValue(window, 0.0);
        appkit.setWindowCollectionBehavior(window, appkit.NSWindowCollectionBehaviorCanJoinAllSpaces | appkit.NSWindowCollectionBehaviorStationary);
        appkit.setIgnoresMouseEvents(window, !is_main);

        const content = appkit.contentView(window);
        appkit.setWantsLayer(content, true);

        const center_x = screen_rect.size.width / 2.0;
        const center_y = screen_rect.size.height / 2.0;

        const msg = appkit.createLabel(msg_text);
        appkit.setFont(msg, appkit.systemFont(28.0));
        appkit.setTextColor(msg, text_color);
        appkit.setAlignment(msg, appkit.NSTextAlignmentCenter);
        appkit.setViewFrame(msg, NSRect{
            .origin = NSPoint{ .x = center_x - 300.0, .y = center_y + 40.0 },
            .size = NSSize{ .width = 600.0, .height = 40.0 },
        });
        appkit.addSubview(content, msg);
        message_labels[i] = msg;

        const countdown = appkit.createLabel(time_str);
        appkit.setFont(countdown, appkit.monospacedSystemFont(120.0, appkit.NSFontWeightUltraLight));
        appkit.setTextColor(countdown, text_color);
        appkit.setAlignment(countdown, appkit.NSTextAlignmentCenter);
        appkit.setViewFrame(countdown, NSRect{
            .origin = NSPoint{ .x = center_x - 200.0, .y = center_y - 100.0 },
            .size = NSSize{ .width = 400.0, .height = 140.0 },
        });
        appkit.addSubview(content, countdown);
        countdown_labels[i] = countdown;

        // Progress bar below countdown
        const progress_str: [*:0]const u8 = @ptrCast(&progress_buf);
        const progress = appkit.createLabel(progress_str);
        appkit.setFont(progress, appkit.monospacedSystemFont(16.0, appkit.NSFontWeightUltraLight));
        appkit.setTextColor(progress, progress_color);
        appkit.setAlignment(progress, appkit.NSTextAlignmentCenter);
        appkit.setViewFrame(progress, NSRect{
            .origin = NSPoint{ .x = center_x - 200.0, .y = center_y - 130.0 },
            .size = NSSize{ .width = 400.0, .height = 24.0 },
        });
        appkit.addSubview(content, progress);
        progress_labels[i] = progress;

        // Stretch prompt below the progress bar
        const stretch = appkit.createLabel(stretch_text);
        appkit.setFont(stretch, appkit.systemFont(20.0));
        appkit.setTextColor(stretch, sub_color);
        appkit.setAlignment(stretch, appkit.NSTextAlignmentCenter);
        appkit.setViewFrame(stretch, NSRect{
            .origin = NSPoint{ .x = center_x - 300.0, .y = center_y - 170.0 },
            .size = NSSize{ .width = 600.0, .height = 30.0 },
        });
        appkit.addSubview(content, stretch);
        stretch_labels[i] = stretch;

        if (is_main and !is_strict) {
            const skip_btn = appkit.createButton("Skip", delegate, objc.sel("skipBreak:"));
            appkit.setViewFrame(skip_btn, NSRect{
                .origin = NSPoint{ .x = center_x - 130.0, .y = center_y - 220.0 },
                .size = NSSize{ .width = 80.0, .height = 32.0 },
            });
            appkit.addSubview(content, skip_btn);

            const delay1_btn = appkit.createButton("+1 min", delegate, objc.sel("delay1Min:"));
            appkit.setViewFrame(delay1_btn, NSRect{
                .origin = NSPoint{ .x = center_x - 40.0, .y = center_y - 220.0 },
                .size = NSSize{ .width = 80.0, .height = 32.0 },
            });
            appkit.addSubview(content, delay1_btn);

            const delay5_btn = appkit.createButton("+5 min", delegate, objc.sel("delay5Min:"));
            appkit.setViewFrame(delay5_btn, NSRect{
                .origin = NSPoint{ .x = center_x + 50.0, .y = center_y - 220.0 },
                .size = NSSize{ .width = 80.0, .height = 32.0 },
            });
            appkit.addSubview(content, delay5_btn);

            appkit.makeKeyAndOrderFront(window);
        } else {
            appkit.orderFront(window);
        }

        overlay_windows[i] = window;
    }

    // Set accessibility on the main screen window
    if (screen_count > 0 and overlay_windows[0] != null) {
        appkit.setAccessibilityRole(overlay_windows[0], "AXWindow");
        appkit.setAccessibilityLabel(overlay_windows[0], "Eye break overlay");
    }
    if (screen_count > 0 and countdown_labels[0] != null) {
        appkit.setAccessibilityRole(countdown_labels[0], "AXStaticText");
        appkit.setAccessibilityLabel(countdown_labels[0], "Break countdown");
        appkit.setAccessibilityValue(countdown_labels[0], time_str);
    }
    if (screen_count > 0 and message_labels[0] != null) {
        appkit.setAccessibilityRole(message_labels[0], "AXStaticText");
        appkit.setAccessibilityLabel(message_labels[0], "Break message");
    }

    // Announce break to VoiceOver
    appkit.postAccessibilityAnnouncement("Break time. Look at something 20 feet away.");

    // Start fade in
    fade_current_alpha = 0.0;
    fade_target_alpha = 1.0;
    fade_on_complete = .none;
    startFadeTimer();

    // Play configurable sound
    if (state.break_sound < sound_names.len) {
        if (sound_names[state.break_sound]) |name| {
            appkit.playSystemSound(name);
        }
    }

    // Enable strict mode if configured
    if (is_strict) {
        enableStrictMode();
    }
}

pub fn hideOverlay() void {
    if (screen_count == 0) return;

    // Disable strict mode if it was active
    disableStrictMode();

    // Start fade out
    fade_target_alpha = 0.0;
    fade_on_complete = .hide_after;
    startFadeTimer();
}

pub fn updateOverlay(state: *app_mod.AppState) void {
    var time_buf = state.formatBreakRemaining();
    const time_str: [*:0]const u8 = @ptrCast(&time_buf);

    // Build progress bar
    var progress_buf: [64]u8 = .{0} ** 64;
    _ = formatProgressBar(&progress_buf, state.break_seconds_remaining, state.break_duration_secs);
    const progress_str: [*:0]const u8 = @ptrCast(&progress_buf);

    for (0..screen_count) |i| {
        if (countdown_labels[i] != null) {
            appkit.setStringValue(countdown_labels[i], time_str);
        }
        if (progress_labels[i] != null) {
            appkit.setStringValue(progress_labels[i], progress_str);
        }
    }

    // Update accessibility value on main screen countdown
    if (screen_count > 0 and countdown_labels[0] != null) {
        appkit.setAccessibilityValue(countdown_labels[0], time_str);
    }
}

fn formatProgressBar(buf: []u8, remaining: i32, total: u32) usize {
    const bar_width: usize = 20;
    const rem: u32 = if (remaining < 0) 0 else @intCast(remaining);
    const elapsed = if (total > rem) total - rem else 0;
    const filled = if (total > 0) (elapsed * bar_width) / total else 0;

    var pos: usize = 0;
    // UTF-8 for block chars: \xe2\x96\x88 = "█", \xe2\x96\x91 = "░"
    for (0..bar_width) |j| {
        if (j < filled) {
            if (pos + 3 <= buf.len) {
                buf[pos] = 0xe2;
                buf[pos + 1] = 0x96;
                buf[pos + 2] = 0x88;
                pos += 3;
            }
        } else {
            if (pos + 3 <= buf.len) {
                buf[pos] = 0xe2;
                buf[pos + 1] = 0x96;
                buf[pos + 2] = 0x91;
                pos += 3;
            }
        }
    }
    if (pos < buf.len) buf[pos] = 0;
    return pos;
}
