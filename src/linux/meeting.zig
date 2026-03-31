// Linux meeting detection via /proc process scanning.
// Checks if any known video conferencing process is running.

const std = @import("std");

const meeting_processes = [_][]const u8{
    "zoom",
    "zoom.real",
    "ZoomWebviewHost",
    "teams",
    "teams-insiders",
    "slack",
    "webex",
    "CiscoCollabHost",
    "discord",
    "FaceTime",
    "skype",
    "Google Meet",
    "jitsi",
    "BlueJeans",
};

pub fn isInMeeting() bool {
    var dir = std.fs.openDirAbsolute("/proc", .{ .iterate = true }) catch return false;
    defer dir.close();

    var iter = dir.iterate();
    while (iter.next() catch null) |entry| {
        if (entry.kind != .directory) continue;

        // Only process numeric directories (PIDs)
        for (entry.name) |ch| {
            if (ch < '0' or ch > '9') break;
        } else {
            // All chars were digits — this is a PID directory
            var comm_path_buf: [64]u8 = undefined;
            const comm_path = std.fmt.bufPrint(&comm_path_buf, "/proc/{s}/comm", .{entry.name}) catch continue;

            var comm_buf: [256]u8 = undefined;
            const comm_file = std.fs.openFileAbsolute(comm_path, .{}) catch continue;
            defer comm_file.close();
            const len = comm_file.readAll(&comm_buf) catch continue;

            // comm includes trailing newline
            var comm = comm_buf[0..len];
            if (comm.len > 0 and comm[comm.len - 1] == '\n') {
                comm = comm[0 .. comm.len - 1];
            }

            for (meeting_processes) |proc_name| {
                if (std.mem.eql(u8, comm, proc_name)) {
                    return true;
                }
                // Also check if comm starts with the process name (some processes truncate)
                if (comm.len >= proc_name.len and std.mem.eql(u8, comm[0..proc_name.len], proc_name)) {
                    return true;
                }
            }
        }
    }

    return false;
}
