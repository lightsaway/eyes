// Eyes — Break reminder app.
// Entry point: sets up the platform-specific event loop and starts the app.

const std = @import("std");
const platform = @import("platform.zig");
const app_mod = @import("app.zig");

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
        registerScreenLockNotifications();
    }

    // Start the 1-second tick timer
    const delegate = objc.msgSend_id(appkit.sharedApplication(), objc.sel("delegate"));
    _ = foundation.scheduledTimer(1.0, delegate, objc.sel("timerTick:"), true);
}

fn registerScreenLockNotifications() void {
    const center = appkit.distributedNotificationCenter();
    const delegate = objc.msgSend_id(appkit.sharedApplication(), objc.sel("delegate"));
    appkit.addObserver(center, delegate, objc.sel("screenDidLock:"), "com.apple.screenIsLocked");
    appkit.addObserver(center, delegate, objc.sel("screenDidUnlock:"), "com.apple.screenIsUnlocked");
    std.log.info("Registered for screen lock/unlock notifications", .{});
}

fn togglePause(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    app_mod.state.togglePause();
    menubar_mod.markDirty();
    menubar_mod.updateMenu();
}

fn takeBreakNow(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    app_mod.state.startBreak();
    menubar_mod.markDirty();
    menubar_mod.updateMenu();
}

fn skipBreak(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    app_mod.state.endBreak();
    menubar_mod.markDirty();
    menubar_mod.updateMenu();
}

fn delay1Min(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    app_mod.state.delayBreak(60);
    menubar_mod.markDirty();
    menubar_mod.updateMenu();
}

fn delay5Min(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    app_mod.state.delayBreak(5 * 60);
    menubar_mod.markDirty();
    menubar_mod.updateMenu();
}

fn quitApp(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    appkit.terminate(appkit.sharedApplication());
}

fn toggleTimerInMenubar(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    app_mod.state.show_timer_in_menubar = !app_mod.state.show_timer_in_menubar;
    app_mod.saveConfig();
    menubar_mod.markDirty();
    menubar_mod.updateMenu();
}

fn toggleStartAtLogin(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    launchagent.setEnabled(!launchagent.isEnabled());
    menubar_mod.markDirty();
    menubar_mod.updateMenu();
}

fn toggleNotification(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    const was_notification = app_mod.state.use_notification;
    const was_gentle = app_mod.state.gentle_mode;
    app_mod.state.use_notification = !app_mod.state.use_notification;
    if (app_mod.state.use_notification) {
        // Disable gentle mode if enabling notification mode
        app_mod.state.gentle_mode = false;
        // Hide any active break UI from the mode we're leaving
        if (app_mod.state.is_on_break) {
            if (was_gentle) {
                platform.backend.gentle.hideGentleBanner();
            } else if (!was_notification) {
                platform.backend.overlay.hideOverlay();
            }
        }
    } else if (was_notification and app_mod.state.is_on_break) {
        // Notification mode has no persistent UI to dismiss, but end the break
        // so the user isn't stuck in an invisible break state
        app_mod.state.endBreak();
    }
    app_mod.saveConfig();
    menubar_mod.markDirty();
    menubar_mod.updateMenu();
}

fn toggleGentleMode(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    const was_gentle = app_mod.state.gentle_mode;
    app_mod.state.gentle_mode = !app_mod.state.gentle_mode;
    if (app_mod.state.gentle_mode) {
        // Disable notification mode if enabling gentle mode
        app_mod.state.use_notification = false;
    } else if (was_gentle and app_mod.state.is_on_break) {
        // Hiding the gentle banner since we're switching away from gentle mode mid-break
        platform.backend.gentle.hideGentleBanner();
    }
    app_mod.saveConfig();
    menubar_mod.markDirty();
    menubar_mod.updateMenu();
}

fn toggleStrictMode(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    app_mod.state.strict_mode = !app_mod.state.strict_mode;
    app_mod.saveConfig();
    menubar_mod.markDirty();
    menubar_mod.updateMenu();
}

