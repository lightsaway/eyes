// Minimal Foundation framework bindings.

const objc = @import("objc.zig");

const id = objc.id;
const SEL = objc.SEL;

// NSAutoreleasePool
pub fn createAutoreleasePool() id {
    return objc.allocInit(objc.getClass("NSAutoreleasePool"));
}

// NSTimer
pub fn scheduledTimer(interval: f64, target: id, selector: SEL, repeats: bool) id {
    const NSTimer = objc.getClass("NSTimer");
    return objc.msgSend_id5(
        NSTimer,
        objc.sel("scheduledTimerWithTimeInterval:target:selector:userInfo:repeats:"),
        interval,
        target,
        selector,
        @as(id, null),
        @as(c_char, if (repeats) 1 else 0),
    );
}

// NSTimer invalidate
pub fn invalidateTimer(timer: id) void {
    objc.msgSend_void(timer, objc.sel("invalidate"));
}

// NSProcessInfo
pub fn processInfo() id {
    return objc.msgSend_id(objc.getClass("NSProcessInfo"), objc.sel("processInfo"));
}
