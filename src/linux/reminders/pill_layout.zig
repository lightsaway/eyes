// Linux pill layout — computes horizontal positions so multiple pills don't overlap.

const posture = @import("posture.zig");
const blink = @import("blink.zig");
const hydration = @import("hydration.zig");
const stretch = @import("stretch.zig");

pub const PillType = enum { posture, blink, hydration, stretch };

const widths = [4]f64{ 160.0, 120.0, 120.0, 120.0 };
const gap: f64 = 12.0;

pub fn getX(pill: PillType, screen_width: f64, include_self: bool) f64 {
    var visible = [4]bool{ posture.isVisible(), blink.isVisible(), hydration.isVisible(), stretch.isVisible() };

    if (include_self) {
        visible[@intFromEnum(pill)] = true;
    }

    var count: u8 = 0;
    for (visible) |v| {
        if (v) count += 1;
    }

    if (count <= 1) {
        return (screen_width - widths[@intFromEnum(pill)]) / 2.0;
    }

    var total_w: f64 = 0.0;
    var first = true;
    for (0..4) |i| {
        if (visible[i]) {
            if (!first) total_w += gap;
            total_w += widths[i];
            first = false;
        }
    }

    var x = (screen_width - total_w) / 2.0;
    for (0..4) |i| {
        if (visible[i]) {
            if (i == @intFromEnum(pill)) return x;
            x += widths[i] + gap;
        }
    }

    return (screen_width - widths[@intFromEnum(pill)]) / 2.0;
}

pub fn repositionAll() void {
    posture.repositionIfNeeded();
    blink.repositionIfNeeded();
    hydration.repositionIfNeeded();
    stretch.repositionIfNeeded();
}
