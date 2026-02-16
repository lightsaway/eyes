// Minimal AppKit framework bindings.

const objc = @import("objc.zig");

const id = objc.id;
const CGFloat = objc.CGFloat;
const NSRect = objc.NSRect;
const NSPoint = objc.NSPoint;
const NSSize = objc.NSSize;
const NSUInteger = objc.NSUInteger;

// NSApplication activation policies
pub const NSApplicationActivationPolicyAccessory: c_long = 1;

// NSWindow style masks
pub const NSWindowStyleMaskBorderless: NSUInteger = 0;
pub const NSWindowStyleMaskTitled: NSUInteger = 1 << 0;

// NSWindow levels
pub const NSScreenSaverWindowLevel: c_long = 1000;

// NSWindow backing store types
pub const NSBackingStoreBuffered: NSUInteger = 2;

// NSStatusBar
pub const NSVariableStatusItemLength: CGFloat = -1.0;

// Collection behaviors
pub const NSWindowCollectionBehaviorCanJoinAllSpaces: NSUInteger = 1 << 0;
pub const NSWindowCollectionBehaviorStationary: NSUInteger = 1 << 4;

// Text alignment
pub const NSTextAlignmentCenter: NSUInteger = 1;

// Font weights
pub const NSFontWeightUltraLight: CGFloat = -0.6;

// NSApplication
pub fn sharedApplication() id {
    return objc.msgSend_id(objc.getClass("NSApplication"), objc.sel("sharedApplication"));
}

pub fn setActivationPolicy(app: id, policy: c_long) void {
    objc.msgSend_void1(app, objc.sel("setActivationPolicy:"), policy);
}

pub fn run(app: id) void {
    objc.msgSend_void(app, objc.sel("run"));
}

pub fn setDelegate(app: id, delegate: id) void {
    objc.msgSend_void1(app, objc.sel("setDelegate:"), delegate);
}

pub fn terminate(app: id) void {
    objc.msgSend_void1(app, objc.sel("terminate:"), @as(id, null));
}

// NSStatusBar
pub fn systemStatusBar() id {
    return objc.msgSend_id(objc.getClass("NSStatusBar"), objc.sel("systemStatusBar"));
}

pub fn statusItemWithLength(statusBar: id, length: CGFloat) id {
    return objc.msgSend_id1(statusBar, objc.sel("statusItemWithLength:"), length);
}

// NSMenu
pub fn createMenu() id {
    return objc.allocInit(objc.getClass("NSMenu"));
}

pub fn addItem(m: id, item: id) void {
    objc.msgSend_void1(m, objc.sel("addItem:"), item);
}

pub fn removeAllItems(m: id) void {
    objc.msgSend_void(m, objc.sel("removeAllItems"));
}

// NSMenuItem
pub fn createMenuItem(title: [*:0]const u8, action: objc.SEL, keyEquiv: [*:0]const u8) id {
    const NSMenuItem = objc.getClass("NSMenuItem");
    const item = objc.alloc(NSMenuItem);
    return objc.msgSend_id3(
        item,
        objc.sel("initWithTitle:action:keyEquivalent:"),
        objc.nsString(title),
        action,
        objc.nsString(keyEquiv),
    );
}

pub fn createSeparator() id {
    return objc.msgSend_id(objc.getClass("NSMenuItem"), objc.sel("separatorItem"));
}

pub fn setTarget(item: id, target: id) void {
    objc.msgSend_void1(item, objc.sel("setTarget:"), target);
}

pub fn setSubmenu(item: id, submenu: id) void {
    objc.msgSend_void1(item, objc.sel("setSubmenu:"), submenu);
}

// NSOnState = 1, NSOffState = 0
pub fn setMenuItemState(item: id, on: bool) void {
    objc.msgSend_void1(item, objc.sel("setState:"), @as(c_long, if (on) 1 else 0));
}

// NSWindow
pub fn createWindow(rect: NSRect, style: NSUInteger, backing: NSUInteger, defer_: bool) id {
    const NSWindow = objc.getClass("NSWindow");
    const win = objc.alloc(NSWindow);
    return objc.msgSend_id4(
        win,
        objc.sel("initWithContentRect:styleMask:backing:defer:"),
        rect,
        style,
        backing,
        @as(c_char, if (defer_) 1 else 0),
    );
}

pub fn setWindowLevel(window: id, level: c_long) void {
    objc.msgSend_void1(window, objc.sel("setLevel:"), level);
}

pub fn setWindowBackgroundColor(window: id, color: id) void {
    objc.msgSend_void1(window, objc.sel("setBackgroundColor:"), color);
}

pub fn setOpaque(window: id, is_opaque: bool) void {
    objc.msgSend_void1(window, objc.sel("setOpaque:"), @as(c_char, if (is_opaque) 1 else 0));
}

pub fn setAlphaValue(window: id, alpha: CGFloat) void {
    objc.msgSend_void1(window, objc.sel("setAlphaValue:"), alpha);
}

pub fn orderFront(window: id) void {
    objc.msgSend_void1(window, objc.sel("orderFront:"), @as(id, null));
}

pub fn orderOut(window: id) void {
    objc.msgSend_void1(window, objc.sel("orderOut:"), @as(id, null));
}

pub fn makeKeyAndOrderFront(window: id) void {
    objc.msgSend_void1(window, objc.sel("makeKeyAndOrderFront:"), @as(id, null));
}

pub fn setContentView(window: id, view: id) void {
    objc.msgSend_void1(window, objc.sel("setContentView:"), view);
}

