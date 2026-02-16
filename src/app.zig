// App state and break timer logic.

const std = @import("std");
const objc = @import("macos/objc.zig");
const overlay = @import("overlay.zig");
const menubar = @import("menubar.zig");
const config = @import("config.zig");
const coreaudio = @import("macos/coreaudio.zig");

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

    pub fn reset(self: *AppState) void {
        self.seconds_until_break = @intCast(self.work_interval_secs);
        self.is_on_break = false;
        self.break_seconds_remaining = 0;
    }

    pub fn startBreak(self: *AppState) void {
        self.is_on_break = true;
        self.break_seconds_remaining = @intCast(self.break_duration_secs);
        overlay.showOverlay(self);
    }

    pub fn endBreak(self: *AppState) void {
        self.is_on_break = false;
        self.break_seconds_remaining = 0;
        self.seconds_until_break = @intCast(self.work_interval_secs);
        overlay.hideOverlay();
    }

    pub fn delayBreak(self: *AppState, extra_secs: i32) void {
        if (self.is_on_break) {
            self.endBreak();
        }
        self.seconds_until_break = extra_secs;
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
    state.seconds_until_break = @intCast(cfg.work_interval_secs);
    std.log.info("Config loaded: {d}s work / {d}s break, timer_in_menubar={}, pause_meetings={}", .{ cfg.work_interval_secs, cfg.break_duration_secs, cfg.show_timer_in_menubar, cfg.pause_during_meetings });
}

// Called every second by the NSTimer
pub fn tick() void {
    // Check microphone state for meeting detection
    if (state.pause_during_meetings) {
        state.mic_check_counter += 1;
        if (state.mic_check_counter >= state.mic_check_interval_secs) {
            state.mic_check_counter = 0;
            state.last_mic_active = coreaudio.isAnyMicrophoneActive();
        }
        if (state.last_mic_active and !state.meeting_paused) {
            std.log.info("Meeting detected — mic active, pausing timer", .{});
            state.meeting_paused = true;
        } else if (!state.last_mic_active and state.meeting_paused) {
            std.log.info("Meeting ended — mic inactive, resuming timer", .{});
            state.meeting_paused = false;
        }
    } else {
        state.meeting_paused = false;
    }

    if (state.is_paused or state.meeting_paused) {
        menubar.updateMenu();
        return;
    }

    if (state.is_on_break) {
        state.break_seconds_remaining -= 1;
        if (state.break_seconds_remaining <= 0) {
            state.endBreak();
        } else {
            overlay.updateOverlay(&state);
        }
    } else {
        state.seconds_until_break -= 1;
        if (state.seconds_until_break <= 0) {
            state.startBreak();
        }
    }

    menubar.updateMenu();
}

// ObjC callback for NSTimer
pub fn timerCallback(_: objc.id, _: objc.SEL, _: objc.id) callconv(.c) void {
    tick();
}
