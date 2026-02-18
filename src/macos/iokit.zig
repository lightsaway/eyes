// IOKit bindings for idle time detection via HIDIdleTime.

const std = @import("std");
const objc = @import("objc.zig");

// IOKit extern declarations
extern "IOKit" fn IOServiceGetMatchingService(mainPort: u32, matching: ?*anyopaque) u32;
extern "IOKit" fn IORegistryEntryCreateCFProperty(entry: u32, key: ?*anyopaque, allocator: ?*anyopaque, options: u32) ?*anyopaque;
extern "IOKit" fn IOObjectRelease(object: u32) u32;

// CoreFoundation extern declarations
extern "CoreFoundation" fn IOServiceMatching(name: [*:0]const u8) ?*anyopaque;
extern "CoreFoundation" fn CFNumberGetValue(number: ?*anyopaque, theType: c_long, valuePtr: *i64) bool;
extern "CoreFoundation" fn CFRelease(cf: ?*anyopaque) void;

// kCFNumberSInt64Type = 4
const kCFNumberSInt64Type: c_long = 4;

/// Returns the number of seconds since the last user input event, or null on failure.
pub fn getIdleSeconds() ?u64 {
    const matching = IOServiceMatching("IOHIDSystem");
    if (matching == null) return null;

    const service = IOServiceGetMatchingService(0, matching);
    // IOServiceMatching result is consumed by IOServiceGetMatchingService
    if (service == 0) return null;
    defer _ = IOObjectRelease(service);

    const key = objc.nsString("HIDIdleTime");
    const prop = IORegistryEntryCreateCFProperty(service, key, null, 0);
    if (prop == null) return null;
    defer CFRelease(prop);

    var nanoseconds: i64 = 0;
    if (!CFNumberGetValue(prop, kCFNumberSInt64Type, &nanoseconds)) return null;

    if (nanoseconds < 0) return 0;
    return @intCast(@divTrunc(nanoseconds, 1_000_000_000));
}
