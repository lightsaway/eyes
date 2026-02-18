// Core Animation bindings via ObjC runtime bridge.

const objc = @import("objc.zig");

const id = objc.id;
const CGFloat = objc.CGFloat;

// --- C functions (linked via QuartzCore / CoreGraphics) ---

pub extern "CoreGraphics" fn CGPathCreateMutable() ?*anyopaque;
pub extern "CoreGraphics" fn CGPathAddArc(
    path: ?*anyopaque,
    m: ?*anyopaque, // const CGAffineTransform* — null for identity
    x: CGFloat,
    y: CGFloat,
    radius: CGFloat,
    startAngle: CGFloat,
    endAngle: CGFloat,
    clockwise: bool,
) void;
pub extern "CoreGraphics" fn CGPathRelease(path: ?*anyopaque) void;

pub extern "CoreGraphics" fn CGColorCreateGenericRGB(
    red: CGFloat,
    green: CGFloat,
    blue: CGFloat,
    alpha: CGFloat,
) ?*anyopaque;
pub extern "CoreGraphics" fn CGColorRelease(color: ?*anyopaque) void;

// --- NSNumber ---

pub fn numberWithFloat(value: f32) id {
    return objc.msgSend_id1(
        objc.getClass("NSNumber"),
        objc.sel("numberWithFloat:"),
        value,
    );
}

pub fn numberWithDouble(value: f64) id {
    return objc.msgSend_id1(
        objc.getClass("NSNumber"),
        objc.sel("numberWithDouble:"),
        value,
    );
}

// --- CAShapeLayer ---

pub fn createShapeLayer() id {
    return objc.msgSend_id(objc.getClass("CAShapeLayer"), objc.sel("layer"));
}

pub fn setPath(layer: id, path: ?*anyopaque) void {
    objc.msgSend_void1(layer, objc.sel("setPath:"), path);
}

pub fn setStrokeColor(layer: id, color: ?*anyopaque) void {
    objc.msgSend_void1(layer, objc.sel("setStrokeColor:"), color);
}

pub fn setFillColor(layer: id, color: ?*anyopaque) void {
    objc.msgSend_void1(layer, objc.sel("setFillColor:"), color);
}

pub fn setLineWidth(layer: id, width: CGFloat) void {
    objc.msgSend_void1(layer, objc.sel("setLineWidth:"), width);
}

pub fn setStrokeEnd(layer: id, value: CGFloat) void {
    objc.msgSend_void1(layer, objc.sel("setStrokeEnd:"), value);
}

pub fn setLineCap(layer: id, cap: id) void {
    objc.msgSend_void1(layer, objc.sel("setLineCap:"), cap);
}

// --- CABasicAnimation ---

pub fn animationWithKeyPath(keyPath: [*:0]const u8) id {
    return objc.msgSend_id1(
        objc.getClass("CABasicAnimation"),
        objc.sel("animationWithKeyPath:"),
        objc.nsString(keyPath),
    );
}

pub fn setFromValue(anim: id, value: id) void {
    objc.msgSend_void1(anim, objc.sel("setFromValue:"), value);
}

pub fn setToValue(anim: id, value: id) void {
    objc.msgSend_void1(anim, objc.sel("setToValue:"), value);
}

pub fn setDuration(anim: id, duration: f64) void {
    objc.msgSend_void1(anim, objc.sel("setDuration:"), duration);
}

pub fn setRepeatCount(anim: id, count: f32) void {
    objc.msgSend_void1(anim, objc.sel("setRepeatCount:"), count);
}

pub fn setAutoreverses(anim: id, value: bool) void {
    objc.msgSend_void1(anim, objc.sel("setAutoreverses:"), @as(c_char, if (value) 1 else 0));
}

pub fn setRemovedOnCompletion(anim: id, value: bool) void {
    objc.msgSend_void1(anim, objc.sel("setRemovedOnCompletion:"), @as(c_char, if (value) 1 else 0));
}

// --- CALayer ---

pub fn addAnimation(layer: id, anim: id, key: [*:0]const u8) void {
    objc.msgSend_void2(layer, objc.sel("addAnimation:forKey:"), anim, objc.nsString(key));
}

pub fn removeAllAnimations(layer: id) void {
    objc.msgSend_void(layer, objc.sel("removeAllAnimations"));
}

pub fn addSublayer(parent: id, child: id) void {
    objc.msgSend_void1(parent, objc.sel("addSublayer:"), child);
}

pub fn setShadowColor(layer: id, color: ?*anyopaque) void {
    objc.msgSend_void1(layer, objc.sel("setShadowColor:"), color);
}

pub fn setShadowRadius(layer: id, radius: CGFloat) void {
    objc.msgSend_void1(layer, objc.sel("setShadowRadius:"), radius);
}

pub fn setShadowOpacity(layer: id, opacity: f32) void {
    objc.msgSend_void1(layer, objc.sel("setShadowOpacity:"), opacity);
}

pub fn setShadowOffset(layer: id, size: extern struct { width: CGFloat, height: CGFloat }) void {
    objc.msgSend_void1(layer, objc.sel("setShadowOffset:"), size);
}

// --- Constants ---

/// kCALineCapRound
pub fn lineCapRound() id {
    return objc.nsString("kCALineCapRound");
}

/// Math constants
pub const pi: CGFloat = 3.14159265358979323846;

/// HUGE_VALF — effectively infinite repeat count
pub const HUGE_VALF: f32 = @bitCast(@as(u32, 0x7f800000));
