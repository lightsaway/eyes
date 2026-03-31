// Linux lifecycle — GTK3 application setup and main loop.

const std = @import("std");
const gtk = @import("gtk.zig");
const app_mod = @import("../app.zig");
const platform = @import("../platform.zig");

const menubar = platform.backend.menubar;

var app: ?*gtk.c.GtkApplication = null;

fn onActivate(_: ?*gtk.c.GApplication) callconv(.c) void {
    // Load saved config
    app_mod.loadConfig();

    // Initialize libnotify
    _ = gtk.c.notify_init("Eyes");

    std.log.info("Eyes started \xe2\x80\x94 break every {d} minutes", .{app_mod.state.work_interval_secs / 60});

    // Set up system tray
    menubar.setup();

    // Register for screen lock notifications
    if (app_mod.state.screen_lock_as_break) {
        platform.backend.registerScreenLockNotifications();
    }

    // Start the 1-second tick timer
    _ = gtk.c.g_timeout_add(1000, &tickCallback, null);

    // GTK needs at least one window to keep the app alive;
    // create a hidden one since we're a tray-only app.
    // GTK needs at least one window to keep the app alive;
    // create a hidden one since we're a tray-only app.
    const window = gtk.c.gtk_application_window_new(app);
    gtk.c.gtk_window_set_default_size(@ptrCast(window), 1, 1);
    gtk.c.gtk_widget_hide(window);
}

fn tickCallback(_: ?*anyopaque) callconv(.c) gtk.c.gboolean {
    app_mod.tick();
    return 1; // G_SOURCE_CONTINUE
}

pub fn run() void {
    app = @ptrCast(gtk.c.gtk_application_new("com.eyes.app", 0));
    gtk.connectSignal(@ptrCast(app), "activate", @ptrCast(&onActivate), null);
    _ = gtk.c.g_application_run(@ptrCast(app), 0, null);
    gtk.c.g_object_unref(@ptrCast(app));
}