fn toggleRespectDND(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    app_mod.state.respect_dnd = !app_mod.state.respect_dnd;
    if (!app_mod.state.respect_dnd) {
        app_mod.state.is_dnd_active = false;
    }
    app_mod.saveConfig();
    menubar_mod.markDirty();
    menubar_mod.updateMenu();
}

fn toggleScreenLockAsBreak(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    app_mod.state.screen_lock_as_break = !app_mod.state.screen_lock_as_break;
    if (app_mod.state.screen_lock_as_break) {
        registerScreenLockNotifications();
    }
    app_mod.saveConfig();
    menubar_mod.markDirty();
    menubar_mod.updateMenu();
}

fn setMicInterval(secs: u32) void {
    app_mod.state.mic_check_interval_secs = secs;
    app_mod.state.mic_check_counter = 0;
    app_mod.saveConfig();
    menubar_mod.markDirty();
    menubar_mod.updateMenu();
}

fn micInterval1(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    setMicInterval(1);
}
fn micInterval5(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    setMicInterval(5);
}
fn micInterval10(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    setMicInterval(10);
}
fn micInterval30(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    setMicInterval(30);
}

fn togglePauseDuringMeetings(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    app_mod.state.pause_during_meetings = !app_mod.state.pause_during_meetings;
    if (!app_mod.state.pause_during_meetings) {
        app_mod.state.meeting_paused = false;
    }
    app_mod.saveConfig();
    menubar_mod.markDirty();
    menubar_mod.updateMenu();
}

// Posture reminder callbacks
fn togglePostureReminder(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    app_mod.state.posture_reminder_enabled = !app_mod.state.posture_reminder_enabled;
    if (app_mod.state.posture_reminder_enabled) {
        app_mod.state.seconds_until_posture = @intCast(app_mod.state.posture_interval_secs);
    } else {
        if (app_mod.state.is_posture_showing) {
            platform.backend.posture.hidePostureReminder();
            app_mod.state.is_posture_showing = false;
        }
    }
    app_mod.saveConfig();
    menubar_mod.markDirty();
    menubar_mod.updateMenu();
}

fn setPostureInterval(secs: u32) void {
    app_mod.state.posture_interval_secs = secs;
    app_mod.state.seconds_until_posture = @intCast(secs);
    app_mod.saveConfig();
    menubar_mod.markDirty();
    menubar_mod.updateMenu();
}

fn postureInterval5s(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    setPostureInterval(5);
}
fn postureInterval15(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    setPostureInterval(15 * 60);
}
fn postureInterval30(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    setPostureInterval(30 * 60);
}
fn postureInterval45(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    setPostureInterval(45 * 60);
}
fn postureInterval60(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    setPostureInterval(60 * 60);
}

// Blink reminder callbacks
fn toggleBlinkReminder(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    app_mod.state.blink_reminder_enabled = !app_mod.state.blink_reminder_enabled;
    if (app_mod.state.blink_reminder_enabled) {
        app_mod.state.seconds_until_blink = @intCast(app_mod.state.blink_interval_secs);
    } else {
        if (app_mod.state.is_blink_showing) {
            platform.backend.blink.hideBlinkReminder();
            app_mod.state.is_blink_showing = false;
        }
    }
    app_mod.saveConfig();
    menubar_mod.markDirty();
    menubar_mod.updateMenu();
}

fn setBlinkInterval(secs: u32) void {
    app_mod.state.blink_interval_secs = secs;
    app_mod.state.seconds_until_blink = @intCast(secs);
    app_mod.saveConfig();
    menubar_mod.markDirty();
    menubar_mod.updateMenu();
}

fn blinkInterval5s(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    setBlinkInterval(5);
}
fn blinkInterval15(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    setBlinkInterval(15 * 60);
}
fn blinkInterval30(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    setBlinkInterval(30 * 60);
}
fn blinkInterval45(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    setBlinkInterval(45 * 60);
}
fn blinkInterval60(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    setBlinkInterval(60 * 60);
}

