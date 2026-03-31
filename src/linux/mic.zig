// Linux microphone detection via /proc/asound.
// Checks if any ALSA capture device is actively recording.

const std = @import("std");

pub fn isAnyMicrophoneActive() bool {
    // Scan /proc/asound/card*/pcm*c/sub*/status for "state: RUNNING"
    var dir = std.fs.openDirAbsolute("/proc/asound", .{ .iterate = true }) catch return false;
    defer dir.close();

    var iter = dir.iterate();
    while (iter.next() catch null) |entry| {
        if (entry.kind != .directory) continue;
        if (!std.mem.startsWith(u8, entry.name, "card")) continue;

        // Open card directory and look for capture PCM devices (pcm*c)
        var card_path_buf: [128]u8 = undefined;
        const card_path = std.fmt.bufPrint(&card_path_buf, "/proc/asound/{s}", .{entry.name}) catch continue;

        var card_dir = std.fs.openDirAbsolute(card_path, .{ .iterate = true }) catch continue;
        defer card_dir.close();

        var pcm_iter = card_dir.iterate();
        while (pcm_iter.next() catch null) |pcm_entry| {
            if (pcm_entry.kind != .directory) continue;
            // Capture devices end with 'c' (e.g., pcm0c)
            if (!std.mem.startsWith(u8, pcm_entry.name, "pcm")) continue;
            if (pcm_entry.name.len == 0 or pcm_entry.name[pcm_entry.name.len - 1] != 'c') continue;

            // Check sub0/status
            var status_path_buf: [192]u8 = undefined;
            const status_path = std.fmt.bufPrint(&status_path_buf, "{s}/{s}/sub0/status", .{ card_path, pcm_entry.name }) catch continue;

            var status_buf: [256]u8 = undefined;
            const status_file = std.fs.openFileAbsolute(status_path, .{}) catch continue;
            defer status_file.close();
            const len = status_file.readAll(&status_buf) catch continue;
            const status = status_buf[0..len];

            if (std.mem.indexOf(u8, status, "state: RUNNING") != null) {
                return true;
            }
        }
    }

    return false;
}
