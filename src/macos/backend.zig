// macOS backend — re-exports platform-specific modules under a unified interface.

const std = @import("std");

// Low-level macOS bindings
pub const objc = @import("objc.zig");
pub const appkit = @import("appkit.zig");
pub const foundation = @import("foundation.zig");
pub const cg = @import("coregraphics.zig");
pub const coreaudio = @import("coreaudio.zig");
pub const iokit = @import("iokit.zig");
pub const coreanim = @import("coreanim.zig");
pub const gifview = @import("gifview.zig");

// UI modules (macOS implementations)
pub const overlay = @import("../overlay.zig");
pub const gentle = @import("../gentle.zig");
pub const posture = @import("../reminders/posture.zig");
pub const blink = @import("../reminders/blink.zig");
pub const hydration = @import("../reminders/hydration.zig");
pub const stretch = @import("../reminders/stretch.zig");
pub const menubar = @import("../menubar.zig");
pub const launchagent = @import("../launchagent.zig");

// --- Platform interface functions ---

pub fn isAnyMicrophoneActive() bool {
    return coreaudio.isAnyMicrophoneActive();
}

pub fn getIdleSeconds() ?u64 {
    return iokit.getIdleSeconds();
}

pub fn deliverNotification(title: [*:0]const u8, body: [*:0]const u8) void {
    appkit.deliverNotification(title, body);
}

pub fn requestNotificationPermission() void {
    appkit.requestNotificationPermission();
}

pub fn playSystemSound(name: [*:0]const u8) void {
    appkit.playSystemSound(name);
}

/// Check if DND / Focus mode is active by reading the macOS assertions file.
pub fn isDNDActive() bool {
    const home = std.posix.getenv("HOME") orelse return false;
    var path_buf: [512]u8 = undefined;
    const slice = std.fmt.bufPrint(path_buf[0 .. path_buf.len - 1], "{s}/Library/DoNotDisturb/DB/Assertions.json", .{home}) catch return false;
    path_buf[slice.len] = 0;
    const path: [:0]const u8 = path_buf[0..slice.len :0];

    const file = std.fs.cwd().openFileZ(path, .{}) catch return false;
    defer file.close();

    var buf: [4096]u8 = undefined;
    const len = file.readAll(&buf) catch return false;
    const data = buf[0..len];

    return std.mem.indexOf(u8, data, "assertionDetails") != null and
        std.mem.indexOf(u8, data, "storeAssertionRecords") != null;
}
