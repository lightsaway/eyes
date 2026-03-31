// Linux system tray via libappindicator3 + GtkMenu.

const std = @import("std");
const gtk = @import("gtk.zig");
const c = gtk.c;
const app_mod = @import("../app.zig");
const actions = @import("../actions.zig");
const autostart = @import("autostart.zig");

var indicator: ?*c.AppIndicator = null;
var menu: ?*c.GtkWidget = null;
var dirty: bool = true;

// Action dispatch — pack an enum value into user_data pointer
const MenuAction = enum(u32) {
    toggle_pause,
    take_break_now,
    skip_break,
    delay_1min,
    delay_5min,
    toggle_timer,
    toggle_notification,
    toggle_gentle,
    toggle_strict,
    toggle_dnd,
    toggle_screen_lock,
    toggle_meetings,
    toggle_smart_meeting,
    toggle_start_at_login,
    preset_20_20,
    preset_30_30,
    preset_45_5,
    preset_60_5,
    idle_off,
    idle_3min,
    idle_5min,
    idle_10min,
    mic_1,
    mic_5,
    mic_10,
    mic_30,
    sound_none,
    sound_tink,
    sound_pop,
    sound_glass,
    sound_purr,
    sound_hero,
    toggle_posture,
    posture_15,
    posture_30,
    posture_45,
    posture_60,
    toggle_blink,
    blink_15,
    blink_30,
    blink_45,
    blink_60,
    toggle_hydration,
    hydration_15,
    hydration_30,
    hydration_45,
    hydration_60,
    toggle_stretch,
    stretch_15,
    stretch_30,
    stretch_45,
    stretch_60,
    toggle_big_break,
    take_big_break_now,
    big_interval_30m,
    big_interval_60m,
    big_interval_90m,
    big_interval_120m,
    big_duration_2m,
    big_duration_5m,
    big_duration_10m,
    big_duration_15m,
    big_every_n_0,
    big_every_n_3,
    big_every_n_4,
    big_every_n_5,
    big_every_n_6,
    show_about,
    quit,
};

fn onMenuAction(_: ?*c.GtkMenuItem, user_data: ?*anyopaque) callconv(.c) void {
    const action: MenuAction = @enumFromInt(@intFromPtr(user_data));
    switch (action) {
        .toggle_pause => actions.togglePause(),
        .take_break_now => actions.takeBreakNow(),
        .skip_break => actions.skipBreak(),
        .delay_1min => actions.delay1Min(),
        .delay_5min => actions.delay5Min(),
        .toggle_timer => actions.toggleTimerInMenubar(),
        .toggle_notification => actions.toggleNotification(),
        .toggle_gentle => actions.toggleGentleMode(),
        .toggle_strict => actions.toggleStrictMode(),
        .toggle_dnd => actions.toggleRespectDND(),
        .toggle_screen_lock => actions.toggleScreenLockAsBreak(),
        .toggle_meetings => actions.togglePauseDuringMeetings(),
        .toggle_smart_meeting => actions.toggleSmartMeetingDetection(),
        .toggle_start_at_login => {
            autostart.setEnabled(!autostart.isEnabled());
            markDirty();
            updateMenu();
        },
        .preset_20_20 => actions.applyPreset(20 * 60, 20),
        .preset_30_30 => actions.applyPreset(30 * 60, 30),
        .preset_45_5 => actions.applyPreset(45 * 60, 5 * 60),
        .preset_60_5 => actions.applyPreset(60 * 60, 5 * 60),
        .idle_off => actions.setIdleThreshold(0),
        .idle_3min => actions.setIdleThreshold(3 * 60),
        .idle_5min => actions.setIdleThreshold(5 * 60),
        .idle_10min => actions.setIdleThreshold(10 * 60),
        .mic_1 => actions.setMicInterval(1),
        .mic_5 => actions.setMicInterval(5),
        .mic_10 => actions.setMicInterval(10),
        .mic_30 => actions.setMicInterval(30),
        .sound_none => actions.setBreakSound(0),
        .sound_tink => actions.setBreakSound(1),
        .sound_pop => actions.setBreakSound(2),
        .sound_glass => actions.setBreakSound(3),
        .sound_purr => actions.setBreakSound(4),
        .sound_hero => actions.setBreakSound(5),
        .toggle_posture => actions.togglePostureReminder(),
        .posture_15 => actions.setPostureInterval(15 * 60),
        .posture_30 => actions.setPostureInterval(30 * 60),
        .posture_45 => actions.setPostureInterval(45 * 60),
        .posture_60 => actions.setPostureInterval(60 * 60),
        .toggle_blink => actions.toggleBlinkReminder(),
        .blink_15 => actions.setBlinkInterval(15 * 60),
        .blink_30 => actions.setBlinkInterval(30 * 60),
        .blink_45 => actions.setBlinkInterval(45 * 60),
        .blink_60 => actions.setBlinkInterval(60 * 60),
        .toggle_hydration => actions.toggleHydrationReminder(),
        .hydration_15 => actions.setHydrationInterval(15 * 60),
        .hydration_30 => actions.setHydrationInterval(30 * 60),
        .hydration_45 => actions.setHydrationInterval(45 * 60),
        .hydration_60 => actions.setHydrationInterval(60 * 60),
        .toggle_stretch => actions.toggleStretchReminder(),
        .stretch_15 => actions.setStretchInterval(15 * 60),
        .stretch_30 => actions.setStretchInterval(30 * 60),
        .stretch_45 => actions.setStretchInterval(45 * 60),
        .stretch_60 => actions.setStretchInterval(60 * 60),
        .toggle_big_break => actions.toggleBigBreak(),
        .take_big_break_now => actions.takeBigBreakNow(),
        .big_interval_30m => actions.setBigBreakInterval(30 * 60),
        .big_interval_60m => actions.setBigBreakInterval(60 * 60),
        .big_interval_90m => actions.setBigBreakInterval(90 * 60),
        .big_interval_120m => actions.setBigBreakInterval(120 * 60),
        .big_duration_2m => actions.setBigBreakDuration(2 * 60),
        .big_duration_5m => actions.setBigBreakDuration(5 * 60),
        .big_duration_10m => actions.setBigBreakDuration(10 * 60),
        .big_duration_15m => actions.setBigBreakDuration(15 * 60),
        .big_every_n_0 => actions.setBigBreakEveryN(0),
        .big_every_n_3 => actions.setBigBreakEveryN(3),
        .big_every_n_4 => actions.setBigBreakEveryN(4),
        .big_every_n_5 => actions.setBigBreakEveryN(5),
        .big_every_n_6 => actions.setBigBreakEveryN(6),
        .show_about => showAbout(),
        .quit => c.gtk_main_quit(),
    }
}

