// Linux idle detection via X11 XScreenSaver extension.
// Falls back to null (disabled) on Wayland or if XScreenSaver is unavailable.

const std = @import("std");
const gtk = @import("gtk.zig");
const x11 = gtk.x11;

var display: ?*x11.Display = null;
var xss_available: bool = false;
var init_done: bool = false;

fn ensureInit() void {
    if (init_done) return;
    init_done = true;

    // Check if running on X11 (not Wayland)
    const session_type = std.posix.getenv("XDG_SESSION_TYPE") orelse "";
    const wayland_display = std.posix.getenv("WAYLAND_DISPLAY");

    if (std.mem.eql(u8, session_type, "wayland") or wayland_display != null) {
        std.log.info("Wayland detected \xe2\x80\x94 idle detection limited", .{});
        return;
    }

    display = x11.XOpenDisplay(null);
    if (display == null) {
        std.log.warn("Cannot open X11 display for idle detection", .{});
        return;
    }

    // Check if XScreenSaver extension is available
    var event_base: c_int = 0;
    var error_base: c_int = 0;
    if (x11.XScreenSaverQueryExtension(display, &event_base, &error_base) != 0) {
        xss_available = true;
        std.log.info("X11 idle detection enabled (XScreenSaver extension)", .{});
    } else {
        std.log.warn("XScreenSaver extension not available", .{});
    }
}

pub fn getIdleSeconds() ?u64 {
    ensureInit();

    if (!xss_available) return null;
    const dpy = display orelse return null;

    const info = x11.XScreenSaverAllocInfo() orelse return null;
    defer _ = x11.XFree(@ptrCast(info));

    const root = x11.XDefaultRootWindow(dpy);
    if (x11.XScreenSaverQueryInfo(dpy, root, info) == 0) {
        return null;
    }

    return info.*.idle / 1000; // milliseconds to seconds
}
