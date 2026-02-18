// Fullscreen break overlay window — circular countdown ring with glow and pulsing message.

const std = @import("std");
const objc = @import("macos/objc.zig");
const appkit = @import("macos/appkit.zig");
const foundation = @import("macos/foundation.zig");
const app_mod = @import("app.zig");
const cg = @import("macos/coregraphics.zig");
const ca = @import("macos/coreanim.zig");

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
var ring_layers: [MAX_SCREENS]objc.id = .{null} ** MAX_SCREENS;
var screen_count: usize = 0;

// Ring geometry
const ring_radius: CGFloat = 80.0;
const ring_line_width: CGFloat = 8.0;

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
            ring_layers[i] = null;
        }
    }
    screen_count = 0;
}

// Strict mode: block keyboard/mouse during break
fn strictTapCallback(_: ?*anyopaque, event_type: cg.CGEventType, _: ?*anyopaque, _: ?*anyopaque) callconv(.c) ?*anyopaque {
    _ = event_type;
    return null;
}

pub fn enableStrictMode() void {
    if (strict_tap != null) return;

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
        @intFromEnum(cg.CGEventTapOptions.defaultTap),
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

/// Create a circular arc CGPath centered at (cx, cy) with given radius.
fn createRingPath(cx: CGFloat, cy: CGFloat, radius: CGFloat) ?*anyopaque {
    const path = ca.CGPathCreateMutable();
    if (path == null) return null;
    // Start at top (12 o'clock), go clockwise.
    // In Core Graphics: 0 = 3 o'clock, pi/2 = 12 o'clock.
    // For clockwise visual (counterclockwise in CG coords): startAngle=pi/2, endAngle=pi/2+2*pi, clockwise=false
    ca.CGPathAddArc(path, null, cx, cy, radius, ca.pi / 2.0, ca.pi / 2.0 + 2.0 * ca.pi, false);
    return path;
}

/// Add a pulsing opacity animation to a layer.
fn addPulseAnimation(layer: objc.id) void {
    const anim = ca.animationWithKeyPath("opacity");
    if (anim == null) return;
    ca.setFromValue(anim, ca.numberWithFloat(1.0));
    ca.setToValue(anim, ca.numberWithFloat(0.4));
    ca.setDuration(anim, 2.0);
    ca.setRepeatCount(anim, ca.HUGE_VALF);
    ca.setAutoreverses(anim, true);
    ca.setRemovedOnCompletion(anim, false);
    ca.addAnimation(layer, anim, "pulse");
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

    // Ring colors
    const stroke_r: CGFloat = if (dark) 0.4 else 0.2;
    const stroke_g: CGFloat = if (dark) 0.8 else 0.6;
    const stroke_b: CGFloat = if (dark) 1.0 else 0.9;
    const ring_color = ca.CGColorCreateGenericRGB(stroke_r, stroke_g, stroke_b, 1.0);
    const track_color = ca.CGColorCreateGenericRGB(stroke_r, stroke_g, stroke_b, 0.2);
    const clear_cg = ca.CGColorCreateGenericRGB(0.0, 0.0, 0.0, 0.0);

    const count = @min(num_screens, MAX_SCREENS);
    screen_count = count;

    // Compute initial strokeEnd
    const elapsed_f: CGFloat = if (state.break_duration_secs > 0)
        1.0 - @as(CGFloat, @floatFromInt(@max(state.break_seconds_remaining, 0))) / @as(CGFloat, @floatFromInt(state.break_duration_secs))
    else
        0.0;

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

        // --- Pulsing message label above ring ---
        const msg = appkit.createLabel(msg_text);
        appkit.setFont(msg, appkit.systemFont(28.0));
        appkit.setTextColor(msg, text_color);
        appkit.setAlignment(msg, appkit.NSTextAlignmentCenter);
        appkit.setViewFrame(msg, NSRect{
            .origin = NSPoint{ .x = center_x - 300.0, .y = center_y + ring_radius + 30.0 },
            .size = NSSize{ .width = 600.0, .height = 40.0 },
        });
        appkit.setWantsLayer(msg, true);
        appkit.addSubview(content, msg);
        message_labels[i] = msg;

        // Add pulse animation to the message label's layer
        const msg_layer = objc.msgSend_id(msg, objc.sel("layer"));
        if (msg_layer != null) {
            addPulseAnimation(msg_layer);
        }

        // --- Circular ring area ---
        // We use a host NSView to contain the ring layers
        const ring_host_size: CGFloat = (ring_radius + ring_line_width) * 2.0 + 40.0;
        const NSView = objc.getClass("NSView");
        const ring_host = objc.msgSend_id1(objc.alloc(NSView), objc.sel("initWithFrame:"), NSRect{
            .origin = NSPoint{ .x = center_x - ring_host_size / 2.0, .y = center_y - ring_host_size / 2.0 },
            .size = NSSize{ .width = ring_host_size, .height = ring_host_size },
        });
        appkit.setWantsLayer(ring_host, true);
        appkit.addSubview(content, ring_host);

        const host_layer = objc.msgSend_id(ring_host, objc.sel("layer"));
        const ring_cx = ring_host_size / 2.0;
        const ring_cy = ring_host_size / 2.0;

        // Create arc path
        const arc_path = createRingPath(ring_cx, ring_cy, ring_radius);

        // Background track ring
        const track_layer = ca.createShapeLayer();
        if (track_layer != null and arc_path != null) {
            ca.setPath(track_layer, arc_path);
            ca.setStrokeColor(track_layer, track_color);
            ca.setFillColor(track_layer, clear_cg);
            ca.setLineWidth(track_layer, ring_line_width);
            ca.setLineCap(track_layer, ca.lineCapRound());
            if (host_layer != null) ca.addSublayer(host_layer, track_layer);
        }

        // Progress ring
        const progress_layer = ca.createShapeLayer();
        if (progress_layer != null and arc_path != null) {
            ca.setPath(progress_layer, arc_path);
            ca.setStrokeColor(progress_layer, ring_color);
            ca.setFillColor(progress_layer, clear_cg);
            ca.setLineWidth(progress_layer, ring_line_width);
            ca.setLineCap(progress_layer, ca.lineCapRound());
            ca.setStrokeEnd(progress_layer, elapsed_f);

            // Glow shadow
            ca.setShadowColor(progress_layer, ring_color);
            ca.setShadowRadius(progress_layer, 15.0);
            ca.setShadowOpacity(progress_layer, 0.6);
            ca.setShadowOffset(progress_layer, .{ .width = 0.0, .height = 0.0 });

            if (host_layer != null) ca.addSublayer(host_layer, progress_layer);
        }

        if (arc_path != null) ca.CGPathRelease(arc_path);

        ring_layers[i] = progress_layer;

        // --- Countdown label inside ring ---
        const countdown = appkit.createLabel(time_str);
        appkit.setFont(countdown, appkit.monospacedSystemFont(72.0, appkit.NSFontWeightUltraLight));
        appkit.setTextColor(countdown, text_color);
        appkit.setAlignment(countdown, appkit.NSTextAlignmentCenter);
        appkit.setViewFrame(countdown, NSRect{
            .origin = NSPoint{ .x = center_x - 100.0, .y = center_y - 45.0 },
            .size = NSSize{ .width = 200.0, .height = 90.0 },
        });
        appkit.addSubview(content, countdown);
        countdown_labels[i] = countdown;

        // --- Stretch prompt below ring ---
        const stretch = appkit.createLabel(stretch_text);
        appkit.setFont(stretch, appkit.systemFont(20.0));
        appkit.setTextColor(stretch, sub_color);
        appkit.setAlignment(stretch, appkit.NSTextAlignmentCenter);
        appkit.setViewFrame(stretch, NSRect{
            .origin = NSPoint{ .x = center_x - 300.0, .y = center_y - ring_radius - 60.0 },
            .size = NSSize{ .width = 600.0, .height = 30.0 },
        });
        appkit.addSubview(content, stretch);
        stretch_labels[i] = stretch;

        // --- Buttons (main screen only, non-strict) ---
        if (is_main and !is_strict) {
            const btn_y = center_y - ring_radius - 110.0;

            const skip_btn = appkit.createButton("Skip", delegate, objc.sel("skipBreak:"));
            appkit.setViewFrame(skip_btn, NSRect{
                .origin = NSPoint{ .x = center_x - 130.0, .y = btn_y },
                .size = NSSize{ .width = 80.0, .height = 32.0 },
            });
            appkit.addSubview(content, skip_btn);

            const delay1_btn = appkit.createButton("+1 min", delegate, objc.sel("delay1Min:"));
            appkit.setViewFrame(delay1_btn, NSRect{
                .origin = NSPoint{ .x = center_x - 40.0, .y = btn_y },
                .size = NSSize{ .width = 80.0, .height = 32.0 },
            });
            appkit.addSubview(content, delay1_btn);

            const delay5_btn = appkit.createButton("+5 min", delegate, objc.sel("delay5Min:"));
            appkit.setViewFrame(delay5_btn, NSRect{
                .origin = NSPoint{ .x = center_x + 50.0, .y = btn_y },
                .size = NSSize{ .width = 80.0, .height = 32.0 },
            });
            appkit.addSubview(content, delay5_btn);

            appkit.makeKeyAndOrderFront(window);
        } else {
            appkit.orderFront(window);
        }

        overlay_windows[i] = window;
    }

    // Release CG colors
    if (ring_color != null) ca.CGColorRelease(ring_color);
    if (track_color != null) ca.CGColorRelease(track_color);
    if (clear_cg != null) ca.CGColorRelease(clear_cg);

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

    // Compute strokeEnd progress
    const elapsed_f: CGFloat = if (state.break_duration_secs > 0)
        1.0 - @as(CGFloat, @floatFromInt(@max(state.break_seconds_remaining, 0))) / @as(CGFloat, @floatFromInt(state.break_duration_secs))
    else
        0.0;

    for (0..screen_count) |i| {
        if (countdown_labels[i] != null) {
            appkit.setStringValue(countdown_labels[i], time_str);
        }
        if (ring_layers[i] != null) {
            ca.setStrokeEnd(ring_layers[i], elapsed_f);
        }
    }

    // Update accessibility value on main screen countdown
    if (screen_count > 0 and countdown_labels[0] != null) {
        appkit.setAccessibilityValue(countdown_labels[0], time_str);
    }
}