fn showAbout() void {
    const dialog = c.gtk_message_dialog_new(
        null,
        0,
        c.GTK_MESSAGE_INFO,
        c.GTK_BUTTONS_OK,
        "Eyes v0.1.0\n\nBreak reminder for Linux.\n\nTake regular breaks to protect your eyes.\nFollow the 20-20-20 rule.",
    );
    _ = c.gtk_dialog_run(@ptrCast(dialog));
    c.gtk_widget_destroy(dialog);
}

// --- Menu building helpers ---

fn addItem(m: ?*c.GtkWidget, label: [*:0]const u8, action: MenuAction) void {
    const item = c.gtk_menu_item_new_with_label(label);
    gtk.connectSignal(@ptrCast(item), "activate", @ptrCast(&onMenuAction), @ptrFromInt(@intFromEnum(action)));
    c.gtk_menu_shell_append(@ptrCast(m), item);
}

fn addCheckItem(m: ?*c.GtkWidget, label: [*:0]const u8, active: bool, action: MenuAction) void {
    const item = c.gtk_check_menu_item_new_with_label(label);
    c.gtk_check_menu_item_set_active(@ptrCast(item), @intFromBool(active));
    gtk.connectSignal(@ptrCast(item), "toggled", @ptrCast(&onMenuAction), @ptrFromInt(@intFromEnum(action)));
    c.gtk_menu_shell_append(@ptrCast(m), item);
}

fn addRadioItem(m: ?*c.GtkWidget, label: [*:0]const u8, active: bool, action: MenuAction) void {
    const item = c.gtk_check_menu_item_new_with_label(label);
    c.gtk_check_menu_item_set_active(@ptrCast(item), @intFromBool(active));
    c.gtk_check_menu_item_set_draw_as_radio(@ptrCast(item), 1);
    gtk.connectSignal(@ptrCast(item), "toggled", @ptrCast(&onMenuAction), @ptrFromInt(@intFromEnum(action)));
    c.gtk_menu_shell_append(@ptrCast(m), item);
}

fn addSeparator(m: ?*c.GtkWidget) void {
    c.gtk_menu_shell_append(@ptrCast(m), c.gtk_separator_menu_item_new());
}

