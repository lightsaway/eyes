// Eyes — Break reminder for macOS.
// Entry point: sets up NSApplication as a menu bar app and starts the run loop.

const std = @import("std");
const objc = @import("macos/objc.zig");
const appkit = @import("macos/appkit.zig");
const foundation = @import("macos/foundation.zig");
const app_mod = @import("app.zig");
const menubar_mod = @import("menubar.zig");
const launchagent = @import("launchagent.zig");


fn registerAppDelegate() objc.Class {
    const cls = objc.allocateClassPair("NSObject", "EyesAppDelegate");
    if (cls == null) return objc.getClass("EyesAppDelegate");

    // applicationDidFinishLaunching:
    _ = objc.addMethod(cls, objc.sel("applicationDidFinishLaunching:"), @ptrCast(&appDidFinishLaunching), "v@:@");

    // Timer tick
    _ = objc.addMethod(cls, objc.sel("timerTick:"), @ptrCast(&app_mod.timerCallback), "v@:@");

    // Menu actions
    _ = objc.addMethod(cls, objc.sel("togglePause:"), @ptrCast(&togglePause), "v@:@");
    _ = objc.addMethod(cls, objc.sel("takeBreakNow:"), @ptrCast(&takeBreakNow), "v@:@");
    _ = objc.addMethod(cls, objc.sel("skipBreak:"), @ptrCast(&skipBreak), "v@:@");
    _ = objc.addMethod(cls, objc.sel("delay1Min:"), @ptrCast(&delay1Min), "v@:@");
    _ = objc.addMethod(cls, objc.sel("delay5Min:"), @ptrCast(&delay5Min), "v@:@");
    _ = objc.addMethod(cls, objc.sel("quitApp:"), @ptrCast(&quitApp), "v@:@");

    // Toggle timer display
    _ = objc.addMethod(cls, objc.sel("toggleTimerInMenubar:"), @ptrCast(&toggleTimerInMenubar), "v@:@");

    // Toggle start at login
    _ = objc.addMethod(cls, objc.sel("toggleStartAtLogin:"), @ptrCast(&toggleStartAtLogin), "v@:@");

    // Toggle pause during meetings
    _ = objc.addMethod(cls, objc.sel("togglePauseDuringMeetings:"), @ptrCast(&togglePauseDuringMeetings), "v@:@");

    // Mic check interval presets
    _ = objc.addMethod(cls, objc.sel("micInterval1:"), @ptrCast(&micInterval1), "v@:@");
    _ = objc.addMethod(cls, objc.sel("micInterval5:"), @ptrCast(&micInterval5), "v@:@");
    _ = objc.addMethod(cls, objc.sel("micInterval10:"), @ptrCast(&micInterval10), "v@:@");
    _ = objc.addMethod(cls, objc.sel("micInterval30:"), @ptrCast(&micInterval30), "v@:@");

    // Posture reminder
    _ = objc.addMethod(cls, objc.sel("postureInterval5s:"), @ptrCast(&postureInterval5s), "v@:@");
    _ = objc.addMethod(cls, objc.sel("togglePostureReminder:"), @ptrCast(&togglePostureReminder), "v@:@");
    _ = objc.addMethod(cls, objc.sel("postureInterval15:"), @ptrCast(&postureInterval15), "v@:@");
    _ = objc.addMethod(cls, objc.sel("postureInterval30:"), @ptrCast(&postureInterval30), "v@:@");
    _ = objc.addMethod(cls, objc.sel("postureInterval45:"), @ptrCast(&postureInterval45), "v@:@");
    _ = objc.addMethod(cls, objc.sel("postureInterval60:"), @ptrCast(&postureInterval60), "v@:@");

    // Blink reminder
    _ = objc.addMethod(cls, objc.sel("toggleBlinkReminder:"), @ptrCast(&toggleBlinkReminder), "v@:@");
    _ = objc.addMethod(cls, objc.sel("blinkInterval5s:"), @ptrCast(&blinkInterval5s), "v@:@");
    _ = objc.addMethod(cls, objc.sel("blinkInterval15:"), @ptrCast(&blinkInterval15), "v@:@");
    _ = objc.addMethod(cls, objc.sel("blinkInterval30:"), @ptrCast(&blinkInterval30), "v@:@");
    _ = objc.addMethod(cls, objc.sel("blinkInterval45:"), @ptrCast(&blinkInterval45), "v@:@");
    _ = objc.addMethod(cls, objc.sel("blinkInterval60:"), @ptrCast(&blinkInterval60), "v@:@");

    // Interval presets
    _ = objc.addMethod(cls, objc.sel("preset20_20:"), @ptrCast(&preset20_20), "v@:@");
    _ = objc.addMethod(cls, objc.sel("preset30_30:"), @ptrCast(&preset30_30), "v@:@");
    _ = objc.addMethod(cls, objc.sel("preset45_5:"), @ptrCast(&preset45_5), "v@:@");
    _ = objc.addMethod(cls, objc.sel("preset60_5:"), @ptrCast(&preset60_5), "v@:@");

    objc.registerClassPair(cls);
    return cls;
}

