// Core Objective-C runtime bridge for Zig.
// Wraps objc_msgSend with type-safe helpers.

const std = @import("std");

pub const c = @cImport({
    @cInclude("objc/runtime.h");
    @cInclude("objc/message.h");
});

// Core ObjC types
pub const id = ?*anyopaque;
pub const Class = ?*anyopaque;
pub const SEL = ?*anyopaque;
pub const NSUInteger = c_ulong;
pub const NSInteger = c_long;
pub const CGFloat = f64;
pub const IMP = *const fn () callconv(.c) void;

pub const YES: c.BOOL = @intFromBool(true);
pub const NO: c.BOOL = @intFromBool(false);

pub const NSRect = extern struct {
    origin: NSPoint,
    size: NSSize,
};

pub const NSPoint = extern struct {
    x: CGFloat,
    y: CGFloat,
};

pub const NSSize = extern struct {
    width: CGFloat,
    height: CGFloat,
};

// Get an ObjC class by name
pub fn getClass(name: [*:0]const u8) Class {
    return c.objc_getClass(name);
}

// Register a selector
pub fn sel(name: [*:0]const u8) SEL {
    return c.sel_registerName(name);
}

// Type-safe objc_msgSend wrappers for different arg counts and return types.
// We cast the C objc_msgSend to the appropriate function pointer type.

// Send message, return id, 0 extra args
pub fn msgSend_id(target: anytype, selector: SEL) id {
    const f: *const fn (id, SEL) callconv(.c) id = @ptrCast(&c.objc_msgSend);
    return f(asId(target), selector);
}

// Send message, return id, 1 arg
pub fn msgSend_id1(target: anytype, selector: SEL, a1: anytype) id {
    const A1 = @TypeOf(a1);
    const f: *const fn (id, SEL, A1) callconv(.c) id = @ptrCast(&c.objc_msgSend);
    return f(asId(target), selector, a1);
}

// Send message, return id, 2 args
pub fn msgSend_id2(target: anytype, selector: SEL, a1: anytype, a2: anytype) id {
    const A1 = @TypeOf(a1);
    const A2 = @TypeOf(a2);
    const f: *const fn (id, SEL, A1, A2) callconv(.c) id = @ptrCast(&c.objc_msgSend);
    return f(asId(target), selector, a1, a2);
}

// Send message, return id, 3 args
pub fn msgSend_id3(target: anytype, selector: SEL, a1: anytype, a2: anytype, a3: anytype) id {
    const A1 = @TypeOf(a1);
    const A2 = @TypeOf(a2);
    const A3 = @TypeOf(a3);
    const f: *const fn (id, SEL, A1, A2, A3) callconv(.c) id = @ptrCast(&c.objc_msgSend);
    return f(asId(target), selector, a1, a2, a3);
}

// Send message, return id, 4 args
pub fn msgSend_id4(target: anytype, selector: SEL, a1: anytype, a2: anytype, a3: anytype, a4: anytype) id {
    const A1 = @TypeOf(a1);
    const A2 = @TypeOf(a2);
    const A3 = @TypeOf(a3);
    const A4 = @TypeOf(a4);
    const f: *const fn (id, SEL, A1, A2, A3, A4) callconv(.c) id = @ptrCast(&c.objc_msgSend);
    return f(asId(target), selector, a1, a2, a3, a4);
}

// Send message, return id, 5 args
pub fn msgSend_id5(target: anytype, selector: SEL, a1: anytype, a2: anytype, a3: anytype, a4: anytype, a5: anytype) id {
    const A1 = @TypeOf(a1);
    const A2 = @TypeOf(a2);
    const A3 = @TypeOf(a3);
    const A4 = @TypeOf(a4);
    const A5 = @TypeOf(a5);
    const f: *const fn (id, SEL, A1, A2, A3, A4, A5) callconv(.c) id = @ptrCast(&c.objc_msgSend);
    return f(asId(target), selector, a1, a2, a3, a4, a5);
}

// Send message, return void
pub fn msgSend_void(target: anytype, selector: SEL) void {
    const f: *const fn (id, SEL) callconv(.c) void = @ptrCast(&c.objc_msgSend);
    f(asId(target), selector);
}

pub fn msgSend_void1(target: anytype, selector: SEL, a1: anytype) void {
    const A1 = @TypeOf(a1);
    const f: *const fn (id, SEL, A1) callconv(.c) void = @ptrCast(&c.objc_msgSend);
    f(asId(target), selector, a1);
}

pub fn msgSend_void2(target: anytype, selector: SEL, a1: anytype, a2: anytype) void {
    const A1 = @TypeOf(a1);
    const A2 = @TypeOf(a2);
    const f: *const fn (id, SEL, A1, A2) callconv(.c) void = @ptrCast(&c.objc_msgSend);
    f(asId(target), selector, a1, a2);
}

