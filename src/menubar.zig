// NSStatusBar menu bar icon and dropdown menu.

const std = @import("std");
const objc = @import("macos/objc.zig");
const appkit = @import("macos/appkit.zig");
const app_mod = @import("app.zig");
const launchagent = @import("launchagent.zig");

var status_item: objc.id = null;
var menu: objc.id = null;

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
        objc.msgSend_void1(button, objc.sel("setTitle:"), objc.nsString("👁 eyes"));
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

    if (!app_mod.state.show_timer_in_menubar) {
        objc.msgSend_void1(button, objc.sel("setTitle:"), objc.nsString(""));
        return;
    }

    var buf: [16]u8 = .{0} ** 16;
    if (app_mod.state.is_on_break) {
        const remaining: u32 = if (app_mod.state.break_seconds_remaining < 0) 0 else @intCast(app_mod.state.break_seconds_remaining);
        _ = std.fmt.bufPrint(&buf, " {d}s", .{remaining}) catch {};
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

pub fn updateMenu() void {
    const m: objc.id = menu orelse return;

    updateStatusTitle();

    appkit.removeAllItems(m);

    // Status line
    if (app_mod.state.is_on_break) {
        var buf: [32]u8 = .{0} ** 32;
        const remaining: u32 = if (app_mod.state.break_seconds_remaining < 0) 0 else @intCast(app_mod.state.break_seconds_remaining);
        _ = std.fmt.bufPrint(&buf, "Break: {d}s remaining", .{remaining}) catch {};
        const str: [*:0]const u8 = @ptrCast(&buf);
        appkit.addItem(m, appkit.createMenuItem(str, null, ""));
    } else if (app_mod.state.meeting_paused) {
        appkit.addItem(m, appkit.createMenuItem("In meeting — paused", null, ""));
    } else if (app_mod.state.is_paused) {
        appkit.addItem(m, appkit.createMenuItem("Paused", null, ""));
    } else {
        var buf: [32]u8 = .{0} ** 32;
        const time_buf = app_mod.state.formatTimeUntilBreak();
        const time_str: [*:0]const u8 = @ptrCast(&time_buf);
        _ = std.fmt.bufPrint(&buf, "Next break: {s}", .{time_str}) catch {};
        const str: [*:0]const u8 = @ptrCast(&buf);
        appkit.addItem(m, appkit.createMenuItem(str, null, ""));
    }

    appkit.addItem(m, appkit.createSeparator());

    // Pause/Resume
    const delegate = getDelegate();
    if (app_mod.state.is_paused) {
        const item = appkit.createMenuItem("Resume", objc.sel("togglePause:"), "");
        appkit.setTarget(item, delegate);
        appkit.addItem(m, item);
    } else {
        const item = appkit.createMenuItem("Pause", objc.sel("togglePause:"), "");
        appkit.setTarget(item, delegate);
        appkit.addItem(m, item);
    }

    // Take break now
    if (!app_mod.state.is_on_break) {
        const item = appkit.createMenuItem("Take Break Now", objc.sel("takeBreakNow:"), "");
        appkit.setTarget(item, delegate);
        appkit.addItem(m, item);
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
        appkit.addItem(interval_menu, pi);
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
        appkit.addItem(interval_menu, custom_item);
    }

    appkit.setSubmenu(interval_item, interval_menu);
    appkit.addItem(m, interval_item);

    // Show Timer in Menu Bar toggle
    const timer_toggle = appkit.createMenuItem("Show Timer in Menu Bar", objc.sel("toggleTimerInMenubar:"), "");
    appkit.setTarget(timer_toggle, delegate);
    appkit.setMenuItemState(timer_toggle, app_mod.state.show_timer_in_menubar);
    appkit.addItem(m, timer_toggle);

    // Start at Login toggle
    const login_toggle = appkit.createMenuItem("Start at Login", objc.sel("toggleStartAtLogin:"), "");
    appkit.setTarget(login_toggle, delegate);
    appkit.setMenuItemState(login_toggle, launchagent.isEnabled());
    appkit.addItem(m, login_toggle);

    // Pause During Meetings submenu
    const meetings_item = appkit.createMenuItem("Pause During Meetings", null, "");
    const meetings_menu = appkit.createMenu();

    const meetings_toggle = appkit.createMenuItem("Enabled", objc.sel("togglePauseDuringMeetings:"), "");
    appkit.setTarget(meetings_toggle, delegate);
    appkit.setMenuItemState(meetings_toggle, app_mod.state.pause_during_meetings);
    appkit.addItem(meetings_menu, meetings_toggle);

    appkit.addItem(meetings_menu, appkit.createSeparator());

    // Check interval presets
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
        appkit.addItem(meetings_menu, iv_item);
    }

    appkit.setSubmenu(meetings_item, meetings_menu);
    appkit.addItem(m, meetings_item);

    // Posture Reminder submenu
    const posture_item = appkit.createMenuItem("Posture Reminder", null, "");
    const posture_menu = appkit.createMenu();

    const posture_toggle = appkit.createMenuItem("Enabled", objc.sel("togglePostureReminder:"), "");
    appkit.setTarget(posture_toggle, delegate);
    appkit.setMenuItemState(posture_toggle, app_mod.state.posture_reminder_enabled);
    appkit.addItem(posture_menu, posture_toggle);

    appkit.addItem(posture_menu, appkit.createSeparator());

    const posture_intervals = [_]struct { secs: u32, label: [*:0]const u8, sel_name: [*:0]const u8 }{
        .{ .secs = 5, .label = "Every 5 sec (test)", .sel_name = "postureInterval5s:" },
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
        appkit.addItem(posture_menu, pi_item);
    }

    appkit.setSubmenu(posture_item, posture_menu);
    appkit.addItem(m, posture_item);

    // Blink Reminder submenu
    const blink_item = appkit.createMenuItem("Blink Reminder", null, "");
    const blink_menu = appkit.createMenu();

    const blink_toggle = appkit.createMenuItem("Enabled", objc.sel("toggleBlinkReminder:"), "");
    appkit.setTarget(blink_toggle, delegate);
    appkit.setMenuItemState(blink_toggle, app_mod.state.blink_reminder_enabled);
    appkit.addItem(blink_menu, blink_toggle);

    appkit.addItem(blink_menu, appkit.createSeparator());

    const blink_intervals = [_]struct { secs: u32, label: [*:0]const u8, sel_name: [*:0]const u8 }{
        .{ .secs = 5, .label = "Every 5 sec (test)", .sel_name = "blinkInterval5s:" },
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
        appkit.addItem(blink_menu, bi_item);
    }

    appkit.setSubmenu(blink_item, blink_menu);
    appkit.addItem(m, blink_item);

    appkit.addItem(m, appkit.createSeparator());

    // Quit
    const quit_item = appkit.createMenuItem("Quit Eyes", objc.sel("quitApp:"), "q");
    appkit.setTarget(quit_item, delegate);
    appkit.addItem(m, quit_item);
}

fn getDelegate() objc.id {
    return objc.msgSend_id(appkit.sharedApplication(), objc.sel("delegate"));
}
