// Hydration reminder — thin wrapper over shared pill core.

const pill = @import("pill.zig");

var state = pill.PillState{};

const cfg = pill.PillConfig{
    .pill_type = .hydration,
    .window_width = 120.0,
    .window_height = 80.0,
    .timer_sel = "hydrationFadeTick:",
    .emoji = "\xf0\x9f\x92\xa7", // "💧"
    .emoji_font_size = 36.0,
    .emoji_y = 20.0,
    .emoji_height = 44.0,
    .alt_emoji = "\xf0\x9f\x9a\xb0", // "🚰"
    .hint_text = "drink water",
    .hint_y = 4.0,
    .accessibility_label = "Hydration reminder",
    .accessibility_announcement = "Drink water. Stay hydrated.",
    .log_name = "Hydration",
};

pub fn showHydrationReminder() void {
    pill.show(&state, &cfg);
}
pub fn hideHydrationReminder() void {
    pill.hide(&state, &cfg);
}
pub fn fadeTick() void {
    pill.fadeTick(&state, &cfg);
}
pub fn updateHydrationAnimation(tick_val: u32) void {
    pill.updateAnimation(&state, &cfg, tick_val);
}
pub fn repositionIfNeeded() void {
    pill.repositionIfNeeded(&state, &cfg);
}
pub fn isVisible() bool {
    return pill.isVisible(&state);
}
