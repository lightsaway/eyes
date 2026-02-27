// Eyes — Break reminder app.
// macOS entry point: ObjC delegate registration, callconv(.c) callback wrappers, NSAlert dialogs.

const std = @import("std");
const platform = @import("platform.zig");
const app_mod = @import("app.zig");
const actions = @import("actions.zig");

const objc = platform.backend.objc;
const appkit = platform.backend.appkit;
const foundation = platform.backend.foundation;
const menubar_mod = platform.backend.menubar;
const launchagent = platform.backend.launchagent;

const Method = struct {
    sel_name: [*:0]const u8,
    impl: objc.IMP,
};

// ObjC callback for NSTimer — wraps the portable tick() with the ObjC calling convention
fn timerCallback(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    app_mod.tick();
}

const delegate_methods = [_]Method{
    // Lifecycle
    .{ .sel_name = "applicationDidFinishLaunching:", .impl = @ptrCast(&appDidFinishLaunching) },
    .{ .sel_name = "timerTick:", .impl = @ptrCast(&timerCallback) },

    // Fade animation ticks
    .{ .sel_name = "overlayFadeTick:", .impl = @ptrCast(&overlayFadeTick) },
    .{ .sel_name = "postureFadeTick:", .impl = @ptrCast(&postureFadeTick) },
    .{ .sel_name = "blinkFadeTick:", .impl = @ptrCast(&blinkFadeTick) },
    .{ .sel_name = "hydrationFadeTick:", .impl = @ptrCast(&hydrationFadeTick) },
    .{ .sel_name = "stretchFadeTick:", .impl = @ptrCast(&stretchFadeTick) },
    .{ .sel_name = "gentleFadeTick:", .impl = @ptrCast(&gentleFadeTick) },

    // Menu actions
    .{ .sel_name = "togglePause:", .impl = @ptrCast(&togglePause) },
    .{ .sel_name = "takeBreakNow:", .impl = @ptrCast(&takeBreakNow) },
    .{ .sel_name = "skipBreak:", .impl = @ptrCast(&skipBreak) },
    .{ .sel_name = "delay1Min:", .impl = @ptrCast(&delay1Min) },
    .{ .sel_name = "delay5Min:", .impl = @ptrCast(&delay5Min) },
    .{ .sel_name = "quitApp:", .impl = @ptrCast(&quitApp) },

    // Toggles
    .{ .sel_name = "toggleTimerInMenubar:", .impl = @ptrCast(&toggleTimerInMenubar) },
    .{ .sel_name = "toggleStartAtLogin:", .impl = @ptrCast(&toggleStartAtLogin) },
    .{ .sel_name = "togglePauseDuringMeetings:", .impl = @ptrCast(&togglePauseDuringMeetings) },
    .{ .sel_name = "toggleSmartMeetingDetection:", .impl = @ptrCast(&toggleSmartMeetingDetection) },
    .{ .sel_name = "toggleNotification:", .impl = @ptrCast(&toggleNotification) },
    .{ .sel_name = "toggleGentleMode:", .impl = @ptrCast(&toggleGentleMode) },
    .{ .sel_name = "toggleStrictMode:", .impl = @ptrCast(&toggleStrictMode) },
    .{ .sel_name = "toggleRespectDND:", .impl = @ptrCast(&toggleRespectDND) },
    .{ .sel_name = "toggleScreenLockAsBreak:", .impl = @ptrCast(&toggleScreenLockAsBreak) },

    // Mic check intervals
    .{ .sel_name = "micInterval1:", .impl = @ptrCast(&micInterval1) },
    .{ .sel_name = "micInterval5:", .impl = @ptrCast(&micInterval5) },
    .{ .sel_name = "micInterval10:", .impl = @ptrCast(&micInterval10) },
    .{ .sel_name = "micInterval30:", .impl = @ptrCast(&micInterval30) },

    // Posture reminder
    .{ .sel_name = "togglePostureReminder:", .impl = @ptrCast(&togglePostureReminder) },
    .{ .sel_name = "postureInterval5s:", .impl = @ptrCast(&postureInterval5s) },
    .{ .sel_name = "postureInterval15:", .impl = @ptrCast(&postureInterval15) },
    .{ .sel_name = "postureInterval30:", .impl = @ptrCast(&postureInterval30) },
    .{ .sel_name = "postureInterval45:", .impl = @ptrCast(&postureInterval45) },
    .{ .sel_name = "postureInterval60:", .impl = @ptrCast(&postureInterval60) },

    // Blink reminder
    .{ .sel_name = "toggleBlinkReminder:", .impl = @ptrCast(&toggleBlinkReminder) },
    .{ .sel_name = "blinkInterval5s:", .impl = @ptrCast(&blinkInterval5s) },
    .{ .sel_name = "blinkInterval15:", .impl = @ptrCast(&blinkInterval15) },
    .{ .sel_name = "blinkInterval30:", .impl = @ptrCast(&blinkInterval30) },
    .{ .sel_name = "blinkInterval45:", .impl = @ptrCast(&blinkInterval45) },
    .{ .sel_name = "blinkInterval60:", .impl = @ptrCast(&blinkInterval60) },

    // Hydration reminder
    .{ .sel_name = "toggleHydrationReminder:", .impl = @ptrCast(&toggleHydrationReminder) },
    .{ .sel_name = "hydrationInterval5s:", .impl = @ptrCast(&hydrationInterval5s) },
    .{ .sel_name = "hydrationInterval15:", .impl = @ptrCast(&hydrationInterval15) },
    .{ .sel_name = "hydrationInterval30:", .impl = @ptrCast(&hydrationInterval30) },
    .{ .sel_name = "hydrationInterval45:", .impl = @ptrCast(&hydrationInterval45) },
    .{ .sel_name = "hydrationInterval60:", .impl = @ptrCast(&hydrationInterval60) },

    // Stretch reminder
    .{ .sel_name = "toggleStretchReminder:", .impl = @ptrCast(&toggleStretchReminder) },
    .{ .sel_name = "stretchInterval5s:", .impl = @ptrCast(&stretchInterval5s) },
    .{ .sel_name = "stretchInterval15:", .impl = @ptrCast(&stretchInterval15) },
    .{ .sel_name = "stretchInterval30:", .impl = @ptrCast(&stretchInterval30) },
    .{ .sel_name = "stretchInterval45:", .impl = @ptrCast(&stretchInterval45) },
    .{ .sel_name = "stretchInterval60:", .impl = @ptrCast(&stretchInterval60) },

    // Idle detection
    .{ .sel_name = "idleOff:", .impl = @ptrCast(&idleOff) },
    .{ .sel_name = "idle3min:", .impl = @ptrCast(&idle3min) },
    .{ .sel_name = "idle5min:", .impl = @ptrCast(&idle5min) },
    .{ .sel_name = "idle10min:", .impl = @ptrCast(&idle10min) },

    // Interval presets
    .{ .sel_name = "preset20_20:", .impl = @ptrCast(&preset20_20) },
    .{ .sel_name = "preset30_30:", .impl = @ptrCast(&preset30_30) },
    .{ .sel_name = "preset45_5:", .impl = @ptrCast(&preset45_5) },
    .{ .sel_name = "preset60_5:", .impl = @ptrCast(&preset60_5) },
    .{ .sel_name = "customInterval:", .impl = @ptrCast(&customInterval) },

    // About
    .{ .sel_name = "showAbout:", .impl = @ptrCast(&showAbout) },

    // Sound
    .{ .sel_name = "soundNone:", .impl = @ptrCast(&soundNone) },
    .{ .sel_name = "soundTink:", .impl = @ptrCast(&soundTink) },
    .{ .sel_name = "soundPop:", .impl = @ptrCast(&soundPop) },
    .{ .sel_name = "soundGlass:", .impl = @ptrCast(&soundGlass) },
    .{ .sel_name = "soundPurr:", .impl = @ptrCast(&soundPurr) },
    .{ .sel_name = "soundHero:", .impl = @ptrCast(&soundHero) },

    // Big break
    .{ .sel_name = "toggleBigBreak:", .impl = @ptrCast(&toggleBigBreak) },
    .{ .sel_name = "takeBigBreakNow:", .impl = @ptrCast(&takeBigBreakNow) },
    .{ .sel_name = "bigBreakInterval30m:", .impl = @ptrCast(&bigBreakInterval30m) },
    .{ .sel_name = "bigBreakInterval60m:", .impl = @ptrCast(&bigBreakInterval60m) },
    .{ .sel_name = "bigBreakInterval90m:", .impl = @ptrCast(&bigBreakInterval90m) },
    .{ .sel_name = "bigBreakInterval120m:", .impl = @ptrCast(&bigBreakInterval120m) },
    .{ .sel_name = "bigBreakDuration2m:", .impl = @ptrCast(&bigBreakDuration2m) },
    .{ .sel_name = "bigBreakDuration5m:", .impl = @ptrCast(&bigBreakDuration5m) },
    .{ .sel_name = "bigBreakDuration10m:", .impl = @ptrCast(&bigBreakDuration10m) },
    .{ .sel_name = "bigBreakDuration15m:", .impl = @ptrCast(&bigBreakDuration15m) },

    // Screen lock notifications
    .{ .sel_name = "screenDidLock:", .impl = @ptrCast(&screenDidLock) },
    .{ .sel_name = "screenDidUnlock:", .impl = @ptrCast(&screenDidUnlock) },
};

