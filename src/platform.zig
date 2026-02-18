// Platform abstraction — selects the native backend at comptime.

const builtin = @import("builtin");

pub const backend = switch (builtin.os.tag) {
    .macos => @import("macos/backend.zig"),
    // .linux => @import("linux/backend.zig"),
    // .windows => @import("windows/backend.zig"),
    else => @compileError("unsupported platform"),
};