// Hydration reminder callbacks
fn toggleHydrationReminder(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    app_mod.state.hydration_reminder_enabled = !app_mod.state.hydration_reminder_enabled;
    if (app_mod.state.hydration_reminder_enabled) {
        app_mod.state.seconds_until_hydration = @intCast(app_mod.state.hydration_interval_secs);
    } else {
        if (app_mod.state.is_hydration_showing) {
            platform.backend.hydration.hideHydrationReminder();
            app_mod.state.is_hydration_showing = false;
        }
    }
    app_mod.saveConfig();
    menubar_mod.markDirty();
    menubar_mod.updateMenu();
}

fn setHydrationInterval(secs: u32) void {
    app_mod.state.hydration_interval_secs = secs;
    app_mod.state.seconds_until_hydration = @intCast(secs);
    app_mod.saveConfig();
    menubar_mod.markDirty();
    menubar_mod.updateMenu();
}

fn hydrationInterval5s(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    setHydrationInterval(5);
}
fn hydrationInterval15(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    setHydrationInterval(15 * 60);
}
fn hydrationInterval30(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    setHydrationInterval(30 * 60);
}
fn hydrationInterval45(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    setHydrationInterval(45 * 60);
}
fn hydrationInterval60(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    setHydrationInterval(60 * 60);
}

// Stretch reminder callbacks
fn toggleStretchReminder(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    app_mod.state.stretch_reminder_enabled = !app_mod.state.stretch_reminder_enabled;
    if (app_mod.state.stretch_reminder_enabled) {
        app_mod.state.seconds_until_stretch = @intCast(app_mod.state.stretch_interval_secs);
    } else {
        if (app_mod.state.is_stretch_showing) {
            platform.backend.stretch.hideStretchReminder();
            app_mod.state.is_stretch_showing = false;
        }
    }
    app_mod.saveConfig();
    menubar_mod.markDirty();
    menubar_mod.updateMenu();
}

fn setStretchInterval(secs: u32) void {
    app_mod.state.stretch_interval_secs = secs;
    app_mod.state.seconds_until_stretch = @intCast(secs);
    app_mod.saveConfig();
    menubar_mod.markDirty();
    menubar_mod.updateMenu();
}

fn stretchInterval5s(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    setStretchInterval(5);
}
fn stretchInterval15(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    setStretchInterval(15 * 60);
}
fn stretchInterval30(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    setStretchInterval(30 * 60);
}
fn stretchInterval45(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    setStretchInterval(45 * 60);
}
fn stretchInterval60(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    setStretchInterval(60 * 60);
}

// Idle detection callbacks
fn setIdleThreshold(secs: u32) void {
    app_mod.state.idle_threshold_secs = secs;
    app_mod.state.is_idle = false;
    app_mod.saveConfig();
    menubar_mod.markDirty();
    menubar_mod.updateMenu();
}

fn idleOff(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    setIdleThreshold(0);
}
fn idle3min(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    setIdleThreshold(3 * 60);
}
fn idle5min(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    setIdleThreshold(5 * 60);
}
fn idle10min(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    setIdleThreshold(10 * 60);
}