pub fn msgSend_void3(target: anytype, selector: SEL, a1: anytype, a2: anytype, a3: anytype) void {
    const A1 = @TypeOf(a1);
    const A2 = @TypeOf(a2);
    const A3 = @TypeOf(a3);
    const f: *const fn (id, SEL, A1, A2, A3) callconv(.c) void = @ptrCast(&c.objc_msgSend);
    f(asId(target), selector, a1, a2, a3);
}

pub fn msgSend_void4(target: anytype, selector: SEL, a1: anytype, a2: anytype, a3: anytype, a4: anytype) void {
    const A1 = @TypeOf(a1);
    const A2 = @TypeOf(a2);
    const A3 = @TypeOf(a3);
    const A4 = @TypeOf(a4);
    const f: *const fn (id, SEL, A1, A2, A3, A4) callconv(.c) void = @ptrCast(&c.objc_msgSend);
    f(asId(target), selector, a1, a2, a3, a4);
}

// Send message, return bool
pub fn msgSend_bool(target: anytype, selector: SEL) bool {
    const f: *const fn (id, SEL) callconv(.c) bool = @ptrCast(&c.objc_msgSend);
    return f(asId(target), selector);
}

pub fn msgSend_bool1(target: anytype, selector: SEL, a1: anytype) bool {
    const A1 = @TypeOf(a1);
    const f: *const fn (id, SEL, A1) callconv(.c) bool = @ptrCast(&c.objc_msgSend);
    return f(asId(target), selector, a1);
}

// Send message, return NSUInteger
pub fn msgSend_uint(target: anytype, selector: SEL) NSUInteger {
    const f: *const fn (id, SEL) callconv(.c) NSUInteger = @ptrCast(&c.objc_msgSend);
    return f(asId(target), selector);
}

// Send message, return CGFloat
pub fn msgSend_float(target: anytype, selector: SEL) CGFloat {
    const f: *const fn (id, SEL) callconv(.c) CGFloat = @ptrCast(&c.objc_msgSend);
    return f(asId(target), selector);
}

// Send message, return NSInteger (c_long)
pub fn msgSend_long(target: anytype, selector: SEL) c_long {
    const f: *const fn (id, SEL) callconv(.c) c_long = @ptrCast(&c.objc_msgSend);
    return f(asId(target), selector);
}

// Send message, return NSRect (struct return — on ARM64 this works via regular msgSend)
pub fn msgSend_rect(target: anytype, selector: SEL) NSRect {
    const f: *const fn (id, SEL) callconv(.c) NSRect = @ptrCast(&c.objc_msgSend);
    return f(asId(target), selector);
}

// Convert anything to id
pub fn asId(val: anytype) id {
    const T = @TypeOf(val);
    if (T == id) return val;
    if (T == Class) return val;
    if (T == SEL) return val;
    if (@typeInfo(T) == .optional) {
        if (val) |v| return @ptrCast(v);
        return null;
    }
    if (@typeInfo(T) == .pointer) {
        return @ptrCast(@constCast(val));
    }
    @compileError("Cannot convert " ++ @typeName(T) ++ " to id");
}

// Convenience helpers
pub fn alloc(cls: Class) id {
    return msgSend_id(cls, sel("alloc"));
}

pub fn init(obj: id) id {
    return msgSend_id(obj, sel("init"));
}

pub fn allocInit(cls: Class) id {
    return init(alloc(cls));
}

pub fn release(obj: id) void {
    msgSend_void(obj, sel("release"));
}

pub fn retain(obj: id) id {
    return msgSend_id(obj, sel("retain"));
}

pub fn autorelease(obj: id) id {
    return msgSend_id(obj, sel("autorelease"));
}

// Create an NSString from a C string
pub fn nsString(str: [*:0]const u8) id {
    const NSString = getClass("NSString");
    return msgSend_id1(NSString, sel("stringWithUTF8String:"), str);
}

// Create a new ObjC class at runtime
pub fn allocateClassPair(superclass_name: [*:0]const u8, name: [*:0]const u8) Class {
    const superclass: *anyopaque = getClass(superclass_name) orelse return null;
    const cls: *anyopaque = c.objc_allocateClassPair(@ptrCast(superclass), name, 0) orelse return null;
    return cls;
}

pub fn registerClassPair(cls: Class) void {
    c.objc_registerClassPair(@ptrCast(cls));
}

pub fn addMethod(cls: Class, name: SEL, imp: IMP, types: [*:0]const u8) bool {
    return c.class_addMethod(@ptrCast(cls), @ptrCast(name), @ptrCast(imp), types);
}

pub fn addIvar(cls: Class, name: [*:0]const u8, size: usize, alignment: u8, types: [*:0]const u8) bool {
    return c.class_addIvar(@ptrCast(cls), name, size, alignment, types);
}

pub fn getInstanceVariable(obj: id, name: [*:0]const u8) ?*anyopaque {
    var out: ?*anyopaque = null;
    _ = c.object_getInstanceVariable(@ptrCast(obj), name, &out);
    return out;
}

pub fn setInstanceVariable(obj: id, name: [*:0]const u8, value: ?*anyopaque) void {
    _ = c.object_setInstanceVariable(@ptrCast(obj), name, value);
}
