// App state and break timer logic.

const std = @import("std");
const platform = @import("platform.zig");
const config = @import("config.zig");

const overlay = platform.backend.overlay;
const gentle = platform.backend.gentle;
const posture = platform.backend.posture;
const blink = platform.backend.blink;
const hydration = platform.backend.hydration;
const stretch = platform.backend.stretch;
const menubar = platform.backend.menubar;

pub const AppState = struct {
    // Configuration
    work_interval_secs: u32 = 20 * 60, // 20 minutes
    break_duration_secs: u32 = 20, // 20 seconds
    show_timer_in_menubar: bool = true,

    // Runtime state
    seconds_until_break: i32 = 20 * 60,
    break_seconds_remaining: i32 = 0,
    is_on_break: bool = false,
    is_paused: bool = false,
    meeting_paused: bool = false,
    pause_during_meetings: bool = false,
    mic_check_interval_secs: u32 = 5,
    mic_check_counter: u32 = 0,
    last_mic_active: bool = false,

    // Posture reminder
    posture_reminder_enabled: bool = false,
    posture_interval_secs: u32 = 30 * 60,
    posture_duration_secs: u32 = 5,
    seconds_until_posture: i32 = 30 * 60,
    posture_seconds_remaining: i32 = 0,
    is_posture_showing: bool = false,
    posture_tick: u32 = 0,

    // Idle detection
    idle_threshold_secs: u32 = 5 * 60,
    is_idle: bool = false,

    // Blink reminder
    blink_reminder_enabled: bool = false,
    blink_interval_secs: u32 = 30 * 60,
    blink_duration_secs: u32 = 5,
    seconds_until_blink: i32 = 30 * 60,
    blink_seconds_remaining: i32 = 0,
    is_blink_showing: bool = false,
    blink_tick: u32 = 0,

    // Hydration reminder
    hydration_reminder_enabled: bool = false,
    hydration_interval_secs: u32 = 45 * 60,
    hydration_duration_secs: u32 = 5,
    seconds_until_hydration: i32 = 45 * 60,
    hydration_seconds_remaining: i32 = 0,
    is_hydration_showing: bool = false,
    hydration_tick: u32 = 0,

    // Stretch reminder
    stretch_reminder_enabled: bool = false,
    stretch_interval_secs: u32 = 30 * 60,
    stretch_duration_secs: u32 = 5,
    seconds_until_stretch: i32 = 30 * 60,
    stretch_seconds_remaining: i32 = 0,
    is_stretch_showing: bool = false,
    stretch_tick: u32 = 0,

    // Sound
    break_sound: u8 = 1,

    // Do Not Disturb
    respect_dnd: bool = true,
    is_dnd_active: bool = false,
    dnd_check_counter: u32 = 0,

    // Screen lock as break
    screen_lock_as_break: bool = true,
    screen_locked: bool = false,
    lock_start_timestamp: i64 = 0,

    // Notification mode
    use_notification: bool = false,

    // Gentle mode
    gentle_mode: bool = false,

    // Strict mode
    strict_mode: bool = false,

    // Hotkeys
    hotkey_break: u8 = 'e',
    hotkey_pause: u8 = 'p',

    // GIF filenames (null-terminated, empty = disabled)
    posture_gif: [64]u8 = .{0} ** 64,
    blink_gif: [64]u8 = .{0} ** 64,
    hydration_gif: [64]u8 = .{0} ** 64,
    stretch_gif: [64]u8 = .{0} ** 64,

    // Statistics (daily, in-memory)
    breaks_taken: u32 = 0,
    breaks_skipped: u32 = 0,
    breaks_delayed: u32 = 0,
    stats_day: i64 = 0,

    pub fn reset(self: *AppState) void {
        self.seconds_until_break = @intCast(self.work_interval_secs);
        self.is_on_break = false;
        self.break_seconds_remaining = 0;
    }

    pub fn startBreak(self: *AppState) void {
        self.is_on_break = true;
        self.break_seconds_remaining = @intCast(self.break_duration_secs);
        if (self.use_notification) {
            platform.backend.deliverNotification("Eyes \xe2\x80\x94 Break Time", "Look at something 20 feet away");
        } else if (self.gentle_mode) {
            gentle.showGentleBanner(self);
        } else {
            overlay.showOverlay(self);
        }
    }

    pub fn endBreak(self: *AppState) void {
        if (self.is_on_break and self.break_seconds_remaining > 0) {
            self.breaks_skipped += 1;
        }
        self.is_on_break = false;
        self.break_seconds_remaining = 0;
        self.seconds_until_break = @intCast(self.work_interval_secs);
        if (!self.use_notification) {
            if (self.gentle_mode) {
                gentle.hideGentleBanner();
            } else {
                overlay.hideOverlay();
            }
        }
    }

    pub fn delayBreak(self: *AppState, extra_secs: i32) void {
        self.breaks_delayed += 1;
        if (self.is_on_break) {
            // Don't count as skipped when delaying
            self.is_on_break = false;
            self.break_seconds_remaining = 0;
            if (!self.use_notification) {
                if (self.gentle_mode) {
                    gentle.hideGentleBanner();
                } else {
                    overlay.hideOverlay();
                }
            }
        }
        self.seconds_until_break = extra_secs;
    }

    pub fn toggleBreak(self: *AppState) void {
        if (self.is_on_break) {
            self.endBreak();
        } else {
            self.startBreak();
        }
    }

    pub fn togglePause(self: *AppState) void {
        self.is_paused = !self.is_paused;
    }

    pub fn formatTimeUntilBreak(self: *const AppState) [16]u8 {
        var buf: [16]u8 = .{0} ** 16;
        const secs: u32 = if (self.seconds_until_break < 0) 0 else @intCast(self.seconds_until_break);
        const mins = secs / 60;
        const s = secs % 60;
        _ = std.fmt.bufPrint(&buf, "{d:0>2}:{d:0>2}", .{ mins, s }) catch {};
        return buf;
    }

    pub fn formatBreakRemaining(self: *const AppState) [16]u8 {
        var buf: [16]u8 = .{0} ** 16;
        const secs: u32 = if (self.break_seconds_remaining < 0) 0 else @intCast(self.break_seconds_remaining);
        _ = std.fmt.bufPrint(&buf, "{d}", .{secs}) catch {};
        return buf;
    }
};

