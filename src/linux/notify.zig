// Linux notifications via libnotify.

const gtk = @import("gtk.zig");
const c = gtk.c;

pub fn deliverNotification(title: [*:0]const u8, body: [*:0]const u8) void {
    const notification = c.notify_notification_new(title, body, "dialog-information");
    if (notification != null) {
        _ = c.notify_notification_show(notification, null);
        c.g_object_unref(@ptrCast(notification));
    }
}
