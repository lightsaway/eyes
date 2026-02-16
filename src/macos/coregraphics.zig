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

// CGWindowList constants
pub const kCGWindowListOptionOnScreenOnly: u32 = 1 << 0;
pub const kCGWindowListExcludeDesktopElements: u32 = 1 << 4;
pub const kCGNullWindowID: u32 = 0;

// CGWindowList functions
pub extern "CoreGraphics" fn CGWindowListCopyWindowInfo(option: u32, relativeToWindow: u32) ?*anyopaque;