// Global state
pub var state = AppState{};

/// Apply a config to the running state and save it to disk.
pub fn applyConfig(cfg: config.Config) void {
    state.work_interval_secs = cfg.work_interval_secs;
    state.break_duration_secs = cfg.break_duration_secs;
    state.show_timer_in_menubar = cfg.show_timer_in_menubar;
    state.pause_during_meetings = cfg.pause_during_meetings;
    state.mic_check_interval_secs = cfg.mic_check_interval_secs;
    state.posture_reminder_enabled = cfg.posture_reminder_enabled;
    state.posture_interval_secs = cfg.posture_interval_secs;
    state.seconds_until_posture = @intCast(cfg.posture_interval_secs);
    state.blink_reminder_enabled = cfg.blink_reminder_enabled;
    state.blink_interval_secs = cfg.blink_interval_secs;
    state.seconds_until_blink = @intCast(cfg.blink_interval_secs);
    state.idle_threshold_secs = cfg.idle_threshold_secs;
    state.hydration_reminder_enabled = cfg.hydration_reminder_enabled;
    state.hydration_interval_secs = cfg.hydration_interval_secs;
    state.seconds_until_hydration = @intCast(cfg.hydration_interval_secs);
    state.stretch_reminder_enabled = cfg.stretch_reminder_enabled;
    state.stretch_interval_secs = cfg.stretch_interval_secs;
    state.seconds_until_stretch = @intCast(cfg.stretch_interval_secs);
    state.break_sound = cfg.break_sound;
    state.respect_dnd = cfg.respect_dnd;
    state.screen_lock_as_break = cfg.screen_lock_as_break;
    state.use_notification = cfg.use_notification;
    state.gentle_mode = cfg.gentle_mode;
    state.strict_mode = cfg.strict_mode;
    state.hotkey_break = cfg.hotkey_break;
    state.hotkey_pause = cfg.hotkey_pause;
    state.posture_gif = cfg.posture_gif;
    state.blink_gif = cfg.blink_gif;
    state.hydration_gif = cfg.hydration_gif;
    state.stretch_gif = cfg.stretch_gif;
    state.reset();
    config.save(cfg);
    std.log.info("Config applied: {d}s work / {d}s break, timer_in_menubar={}", .{ cfg.work_interval_secs, cfg.break_duration_secs, cfg.show_timer_in_menubar });
}

