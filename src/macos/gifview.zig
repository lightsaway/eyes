// Animated GIF helper — loads a GIF from file into an NSImageView with animation.

const std = @import("std");
const objc = @import("objc.zig");
const appkit = @import("appkit.zig");

const id = objc.id;
const CGFloat = objc.CGFloat;
const NSRect = objc.NSRect;
const NSPoint = objc.NSPoint;
const NSSize = objc.NSSize;

/// Create an animated NSImageView from a GIF file path.
/// Returns null if the file doesn't exist or can't be loaded.
/// The returned view is sized to fit within `frame`, scaled proportionally.
pub fn create(path: [:0]const u8, frame_rect: NSRect) id {
    // Load NSImage from file path
    const ns_path = objc.nsString(path);
    const image = objc.msgSend_id1(
        objc.alloc(objc.getClass("NSImage")),
        objc.sel("initWithContentsOfFile:"),
        ns_path,
    );
    if (image == null) {
        std.log.warn("gifview: failed to load image from {s}", .{path.ptr});
        return null;
    }

    // Get image size for proportional scaling
    const img_size: NSSize = objc.msgSend_rect(image, objc.sel("size")).size;
    var display_rect = frame_rect;

    if (img_size.width > 0 and img_size.height > 0) {
        const scale_w = frame_rect.size.width / img_size.width;
        const scale_h = frame_rect.size.height / img_size.height;
        const scale = @min(scale_w, scale_h);
        const w = img_size.width * scale;
        const h = img_size.height * scale;
        display_rect.origin.x = frame_rect.origin.x + (frame_rect.size.width - w) / 2.0;
        display_rect.origin.y = frame_rect.origin.y + (frame_rect.size.height - h) / 2.0;
        display_rect.size.width = w;
        display_rect.size.height = h;
    }

    // Create NSImageView
    const NSImageView = objc.getClass("NSImageView");
    const view = objc.msgSend_id1(
        objc.alloc(NSImageView),
        objc.sel("initWithFrame:"),
        display_rect,
    );
    if (view == null) {
        objc.release(image);
        return null;
    }

    objc.msgSend_void1(view, objc.sel("setImage:"), image);
    objc.msgSend_void1(view, objc.sel("setAnimates:"), @as(c_char, 1));
    // NSImageScaleProportionallyUpOrDown = 3
    objc.msgSend_void1(view, objc.sel("setImageScaling:"), @as(c_ulong, 3));

    objc.release(image);
    return view;
}

/// Release/destroy a GIF view.
pub fn destroy(view: id) void {
    if (view != null) {
        objc.msgSend_void(view, objc.sel("removeFromSuperview"));
        objc.release(view);
    }
}