// Interval preset callbacks
fn applyPreset(work_secs: u32, brk_secs: u32) void {
    app_mod.applyConfig(.{
        .work_interval_secs = work_secs,
        .break_duration_secs = brk_secs,
        .show_timer_in_menubar = app_mod.state.show_timer_in_menubar,
        .pause_during_meetings = app_mod.state.pause_during_meetings,
        .mic_check_interval_secs = app_mod.state.mic_check_interval_secs,
        .posture_reminder_enabled = app_mod.state.posture_reminder_enabled,
        .posture_interval_secs = app_mod.state.posture_interval_secs,
        .blink_reminder_enabled = app_mod.state.blink_reminder_enabled,
        .blink_interval_secs = app_mod.state.blink_interval_secs,
        .idle_threshold_secs = app_mod.state.idle_threshold_secs,
        .hydration_reminder_enabled = app_mod.state.hydration_reminder_enabled,
        .hydration_interval_secs = app_mod.state.hydration_interval_secs,
        .stretch_reminder_enabled = app_mod.state.stretch_reminder_enabled,
        .stretch_interval_secs = app_mod.state.stretch_interval_secs,
        .break_sound = app_mod.state.break_sound,
        .respect_dnd = app_mod.state.respect_dnd,
        .screen_lock_as_break = app_mod.state.screen_lock_as_break,
        .use_notification = app_mod.state.use_notification,
        .gentle_mode = app_mod.state.gentle_mode,
        .strict_mode = app_mod.state.strict_mode,
        .hotkey_break = app_mod.state.hotkey_break,
        .hotkey_pause = app_mod.state.hotkey_pause,
        .stretch_gif = app_mod.state.stretch_gif,
    });
    menubar_mod.markDirty();
    menubar_mod.updateMenu();
}

fn preset20_20(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    applyPreset(20 * 60, 20);
}

fn preset30_30(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    applyPreset(30 * 60, 30);
}

fn preset45_5(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    applyPreset(45 * 60, 5 * 60);
}

fn preset60_5(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    applyPreset(60 * 60, 5 * 60);
}

// Custom interval via NSAlert dialog
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
            applyPreset(work_u32 * 60, break_u32);
        }
    }

    objc.release(alert);
}

// About dialog
fn showAbout(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    const alert = appkit.createAlert();
    appkit.setAlertMessageText(alert, "Eyes v0.1.0");
    appkit.setAlertInformativeText(alert, "Break reminder for macOS.\n\nTake regular breaks to protect your eyes.\nFollow the 20-20-20 rule.");
    appkit.addAlertButton(alert, "OK");
    _ = appkit.runModal(alert);
    objc.release(alert);
}

// Sound callbacks
fn setBreakSound(val: u8) void {
    app_mod.state.break_sound = val;
    app_mod.saveConfig();
    menubar_mod.markDirty();
    menubar_mod.updateMenu();
}

fn soundNone(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    setBreakSound(0);
}
fn soundTink(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    setBreakSound(1);
}
fn soundPop(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    setBreakSound(2);
}
fn soundGlass(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    setBreakSound(3);
}
fn soundPurr(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    setBreakSound(4);
}
fn soundHero(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    setBreakSound(5);
}

// Screen lock/unlock callbacks
fn screenDidLock(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    if (!app_mod.state.screen_lock_as_break) return;

    std.log.info("Screen locked", .{});
    app_mod.state.screen_locked = true;
    app_mod.state.lock_start_timestamp = std.time.timestamp();

    // End active break if showing
    if (app_mod.state.is_on_break) {
        app_mod.state.endBreak();
    }
    menubar_mod.markDirty();
}

fn screenDidUnlock(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    if (!app_mod.state.screen_lock_as_break) return;

    std.log.info("Screen unlocked", .{});
    app_mod.state.screen_locked = false;

    if (app_mod.state.lock_start_timestamp > 0) {
        const locked_duration = std.time.timestamp() - app_mod.state.lock_start_timestamp;
        const break_duration: i64 = @intCast(app_mod.state.break_duration_secs);
        if (locked_duration >= break_duration) {
            // Count as a completed break
            app_mod.state.breaks_taken += 1;
            app_mod.state.seconds_until_break = @intCast(app_mod.state.work_interval_secs);
            std.log.info("Screen was locked for {d}s >= {d}s break \xe2\x80\x94 counted as break", .{ locked_duration, break_duration });
        }
        app_mod.state.lock_start_timestamp = 0;
    }
    menubar_mod.markDirty();
    menubar_mod.updateMenu();
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