/// Save current state as config to disk.
pub fn saveConfig() void {
    config.save(.{
        .work_interval_secs = state.work_interval_secs,
        .break_duration_secs = state.break_duration_secs,
        .show_timer_in_menubar = state.show_timer_in_menubar,
        .pause_during_meetings = state.pause_during_meetings,
        .mic_check_interval_secs = state.mic_check_interval_secs,
        .posture_reminder_enabled = state.posture_reminder_enabled,
        .posture_interval_secs = state.posture_interval_secs,
        .blink_reminder_enabled = state.blink_reminder_enabled,
        .blink_interval_secs = state.blink_interval_secs,
        .idle_threshold_secs = state.idle_threshold_secs,
        .hydration_reminder_enabled = state.hydration_reminder_enabled,
        .hydration_interval_secs = state.hydration_interval_secs,
        .stretch_reminder_enabled = state.stretch_reminder_enabled,
        .stretch_interval_secs = state.stretch_interval_secs,
        .break_sound = state.break_sound,
        .respect_dnd = state.respect_dnd,
        .screen_lock_as_break = state.screen_lock_as_break,
        .use_notification = state.use_notification,
        .gentle_mode = state.gentle_mode,
        .strict_mode = state.strict_mode,
        .hotkey_break = state.hotkey_break,
        .hotkey_pause = state.hotkey_pause,
        .posture_gif = state.posture_gif,
        .blink_gif = state.blink_gif,
        .hydration_gif = state.hydration_gif,
        .stretch_gif = state.stretch_gif,
    });
}

/// Load config from disk and apply it to state (no save, avoids rewriting on startup).
pub fn loadConfig() void {
    const cfg = config.load();
    state.work_interval_secs = cfg.work_interval_secs;
    state.break_duration_secs = cfg.break_duration_secs;
    state.show_timer_in_menubar = cfg.show_timer_in_menubar;
    state.pause_during_meetings = cfg.pause_during_meetings;
    state.mic_check_interval_secs = cfg.mic_check_interval_secs;
    state.posture_reminder_enabled = cfg.posture_reminder_enabled;
    state.posture_interval_secs = cfg.posture_interval_secs;
    state.blink_reminder_enabled = cfg.blink_reminder_enabled;
    state.blink_interval_secs = cfg.blink_interval_secs;
    state.idle_threshold_secs = cfg.idle_threshold_secs;
    state.hydration_reminder_enabled = cfg.hydration_reminder_enabled;
    state.hydration_interval_secs = cfg.hydration_interval_secs;
    state.stretch_reminder_enabled = cfg.stretch_reminder_enabled;
    state.stretch_interval_secs = cfg.stretch_interval_secs;
    state.break_sound = cfg.break_sound;
    state.respect_dnd = cfg.respect_dnd;
    state.screen_lock_as_break = cfg.screen_lock_as_break;
    state.use_notification = cfg.use_notification;
    state.gentle_mode = cfg.gentle_mode;
    state.strict_mode = cfg.strict_mode;
    state.hotkey_break = cfg.hotkey_break;
    state.hotkey_pause = cfg.hotkey_pause;
    state.posture_gif = cfg.posture_gif;
    state.blink_gif = cfg.blink_gif;
    state.hydration_gif = cfg.hydration_gif;
    state.stretch_gif = cfg.stretch_gif;
    state.seconds_until_break = @intCast(cfg.work_interval_secs);
    state.seconds_until_posture = @intCast(cfg.posture_interval_secs);
    state.seconds_until_blink = @intCast(cfg.blink_interval_secs);
    state.seconds_until_hydration = @intCast(cfg.hydration_interval_secs);
    state.seconds_until_stretch = @intCast(cfg.stretch_interval_secs);
    std.log.info("Config loaded: {d}s work / {d}s break", .{ cfg.work_interval_secs, cfg.break_duration_secs });
}

/// Reset daily stats if the day has changed.
fn maybeResetDailyStats() void {
    const today = @divTrunc(std.time.timestamp(), 86400);
    if (state.stats_day != today) {
        state.breaks_taken = 0;
        state.breaks_skipped = 0;
        state.breaks_delayed = 0;
        state.stats_day = today;
    }
}