fn appDidFinishLaunching(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    // Load saved config before anything else
    app_mod.loadConfig();

    std.log.info("Eyes started — break every {d} minutes", .{app_mod.state.work_interval_secs / 60});

    // Set up menu bar
    menubar_mod.setup();

    // Start the 1-second tick timer
    const delegate = objc.msgSend_id(appkit.sharedApplication(), objc.sel("delegate"));
    _ = foundation.scheduledTimer(1.0, delegate, objc.sel("timerTick:"), true);
}

fn togglePause(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    app_mod.state.togglePause();
    menubar_mod.updateMenu();
}

fn takeBreakNow(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    app_mod.state.startBreak();
    menubar_mod.updateMenu();
}

fn skipBreak(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    app_mod.state.endBreak();
    menubar_mod.updateMenu();
}

fn delay1Min(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    app_mod.state.delayBreak(60);
    menubar_mod.updateMenu();
}

fn delay5Min(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    app_mod.state.delayBreak(5 * 60);
    menubar_mod.updateMenu();
}

fn quitApp(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    appkit.terminate(appkit.sharedApplication());
}

fn toggleTimerInMenubar(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    app_mod.state.show_timer_in_menubar = !app_mod.state.show_timer_in_menubar;
    app_mod.saveConfig();
    menubar_mod.updateMenu();
}

fn toggleStartAtLogin(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    launchagent.setEnabled(!launchagent.isEnabled());
    menubar_mod.updateMenu();
}

fn setMicInterval(secs: u32) void {
    app_mod.state.mic_check_interval_secs = secs;
    app_mod.state.mic_check_counter = 0;
    app_mod.saveConfig();
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
    menubar_mod.updateMenu();
}

// Posture reminder callbacks
fn togglePostureReminder(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    app_mod.state.posture_reminder_enabled = !app_mod.state.posture_reminder_enabled;
    std.log.info("Posture toggle: enabled={}, interval={d}s", .{ app_mod.state.posture_reminder_enabled, app_mod.state.posture_interval_secs });
    if (app_mod.state.posture_reminder_enabled) {
        app_mod.state.seconds_until_posture = @intCast(app_mod.state.posture_interval_secs);
    } else {
        // Dismiss if currently showing
        if (app_mod.state.is_posture_showing) {
            const posture = @import("posture.zig");
            posture.hidePostureReminder();
            app_mod.state.is_posture_showing = false;
        }
    }
    app_mod.saveConfig();
    menubar_mod.updateMenu();
}

fn setPostureInterval(secs: u32) void {
    std.log.info("Posture interval set: {d}s", .{secs});
    app_mod.state.posture_interval_secs = secs;
    app_mod.state.seconds_until_posture = @intCast(secs);
    app_mod.saveConfig();
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
    std.log.info("Blink toggle: enabled={}, interval={d}s", .{ app_mod.state.blink_reminder_enabled, app_mod.state.blink_interval_secs });
    if (app_mod.state.blink_reminder_enabled) {
        app_mod.state.seconds_until_blink = @intCast(app_mod.state.blink_interval_secs);
    } else {
        if (app_mod.state.is_blink_showing) {
            const blink_mod = @import("blink.zig");
            blink_mod.hideBlinkReminder();
            app_mod.state.is_blink_showing = false;
        }
    }
    app_mod.saveConfig();
    menubar_mod.updateMenu();
}

fn setBlinkInterval(secs: u32) void {
    std.log.info("Blink interval set: {d}s", .{secs});
    app_mod.state.blink_interval_secs = secs;
    app_mod.state.seconds_until_blink = @intCast(secs);
    app_mod.saveConfig();
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

// Interval preset callbacks
fn applyPreset(work: u32, brk: u32) void {
    app_mod.applyConfig(.{
        .work_interval_secs = work,
        .break_duration_secs = brk,
        .show_timer_in_menubar = app_mod.state.show_timer_in_menubar,
        .pause_during_meetings = app_mod.state.pause_during_meetings,
        .mic_check_interval_secs = app_mod.state.mic_check_interval_secs,
        .posture_reminder_enabled = app_mod.state.posture_reminder_enabled,
        .posture_interval_secs = app_mod.state.posture_interval_secs,
        .blink_reminder_enabled = app_mod.state.blink_reminder_enabled,
        .blink_interval_secs = app_mod.state.blink_interval_secs,
    });
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

pub fn main() !void {
    // Create autorelease pool
    _ = foundation.createAutoreleasePool();

    // Get shared application
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
