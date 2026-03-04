// NSStatusBar menu bar icon and dropdown menu.

const std = @import("std");
const objc = @import("macos/objc.zig");
const appkit = @import("macos/appkit.zig");
const app_mod = @import("app.zig");
const launchagent = @import("launchagent.zig");

var status_item: objc.id = null;
var menu: objc.id = null;
var status_line_item: objc.id = null;
var stats_line_item: objc.id = null;
var dirty: bool = true;

// Presets: { work_secs, break_secs, label, selector }
const Preset = struct {
    work: u32,
    brk: u32,
    label: [*:0]const u8,
    sel_name: [*:0]const u8,
};

pub const presets = [_]Preset{
    .{ .work = 20 * 60, .brk = 20, .label = "20 min / 20 sec (20-20-20)", .sel_name = "preset20_20:" },
    .{ .work = 30 * 60, .brk = 30, .label = "30 min / 30 sec", .sel_name = "preset30_30:" },
    .{ .work = 45 * 60, .brk = 5 * 60, .label = "45 min / 5 min", .sel_name = "preset45_5:" },
    .{ .work = 60 * 60, .brk = 5 * 60, .label = "60 min / 5 min", .sel_name = "preset60_5:" },
};

pub fn markDirty() void {
    dirty = true;
}

/// Add a menu item and release the caller's +1 reference (menu retains it).
fn addItemAndRelease(m: objc.id, item: objc.id) void {
    appkit.addItem(m, item);
    objc.release(item);
}

pub fn setup() void {
    // Create status bar item
    const bar = appkit.systemStatusBar();
    const item = appkit.statusItemWithLength(bar, appkit.NSVariableStatusItemLength);
    // Retain — the status bar doesn't retain the item for us
    _ = objc.retain(item);
    status_item = item;

    // Set title on the status item button
    const button = objc.msgSend_id(item, objc.sel("button"));

    if (button == null) {
        std.log.err("Failed to get status item button", .{});
        return;
    }

    // Try SF Symbol for eye icon, fall back to text title
    const eye_image = appkit.imageWithSystemSymbolName("eye");
    if (eye_image != null) {
        appkit.setImageSize(eye_image, objc.NSSize{ .width = 18.0, .height = 18.0 });
        objc.msgSend_void1(button, objc.sel("setImage:"), eye_image);
        // setTemplate so it adapts to light/dark menu bar
        objc.msgSend_void1(eye_image, objc.sel("setTemplate:"), @as(c_char, 1));
        // NSImageLeft = 2 — show image on left, title on right
        objc.msgSend_void1(button, objc.sel("setImagePosition:"), @as(c_ulong, 2));
    } else {
        // Fallback: plain text
        objc.msgSend_void1(button, objc.sel("setTitle:"), objc.nsString("eyes"));
    }

    // Create and attach menu
    menu = appkit.createMenu();
    _ = objc.retain(menu);
    objc.msgSend_void1(item, objc.sel("setMenu:"), menu);

    updateMenu();
    std.log.info("Menu bar setup complete", .{});
}

fn updateStatusTitle() void {
    const item: objc.id = status_item orelse return;
    const button = objc.msgSend_id(item, objc.sel("button"));
    if (button == null) return;

    // Update icon based on state
    const icon_name: [*:0]const u8 = if (app_mod.state.is_paused or (app_mod.state.is_dnd_active and app_mod.state.respect_dnd) or app_mod.state.meeting_paused)
        "eye.slash"
    else
        "eye";
    const eye_image = appkit.imageWithSystemSymbolName(icon_name);
    if (eye_image != null) {
        appkit.setImageSize(eye_image, objc.NSSize{ .width = 18.0, .height = 18.0 });
        objc.msgSend_void1(button, objc.sel("setImage:"), eye_image);
        objc.msgSend_void1(eye_image, objc.sel("setTemplate:"), @as(c_char, 1));
    }

    if (!app_mod.state.show_timer_in_menubar) {
        objc.msgSend_void1(button, objc.sel("setTitle:"), objc.nsString(""));
        return;
    }

    var buf: [16]u8 = .{0} ** 16;
    if (app_mod.state.is_on_break) {
        const remaining: u32 = if (app_mod.state.break_seconds_remaining < 0) 0 else @intCast(app_mod.state.break_seconds_remaining);
        _ = std.fmt.bufPrint(&buf, " {d}s", .{remaining}) catch {};
    } else if (app_mod.state.is_dnd_active and app_mod.state.respect_dnd) {
        _ = std.fmt.bufPrint(&buf, " focus", .{}) catch {};
    } else if (app_mod.state.meeting_paused) {
        _ = std.fmt.bufPrint(&buf, " meeting", .{}) catch {};
    } else if (app_mod.state.is_paused) {
        _ = std.fmt.bufPrint(&buf, " paused", .{}) catch {};
    } else {
        const time_buf = app_mod.state.formatTimeUntilBreak();
        const time_str: [*:0]const u8 = @ptrCast(&time_buf);
        _ = std.fmt.bufPrint(&buf, " {s}", .{time_str}) catch {};
    }
    const str: [*:0]const u8 = @ptrCast(&buf);
    objc.msgSend_void1(button, objc.sel("setTitle:"), objc.nsString(str));
}