// Called every second by the platform timer
pub fn tick() void {
    // Reset daily stats if needed
    maybeResetDailyStats();

    // Screen lock — skip all processing while locked
    if (state.screen_locked) {
        menubar.updateMenu();
        return;
    }

    // Check DND / Focus state
    if (state.respect_dnd) {
        state.dnd_check_counter += 1;
        if (state.dnd_check_counter >= 10) {
            state.dnd_check_counter = 0;
            const was_active = state.is_dnd_active;
            state.is_dnd_active = platform.backend.isDNDActive();
            if (state.is_dnd_active != was_active) {
                menubar.markDirty();
                if (state.is_dnd_active) {
                    std.log.info("Focus/DND active \xe2\x80\x94 pausing reminders", .{});
                } else {
                    std.log.info("Focus/DND ended \xe2\x80\x94 resuming reminders", .{});
                }
            }
        }
        if (state.is_dnd_active) {
            // Dismiss any active reminders
            if (state.is_on_break) state.endBreak();
            if (state.is_posture_showing) {
                posture.hidePostureReminder();
                state.is_posture_showing = false;
            }
            if (state.is_blink_showing) {
                blink.hideBlinkReminder();
                state.is_blink_showing = false;
            }
            if (state.is_hydration_showing) {
                hydration.hideHydrationReminder();
                state.is_hydration_showing = false;
            }
            if (state.is_stretch_showing) {
                stretch.hideStretchReminder();
                state.is_stretch_showing = false;
            }
            menubar.updateMenu();
            return;
        }
    }

    // Check microphone state for meeting detection
    if (state.pause_during_meetings) {
        state.mic_check_counter += 1;
        if (state.mic_check_counter >= state.mic_check_interval_secs) {
            state.mic_check_counter = 0;
            state.last_mic_active = platform.backend.isAnyMicrophoneActive();
        }
        if (state.last_mic_active and !state.meeting_paused) {
            std.log.info("Meeting detected \xe2\x80\x94 mic active, pausing timer", .{});
            state.meeting_paused = true;
            menubar.markDirty();
        } else if (!state.last_mic_active and state.meeting_paused) {
            std.log.info("Meeting ended \xe2\x80\x94 mic inactive, resuming timer", .{});
            state.meeting_paused = false;
            menubar.markDirty();
        }
    } else {
        state.meeting_paused = false;
    }

    // Idle detection
    if (state.idle_threshold_secs > 0) {
        if (platform.backend.getIdleSeconds()) |idle_secs| {
            if (idle_secs >= state.idle_threshold_secs) {
                if (!state.is_idle) {
                    std.log.info("User idle ({d}s >= {d}s threshold)", .{ idle_secs, state.idle_threshold_secs });
                    state.is_idle = true;
                    menubar.markDirty();
                    // End break if active
                    if (state.is_on_break) {
                        state.endBreak();
                    }
                    if (state.is_posture_showing) {
                        posture.hidePostureReminder();
                        state.is_posture_showing = false;
                    }
                    if (state.is_blink_showing) {
                        blink.hideBlinkReminder();
                        state.is_blink_showing = false;
                    }
                    if (state.is_hydration_showing) {
                        hydration.hideHydrationReminder();
                        state.is_hydration_showing = false;
                    }
                    if (state.is_stretch_showing) {
                        stretch.hideStretchReminder();
                        state.is_stretch_showing = false;
                    }
                }
                menubar.updateMenu();
                return;
            } else if (state.is_idle) {
                // User returned from idle — reset all countdowns
                std.log.info("User returned from idle, resetting timers", .{});
                state.is_idle = false;
                menubar.markDirty();
                state.seconds_until_break = @intCast(state.work_interval_secs);
                state.seconds_until_posture = @intCast(state.posture_interval_secs);
                state.seconds_until_blink = @intCast(state.blink_interval_secs);
                state.seconds_until_hydration = @intCast(state.hydration_interval_secs);
                state.seconds_until_stretch = @intCast(state.stretch_interval_secs);
            }
        }
    }

    // Always tick an active break (e.g. user clicked "Take Break Now" during a meeting)
    if (state.is_on_break) {
        state.break_seconds_remaining -= 1;
        if (state.break_seconds_remaining <= 0) {
            state.breaks_taken += 1;
            menubar.markDirty();
            state.endBreak();
        } else {
            if (state.use_notification) {
                // No overlay to update in notification mode
            } else if (state.gentle_mode) {
                gentle.updateGentleBanner(&state);
            } else {
                overlay.updateOverlay(&state);
            }
        }
    } else if (state.is_paused or state.meeting_paused) {
        // Paused — dismiss reminders and skip work timer, but don't block active breaks above
        if (state.is_posture_showing) {
            posture.hidePostureReminder();
            state.is_posture_showing = false;
            state.seconds_until_posture = @intCast(state.posture_interval_secs);
        }
        if (state.is_blink_showing) {
            blink.hideBlinkReminder();
            state.is_blink_showing = false;
            state.seconds_until_blink = @intCast(state.blink_interval_secs);
        }
        if (state.is_hydration_showing) {
            hydration.hideHydrationReminder();
            state.is_hydration_showing = false;
            state.seconds_until_hydration = @intCast(state.hydration_interval_secs);
        }
        if (state.is_stretch_showing) {
            stretch.hideStretchReminder();
            state.is_stretch_showing = false;
            state.seconds_until_stretch = @intCast(state.stretch_interval_secs);
        }
        menubar.updateMenu();
        return;
    } else {
        state.seconds_until_break -= 1;
        if (state.seconds_until_break <= 0) {
            menubar.markDirty();
            state.startBreak();
        }
    }

    // Blink reminder logic (independent of eye breaks and posture)
    if (state.blink_reminder_enabled) {
        if (state.is_blink_showing) {
            state.blink_seconds_remaining -= 1;
            state.blink_tick +%= 1;
            if (state.blink_seconds_remaining <= 0) {
                blink.hideBlinkReminder();
                state.is_blink_showing = false;
                state.seconds_until_blink = @intCast(state.blink_interval_secs);
            } else {
                blink.updateBlinkAnimation(state.blink_tick);
            }
        } else if (!state.is_on_break) {
            state.seconds_until_blink -= 1;
            if (state.seconds_until_blink <= 0) {
                blink.showBlinkReminder();
                state.is_blink_showing = true;
                state.blink_seconds_remaining = @intCast(state.blink_duration_secs);
                state.blink_tick = 0;
            }
        }
    }

    // Posture reminder logic (independent of eye breaks)
    if (state.posture_reminder_enabled) {
        if (state.is_posture_showing) {
            state.posture_seconds_remaining -= 1;
            state.posture_tick +%= 1;
            if (state.posture_seconds_remaining <= 0) {
                posture.hidePostureReminder();
                state.is_posture_showing = false;
                state.seconds_until_posture = @intCast(state.posture_interval_secs);
            } else {
                posture.updatePostureAnimation(state.posture_tick);
            }
        } else if (!state.is_on_break) {
            state.seconds_until_posture -= 1;
            if (state.seconds_until_posture <= 0) {
                posture.showPostureReminder();
                state.is_posture_showing = true;
                state.posture_seconds_remaining = @intCast(state.posture_duration_secs);
                state.posture_tick = 0;
            }
        }
    }

    // Hydration reminder logic (independent of other reminders)
    if (state.hydration_reminder_enabled) {
        if (state.is_hydration_showing) {
            state.hydration_seconds_remaining -= 1;
            state.hydration_tick +%= 1;
            if (state.hydration_seconds_remaining <= 0) {
                hydration.hideHydrationReminder();
                state.is_hydration_showing = false;
                state.seconds_until_hydration = @intCast(state.hydration_interval_secs);
            } else {
                hydration.updateHydrationAnimation(state.hydration_tick);
            }
        } else if (!state.is_on_break) {
            state.seconds_until_hydration -= 1;
            if (state.seconds_until_hydration <= 0) {
                hydration.showHydrationReminder();
                state.is_hydration_showing = true;
                state.hydration_seconds_remaining = @intCast(state.hydration_duration_secs);
                state.hydration_tick = 0;
            }
        }
    }

    // Stretch reminder logic (independent of other reminders)
    if (state.stretch_reminder_enabled) {
        if (state.is_stretch_showing) {
            state.stretch_seconds_remaining -= 1;
            state.stretch_tick +%= 1;
            if (state.stretch_seconds_remaining <= 0) {
                stretch.hideStretchReminder();
                state.is_stretch_showing = false;
                state.seconds_until_stretch = @intCast(state.stretch_interval_secs);
            } else {
                stretch.updateStretchAnimation(state.stretch_tick);
            }
        } else if (!state.is_on_break) {
            state.seconds_until_stretch -= 1;
            if (state.seconds_until_stretch <= 0) {
                stretch.showStretchReminder();
                state.is_stretch_showing = true;
                state.stretch_seconds_remaining = @intCast(state.stretch_duration_secs);
                state.stretch_tick = 0;
            }
        }
    }

    menubar.updateMenu();
}
