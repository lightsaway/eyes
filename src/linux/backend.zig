// Linux backend — re-exports platform-specific modules under a unified interface.

const std = @import("std");
const idle = @import("idle.zig");
const mic = @import("mic.zig");
const meeting_mod = @import("meeting.zig");
const notify = @import("notify.zig");
const sound = @import("sound.zig");

// Lifecycle
const lifecycle = @import("lifecycle.zig");
pub const run = lifecycle.run;

// UI modules (Linux implementations)
pub const overlay = @import("overlay.zig");
pub const gentle = @import("gentle.zig");
pub const menubar = @import("menubar.zig");
pub const autostart = @import("autostart.zig");

// Reminder modules
pub const posture = @import("reminders/posture.zig");
pub const blink = @import("reminders/blink.zig");
pub const hydration = @import("reminders/hydration.zig");
pub const stretch = @import("reminders/stretch.zig");

// --- Platform interface functions ---

pub fn isAnyMicrophoneActive() bool {
    return mic.isAnyMicrophoneActive();
}

pub fn isInMeeting() bool {
    return meeting_mod.isInMeeting();
}

pub fn getIdleSeconds() ?u64 {
    return idle.getIdleSeconds();
}

pub fn deliverNotification(title: [*:0]const u8, body: [*:0]const u8) void {
    notify.deliverNotification(title, body);
}

pub fn requestNotificationPermission() void {
    // No-op on Linux — notifications don't require permission
}

pub fn playSystemSound(name: [*:0]const u8) void {
    sound.playSystemSound(name);
}

pub fn registerScreenLockNotifications() void {
    // TODO: Subscribe to D-Bus org.freedesktop.ScreenSaver ActiveChanged signal
    // or org.freedesktop.login1.Session Lock/Unlock signals.
    // For now, screen lock detection is not implemented on Linux.
    std.log.info("Screen lock detection not yet implemented on Linux", .{});
}

/// Check if DND / Focus mode is active via D-Bus.
pub fn isDNDActive() bool {
    // TODO: Query org.freedesktop.Notifications Inhibited property
    // or org.gnome.Shell DoNotDisturb state via D-Bus.
    return false;
}
