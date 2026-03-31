// Posture reminder — thin wrapper over shared pill core.

const pill = @import("pill.zig");

var state = pill.PillState{};

const cfg = pill.PillConfig{
    .pill_type = .posture,
    .window_width = 160.0,
    .window_height = 120.0,
    .emoji = "\xe2\x86\x91", // "↑"
    .emoji_font_size = 52.0,
    .emoji_y = 8.0,
    .emoji_height = 64.0,
    .alt_emoji = null,
    .hint_text = "straighten up",
    .hint_y = 76.0,
    .accessibility_label = "Posture reminder",
    .accessibility_announcement = "Straighten up. Check your posture.",
    .log_name = "Posture",
};

pub fn showPostureReminder() void {
    pill.show(&state, &cfg);
}
pub fn hidePostureReminder() void {
    pill.hide(&state, &cfg);
}
pub fn fadeTick() void {
    pill.fadeTick(&state, &cfg);
}
pub fn updatePostureAnimation(tick_val: u32) void {
    pill.updateAnimation(&state, &cfg, tick_val);
}
pub fn repositionIfNeeded() void {
    pill.repositionIfNeeded(&state, &cfg);
}
pub fn isVisible() bool {
    return pill.isVisible(&state);
}
