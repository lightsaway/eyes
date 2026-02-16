// Persistent configuration — loads/saves from ~/.config/eyes/config.json

const std = @import("std");

pub const Config = struct {
    work_interval_secs: u32 = 20 * 60,
    break_duration_secs: u32 = 20,
    show_timer_in_menubar: bool = true,
    pause_during_meetings: bool = false,
    mic_check_interval_secs: u32 = 5,
};

const config_dir = ".config/eyes";
const config_file = "config.json";

/// Format a path into a sentinel-terminated buffer. Returns null on failure.
fn fmtPathZ(buf: []u8, comptime fmt: []const u8, args: anytype) ?[:0]const u8 {
    const slice = std.fmt.bufPrint(buf[0 .. buf.len - 1], fmt, args) catch return null;
    buf[slice.len] = 0;
    return buf[0..slice.len :0];
}

/// Load config from ~/.config/eyes/config.json. Returns defaults if missing or invalid.
pub fn load() Config {
    const home = std.posix.getenv("HOME") orelse return Config{};

    var path_buf: [512]u8 = undefined;
    const path = fmtPathZ(&path_buf, "{s}/{s}/{s}", .{ home, config_dir, config_file }) orelse return Config{};

    const file = std.fs.cwd().openFileZ(path, .{}) catch return Config{};
    defer file.close();

    var buf: [256]u8 = undefined;
    const len = file.readAll(&buf) catch return Config{};
    const data = buf[0..len];

    return parse(data);
}

/// Save config to ~/.config/eyes/config.json. Creates dir if needed.
pub fn save(cfg: Config) void {
    const home = std.posix.getenv("HOME") orelse return;

    // Create ~/.config/eyes/ recursively
    var dir_buf: [512]u8 = undefined;
    const dir_path = fmtPathZ(&dir_buf, "{s}/{s}", .{ home, config_dir }) orelse return;
    std.fs.cwd().makePath(dir_path) catch return;

    var path_buf: [512]u8 = undefined;
    const file_path = fmtPathZ(&path_buf, "{s}/{s}/{s}", .{ home, config_dir, config_file }) orelse return;

    const file = std.fs.cwd().createFileZ(file_path, .{}) catch return;
    defer file.close();

    const show_str: [*:0]const u8 = if (cfg.show_timer_in_menubar) "true" else "false";
    const meetings_str: [*:0]const u8 = if (cfg.pause_during_meetings) "true" else "false";
    var json_buf: [320]u8 = undefined;
    const json = std.fmt.bufPrint(&json_buf, "{{\n  \"work_interval_secs\": {d},\n  \"break_duration_secs\": {d},\n  \"show_timer_in_menubar\": {s},\n  \"pause_during_meetings\": {s},\n  \"mic_check_interval_secs\": {d}\n}}\n", .{ cfg.work_interval_secs, cfg.break_duration_secs, show_str, meetings_str, cfg.mic_check_interval_secs }) catch return;
    file.writeAll(json) catch {};
}

/// Simple JSON parser for our config fields.
fn parse(data: []const u8) Config {
    var cfg = Config{};
    cfg.work_interval_secs = parseField(data, "work_interval_secs") orelse cfg.work_interval_secs;
    cfg.break_duration_secs = parseField(data, "break_duration_secs") orelse cfg.break_duration_secs;
    cfg.show_timer_in_menubar = parseBoolField(data, "show_timer_in_menubar") orelse cfg.show_timer_in_menubar;
    cfg.pause_during_meetings = parseBoolField(data, "pause_during_meetings") orelse cfg.pause_during_meetings;
    cfg.mic_check_interval_secs = parseField(data, "mic_check_interval_secs") orelse cfg.mic_check_interval_secs;
    return cfg;
}

fn parseBoolField(data: []const u8, key: []const u8) ?bool {
    const idx = std.mem.indexOf(u8, data, key) orelse return null;
    const after_key = data[idx + key.len ..];
    const colon = std.mem.indexOfScalar(u8, after_key, ':') orelse return null;
    const after_colon = after_key[colon + 1 ..];

    const comma = std.mem.indexOfScalar(u8, after_colon, ',') orelse after_colon.len;
    const brace = std.mem.indexOfScalar(u8, after_colon, '}') orelse after_colon.len;
    const end = @min(comma, brace);
    const value = after_colon[0..end];

    if (std.mem.indexOf(u8, value, "true") != null) return true;
    if (std.mem.indexOf(u8, value, "false") != null) return false;
    return null;
}

fn parseField(data: []const u8, key: []const u8) ?u32 {
    const idx = std.mem.indexOf(u8, data, key) orelse return null;
    const after_key = data[idx + key.len ..];

    const colon = std.mem.indexOfScalar(u8, after_key, ':') orelse return null;
    const after_colon = after_key[colon + 1 ..];

    // Find start of number
    var start: usize = 0;
    while (start < after_colon.len and (after_colon[start] == ' ' or after_colon[start] == '\t')) {
        start += 1;
    }
    if (start >= after_colon.len) return null;

    // Find end of number
    var end: usize = start;
    while (end < after_colon.len and after_colon[end] >= '0' and after_colon[end] <= '9') {
        end += 1;
    }
    if (end == start) return null;

    return std.fmt.parseInt(u32, after_colon[start..end], 10) catch null;
}
