// Smart meeting detection via window titles.
// Checks on-screen windows against known meeting app patterns.

const std = @import("std");
const cg = @import("coregraphics.zig");

/// Check if any on-screen window matches a known meeting app pattern.
pub fn isInMeeting() bool {
    const window_list = cg.CGWindowListCopyWindowInfo(
        cg.kCGWindowListOptionOnScreenOnly | cg.kCGWindowListExcludeDesktopElements,
        cg.kCGNullWindowID,
    ) orelse {
        std.log.warn("Smart meeting: CGWindowListCopyWindowInfo returned null", .{});
        return false;
    };
    defer cg.CFRelease(window_list);

    const count = cg.CFArrayGetCount(window_list);
    if (count <= 0) return false;

    var i: c_long = 0;
    while (i < count) : (i += 1) {
        const dict = cg.CFArrayGetValueAtIndex(window_list, i) orelse continue;

        var owner_buf: [256]u8 = undefined;
        const owner = getCFString(dict, cg.kCGWindowOwnerName, &owner_buf) orelse continue;

        var title_buf: [512]u8 = undefined;
        const title = getCFString(dict, cg.kCGWindowName, &title_buf);

        if (matchesMeeting(owner, title)) {
            std.log.info("Smart meeting: matched owner=\"{s}\" title=\"{s}\"", .{ owner, title orelse "(none)" });
            return true;
        }
    }

    std.log.debug("Smart meeting: scanned {d} windows, no meeting found", .{count});
    return false;
}

fn getCFString(dict: ?*anyopaque, key: ?*anyopaque, buf: []u8) ?[]const u8 {
    const cf_str = cg.CFDictionaryGetValue(dict, key) orelse return null;
    const len = cg.CFStringGetLength(cf_str);
    if (len <= 0 or len >= buf.len) return null;
    if (!cg.CFStringGetCString(cf_str, buf.ptr, @intCast(buf.len), cg.kCFStringEncodingUTF8)) return null;
    return buf[0..@intCast(len)];
}

fn matchesMeeting(owner: []const u8, title_opt: ?[]const u8) bool {
    // Zoom
    if (std.mem.eql(u8, owner, "zoom.us")) {
        if (title_opt) |t| {
            if (contains(t, "Zoom Meeting") or contains(t, "Zoom Webinar")) return true;
        }
        return false;
    }

    // Google Meet in browsers
    if (std.mem.eql(u8, owner, "Google Chrome") or
        std.mem.eql(u8, owner, "Safari") or
        std.mem.eql(u8, owner, "Arc") or
        std.mem.eql(u8, owner, "Firefox") or
        std.mem.eql(u8, owner, "Microsoft Edge") or
        std.mem.eql(u8, owner, "Brave Browser"))
    {
        if (title_opt) |t| {
            if (contains(t, "Meet - ") or containsMeetCode(t)) return true;
        }
        return false;
    }

    // Microsoft Teams
    if (std.mem.eql(u8, owner, "Microsoft Teams") or std.mem.eql(u8, owner, "Microsoft Teams (work or school)")) {
        if (title_opt) |t| {
            if (contains(t, "Meeting with") or contains(t, "(Meeting)")) return true;
        }
        return false;
    }

    // Slack Huddle
    if (std.mem.eql(u8, owner, "Slack")) {
        if (title_opt) |t| {
            if (contains(t, "Huddle")) return true;
        }
        return false;
    }

    // FaceTime — any window means active call
    if (std.mem.eql(u8, owner, "FaceTime")) {
        return true;
    }

    // Webex
    if (std.mem.eql(u8, owner, "Webex") or contains(owner, "Cisco Webex")) {
        if (title_opt) |t| {
            if (contains(t, "Meeting")) return true;
        }
        return false;
    }

    // Discord voice
    if (std.mem.eql(u8, owner, "Discord")) {
        if (title_opt) |t| {
            if (contains(t, "Voice Connected")) return true;
        }
        return false;
    }

    return false;
}

fn contains(haystack: []const u8, needle: []const u8) bool {
    return std.mem.indexOf(u8, haystack, needle) != null;
}

/// Check for Google Meet URL code pattern: xxx-xxxx-xxx (3 lowercase letters, dash, 4 lowercase, dash, 3 lowercase)
fn containsMeetCode(title: []const u8) bool {
    if (title.len < 11) return false;
    var i: usize = 0;
    while (i + 11 <= title.len) : (i += 1) {
        if (isLower(title[i]) and isLower(title[i + 1]) and isLower(title[i + 2]) and
            title[i + 3] == '-' and
            isLower(title[i + 4]) and isLower(title[i + 5]) and isLower(title[i + 6]) and isLower(title[i + 7]) and
            title[i + 8] == '-' and
            isLower(title[i + 9]) and isLower(title[i + 10]) and isLower(title[i + 11]))
        {
            return true;
        }
    }
    return false;
}

fn isLower(c: u8) bool {
    return c >= 'a' and c <= 'z';
}
