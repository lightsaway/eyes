// Stretch reminder — thin wrapper over shared pill core.

const pill = @import("pill.zig");

var state = pill.PillState{};

const cfg = pill.PillConfig{
    .pill_type = .stretch,
    .window_width = 120.0,
    .window_height = 80.0,
    .timer_sel = "stretchFadeTick:",
    .emoji = "\xf0\x9f\x99\x86", // "🙆"
    .emoji_font_size = 36.0,
    .emoji_y = 20.0,
    .emoji_height = 44.0,
    .alt_emoji = "\xf0\x9f\x99\x8b", // "🙋"
    .hint_text = "stretch",
    .hint_y = 4.0,
    .accessibility_label = "Stretch reminder",
    .accessibility_announcement = "Time to stretch your body.",
    .log_name = "Stretch",
};

pub fn showStretchReminder() void {
    pill.show(&state, &cfg);
}
pub fn hideStretchReminder() void {
    pill.hide(&state, &cfg);
}
pub fn fadeTick() void {
    pill.fadeTick(&state, &cfg);
}
pub fn updateStretchAnimation(tick_val: u32) void {
    pill.updateAnimation(&state, &cfg, tick_val);
}
pub fn repositionIfNeeded() void {
    pill.repositionIfNeeded(&state, &cfg);
}
pub fn isVisible() bool {
    return pill.isVisible(&state);
}
