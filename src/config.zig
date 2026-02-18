// Persistent configuration — loads/saves from ~/.config/eyes/config.json

const std = @import("std");

pub const Config = struct {
    work_interval_secs: u32 = 20 * 60,
    break_duration_secs: u32 = 20,
    show_timer_in_menubar: bool = true,
    pause_during_meetings: bool = false,
    mic_check_interval_secs: u32 = 5,
    posture_reminder_enabled: bool = false,
    posture_interval_secs: u32 = 30 * 60,
    blink_reminder_enabled: bool = false,
    blink_interval_secs: u32 = 30 * 60,
    idle_threshold_secs: u32 = 5 * 60,
    hydration_reminder_enabled: bool = false,
    hydration_interval_secs: u32 = 45 * 60,
    break_sound: u8 = 1,
    respect_dnd: bool = true,
    screen_lock_as_break: bool = true,
    use_notification: bool = false,
    gentle_mode: bool = false,
    strict_mode: bool = false,
    posture_gif: [64]u8 = .{0} ** 64,
    blink_gif: [64]u8 = .{0} ** 64,
    hydration_gif: [64]u8 = .{0} ** 64,
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

    const file = std.fs.cwd().openFileZ(path, .{}) catch |err| {
        if (err != error.FileNotFound) std.log.warn("config load: open failed: {}", .{err});
        return Config{};
    };
    defer file.close();

    var buf: [1024]u8 = undefined;
    const len = file.readAll(&buf) catch |err| {
        std.log.warn("config load: read failed: {}", .{err});
        return Config{};
    };
    const data = buf[0..len];

    return parse(data);
}

/// Get a null-terminated slice from a fixed-size buffer for formatting.
fn bufSlice(buf: *const [64]u8) []const u8 {
    var len: usize = 0;
    while (len < 64 and buf[len] != 0) : (len += 1) {}
    return buf[0..len];
}

/// Save config to ~/.config/eyes/config.json. Creates dir if needed.
pub fn save(cfg: Config) void {
    const home = std.posix.getenv("HOME") orelse return;

    // Create ~/.config/eyes/ recursively
    var dir_buf: [512]u8 = undefined;
    const dir_path = fmtPathZ(&dir_buf, "{s}/{s}", .{ home, config_dir }) orelse return;
    std.fs.cwd().makePath(dir_path) catch |err| {
        std.log.warn("config save: makePath failed: {}", .{err});
        return;
    };

    var path_buf: [512]u8 = undefined;
    const file_path = fmtPathZ(&path_buf, "{s}/{s}/{s}", .{ home, config_dir, config_file }) orelse return;

    const file = std.fs.cwd().createFileZ(file_path, .{}) catch |err| {
        std.log.warn("config save: createFile failed: {}", .{err});
        return;
    };
    defer file.close();

    const boolStr = struct {
        fn f(v: bool) [*:0]const u8 {
            return if (v) "true" else "false";
        }
    }.f;

    var json_buf: [2048]u8 = undefined;
    const json = std.fmt.bufPrint(&json_buf,
        \\{{
        \\  "work_interval_secs": {d},
        \\  "break_duration_secs": {d},
        \\  "show_timer_in_menubar": {s},
        \\  "pause_during_meetings": {s},
        \\  "mic_check_interval_secs": {d},
        \\  "posture_reminder_enabled": {s},
        \\  "posture_interval_secs": {d},
        \\  "blink_reminder_enabled": {s},
        \\  "blink_interval_secs": {d},
        \\  "idle_threshold_secs": {d},
        \\  "hydration_reminder_enabled": {s},
        \\  "hydration_interval_secs": {d},
        \\  "break_sound": {d},
        \\  "respect_dnd": {s},
        \\  "screen_lock_as_break": {s},
        \\  "use_notification": {s},
        \\  "gentle_mode": {s},
        \\  "strict_mode": {s},
        \\  "posture_gif": "{s}",
        \\  "blink_gif": "{s}",
        \\  "hydration_gif": "{s}"
        \\}}
        \\
    , .{
        cfg.work_interval_secs,
        cfg.break_duration_secs,
        boolStr(cfg.show_timer_in_menubar),
        boolStr(cfg.pause_during_meetings),
        cfg.mic_check_interval_secs,
        boolStr(cfg.posture_reminder_enabled),
        cfg.posture_interval_secs,
        boolStr(cfg.blink_reminder_enabled),
        cfg.blink_interval_secs,
        cfg.idle_threshold_secs,
        boolStr(cfg.hydration_reminder_enabled),
        cfg.hydration_interval_secs,
        cfg.break_sound,
        boolStr(cfg.respect_dnd),
        boolStr(cfg.screen_lock_as_break),
        boolStr(cfg.use_notification),
        boolStr(cfg.gentle_mode),
        boolStr(cfg.strict_mode),
        bufSlice(&cfg.posture_gif),
        bufSlice(&cfg.blink_gif),
        bufSlice(&cfg.hydration_gif),
    }) catch return;
    file.writeAll(json) catch |err| {
        std.log.warn("config save: write failed: {}", .{err});
    };
}