fn updateStatusLine() void {
    const item: objc.id = status_line_item orelse return;

    if (app_mod.state.is_on_break) {
        var buf: [32]u8 = .{0} ** 32;
        const remaining: u32 = if (app_mod.state.break_seconds_remaining < 0) 0 else @intCast(app_mod.state.break_seconds_remaining);
        _ = std.fmt.bufPrint(&buf, "Break: {d}s remaining", .{remaining}) catch {};
        const str: [*:0]const u8 = @ptrCast(&buf);
        appkit.setStringValue_menuItem(item, str);
    } else if (app_mod.state.is_dnd_active and app_mod.state.respect_dnd) {
        appkit.setStringValue_menuItem(item, "Focus active \xe2\x80\x94 paused");
    } else if (app_mod.state.meeting_paused) {
        appkit.setStringValue_menuItem(item, "In meeting \xe2\x80\x94 paused");
    } else if (app_mod.state.is_paused) {
        appkit.setStringValue_menuItem(item, "Paused");
    } else {
        var buf: [32]u8 = .{0} ** 32;
        const time_buf = app_mod.state.formatTimeUntilBreak();
        const time_str: [*:0]const u8 = @ptrCast(&time_buf);
        _ = std.fmt.bufPrint(&buf, "Next break: {s}", .{time_str}) catch {};
        const str: [*:0]const u8 = @ptrCast(&buf);
        appkit.setStringValue_menuItem(item, str);
    }
}

fn updateStatsLine() void {
    const item: objc.id = stats_line_item orelse return;
    const s = &app_mod.state;
    const total = s.breaks_taken + s.breaks_skipped + s.breaks_delayed;
    if (total == 0) {
        appkit.setStringValue_menuItem(item, "");
        return;
    }
    var buf: [64]u8 = .{0} ** 64;
    _ = std.fmt.bufPrint(&buf, "Today: {d} taken, {d} skipped, {d} delayed", .{ s.breaks_taken, s.breaks_skipped, s.breaks_delayed }) catch {};
    const str: [*:0]const u8 = @ptrCast(&buf);
    appkit.setStringValue_menuItem(item, str);
}

