// GTK3 / GLib / cairo / AppIndicator / libnotify / libcanberra C bindings via @cImport.

pub const c = @cImport({
    @cInclude("gtk/gtk.h");
    @cInclude("libappindicator/app-indicator.h");
    @cInclude("libnotify/notify.h");
    @cInclude("canberra.h");
});

// X11 idle detection (separate cImport to avoid conflicts)
pub const x11 = @cImport({
    @cInclude("X11/Xlib.h");
    @cInclude("X11/extensions/scrnsaver.h");
});

// Math constant
pub const M_PI = 3.14159265358979323846;

// Helper: connect a GObject signal with user_data packed from an enum
pub fn connectSignal(
    instance: ?*anyopaque,
    signal: [*:0]const u8,
    callback: ?*const anyopaque,
    data: ?*anyopaque,
) void {
    _ = c.g_signal_connect_data(
        instance,
        signal,
        @ptrCast(callback),
        data,
        null,
        0,
    );
}