/// Simple JSON parser for our config fields.
fn parse(data: []const u8) Config {
    var cfg = Config{};
    cfg.work_interval_secs = parseField(data, "work_interval_secs") orelse cfg.work_interval_secs;
    cfg.break_duration_secs = parseField(data, "break_duration_secs") orelse cfg.break_duration_secs;
    cfg.show_timer_in_menubar = parseBoolField(data, "show_timer_in_menubar") orelse cfg.show_timer_in_menubar;
    cfg.pause_during_meetings = parseBoolField(data, "pause_during_meetings") orelse cfg.pause_during_meetings;
    cfg.mic_check_interval_secs = parseField(data, "mic_check_interval_secs") orelse cfg.mic_check_interval_secs;
    cfg.posture_reminder_enabled = parseBoolField(data, "posture_reminder_enabled") orelse cfg.posture_reminder_enabled;
    cfg.posture_interval_secs = parseField(data, "posture_interval_secs") orelse cfg.posture_interval_secs;
    cfg.blink_reminder_enabled = parseBoolField(data, "blink_reminder_enabled") orelse cfg.blink_reminder_enabled;
    cfg.blink_interval_secs = parseField(data, "blink_interval_secs") orelse cfg.blink_interval_secs;
    cfg.idle_threshold_secs = parseField(data, "idle_threshold_secs") orelse cfg.idle_threshold_secs;
    cfg.hydration_reminder_enabled = parseBoolField(data, "hydration_reminder_enabled") orelse cfg.hydration_reminder_enabled;
    cfg.hydration_interval_secs = parseField(data, "hydration_interval_secs") orelse cfg.hydration_interval_secs;
    if (parseField(data, "break_sound")) |v| {
        if (v <= 5) cfg.break_sound = @intCast(v);
    }
    cfg.respect_dnd = parseBoolField(data, "respect_dnd") orelse cfg.respect_dnd;
    cfg.screen_lock_as_break = parseBoolField(data, "screen_lock_as_break") orelse cfg.screen_lock_as_break;
    cfg.use_notification = parseBoolField(data, "use_notification") orelse cfg.use_notification;
    cfg.gentle_mode = parseBoolField(data, "gentle_mode") orelse cfg.gentle_mode;
    cfg.strict_mode = parseBoolField(data, "strict_mode") orelse cfg.strict_mode;
    parseStringField(data, "posture_gif", &cfg.posture_gif);
    parseStringField(data, "blink_gif", &cfg.blink_gif);
    parseStringField(data, "hydration_gif", &cfg.hydration_gif);
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

fn parseStringField(data: []const u8, key: []const u8, out: []u8) void {
    const idx = std.mem.indexOf(u8, data, key) orelse return;
    const after_key = data[idx + key.len ..];
    const colon = std.mem.indexOfScalar(u8, after_key, ':') orelse return;
    const after_colon = after_key[colon + 1 ..];

    // Find opening quote
    const open = std.mem.indexOfScalar(u8, after_colon, '"') orelse return;
    const after_open = after_colon[open + 1 ..];

    // Find closing quote
    const close = std.mem.indexOfScalar(u8, after_open, '"') orelse return;
    const value = after_open[0..close];

    if (value.len >= out.len) return; // too long
    @memset(out, 0);
    @memcpy(out[0..value.len], value);
}

/// Get a null-terminated slice from a GIF filename buffer. Returns null if empty.
pub fn gifString(buf: *const [64]u8) ?[:0]const u8 {
    if (buf[0] == 0) return null;
    // Find the null terminator
    var len: usize = 0;
    while (len < 64 and buf[len] != 0) : (len += 1) {}
    return buf[0..len :0];
}

// ---- Tests ----

test "parse default config" {
    const cfg = parse("");
    try std.testing.expectEqual(@as(u32, 20 * 60), cfg.work_interval_secs);
    try std.testing.expectEqual(@as(u32, 20), cfg.break_duration_secs);
    try std.testing.expectEqual(true, cfg.show_timer_in_menubar);
    try std.testing.expectEqual(false, cfg.pause_during_meetings);
    try std.testing.expectEqual(false, cfg.hydration_reminder_enabled);
    try std.testing.expectEqual(@as(u32, 45 * 60), cfg.hydration_interval_secs);
    try std.testing.expectEqual(@as(u8, 1), cfg.break_sound);
    try std.testing.expectEqual(true, cfg.respect_dnd);
    try std.testing.expectEqual(true, cfg.screen_lock_as_break);
    try std.testing.expectEqual(false, cfg.use_notification);
    try std.testing.expectEqual(false, cfg.gentle_mode);
    try std.testing.expectEqual(false, cfg.strict_mode);
}

test "parse full config" {
    const data =
        \\{
        \\  "work_interval_secs": 1800,
        \\  "break_duration_secs": 30,
        \\  "show_timer_in_menubar": false,
        \\  "pause_during_meetings": true,
        \\  "mic_check_interval_secs": 10,
        \\  "posture_reminder_enabled": true,
        \\  "posture_interval_secs": 900,
        \\  "blink_reminder_enabled": true,
        \\  "blink_interval_secs": 600,
        \\  "idle_threshold_secs": 180,
        \\  "hydration_reminder_enabled": true,
        \\  "hydration_interval_secs": 900,
        \\  "break_sound": 3,
        \\  "respect_dnd": false,
        \\  "screen_lock_as_break": false,
        \\  "use_notification": true,
        \\  "gentle_mode": true,
        \\  "strict_mode": true
        \\}
    ;
    const cfg = parse(data);
    try std.testing.expectEqual(@as(u32, 1800), cfg.work_interval_secs);
    try std.testing.expectEqual(@as(u32, 30), cfg.break_duration_secs);
    try std.testing.expectEqual(false, cfg.show_timer_in_menubar);
    try std.testing.expectEqual(true, cfg.pause_during_meetings);
    try std.testing.expectEqual(@as(u32, 10), cfg.mic_check_interval_secs);
    try std.testing.expectEqual(true, cfg.posture_reminder_enabled);
    try std.testing.expectEqual(@as(u32, 900), cfg.posture_interval_secs);
    try std.testing.expectEqual(true, cfg.blink_reminder_enabled);
    try std.testing.expectEqual(@as(u32, 600), cfg.blink_interval_secs);
    try std.testing.expectEqual(@as(u32, 180), cfg.idle_threshold_secs);
    try std.testing.expectEqual(true, cfg.hydration_reminder_enabled);
    try std.testing.expectEqual(@as(u32, 900), cfg.hydration_interval_secs);
    try std.testing.expectEqual(@as(u8, 3), cfg.break_sound);
    try std.testing.expectEqual(false, cfg.respect_dnd);
    try std.testing.expectEqual(false, cfg.screen_lock_as_break);
    try std.testing.expectEqual(true, cfg.use_notification);
    try std.testing.expectEqual(true, cfg.gentle_mode);
    try std.testing.expectEqual(true, cfg.strict_mode);
}

test "parseBoolField" {
    try std.testing.expectEqual(true, parseBoolField("\"foo\": true", "foo"));
    try std.testing.expectEqual(false, parseBoolField("\"foo\": false", "foo"));
    try std.testing.expectEqual(@as(?bool, null), parseBoolField("\"bar\": true", "foo"));
}

test "parseField" {
    try std.testing.expectEqual(@as(?u32, 42), parseField("\"num\": 42", "num"));
    try std.testing.expectEqual(@as(?u32, 0), parseField("\"num\": 0", "num"));
    try std.testing.expectEqual(@as(?u32, null), parseField("\"other\": 5", "num"));
    try std.testing.expectEqual(@as(?u32, null), parseField("\"num\": abc", "num"));
}
