// Linux sound playback via libcanberra (freedesktop sound theme).

const std = @import("std");
const gtk = @import("gtk.zig");
const c = gtk.c;

var ca_ctx: ?*c.ca_context = null;

fn ensureInit() void {
    if (ca_ctx != null) return;
    _ = c.ca_context_create(&ca_ctx);
}

// Map macOS sound names to freedesktop sound theme event IDs
fn mapSoundName(name: [*:0]const u8) [*:0]const u8 {
    const s = std.mem.span(name);
    if (std.mem.eql(u8, s, "Tink")) return "message-new-instant";
    if (std.mem.eql(u8, s, "Pop")) return "dialog-information";
    if (std.mem.eql(u8, s, "Glass")) return "bell";
    if (std.mem.eql(u8, s, "Purr")) return "dialog-warning";
    if (std.mem.eql(u8, s, "Hero")) return "complete";
    return "bell"; // fallback
}

pub fn playSystemSound(name: [*:0]const u8) void {
    ensureInit();
    const ctx = ca_ctx orelse return;
    const event_id = mapSoundName(name);
    _ = c.ca_context_play(
        ctx,
        0,
        c.CA_PROP_EVENT_ID,
        event_id,
        c.CA_PROP_EVENT_DESCRIPTION,
        "Eyes break reminder",
        @as(?*const anyopaque, null),
    );
}