fn addDisabledItem(m: ?*c.GtkWidget, label: [*:0]const u8) void {
    const item = c.gtk_menu_item_new_with_label(label);
    c.gtk_widget_set_sensitive(item, 0);
    c.gtk_menu_shell_append(@ptrCast(m), item);
}

fn addSubmenu(m: ?*c.GtkWidget, label: [*:0]const u8) ?*c.GtkWidget {
    const item = c.gtk_menu_item_new_with_label(label);
    const sub = c.gtk_menu_new();
    c.gtk_menu_item_set_submenu(@ptrCast(item), sub);
    c.gtk_menu_shell_append(@ptrCast(m), item);
    return sub;
}

pub fn markDirty() void {
    dirty = true;
}

pub fn setup() void {
    indicator = c.app_indicator_new("eyes", "view-reveal-symbolic", c.APP_INDICATOR_CATEGORY_APPLICATION_STATUS);
    c.app_indicator_set_status(indicator, c.APP_INDICATOR_STATUS_ACTIVE);

    buildMenu();
    std.log.info("Menu bar setup complete", .{});
}

fn buildMenu() void {
    menu = c.gtk_menu_new();
    const m = menu;
    const s = &app_mod.state;

    // Status line
    {
        var buf: [48]u8 = .{0} ** 48;
        if (s.is_on_break) {
            const rem: u32 = if (s.break_seconds_remaining < 0) 0 else @intCast(s.break_seconds_remaining);
            _ = std.fmt.bufPrint(&buf, "Break: {d}s remaining", .{rem}) catch {};
        } else if (s.is_dnd_active and s.respect_dnd) {
            _ = std.fmt.bufPrint(&buf, "Focus active \xe2\x80\x94 paused", .{}) catch {};
        } else if (s.meeting_paused) {
            _ = std.fmt.bufPrint(&buf, "In meeting \xe2\x80\x94 paused", .{}) catch {};
        } else if (s.is_paused) {
            _ = std.fmt.bufPrint(&buf, "Paused", .{}) catch {};
        } else {
            const tb = s.formatTimeUntilBreak();
            const ts: [*:0]const u8 = @ptrCast(&tb);
            _ = std.fmt.bufPrint(&buf, "Next break: {s}", .{ts}) catch {};
        }
        addDisabledItem(m, @ptrCast(&buf));
    }

    // Stats line
    {
        const total = s.breaks_taken + s.breaks_skipped + s.breaks_delayed;
        if (total > 0) {
            var buf: [64]u8 = .{0} ** 64;
            _ = std.fmt.bufPrint(&buf, "Today: {d} taken, {d} skipped, {d} delayed", .{ s.breaks_taken, s.breaks_skipped, s.breaks_delayed }) catch {};
            addDisabledItem(m, @ptrCast(&buf));
        }
    }

    addSeparator(m);

    // Pause/Resume
    addItem(m, if (s.is_paused) "Resume" else "Pause", .toggle_pause);
    if (!s.is_on_break) {
        addItem(m, "Take Break Now", .take_break_now);
    } else {
        addItem(m, "Skip Break", .skip_break);
        addItem(m, "Delay 1 min", .delay_1min);
        addItem(m, "Delay 5 min", .delay_5min);
    }

    addSeparator(m);

    // Interval submenu
    {
        const sub = addSubmenu(m, "Interval");
        const work = s.work_interval_secs;
        const brk = s.break_duration_secs;

        addRadioItem(sub, "20 min / 20 sec (20-20-20)", work == 20 * 60 and brk == 20, .preset_20_20);
        addRadioItem(sub, "30 min / 30 sec", work == 30 * 60 and brk == 30, .preset_30_30);
        addRadioItem(sub, "45 min / 5 min", work == 45 * 60 and brk == 5 * 60, .preset_45_5);
        addRadioItem(sub, "60 min / 5 min", work == 60 * 60 and brk == 5 * 60, .preset_60_5);
    }

    // Break Sound submenu
    {
        const sub = addSubmenu(m, "Break Sound");
        addRadioItem(sub, "None", s.break_sound == 0, .sound_none);
        addRadioItem(sub, "Tink", s.break_sound == 1, .sound_tink);
        addRadioItem(sub, "Pop", s.break_sound == 2, .sound_pop);
        addRadioItem(sub, "Glass", s.break_sound == 3, .sound_glass);
        addRadioItem(sub, "Purr", s.break_sound == 4, .sound_purr);
        addRadioItem(sub, "Hero", s.break_sound == 5, .sound_hero);
    }

    // Show Timer toggle
    addCheckItem(m, "Show Timer in Menu Bar", s.show_timer_in_menubar, .toggle_timer);

    // Start at Login toggle
    addCheckItem(m, "Start at Login", autostart.isEnabled(), .toggle_start_at_login);

    addSeparator(m);

    // Feature toggles
    addCheckItem(m, "Show as Notification", s.use_notification, .toggle_notification);
    addCheckItem(m, "Gentle Mode (Banner)", s.gentle_mode, .toggle_gentle);
    addCheckItem(m, "Strict Mode (No Skip)", s.strict_mode, .toggle_strict);
    addCheckItem(m, "Respect Do Not Disturb", s.respect_dnd, .toggle_dnd);
    addCheckItem(m, "Screen Lock as Break", s.screen_lock_as_break, .toggle_screen_lock);

    addSeparator(m);

    // Meetings submenu
    {
        const sub = addSubmenu(m, "Pause During Meetings");
        addCheckItem(sub, "Mic Detection", s.pause_during_meetings, .toggle_meetings);
        addCheckItem(sub, "Smart Detection (Process)", s.smart_meeting_detection, .toggle_smart_meeting);
        addSeparator(sub);
        addRadioItem(sub, "Check every 1 sec", s.mic_check_interval_secs == 1, .mic_1);
        addRadioItem(sub, "Check every 5 sec", s.mic_check_interval_secs == 5, .mic_5);
        addRadioItem(sub, "Check every 10 sec", s.mic_check_interval_secs == 10, .mic_10);
        addRadioItem(sub, "Check every 30 sec", s.mic_check_interval_secs == 30, .mic_30);
    }

    // Idle Detection submenu
    {
        const sub = addSubmenu(m, "Idle Detection");
        addRadioItem(sub, "Off", s.idle_threshold_secs == 0, .idle_off);
        addRadioItem(sub, "3 minutes", s.idle_threshold_secs == 3 * 60, .idle_3min);
        addRadioItem(sub, "5 minutes", s.idle_threshold_secs == 5 * 60, .idle_5min);
        addRadioItem(sub, "10 minutes", s.idle_threshold_secs == 10 * 60, .idle_10min);
    }

    // Posture Reminder submenu
    {
        const sub = addSubmenu(m, "Posture Reminder");
        addCheckItem(sub, "Enabled", s.posture_reminder_enabled, .toggle_posture);
        addSeparator(sub);
        addRadioItem(sub, "Every 15 min", s.posture_interval_secs == 15 * 60, .posture_15);
        addRadioItem(sub, "Every 30 min", s.posture_interval_secs == 30 * 60, .posture_30);
        addRadioItem(sub, "Every 45 min", s.posture_interval_secs == 45 * 60, .posture_45);
        addRadioItem(sub, "Every 60 min", s.posture_interval_secs == 60 * 60, .posture_60);
    }

    // Blink Reminder submenu
    {
        const sub = addSubmenu(m, "Blink Reminder");
        addCheckItem(sub, "Enabled", s.blink_reminder_enabled, .toggle_blink);
        addSeparator(sub);
        addRadioItem(sub, "Every 15 min", s.blink_interval_secs == 15 * 60, .blink_15);
        addRadioItem(sub, "Every 30 min", s.blink_interval_secs == 30 * 60, .blink_30);
        addRadioItem(sub, "Every 45 min", s.blink_interval_secs == 45 * 60, .blink_45);
        addRadioItem(sub, "Every 60 min", s.blink_interval_secs == 60 * 60, .blink_60);
    }

    // Hydration Reminder submenu
    {
        const sub = addSubmenu(m, "Hydration Reminder");
        addCheckItem(sub, "Enabled", s.hydration_reminder_enabled, .toggle_hydration);
        addSeparator(sub);
        addRadioItem(sub, "Every 15 min", s.hydration_interval_secs == 15 * 60, .hydration_15);
        addRadioItem(sub, "Every 30 min", s.hydration_interval_secs == 30 * 60, .hydration_30);
        addRadioItem(sub, "Every 45 min", s.hydration_interval_secs == 45 * 60, .hydration_45);
        addRadioItem(sub, "Every 60 min", s.hydration_interval_secs == 60 * 60, .hydration_60);
    }

    // Stretch Reminder submenu
    {
        const sub = addSubmenu(m, "Stretch Reminder");
        addCheckItem(sub, "Enabled", s.stretch_reminder_enabled, .toggle_stretch);
        addSeparator(sub);
        addRadioItem(sub, "Every 15 min", s.stretch_interval_secs == 15 * 60, .stretch_15);
        addRadioItem(sub, "Every 30 min", s.stretch_interval_secs == 30 * 60, .stretch_30);
        addRadioItem(sub, "Every 45 min", s.stretch_interval_secs == 45 * 60, .stretch_45);
        addRadioItem(sub, "Every 60 min", s.stretch_interval_secs == 60 * 60, .stretch_60);
    }

    // Big Break submenu
    {
        const sub = addSubmenu(m, "Big Break");
        addCheckItem(sub, "Enabled", s.big_break_enabled, .toggle_big_break);
        addItem(sub, "Take Big Break Now", .take_big_break_now);
        addSeparator(sub);

        const interval_sub = addSubmenu(sub, "Interval");
        addRadioItem(interval_sub, "Every 30 min", s.big_break_interval_secs == 30 * 60, .big_interval_30m);
        addRadioItem(interval_sub, "Every 60 min", s.big_break_interval_secs == 60 * 60, .big_interval_60m);
        addRadioItem(interval_sub, "Every 90 min", s.big_break_interval_secs == 90 * 60, .big_interval_90m);
        addRadioItem(interval_sub, "Every 120 min", s.big_break_interval_secs == 120 * 60, .big_interval_120m);

        const dur_sub = addSubmenu(sub, "Duration");
        addRadioItem(dur_sub, "2 min", s.big_break_duration_secs == 2 * 60, .big_duration_2m);
        addRadioItem(dur_sub, "5 min", s.big_break_duration_secs == 5 * 60, .big_duration_5m);
        addRadioItem(dur_sub, "10 min", s.big_break_duration_secs == 10 * 60, .big_duration_10m);
        addRadioItem(dur_sub, "15 min", s.big_break_duration_secs == 15 * 60, .big_duration_15m);

        const trigger_sub = addSubmenu(sub, "Trigger");
        addRadioItem(trigger_sub, "By Time Interval", s.big_break_every_n == 0, .big_every_n_0);
        addRadioItem(trigger_sub, "Every 3 Breaks", s.big_break_every_n == 3, .big_every_n_3);
        addRadioItem(trigger_sub, "Every 4 Breaks", s.big_break_every_n == 4, .big_every_n_4);
        addRadioItem(trigger_sub, "Every 5 Breaks", s.big_break_every_n == 5, .big_every_n_5);
        addRadioItem(trigger_sub, "Every 6 Breaks", s.big_break_every_n == 6, .big_every_n_6);
    }

    addSeparator(m);

    addItem(m, "About Eyes", .show_about);
    addItem(m, "Quit Eyes", .quit);

    c.gtk_widget_show_all(m);
    c.app_indicator_set_menu(indicator, @ptrCast(m));
}

