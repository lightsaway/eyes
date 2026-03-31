// Linux autostart — XDG desktop file management.

const std = @import("std");

const desktop_file = "eyes.desktop";

fn fmtPathZ(buf: []u8, comptime fmt: []const u8, args: anytype) ?[:0]const u8 {
    const slice = std.fmt.bufPrint(buf[0 .. buf.len - 1], fmt, args) catch return null;
    buf[slice.len] = 0;
    return buf[0..slice.len :0];
}

pub fn isEnabled() bool {
    const home = std.posix.getenv("HOME") orelse return false;
    var path_buf: [512]u8 = undefined;
    const path = fmtPathZ(&path_buf, "{s}/.config/autostart/{s}", .{ home, desktop_file }) orelse return false;
    _ = std.fs.cwd().statFile(path) catch return false;
    return true;
}

pub fn setEnabled(enabled: bool) void {
    const home = std.posix.getenv("HOME") orelse return;

    var path_buf: [512]u8 = undefined;
    const path = fmtPathZ(&path_buf, "{s}/.config/autostart/{s}", .{ home, desktop_file }) orelse return;

    if (enabled) {
        // Get our own executable path
        var exe_buf: [512]u8 = undefined;
        const exe_path = std.fs.selfExePath(&exe_buf) catch return;

        var dir_buf: [512]u8 = undefined;
        const dir_path = fmtPathZ(&dir_buf, "{s}/.config/autostart", .{home}) orelse return;
        std.fs.cwd().makePath(dir_path) catch {};

        const content = std.fmt.allocPrint(std.heap.page_allocator,
            \\[Desktop Entry]
            \\Type=Application
            \\Name=Eyes
            \\Exec={s}
            \\X-GNOME-Autostart-enabled=true
            \\Comment=Break reminder app
        , .{exe_path}) catch return;
        defer std.heap.page_allocator.free(content);

        const file = std.fs.cwd().createFileZ(path, .{}) catch return;
        defer file.close();
        _ = file.writeAll(content) catch {};
    } else {
        std.fs.cwd().deleteFileZ(path) catch {};
    }
}
