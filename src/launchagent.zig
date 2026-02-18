// LaunchAgent management — creates/removes ~/Library/LaunchAgents/com.eyes.app.plist
// for "Start at Login" functionality.

const std = @import("std");

const plist_dir = "Library/LaunchAgents";
const plist_file = "com.eyes.app.plist";

/// Format a path into a sentinel-terminated buffer. Returns null on failure.
fn fmtPathZ(buf: []u8, comptime fmt: []const u8, args: anytype) ?[:0]const u8 {
    const slice = std.fmt.bufPrint(buf[0 .. buf.len - 1], fmt, args) catch return null;
    buf[slice.len] = 0;
    return buf[0..slice.len :0];
}

/// Check if the launch agent plist exists.
pub fn isEnabled() bool {
    const home = std.posix.getenv("HOME") orelse return false;

    var path_buf: [512]u8 = undefined;
    const path = fmtPathZ(&path_buf, "{s}/{s}/{s}", .{ home, plist_dir, plist_file }) orelse return false;

    std.fs.cwd().accessZ(path, .{}) catch return false;
    return true;
}

/// Enable or disable start-at-login by creating or removing the plist.
pub fn setEnabled(enabled: bool) void {
    const home = std.posix.getenv("HOME") orelse return;

    if (enabled) {
        // Get the path to the current binary
        var exe_buf: [std.fs.max_path_bytes]u8 = undefined;
        const exe_path = std.fs.selfExePath(&exe_buf) catch |err| {
            std.log.warn("launchagent: selfExePath failed: {}", .{err});
            return;
        };

        // Create ~/Library/LaunchAgents/ if needed
        var dir_buf: [512]u8 = undefined;
        const dir_path = fmtPathZ(&dir_buf, "{s}/{s}", .{ home, plist_dir }) orelse return;
        std.fs.cwd().makePath(dir_path) catch |err| {
            std.log.warn("launchagent: makePath failed: {}", .{err});
            return;
        };

        // Write the plist
        var path_buf: [512]u8 = undefined;
        const file_path = fmtPathZ(&path_buf, "{s}/{s}/{s}", .{ home, plist_dir, plist_file }) orelse return;

        var plist_buf: [2048]u8 = undefined;
        const plist_content = std.fmt.bufPrint(&plist_buf, plist_template, .{exe_path}) catch |err| {
            std.log.warn("launchagent: bufPrint failed: {}", .{err});
            return;
        };

        const file = std.fs.cwd().createFileZ(file_path, .{}) catch |err| {
            std.log.warn("launchagent: createFile failed: {}", .{err});
            return;
        };
        defer file.close();

        file.writeAll(plist_content) catch |err| {
            std.log.warn("launchagent: write failed: {}", .{err});
            return;
        };
    } else {
        // Remove the plist
        var path_buf: [512]u8 = undefined;
        const file_path = fmtPathZ(&path_buf, "{s}/{s}/{s}", .{ home, plist_dir, plist_file }) orelse return;

        std.fs.cwd().deleteFileZ(file_path) catch |err| {
            std.log.warn("launchagent: deleteFile failed: {}", .{err});
            return;
        };
    }
}

const plist_template =
    \\<?xml version="1.0" encoding="UTF-8"?>
    \\<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    \\<plist version="1.0">
    \\<dict>
    \\    <key>Label</key>
    \\    <string>com.eyes.app</string>
    \\    <key>ProgramArguments</key>
    \\    <array>
    \\        <string>{s}</string>
    \\    </array>
    \\    <key>RunAtLoad</key>
    \\    <true/>
    \\</dict>
    \\</plist>
    \\
;