fn registerAppDelegate() objc.Class {
    const cls = objc.allocateClassPair("NSObject", "EyesAppDelegate");
    if (cls == null) return objc.getClass("EyesAppDelegate");

    for (delegate_methods) |m| {
        if (!objc.addMethod(cls, objc.sel(m.sel_name), m.impl, "v@:@")) {
            std.log.warn("Failed to register method: {s}", .{m.sel_name});
        }
    }

    objc.registerClassPair(cls);
    return cls;
}

fn appDidFinishLaunching(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    // Load saved config before anything else
    app_mod.loadConfig();

    // Request notification permission (non-blocking, needed for notification mode)
    platform.backend.requestNotificationPermission();

    std.log.info("Eyes started \xe2\x80\x94 break every {d} minutes", .{app_mod.state.work_interval_secs / 60});

    // Set up menu bar
    menubar_mod.setup();

    // Register for screen lock/unlock notifications
    if (app_mod.state.screen_lock_as_break) {
        platform.backend.registerScreenLockNotifications();
    }

    // Start the 1-second tick timer
    const delegate = objc.msgSend_id(appkit.sharedApplication(), objc.sel("delegate"));
    _ = foundation.scheduledTimer(1.0, delegate, objc.sel("timerTick:"), true);
}

// --- Thin callconv(.c) wrappers delegating to actions.* ---

