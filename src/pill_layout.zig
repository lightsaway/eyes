// Shared pill layout — computes horizontal positions so multiple pills don't overlap.

const posture = @import("posture.zig");
const blink = @import("blink.zig");
const hydration = @import("hydration.zig");
const stretch = @import("stretch.zig");
const CGFloat = @import("macos/objc.zig").CGFloat;

pub const PillType = enum { posture, blink, hydration, stretch };

// Fixed widths per pill type (must match the window_width in each module)
const widths = [4]CGFloat{ 160.0, 120.0, 120.0, 120.0 };
const gap: CGFloat = 12.0;

/// Get the x position for a pill, spreading horizontally if others are visible.
/// `include_self` should be true when calling for a pill that's about to show.
pub fn getX(pill: PillType, screen_width: CGFloat, include_self: bool) CGFloat {
    var visible = [4]bool{ posture.isVisible(), blink.isVisible(), hydration.isVisible(), stretch.isVisible() };

    if (include_self) {
        visible[@intFromEnum(pill)] = true;
    }

    var count: u8 = 0;
    for (visible) |v| {
        if (v) count += 1;
    }

    if (count <= 1) {
        // Single pill — center it
        return (screen_width - widths[@intFromEnum(pill)]) / 2.0;
    }

    // Compute total width of all visible pills
    var total_w: CGFloat = 0.0;
    var first = true;
    for (0..4) |i| {
        if (visible[i]) {
            if (!first) total_w += gap;
            total_w += widths[i];
            first = false;
        }
    }

    // Walk to our slot
    var x = (screen_width - total_w) / 2.0;
    for (0..4) |i| {
        if (visible[i]) {
            if (i == @intFromEnum(pill)) return x;
            x += widths[i] + gap;
        }
    }

    return (screen_width - widths[@intFromEnum(pill)]) / 2.0;
}

/// Reposition all currently visible pills immediately (any slide phase).
pub fn repositionAll() void {
    posture.repositionIfNeeded();
    blink.repositionIfNeeded();
    hydration.repositionIfNeeded();
    stretch.repositionIfNeeded();
}
