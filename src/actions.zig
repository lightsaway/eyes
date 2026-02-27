// Platform-agnostic action handlers.
// Pure state mutation + config save + menu update. No ObjC types, no callconv(.c).

const std = @import("std");
const platform = @import("platform.zig");
const app_mod = @import("app.zig");

const menubar_mod = platform.backend.menubar;

// --- Menu actions ---

pub fn togglePause() void {
    app_mod.state.togglePause();
    menubar_mod.markDirty();
    menubar_mod.updateMenu();
}

pub fn takeBreakNow() void {
    app_mod.state.startBreak();
    menubar_mod.markDirty();
    menubar_mod.updateMenu();
}

pub fn skipBreak() void {
    app_mod.state.endBreak();
    menubar_mod.markDirty();
    menubar_mod.updateMenu();
}

pub fn delay1Min() void {
    app_mod.state.delayBreak(60);
    menubar_mod.markDirty();
    menubar_mod.updateMenu();
}

pub fn delay5Min() void {
    app_mod.state.delayBreak(5 * 60);
    menubar_mod.markDirty();
    menubar_mod.updateMenu();
}

// --- Toggles ---

pub fn toggleTimerInMenubar() void {
    app_mod.state.show_timer_in_menubar = !app_mod.state.show_timer_in_menubar;
    app_mod.saveConfig();
    menubar_mod.markDirty();
    menubar_mod.updateMenu();
}

pub fn toggleNotification() void {
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

pub fn toggleGentleMode() void {
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

pub fn toggleStrictMode() void {
    app_mod.state.strict_mode = !app_mod.state.strict_mode;
    app_mod.saveConfig();
    menubar_mod.markDirty();
    menubar_mod.updateMenu();
}

pub fn toggleRespectDND() void {
    app_mod.state.respect_dnd = !app_mod.state.respect_dnd;
    if (!app_mod.state.respect_dnd) {
        app_mod.state.is_dnd_active = false;
    }
    app_mod.saveConfig();
    menubar_mod.markDirty();
    menubar_mod.updateMenu();
}

pub fn toggleScreenLockAsBreak() void {
    app_mod.state.screen_lock_as_break = !app_mod.state.screen_lock_as_break;
    if (app_mod.state.screen_lock_as_break) {
        platform.backend.registerScreenLockNotifications();
    }
    app_mod.saveConfig();
    menubar_mod.markDirty();
    menubar_mod.updateMenu();
}

pub fn togglePauseDuringMeetings() void {
    app_mod.state.pause_during_meetings = !app_mod.state.pause_during_meetings;
    if (!app_mod.state.pause_during_meetings and !app_mod.state.smart_meeting_detection) {
        app_mod.state.meeting_paused = false;
    }
    app_mod.saveConfig();
    menubar_mod.markDirty();
    menubar_mod.updateMenu();
}

pub fn toggleSmartMeetingDetection() void {
    app_mod.state.smart_meeting_detection = !app_mod.state.smart_meeting_detection;
    if (!app_mod.state.smart_meeting_detection and !app_mod.state.pause_during_meetings) {
        app_mod.state.meeting_paused = false;
    }
    app_mod.saveConfig();
    menubar_mod.markDirty();
    menubar_mod.updateMenu();
}

// --- Reminder toggles ---

pub fn togglePostureReminder() void {
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

pub fn toggleBlinkReminder() void {
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

pub fn toggleHydrationReminder() void {
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

pub fn toggleStretchReminder() void {
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

// --- Interval setters ---

pub fn setMicInterval(secs: u32) void {
    app_mod.state.mic_check_interval_secs = secs;
    app_mod.state.mic_check_counter = 0;
    app_mod.saveConfig();
    menubar_mod.markDirty();
    menubar_mod.updateMenu();
}

pub fn setPostureInterval(secs: u32) void {
    app_mod.state.posture_interval_secs = secs;
    app_mod.state.seconds_until_posture = @intCast(secs);
    app_mod.saveConfig();
    menubar_mod.markDirty();
    menubar_mod.updateMenu();
}

pub fn setBlinkInterval(secs: u32) void {
    app_mod.state.blink_interval_secs = secs;
    app_mod.state.seconds_until_blink = @intCast(secs);
    app_mod.saveConfig();
    menubar_mod.markDirty();
    menubar_mod.updateMenu();
}

pub fn setHydrationInterval(secs: u32) void {
    app_mod.state.hydration_interval_secs = secs;
    app_mod.state.seconds_until_hydration = @intCast(secs);
    app_mod.saveConfig();
    menubar_mod.markDirty();
    menubar_mod.updateMenu();
}

pub fn setStretchInterval(secs: u32) void {
    app_mod.state.stretch_interval_secs = secs;
    app_mod.state.seconds_until_stretch = @intCast(secs);
    app_mod.saveConfig();
    menubar_mod.markDirty();
    menubar_mod.updateMenu();
}

pub fn setIdleThreshold(secs: u32) void {
    app_mod.state.idle_threshold_secs = secs;
    app_mod.state.is_idle = false;
    app_mod.saveConfig();
    menubar_mod.markDirty();
    menubar_mod.updateMenu();
}

// --- Big Break ---

pub fn toggleBigBreak() void {
    app_mod.state.big_break_enabled = !app_mod.state.big_break_enabled;
    if (app_mod.state.big_break_enabled) {
        app_mod.state.seconds_until_big_break = @intCast(app_mod.state.big_break_interval_secs);
    }
    app_mod.state.is_big_break = false;
    app_mod.saveConfig();
    menubar_mod.markDirty();
    menubar_mod.updateMenu();
}

pub fn setBigBreakInterval(secs: u32) void {
    app_mod.state.big_break_interval_secs = secs;
    app_mod.state.seconds_until_big_break = @intCast(secs);
    app_mod.saveConfig();
    menubar_mod.markDirty();
    menubar_mod.updateMenu();
}

pub fn takeBigBreakNow() void {
    app_mod.state.is_big_break = true;
    app_mod.state.seconds_until_big_break = @intCast(app_mod.state.big_break_interval_secs);
    app_mod.state.startBreak();
    menubar_mod.markDirty();
    menubar_mod.updateMenu();
}

pub fn setBigBreakDuration(secs: u32) void {
    app_mod.state.big_break_duration_secs = secs;
    app_mod.saveConfig();
    menubar_mod.markDirty();
    menubar_mod.updateMenu();
}

// --- Presets ---

pub fn applyPreset(work_secs: u32, brk_secs: u32) void {
    app_mod.applyConfig(.{
        .work_interval_secs = work_secs,
        .break_duration_secs = brk_secs,
        .show_timer_in_menubar = app_mod.state.show_timer_in_menubar,
        .pause_during_meetings = app_mod.state.pause_during_meetings,
        .smart_meeting_detection = app_mod.state.smart_meeting_detection,
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
        .show_test_settings = app_mod.state.show_test_settings,
        .big_break_enabled = app_mod.state.big_break_enabled,
        .big_break_interval_secs = app_mod.state.big_break_interval_secs,
        .big_break_duration_secs = app_mod.state.big_break_duration_secs,
    });
    menubar_mod.markDirty();
    menubar_mod.updateMenu();
}

// --- Sound ---

pub fn setBreakSound(val: u8) void {
    app_mod.state.break_sound = val;
    app_mod.saveConfig();
    menubar_mod.markDirty();
    menubar_mod.updateMenu();
}

// --- Screen lock/unlock ---

pub fn screenDidLock() void {
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

pub fn screenDidUnlock() void {
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