pub fn updateMenu() void {
    if (indicator == null) return;

    // Update tray label with countdown
    if (app_mod.state.show_timer_in_menubar) {
        var buf: [24]u8 = .{0} ** 24;
        if (app_mod.state.is_on_break) {
            const rem: u32 = if (app_mod.state.break_seconds_remaining < 0) 0 else @intCast(app_mod.state.break_seconds_remaining);
            _ = std.fmt.bufPrint(&buf, "{d}s", .{rem}) catch {};
        } else if (app_mod.state.is_paused) {
            _ = std.fmt.bufPrint(&buf, "paused", .{}) catch {};
        } else if (app_mod.state.meeting_paused) {
            _ = std.fmt.bufPrint(&buf, "meeting", .{}) catch {};
        } else if (app_mod.state.is_dnd_active and app_mod.state.respect_dnd) {
            _ = std.fmt.bufPrint(&buf, "focus", .{}) catch {};
        } else {
            const tb = app_mod.state.formatTimeUntilBreak();
            const ts: [*:0]const u8 = @ptrCast(&tb);
            _ = std.fmt.bufPrint(&buf, "{s}", .{ts}) catch {};
        }
        c.app_indicator_set_label(indicator, @ptrCast(&buf), "99:99");
    } else {
        c.app_indicator_set_label(indicator, "", "");
    }

    // Update icon based on state
    if (app_mod.state.is_paused or app_mod.state.meeting_paused or (app_mod.state.is_dnd_active and app_mod.state.respect_dnd)) {
        c.app_indicator_set_icon(indicator, "view-conceal-symbolic");
    } else {
        c.app_indicator_set_icon(indicator, "view-reveal-symbolic");
    }

    // Rebuild menu only when state changes
    if (dirty) {
        if (menu != null) c.gtk_widget_destroy(menu.?);
        buildMenu();
        dirty = false;
    }
}
