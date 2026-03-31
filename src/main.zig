// Eyes — Break reminder app.
// Thin entry point that delegates to the platform-specific backend.

const platform = @import("platform.zig");

pub fn main() !void {
    platform.backend.run();
}