// Menu actions
fn togglePause(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    actions.togglePause();
}
fn takeBreakNow(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    actions.takeBreakNow();
}
fn skipBreak(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    actions.skipBreak();
}
fn delay1Min(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    actions.delay1Min();
}
fn delay5Min(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    actions.delay5Min();
}

// macOS-specific actions (stay in main.zig)
fn quitApp(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    appkit.terminate(appkit.sharedApplication());
}

fn toggleStartAtLogin(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    launchagent.setEnabled(!launchagent.isEnabled());
    menubar_mod.markDirty();
    menubar_mod.updateMenu();
}

// Toggles
fn toggleTimerInMenubar(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    actions.toggleTimerInMenubar();
}
fn toggleNotification(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    actions.toggleNotification();
}
fn toggleGentleMode(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    actions.toggleGentleMode();
}
fn toggleStrictMode(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    actions.toggleStrictMode();
}
fn toggleRespectDND(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    actions.toggleRespectDND();
}
fn toggleScreenLockAsBreak(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    actions.toggleScreenLockAsBreak();
}
fn togglePauseDuringMeetings(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    actions.togglePauseDuringMeetings();
}
fn toggleSmartMeetingDetection(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    actions.toggleSmartMeetingDetection();
}

// Mic check intervals
fn micInterval1(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    actions.setMicInterval(1);
}
fn micInterval5(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    actions.setMicInterval(5);
}
fn micInterval10(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    actions.setMicInterval(10);
}
fn micInterval30(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    actions.setMicInterval(30);
}

// Posture reminder callbacks
fn togglePostureReminder(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    actions.togglePostureReminder();
}
fn postureInterval5s(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    actions.setPostureInterval(5);
}
fn postureInterval15(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    actions.setPostureInterval(15 * 60);
}
fn postureInterval30(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    actions.setPostureInterval(30 * 60);
}
fn postureInterval45(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    actions.setPostureInterval(45 * 60);
}
fn postureInterval60(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    actions.setPostureInterval(60 * 60);
}

