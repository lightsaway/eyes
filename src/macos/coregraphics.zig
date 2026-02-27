// Minimal CoreGraphics bindings.

const objc = @import("objc.zig");

pub const CGFloat = objc.CGFloat;

pub const CGRect = extern struct {
    origin: CGPoint,
    size: CGSize,
};

pub const CGPoint = extern struct {
    x: CGFloat,
    y: CGFloat,
};

pub const CGSize = extern struct {
    width: CGFloat,
    height: CGFloat,
};

// CGDisplay functions (linked via CoreGraphics framework)
pub extern "CoreGraphics" fn CGMainDisplayID() u32;
pub extern "CoreGraphics" fn CGDisplayCapture(display: u32) i32;
pub extern "CoreGraphics" fn CGDisplayRelease(display: u32) i32;
pub extern "CoreGraphics" fn CGCaptureAllDisplays() i32;
pub extern "CoreGraphics" fn CGReleaseAllDisplays() i32;
pub extern "CoreGraphics" fn CGShieldingWindowLevel() i32;

// CGEvent types
pub const CGEventTapLocation = enum(u32) {
    cghidEventTap = 0,
    cgSessionEventTap = 1,
    cgAnnotatedSessionEventTap = 2,
};

pub const CGEventTapPlacement = enum(u32) {
    headInsertEventTap = 0,
    tailAppendEventTap = 1,
};

pub const CGEventTapOptions = enum(u32) {
    defaultTap = 0,
    listenOnly = 1,
};

// CGEvent types and constants
pub const CGEventType = u32;
pub const kCGEventKeyDown: CGEventType = 10;
pub const kCGEventKeyUp: CGEventType = 11;
pub const kCGEventLeftMouseDown: CGEventType = 1;
pub const kCGEventLeftMouseUp: CGEventType = 2;
pub const kCGEventRightMouseDown: CGEventType = 3;
pub const kCGEventRightMouseUp: CGEventType = 4;
pub const kCGEventScrollWheel: CGEventType = 22;

pub const CGEventFlags = u64;
pub const kCGEventFlagMaskCommand: CGEventFlags = 1 << 20;
pub const kCGEventFlagMaskShift: CGEventFlags = 1 << 17;

pub const kCGKeyboardEventKeycode: u32 = 9;

// CGEventTap callback type: (proxy, type, event, userInfo) -> event
pub const CGEventTapCallBack = *const fn (?*anyopaque, CGEventType, ?*anyopaque, ?*anyopaque) callconv(.c) ?*anyopaque;

pub extern "CoreGraphics" fn CGEventTapCreate(
    tap: u32, // CGEventTapLocation
    place: u32, // CGEventTapPlacement
    options: u32, // CGEventTapOptions
    eventsOfInterest: u64, // CGEventMask
    callback: CGEventTapCallBack,
    userInfo: ?*anyopaque,
) ?*anyopaque; // CFMachPortRef

pub extern "CoreGraphics" fn CGEventTapEnable(tap: ?*anyopaque, enable: bool) void;

pub extern "CoreGraphics" fn CGEventGetFlags(event: ?*anyopaque) CGEventFlags;

pub extern "CoreGraphics" fn CGEventGetIntegerValueField(event: ?*anyopaque, field: u32) i64;

// CoreFoundation run loop helpers
pub extern "CoreFoundation" fn CFMachPortCreateRunLoopSource(allocator: ?*anyopaque, port: ?*anyopaque, order: c_long) ?*anyopaque;
pub extern "CoreFoundation" fn CFRunLoopGetCurrent() ?*anyopaque;
pub extern "CoreFoundation" fn CFRunLoopAddSource(rl: ?*anyopaque, source: ?*anyopaque, mode: ?*anyopaque) void;
pub extern "CoreFoundation" fn CFMachPortInvalidate(port: ?*anyopaque) void;
pub extern "CoreFoundation" fn CFRunLoopSourceInvalidate(source: ?*anyopaque) void;
pub extern "CoreFoundation" fn CFRelease(cf: ?*anyopaque) void;

// kCFRunLoopCommonModes — this is an extern global CFStringRef
pub extern "CoreFoundation" var kCFRunLoopCommonModes: ?*anyopaque;

// CGWindowList constants
pub const kCGWindowListOptionOnScreenOnly: u32 = 1 << 0;
pub const kCGWindowListExcludeDesktopElements: u32 = 1 << 4;
pub const kCGNullWindowID: u32 = 0;

// CGWindowList functions
pub extern "CoreGraphics" fn CGWindowListCopyWindowInfo(option: u32, relativeToWindow: u32) ?*anyopaque;

// CoreFoundation helpers for iterating CGWindowList results
pub extern "CoreFoundation" fn CFArrayGetCount(theArray: ?*anyopaque) c_long;
pub extern "CoreFoundation" fn CFArrayGetValueAtIndex(theArray: ?*anyopaque, idx: c_long) ?*anyopaque;
pub extern "CoreFoundation" fn CFDictionaryGetValue(theDict: ?*anyopaque, key: ?*anyopaque) ?*anyopaque;
pub extern "CoreFoundation" fn CFStringGetCString(theString: ?*anyopaque, buffer: [*]u8, bufferSize: c_long, encoding: u32) bool;
pub extern "CoreFoundation" fn CFStringGetLength(theString: ?*anyopaque) c_long;

// CFString encoding
pub const kCFStringEncodingUTF8: u32 = 0x08000100;

// CGWindowList dictionary keys (extern CFStringRef globals)
pub extern "CoreGraphics" var kCGWindowOwnerName: ?*anyopaque;
pub extern "CoreGraphics" var kCGWindowName: ?*anyopaque;