pub fn contentView(window: id) id {
    return objc.msgSend_id(window, objc.sel("contentView"));
}

pub fn setWindowCollectionBehavior(window: id, behavior: NSUInteger) void {
    objc.msgSend_void1(window, objc.sel("setCollectionBehavior:"), behavior);
}

pub fn setIgnoresMouseEvents(window: id, ignores: bool) void {
    objc.msgSend_void1(window, objc.sel("setIgnoresMouseEvents:"), @as(c_char, if (ignores) 1 else 0));
}

// NSColor
pub fn colorWithRGBA(r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) id {
    return objc.msgSend_id4(objc.getClass("NSColor"), objc.sel("colorWithRed:green:blue:alpha:"), r, g, b, a);
}

pub fn blackColor() id {
    return objc.msgSend_id(objc.getClass("NSColor"), objc.sel("blackColor"));
}

pub fn whiteColor() id {
    return objc.msgSend_id(objc.getClass("NSColor"), objc.sel("whiteColor"));
}

pub fn clearColor() id {
    return objc.msgSend_id(objc.getClass("NSColor"), objc.sel("clearColor"));
}

// NSScreen
pub fn mainScreen() id {
    return objc.msgSend_id(objc.getClass("NSScreen"), objc.sel("mainScreen"));
}

pub fn screens() id {
    return objc.msgSend_id(objc.getClass("NSScreen"), objc.sel("screens"));
}

pub fn screenFrame(screen: id) NSRect {
    return objc.msgSend_rect(screen, objc.sel("frame"));
}

// NSTextField (label)
pub fn createLabel(text: [*:0]const u8) id {
    const NSTextField = objc.getClass("NSTextField");
    const label = objc.init(objc.alloc(NSTextField));
    objc.msgSend_void1(label, objc.sel("setStringValue:"), objc.nsString(text));
    objc.msgSend_void1(label, objc.sel("setBezeled:"), @as(c_char, 0));
    objc.msgSend_void1(label, objc.sel("setDrawsBackground:"), @as(c_char, 0));
    objc.msgSend_void1(label, objc.sel("setEditable:"), @as(c_char, 0));
    objc.msgSend_void1(label, objc.sel("setSelectable:"), @as(c_char, 0));
    return label;
}

pub fn setStringValue(field: id, text: [*:0]const u8) void {
    objc.msgSend_void1(field, objc.sel("setStringValue:"), objc.nsString(text));
}

pub fn setFont(view: id, font: id) void {
    objc.msgSend_void1(view, objc.sel("setFont:"), font);
}

pub fn setTextColor(view: id, color: id) void {
    objc.msgSend_void1(view, objc.sel("setTextColor:"), color);
}

pub fn setAlignment(view: id, alignment: NSUInteger) void {
    objc.msgSend_void1(view, objc.sel("setAlignment:"), alignment);
}

// NSFont
pub fn systemFont(size: CGFloat) id {
    return objc.msgSend_id1(objc.getClass("NSFont"), objc.sel("systemFontOfSize:"), size);
}

pub fn boldSystemFont(size: CGFloat) id {
    return objc.msgSend_id1(objc.getClass("NSFont"), objc.sel("boldSystemFontOfSize:"), size);
}

pub fn monospacedSystemFont(size: CGFloat, weight: CGFloat) id {
    return objc.msgSend_id2(objc.getClass("NSFont"), objc.sel("monospacedSystemFontOfSize:weight:"), size, weight);
}

// NSView
pub fn setViewFrame(view: id, rect: NSRect) void {
    objc.msgSend_void1(view, objc.sel("setFrame:"), rect);
}

pub fn viewFrame(view: id) NSRect {
    return objc.msgSend_rect(view, objc.sel("frame"));
}

pub fn addSubview(parent: id, child: id) void {
    objc.msgSend_void1(parent, objc.sel("addSubview:"), child);
}

pub fn setWantsLayer(view: id, wants: bool) void {
    objc.msgSend_void1(view, objc.sel("setWantsLayer:"), @as(c_char, if (wants) 1 else 0));
}

// NSButton
pub fn createButton(title: [*:0]const u8, target: id, action: objc.SEL) id {
    return objc.msgSend_id3(
        objc.getClass("NSButton"),
        objc.sel("buttonWithTitle:target:action:"),
        objc.nsString(title),
        target,
        action,
    );
}

// NSImage
pub fn imageWithSystemSymbolName(name: [*:0]const u8) id {
    return objc.msgSend_id2(
        objc.getClass("NSImage"),
        objc.sel("imageWithSystemSymbolName:accessibilityDescription:"),
        objc.nsString(name),
        @as(id, null),
    );
}

pub fn setImageSize(image: id, size: NSSize) void {
    objc.msgSend_void1(image, objc.sel("setSize:"), size);
}

// NSSound
pub fn playSystemSound(name: [*:0]const u8) void {
    const sound = objc.msgSend_id1(objc.getClass("NSSound"), objc.sel("soundNamed:"), objc.nsString(name));
    if (sound != null) {
        objc.msgSend_void(sound, objc.sel("play"));
    }
}

// NSArray helpers
pub fn arrayCount(arr: id) NSUInteger {
    return objc.msgSend_uint(arr, objc.sel("count"));
}

pub fn arrayObjectAtIndex(arr: id, index: NSUInteger) id {
    return objc.msgSend_id1(arr, objc.sel("objectAtIndex:"), index);
}