// Blink reminder callbacks
fn toggleBlinkReminder(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    actions.toggleBlinkReminder();
}
fn blinkInterval5s(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    actions.setBlinkInterval(5);
}
fn blinkInterval15(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    actions.setBlinkInterval(15 * 60);
}
fn blinkInterval30(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    actions.setBlinkInterval(30 * 60);
}
fn blinkInterval45(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    actions.setBlinkInterval(45 * 60);
}
fn blinkInterval60(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    actions.setBlinkInterval(60 * 60);
}

// Hydration reminder callbacks
fn toggleHydrationReminder(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    actions.toggleHydrationReminder();
}
fn hydrationInterval5s(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    actions.setHydrationInterval(5);
}
fn hydrationInterval15(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    actions.setHydrationInterval(15 * 60);
}
fn hydrationInterval30(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    actions.setHydrationInterval(30 * 60);
}
fn hydrationInterval45(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    actions.setHydrationInterval(45 * 60);
}
fn hydrationInterval60(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    actions.setHydrationInterval(60 * 60);
}

// Stretch reminder callbacks
fn toggleStretchReminder(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    actions.toggleStretchReminder();
}
fn stretchInterval5s(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    actions.setStretchInterval(5);
}
fn stretchInterval15(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    actions.setStretchInterval(15 * 60);
}
fn stretchInterval30(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    actions.setStretchInterval(30 * 60);
}
fn stretchInterval45(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    actions.setStretchInterval(45 * 60);
}
fn stretchInterval60(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    actions.setStretchInterval(60 * 60);
}

// Idle detection callbacks
fn idleOff(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    actions.setIdleThreshold(0);
}
fn idle3min(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    actions.setIdleThreshold(3 * 60);
}
fn idle5min(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    actions.setIdleThreshold(5 * 60);
}
fn idle10min(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    actions.setIdleThreshold(10 * 60);
}

// Interval preset callbacks
fn preset20_20(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    actions.applyPreset(20 * 60, 20);
}
fn preset30_30(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    actions.applyPreset(30 * 60, 30);
}
fn preset45_5(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    actions.applyPreset(45 * 60, 5 * 60);
}
fn preset60_5(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    actions.applyPreset(60 * 60, 5 * 60);
}

// Custom interval via NSAlert dialog (macOS-specific)
fn customInterval(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    const alert = appkit.createAlert();
    appkit.setAlertMessageText(alert, "Custom Interval");
    appkit.setAlertInformativeText(alert, "Enter work time (minutes) and break time (seconds):");
    appkit.addAlertButton(alert, "OK");
    appkit.addAlertButton(alert, "Cancel");

    // Create accessory view with two text fields
    const NSView = objc.getClass("NSView");
    const accessory = objc.alloc(NSView);
    const accessory_inited = objc.msgSend_id1(accessory, objc.sel("initWithFrame:"), objc.NSRect{
        .origin = objc.NSPoint{ .x = 0.0, .y = 0.0 },
        .size = objc.NSSize{ .width = 260.0, .height = 54.0 },
    });

    // Work minutes label + field
    const work_label = appkit.createLabel("Work (min):");
    appkit.setFont(work_label, appkit.systemFont(13.0));
    appkit.setViewFrame(work_label, objc.NSRect{
        .origin = objc.NSPoint{ .x = 0.0, .y = 30.0 },
        .size = objc.NSSize{ .width = 80.0, .height = 20.0 },
    });
    appkit.addSubview(accessory_inited, work_label);

    const work_field = appkit.createTextFieldWithFrame(objc.NSRect{
        .origin = objc.NSPoint{ .x = 85.0, .y = 28.0 },
        .size = objc.NSSize{ .width = 60.0, .height = 24.0 },
    });
    // Set default value
    var work_default_buf: [8]u8 = .{0} ** 8;
    _ = std.fmt.bufPrint(&work_default_buf, "{d}", .{app_mod.state.work_interval_secs / 60}) catch {};
    const work_default_str: [*:0]const u8 = @ptrCast(&work_default_buf);
    appkit.setStringValue(work_field, work_default_str);
    appkit.addSubview(accessory_inited, work_field);

    // Break seconds label + field
    const break_label = appkit.createLabel("Break (sec):");
    appkit.setFont(break_label, appkit.systemFont(13.0));
    appkit.setViewFrame(break_label, objc.NSRect{
        .origin = objc.NSPoint{ .x = 0.0, .y = 2.0 },
        .size = objc.NSSize{ .width = 80.0, .height = 20.0 },
    });
    appkit.addSubview(accessory_inited, break_label);

    const break_field = appkit.createTextFieldWithFrame(objc.NSRect{
        .origin = objc.NSPoint{ .x = 85.0, .y = 0.0 },
        .size = objc.NSSize{ .width = 60.0, .height = 24.0 },
    });
    var break_default_buf: [8]u8 = .{0} ** 8;
    _ = std.fmt.bufPrint(&break_default_buf, "{d}", .{app_mod.state.break_duration_secs}) catch {};
    const break_default_str: [*:0]const u8 = @ptrCast(&break_default_buf);
    appkit.setStringValue(break_field, break_default_str);
    appkit.addSubview(accessory_inited, break_field);

    appkit.setAlertAccessoryView(alert, accessory_inited);

    const result = appkit.runModal(alert);
    if (result == appkit.NSAlertFirstButtonReturn) {
        // Read values from text fields
        const work_val = appkit.integerValue(work_field);
        const break_val = appkit.integerValue(break_field);

        if (work_val > 0 and break_val > 0) {
            const work_u32: u32 = @intCast(@max(1, @min(work_val, 180)));
            const break_u32: u32 = @intCast(@max(1, @min(break_val, 3600)));
            actions.applyPreset(work_u32 * 60, break_u32);
        }
    }

    objc.release(alert);
}

