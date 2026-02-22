// Blink reminder — thin wrapper over shared pill core.

const pill = @import("pill.zig");

var state = pill.PillState{};

const cfg = pill.PillConfig{
    .pill_type = .blink,
    .window_width = 120.0,
    .window_height = 80.0,
    .timer_sel = "blinkFadeTick:",
    .emoji = "\xf0\x9f\x91\x81", // "👁"
    .emoji_font_size = 36.0,
    .emoji_y = 20.0,
    .emoji_height = 44.0,
    .alt_emoji = "\xe2\x80\x94", // "—"
    .hint_text = "blink",
    .hint_y = 4.0,
    .accessibility_label = "Blink reminder",
    .accessibility_announcement = "Blink. Remember to blink your eyes.",
    .log_name = "Blink",
};

pub fn showBlinkReminder() void {
    pill.show(&state, &cfg);
}
pub fn hideBlinkReminder() void {
    pill.hide(&state, &cfg);
}
pub fn fadeTick() void {
    pill.fadeTick(&state, &cfg);
}
pub fn updateBlinkAnimation(tick_val: u32) void {
    pill.updateAnimation(&state, &cfg, tick_val);
}
pub fn repositionIfNeeded() void {
    pill.repositionIfNeeded(&state, &cfg);
}
pub fn isVisible() bool {
    return pill.isVisible(&state);
}