pub fn updateMenu() void {
    const m: objc.id = menu orelse return;

    updateStatusTitle();

    // Fast path: only update the status line text and menu bar title
    if (!dirty and status_line_item != null) {
        updateStatusLine();
        updateStatsLine();
        return;
    }
    dirty = false;

    // Release the old status/stats line items before rebuilding
    if (status_line_item != null) {
        objc.release(status_line_item);
        status_line_item = null;
    }
    if (stats_line_item != null) {
        objc.release(stats_line_item);
        stats_line_item = null;
    }

    appkit.removeAllItems(m);

    // Status line
    if (app_mod.state.is_on_break) {
        var buf: [32]u8 = .{0} ** 32;
        const remaining: u32 = if (app_mod.state.break_seconds_remaining < 0) 0 else @intCast(app_mod.state.break_seconds_remaining);
        _ = std.fmt.bufPrint(&buf, "Break: {d}s remaining", .{remaining}) catch {};
        const str: [*:0]const u8 = @ptrCast(&buf);
        status_line_item = appkit.createMenuItem(str, null, "");
    } else if (app_mod.state.is_dnd_active and app_mod.state.respect_dnd) {
        status_line_item = appkit.createMenuItem("Focus active \xe2\x80\x94 paused", null, "");
    } else if (app_mod.state.meeting_paused) {
        status_line_item = appkit.createMenuItem("In meeting \xe2\x80\x94 paused", null, "");
    } else if (app_mod.state.is_paused) {
        status_line_item = appkit.createMenuItem("Paused", null, "");
    } else {
        var buf: [32]u8 = .{0} ** 32;
        const time_buf = app_mod.state.formatTimeUntilBreak();
        const time_str: [*:0]const u8 = @ptrCast(&time_buf);
        _ = std.fmt.bufPrint(&buf, "Next break: {s}", .{time_str}) catch {};
        const str: [*:0]const u8 = @ptrCast(&buf);
        status_line_item = appkit.createMenuItem(str, null, "");
    }
    appkit.addItem(m, status_line_item); // keep +1 ref for fast-path updates

    // Stats line (non-clickable, only shown if any stats)
    {
        const s = &app_mod.state;
        const total = s.breaks_taken + s.breaks_skipped + s.breaks_delayed;
        if (total > 0) {
            var buf: [64]u8 = .{0} ** 64;
            _ = std.fmt.bufPrint(&buf, "Today: {d} taken, {d} skipped, {d} delayed", .{ s.breaks_taken, s.breaks_skipped, s.breaks_delayed }) catch {};
            const str: [*:0]const u8 = @ptrCast(&buf);
            stats_line_item = appkit.createMenuItem(str, null, "");
        } else {
            stats_line_item = appkit.createMenuItem("", null, "");
        }
        appkit.addItem(m, stats_line_item);
    }

    appkit.addItem(m, appkit.createSeparator());

    // Pause/Resume
    const delegate = getDelegate();
    {
        const pause_key: [1:0]u8 = .{app_mod.state.hotkey_pause};
        const item = appkit.createMenuItem(if (app_mod.state.is_paused) "Resume" else "Pause", objc.sel("togglePause:"), &pause_key);
        appkit.setTarget(item, delegate);
        addItemAndRelease(m, item);
    }

    // Take break now
    if (!app_mod.state.is_on_break) {
        const break_key: [1:0]u8 = .{app_mod.state.hotkey_break};
        const item = appkit.createMenuItem("Take Break Now", objc.sel("takeBreakNow:"), &break_key);
        appkit.setTarget(item, delegate);
        addItemAndRelease(m, item);
    }

    appkit.addItem(m, appkit.createSeparator());

    // Interval submenu
    const interval_item = appkit.createMenuItem("Interval", null, "");
    const interval_menu = appkit.createMenu();

    const work = app_mod.state.work_interval_secs;
    const brk = app_mod.state.break_duration_secs;

    var matched_preset = false;
    for (presets) |p| {
        const pi = appkit.createMenuItem(p.label, objc.sel(p.sel_name), "");
        appkit.setTarget(pi, delegate);
        if (work == p.work and brk == p.brk) {
            appkit.setMenuItemState(pi, true);
            matched_preset = true;
        }
        addItemAndRelease(interval_menu, pi);
    }

    // Show "Custom" line when config doesn't match any preset
    if (!matched_preset) {
        appkit.addItem(interval_menu, appkit.createSeparator());
        var custom_buf: [48]u8 = .{0} ** 48;
        const work_min = work / 60;
        const brk_display = if (brk >= 60) brk / 60 else brk;
        const brk_unit: [*:0]const u8 = if (brk >= 60) "min" else "sec";
        _ = std.fmt.bufPrint(&custom_buf, "Custom ({d} min / {d} {s})", .{ work_min, brk_display, brk_unit }) catch {};
        const custom_str: [*:0]const u8 = @ptrCast(&custom_buf);
        const custom_item = appkit.createMenuItem(custom_str, null, "");
        appkit.setMenuItemState(custom_item, true);
        addItemAndRelease(interval_menu, custom_item);
    }

    // Custom... entry
    appkit.addItem(interval_menu, appkit.createSeparator());
    {
        const ci = appkit.createMenuItem("Custom...", objc.sel("customInterval:"), "");
        appkit.setTarget(ci, delegate);
        addItemAndRelease(interval_menu, ci);
    }

    appkit.setSubmenu(interval_item, interval_menu);
    objc.release(interval_menu);
    addItemAndRelease(m, interval_item);

    // Break Sound submenu
    {
        const sound_item = appkit.createMenuItem("Break Sound", null, "");
        const sound_menu = appkit.createMenu();

        const sound_options = [_]struct { val: u8, label: [*:0]const u8, sel_name: [*:0]const u8 }{
            .{ .val = 0, .label = "None", .sel_name = "soundNone:" },
            .{ .val = 1, .label = "Tink", .sel_name = "soundTink:" },
            .{ .val = 2, .label = "Pop", .sel_name = "soundPop:" },
            .{ .val = 3, .label = "Glass", .sel_name = "soundGlass:" },
            .{ .val = 4, .label = "Purr", .sel_name = "soundPurr:" },
            .{ .val = 5, .label = "Hero", .sel_name = "soundHero:" },
        };
        for (sound_options) |so| {
            const si = appkit.createMenuItem(so.label, objc.sel(so.sel_name), "");
            appkit.setTarget(si, delegate);
            if (app_mod.state.break_sound == so.val) {
                appkit.setMenuItemState(si, true);
            }
            addItemAndRelease(sound_menu, si);
        }

        appkit.setSubmenu(sound_item, sound_menu);
        objc.release(sound_menu);
        addItemAndRelease(m, sound_item);
    }

    // Show Timer in Menu Bar toggle
    {
        const item = appkit.createMenuItem("Show Timer in Menu Bar", objc.sel("toggleTimerInMenubar:"), "");
        appkit.setTarget(item, delegate);
        appkit.setMenuItemState(item, app_mod.state.show_timer_in_menubar);
        addItemAndRelease(m, item);
    }

    // Start at Login toggle
    {
        const item = appkit.createMenuItem("Start at Login", objc.sel("toggleStartAtLogin:"), "");
        appkit.setTarget(item, delegate);
        appkit.setMenuItemState(item, launchagent.isEnabled());
        addItemAndRelease(m, item);
    }

    appkit.addItem(m, appkit.createSeparator());

    // --- Feature toggles ---

    // Show as Notification toggle
    {
        const item = appkit.createMenuItem("Show as Notification", objc.sel("toggleNotification:"), "");
        appkit.setTarget(item, delegate);
        appkit.setMenuItemState(item, app_mod.state.use_notification);
        addItemAndRelease(m, item);
    }

    // Gentle Mode toggle
    {
        const item = appkit.createMenuItem("Gentle Mode (Banner)", objc.sel("toggleGentleMode:"), "");
        appkit.setTarget(item, delegate);
        appkit.setMenuItemState(item, app_mod.state.gentle_mode);
        addItemAndRelease(m, item);
    }

    // Strict Mode toggle
    {
        const item = appkit.createMenuItem("Strict Mode (No Skip)", objc.sel("toggleStrictMode:"), "");
        appkit.setTarget(item, delegate);
        appkit.setMenuItemState(item, app_mod.state.strict_mode);
        addItemAndRelease(m, item);
    }

    // Respect Do Not Disturb toggle
    {
        const item = appkit.createMenuItem("Respect Do Not Disturb", objc.sel("toggleRespectDND:"), "");
        appkit.setTarget(item, delegate);
        appkit.setMenuItemState(item, app_mod.state.respect_dnd);
        addItemAndRelease(m, item);
    }

    // Screen Lock Counts as Break toggle
    {
        const item = appkit.createMenuItem("Screen Lock as Break", objc.sel("toggleScreenLockAsBreak:"), "");
        appkit.setTarget(item, delegate);
        appkit.setMenuItemState(item, app_mod.state.screen_lock_as_break);
        addItemAndRelease(m, item);
    }

    appkit.addItem(m, appkit.createSeparator());

    // Pause During Meetings submenu
    {
        const meetings_item = appkit.createMenuItem("Pause During Meetings", null, "");
        const meetings_menu = appkit.createMenu();

        const mic_toggle = appkit.createMenuItem("Mic Detection", objc.sel("togglePauseDuringMeetings:"), "");
        appkit.setTarget(mic_toggle, delegate);
        appkit.setMenuItemState(mic_toggle, app_mod.state.pause_during_meetings);
        addItemAndRelease(meetings_menu, mic_toggle);

        const smart_toggle = appkit.createMenuItem("Smart Detection (Window Titles)", objc.sel("toggleSmartMeetingDetection:"), "");
        appkit.setTarget(smart_toggle, delegate);
        appkit.setMenuItemState(smart_toggle, app_mod.state.smart_meeting_detection);
        addItemAndRelease(meetings_menu, smart_toggle);

        appkit.addItem(meetings_menu, appkit.createSeparator());

        const intervals = [_]struct { secs: u32, label: [*:0]const u8, sel_name: [*:0]const u8 }{
            .{ .secs = 1, .label = "Check every 1 sec", .sel_name = "micInterval1:" },
            .{ .secs = 5, .label = "Check every 5 sec", .sel_name = "micInterval5:" },
            .{ .secs = 10, .label = "Check every 10 sec", .sel_name = "micInterval10:" },
            .{ .secs = 30, .label = "Check every 30 sec", .sel_name = "micInterval30:" },
        };
        for (intervals) |iv| {
            const iv_item = appkit.createMenuItem(iv.label, objc.sel(iv.sel_name), "");
            appkit.setTarget(iv_item, delegate);
            if (app_mod.state.mic_check_interval_secs == iv.secs) {
                appkit.setMenuItemState(iv_item, true);
            }
            addItemAndRelease(meetings_menu, iv_item);
        }

        appkit.setSubmenu(meetings_item, meetings_menu);
        objc.release(meetings_menu);
        addItemAndRelease(m, meetings_item);
    }

    // Idle Detection submenu
    {
        const idle_item = appkit.createMenuItem("Idle Detection", null, "");
        const idle_menu = appkit.createMenu();

        const idle_options = [_]struct { secs: u32, label: [*:0]const u8, sel_name: [*:0]const u8 }{
            .{ .secs = 0, .label = "Off", .sel_name = "idleOff:" },
            .{ .secs = 3 * 60, .label = "3 minutes", .sel_name = "idle3min:" },
            .{ .secs = 5 * 60, .label = "5 minutes", .sel_name = "idle5min:" },
            .{ .secs = 10 * 60, .label = "10 minutes", .sel_name = "idle10min:" },
        };
        for (idle_options) |io| {
            const io_item = appkit.createMenuItem(io.label, objc.sel(io.sel_name), "");
            appkit.setTarget(io_item, delegate);
            if (app_mod.state.idle_threshold_secs == io.secs) {
                appkit.setMenuItemState(io_item, true);
            }
            addItemAndRelease(idle_menu, io_item);
        }

        appkit.setSubmenu(idle_item, idle_menu);
        objc.release(idle_menu);
        addItemAndRelease(m, idle_item);
    }

    // Posture Reminder submenu
    {
        const posture_item = appkit.createMenuItem("Posture Reminder", null, "");
        const posture_menu = appkit.createMenu();

        const posture_toggle = appkit.createMenuItem("Enabled", objc.sel("togglePostureReminder:"), "");
        appkit.setTarget(posture_toggle, delegate);
        appkit.setMenuItemState(posture_toggle, app_mod.state.posture_reminder_enabled);
        addItemAndRelease(posture_menu, posture_toggle);

        appkit.addItem(posture_menu, appkit.createSeparator());

        if (app_mod.state.show_test_settings) {
            const test_item = appkit.createMenuItem("Every 5 sec (test)", objc.sel("postureInterval5s:"), "");
            appkit.setTarget(test_item, delegate);
            if (app_mod.state.posture_interval_secs == 5) appkit.setMenuItemState(test_item, true);
            addItemAndRelease(posture_menu, test_item);
        }

        const posture_intervals = [_]struct { secs: u32, label: [*:0]const u8, sel_name: [*:0]const u8 }{
            .{ .secs = 15 * 60, .label = "Every 15 min", .sel_name = "postureInterval15:" },
            .{ .secs = 30 * 60, .label = "Every 30 min", .sel_name = "postureInterval30:" },
            .{ .secs = 45 * 60, .label = "Every 45 min", .sel_name = "postureInterval45:" },
            .{ .secs = 60 * 60, .label = "Every 60 min", .sel_name = "postureInterval60:" },
        };
        for (posture_intervals) |pi| {
            const pi_item = appkit.createMenuItem(pi.label, objc.sel(pi.sel_name), "");
            appkit.setTarget(pi_item, delegate);
            if (app_mod.state.posture_interval_secs == pi.secs) {
                appkit.setMenuItemState(pi_item, true);
            }
            addItemAndRelease(posture_menu, pi_item);
        }

        appkit.setSubmenu(posture_item, posture_menu);
        objc.release(posture_menu);
        addItemAndRelease(m, posture_item);
    }

    // Blink Reminder submenu
    {
        const blink_item = appkit.createMenuItem("Blink Reminder", null, "");
        const blink_menu = appkit.createMenu();

        const blink_toggle = appkit.createMenuItem("Enabled", objc.sel("toggleBlinkReminder:"), "");
        appkit.setTarget(blink_toggle, delegate);
        appkit.setMenuItemState(blink_toggle, app_mod.state.blink_reminder_enabled);
        addItemAndRelease(blink_menu, blink_toggle);

        appkit.addItem(blink_menu, appkit.createSeparator());

        if (app_mod.state.show_test_settings) {
            const test_item = appkit.createMenuItem("Every 5 sec (test)", objc.sel("blinkInterval5s:"), "");
            appkit.setTarget(test_item, delegate);
            if (app_mod.state.blink_interval_secs == 5) appkit.setMenuItemState(test_item, true);
            addItemAndRelease(blink_menu, test_item);
        }

        const blink_intervals = [_]struct { secs: u32, label: [*:0]const u8, sel_name: [*:0]const u8 }{
            .{ .secs = 15 * 60, .label = "Every 15 min", .sel_name = "blinkInterval15:" },
            .{ .secs = 30 * 60, .label = "Every 30 min", .sel_name = "blinkInterval30:" },
            .{ .secs = 45 * 60, .label = "Every 45 min", .sel_name = "blinkInterval45:" },
            .{ .secs = 60 * 60, .label = "Every 60 min", .sel_name = "blinkInterval60:" },
        };
        for (blink_intervals) |bi| {
            const bi_item = appkit.createMenuItem(bi.label, objc.sel(bi.sel_name), "");
            appkit.setTarget(bi_item, delegate);
            if (app_mod.state.blink_interval_secs == bi.secs) {
                appkit.setMenuItemState(bi_item, true);
            }
            addItemAndRelease(blink_menu, bi_item);
        }

        appkit.setSubmenu(blink_item, blink_menu);
        objc.release(blink_menu);
        addItemAndRelease(m, blink_item);
    }

    // Hydration Reminder submenu
    {
        const hydration_item = appkit.createMenuItem("Hydration Reminder", null, "");
        const hydration_menu = appkit.createMenu();

        const hydration_toggle = appkit.createMenuItem("Enabled", objc.sel("toggleHydrationReminder:"), "");
        appkit.setTarget(hydration_toggle, delegate);
        appkit.setMenuItemState(hydration_toggle, app_mod.state.hydration_reminder_enabled);
        addItemAndRelease(hydration_menu, hydration_toggle);

        appkit.addItem(hydration_menu, appkit.createSeparator());

        if (app_mod.state.show_test_settings) {
            const test_item = appkit.createMenuItem("Every 5 sec (test)", objc.sel("hydrationInterval5s:"), "");
            appkit.setTarget(test_item, delegate);
            if (app_mod.state.hydration_interval_secs == 5) appkit.setMenuItemState(test_item, true);
            addItemAndRelease(hydration_menu, test_item);
        }

        const hydration_intervals = [_]struct { secs: u32, label: [*:0]const u8, sel_name: [*:0]const u8 }{
            .{ .secs = 15 * 60, .label = "Every 15 min", .sel_name = "hydrationInterval15:" },
            .{ .secs = 30 * 60, .label = "Every 30 min", .sel_name = "hydrationInterval30:" },
            .{ .secs = 45 * 60, .label = "Every 45 min", .sel_name = "hydrationInterval45:" },
            .{ .secs = 60 * 60, .label = "Every 60 min", .sel_name = "hydrationInterval60:" },
        };
        for (hydration_intervals) |hi| {
            const hi_item = appkit.createMenuItem(hi.label, objc.sel(hi.sel_name), "");
            appkit.setTarget(hi_item, delegate);
            if (app_mod.state.hydration_interval_secs == hi.secs) {
                appkit.setMenuItemState(hi_item, true);
            }
            addItemAndRelease(hydration_menu, hi_item);
        }

        appkit.setSubmenu(hydration_item, hydration_menu);
        objc.release(hydration_menu);
        addItemAndRelease(m, hydration_item);
    }

    // Stretch Reminder submenu
    {
        const stretch_item = appkit.createMenuItem("Stretch Reminder", null, "");
        const stretch_menu = appkit.createMenu();

        const stretch_toggle = appkit.createMenuItem("Enabled", objc.sel("toggleStretchReminder:"), "");
        appkit.setTarget(stretch_toggle, delegate);
        appkit.setMenuItemState(stretch_toggle, app_mod.state.stretch_reminder_enabled);
        addItemAndRelease(stretch_menu, stretch_toggle);

        appkit.addItem(stretch_menu, appkit.createSeparator());

        if (app_mod.state.show_test_settings) {
            const test_item = appkit.createMenuItem("Every 5 sec (test)", objc.sel("stretchInterval5s:"), "");
            appkit.setTarget(test_item, delegate);
            if (app_mod.state.stretch_interval_secs == 5) appkit.setMenuItemState(test_item, true);
            addItemAndRelease(stretch_menu, test_item);
        }

        const stretch_intervals = [_]struct { secs: u32, label: [*:0]const u8, sel_name: [*:0]const u8 }{
            .{ .secs = 15 * 60, .label = "Every 15 min", .sel_name = "stretchInterval15:" },
            .{ .secs = 30 * 60, .label = "Every 30 min", .sel_name = "stretchInterval30:" },
            .{ .secs = 45 * 60, .label = "Every 45 min", .sel_name = "stretchInterval45:" },
            .{ .secs = 60 * 60, .label = "Every 60 min", .sel_name = "stretchInterval60:" },
        };
        for (stretch_intervals) |si| {
            const si_item = appkit.createMenuItem(si.label, objc.sel(si.sel_name), "");
            appkit.setTarget(si_item, delegate);
            if (app_mod.state.stretch_interval_secs == si.secs) {
                appkit.setMenuItemState(si_item, true);
            }
            addItemAndRelease(stretch_menu, si_item);
        }

        appkit.setSubmenu(stretch_item, stretch_menu);
        objc.release(stretch_menu);
        addItemAndRelease(m, stretch_item);
    }

    // Big Break submenu
    {
        const bb_item = appkit.createMenuItem("Big Break", null, "");
        const bb_menu = appkit.createMenu();

        const bb_toggle = appkit.createMenuItem("Enabled", objc.sel("toggleBigBreak:"), "");
        appkit.setTarget(bb_toggle, delegate);
        appkit.setMenuItemState(bb_toggle, app_mod.state.big_break_enabled);
        addItemAndRelease(bb_menu, bb_toggle);

        {
            const bb_now = appkit.createMenuItem("Take Big Break Now", objc.sel("takeBigBreakNow:"), "");
            appkit.setTarget(bb_now, delegate);
            addItemAndRelease(bb_menu, bb_now);
        }

        appkit.addItem(bb_menu, appkit.createSeparator());

        // Interval sub-options
        {
            const interval_label = appkit.createMenuItem("Interval", null, "");
            const interval_sub = appkit.createMenu();

            const bb_intervals = [_]struct { secs: u32, label: [*:0]const u8, sel_name: [*:0]const u8 }{
                .{ .secs = 30 * 60, .label = "Every 30 min", .sel_name = "bigBreakInterval30m:" },
                .{ .secs = 60 * 60, .label = "Every 60 min", .sel_name = "bigBreakInterval60m:" },
                .{ .secs = 90 * 60, .label = "Every 90 min", .sel_name = "bigBreakInterval90m:" },
                .{ .secs = 120 * 60, .label = "Every 120 min", .sel_name = "bigBreakInterval120m:" },
            };
            for (bb_intervals) |bi| {
                const bi_item = appkit.createMenuItem(bi.label, objc.sel(bi.sel_name), "");
                appkit.setTarget(bi_item, delegate);
                if (app_mod.state.big_break_interval_secs == bi.secs) {
                    appkit.setMenuItemState(bi_item, true);
                }
                addItemAndRelease(interval_sub, bi_item);
            }

            appkit.setSubmenu(interval_label, interval_sub);
            objc.release(interval_sub);
            addItemAndRelease(bb_menu, interval_label);
        }

        // Duration sub-options
        {
            const duration_label = appkit.createMenuItem("Duration", null, "");
            const duration_sub = appkit.createMenu();

            const bb_durations = [_]struct { secs: u32, label: [*:0]const u8, sel_name: [*:0]const u8 }{
                .{ .secs = 2 * 60, .label = "2 min", .sel_name = "bigBreakDuration2m:" },
                .{ .secs = 5 * 60, .label = "5 min", .sel_name = "bigBreakDuration5m:" },
                .{ .secs = 10 * 60, .label = "10 min", .sel_name = "bigBreakDuration10m:" },
                .{ .secs = 15 * 60, .label = "15 min", .sel_name = "bigBreakDuration15m:" },
            };
            for (bb_durations) |bd| {
                const bd_item = appkit.createMenuItem(bd.label, objc.sel(bd.sel_name), "");
                appkit.setTarget(bd_item, delegate);
                if (app_mod.state.big_break_duration_secs == bd.secs) {
                    appkit.setMenuItemState(bd_item, true);
                }
                addItemAndRelease(duration_sub, bd_item);
            }

            appkit.setSubmenu(duration_label, duration_sub);
            objc.release(duration_sub);
            addItemAndRelease(bb_menu, duration_label);
        }

        // Trigger mode: time vs every N breaks
        {
            const trigger_label = appkit.createMenuItem("Trigger", null, "");
            const trigger_sub = appkit.createMenu();

            const trigger_opts = [_]struct { n: u32, label: [*:0]const u8, sel_name: [*:0]const u8 }{
                .{ .n = 0, .label = "By Time Interval", .sel_name = "bigBreakEveryN0:" },
                .{ .n = 3, .label = "Every 3 Breaks", .sel_name = "bigBreakEveryN3:" },
                .{ .n = 4, .label = "Every 4 Breaks", .sel_name = "bigBreakEveryN4:" },
                .{ .n = 5, .label = "Every 5 Breaks", .sel_name = "bigBreakEveryN5:" },
                .{ .n = 6, .label = "Every 6 Breaks", .sel_name = "bigBreakEveryN6:" },
            };
            for (trigger_opts) |opt| {
                const opt_item = appkit.createMenuItem(opt.label, objc.sel(opt.sel_name), "");
                appkit.setTarget(opt_item, delegate);
                if (app_mod.state.big_break_every_n == opt.n) {
                    appkit.setMenuItemState(opt_item, true);
                }
                addItemAndRelease(trigger_sub, opt_item);
            }

            appkit.setSubmenu(trigger_label, trigger_sub);
            objc.release(trigger_sub);
            addItemAndRelease(bb_menu, trigger_label);
        }

        appkit.setSubmenu(bb_item, bb_menu);
        objc.release(bb_menu);
        addItemAndRelease(m, bb_item);
    }

    appkit.addItem(m, appkit.createSeparator());

    // About Eyes
    {
        const item = appkit.createMenuItem("About Eyes", objc.sel("showAbout:"), "");
        appkit.setTarget(item, delegate);
        addItemAndRelease(m, item);
    }

    // Quit
    {
        const item = appkit.createMenuItem("Quit Eyes", objc.sel("quitApp:"), "q");
        appkit.setTarget(item, delegate);
        addItemAndRelease(m, item);
    }
}

fn getDelegate() objc.id {
    return objc.msgSend_id(appkit.sharedApplication(), objc.sel("delegate"));
}