// About dialog (macOS-specific)
fn showAbout(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    const alert = appkit.createAlert();
    appkit.setAlertMessageText(alert, "Eyes v0.1.0");
    appkit.setAlertInformativeText(alert, "Break reminder for macOS.\n\nTake regular breaks to protect your eyes.\nFollow the 20-20-20 rule.");
    appkit.addAlertButton(alert, "OK");
    _ = appkit.runModal(alert);
    objc.release(alert);
}

// Big break callbacks
fn toggleBigBreak(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    actions.toggleBigBreak();
}
fn takeBigBreakNow(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    actions.takeBigBreakNow();
}
fn bigBreakInterval30m(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    actions.setBigBreakInterval(30 * 60);
}
fn bigBreakInterval60m(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    actions.setBigBreakInterval(60 * 60);
}
fn bigBreakInterval90m(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    actions.setBigBreakInterval(90 * 60);
}
fn bigBreakInterval120m(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    actions.setBigBreakInterval(120 * 60);
}
fn bigBreakDuration2m(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    actions.setBigBreakDuration(2 * 60);
}
fn bigBreakDuration5m(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    actions.setBigBreakDuration(5 * 60);
}
fn bigBreakDuration10m(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    actions.setBigBreakDuration(10 * 60);
}
fn bigBreakDuration15m(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    actions.setBigBreakDuration(15 * 60);
}

// Sound callbacks
fn soundNone(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    actions.setBreakSound(0);
}
fn soundTink(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    actions.setBreakSound(1);
}
fn soundPop(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    actions.setBreakSound(2);
}
fn soundGlass(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    actions.setBreakSound(3);
}
fn soundPurr(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    actions.setBreakSound(4);
}
fn soundHero(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    actions.setBreakSound(5);
}

// Screen lock/unlock callbacks
fn screenDidLock(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    actions.screenDidLock();
}
fn screenDidUnlock(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    actions.screenDidUnlock();
}

// Fade animation tick callbacks
fn overlayFadeTick(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    platform.backend.overlay.fadeTick();
}
fn postureFadeTick(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    platform.backend.posture.fadeTick();
}
fn blinkFadeTick(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    platform.backend.blink.fadeTick();
}
fn hydrationFadeTick(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    platform.backend.hydration.fadeTick();
}
fn stretchFadeTick(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    platform.backend.stretch.fadeTick();
}
fn gentleFadeTick(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    platform.backend.gentle.fadeTick();
}

pub fn main() !void {
    // Get shared application (NSApplication.run creates its own autorelease pool)
    const NSApp = appkit.sharedApplication();

    // Set as accessory app (no dock icon)
    appkit.setActivationPolicy(NSApp, appkit.NSApplicationActivationPolicyAccessory);

    // Register and create our delegate
    const DelegateClass = registerAppDelegate();
    const delegate = objc.allocInit(DelegateClass);
    appkit.setDelegate(NSApp, delegate);

    // Run the app (blocks until quit)
    appkit.run(NSApp);
}
