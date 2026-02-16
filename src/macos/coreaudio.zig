// CoreAudio HAL bindings — detect active microphones.

const std = @import("std");

// AudioObjectPropertyAddress
const AudioObjectPropertyAddress = extern struct {
    mSelector: u32,
    mScope: u32,
    mElement: u32,
};

// Constants
const kAudioHardwarePropertyDevices: u32 = 0x64657623; // 'dev#'
const kAudioDevicePropertyStreams: u32 = 0x73746D23; // 'stm#'
const kAudioDevicePropertyDeviceIsRunning: u32 = 0x676F696E; // 'goin'
const kAudioDevicePropertyDeviceIsRunningSomewhere: u32 = 0x676F6E65; // 'gone'
const kAudioObjectPropertyScopeGlobal: u32 = 0x676C6F62; // 'glob'
const kAudioObjectPropertyScopeInput: u32 = 0x696E7074; // 'inpt'
const kAudioObjectPropertyElementMain: u32 = 0; // element 0 (was kAudioObjectPropertyElementMaster)
const kAudioObjectSystemObject: u32 = 1;

// CoreAudio HAL functions
extern "CoreAudio" fn AudioObjectGetPropertyDataSize(
    inObjectID: u32,
    inAddress: *const AudioObjectPropertyAddress,
    inQualifierDataSize: u32,
    inQualifierData: ?*const anyopaque,
    outDataSize: *u32,
) i32;

extern "CoreAudio" fn AudioObjectGetPropertyData(
    inObjectID: u32,
    inAddress: *const AudioObjectPropertyAddress,
    inQualifierDataSize: u32,
    inQualifierData: ?*const anyopaque,
    ioDataSize: *u32,
    outData: [*]u8,
) i32;

var check_count: u32 = 0;
var last_result: bool = false;

/// Check if any audio input device (microphone) is currently active.
/// Uses CoreAudio HAL to query device state — no permissions required.
pub fn isAnyMicrophoneActive() bool {
    check_count += 1;
    // Log full details on first check and every 10 seconds
    const verbose = (check_count <= 1) or (check_count % 10 == 0);

    // Get list of all audio devices
    var devices_addr = AudioObjectPropertyAddress{
        .mSelector = kAudioHardwarePropertyDevices,
        .mScope = kAudioObjectPropertyScopeGlobal,
        .mElement = kAudioObjectPropertyElementMain,
    };

    var data_size: u32 = 0;
    var status = AudioObjectGetPropertyDataSize(
        kAudioObjectSystemObject,
        &devices_addr,
        0,
        null,
        &data_size,
    );
    if (status != 0 or data_size == 0) {
        std.log.info("coreaudio: failed to get device list size (status={d}, size={d})", .{ status, data_size });
        return false;
    }

    const device_count = data_size / @sizeOf(u32);
    if (device_count == 0 or device_count > 64) {
        std.log.info("coreaudio: unexpected device count: {d}", .{device_count});
        return false;
    }

    var device_ids: [64]u32 = undefined;
    status = AudioObjectGetPropertyData(
        kAudioObjectSystemObject,
        &devices_addr,
        0,
        null,
        &data_size,
        @ptrCast(&device_ids),
    );
    if (status != 0) {
        std.log.info("coreaudio: failed to get device list (status={d})", .{status});
        return false;
    }

    if (verbose) {
        std.log.info("coreaudio: scanning {d} audio devices (check #{d})", .{ device_count, check_count });
    }

    // Check each device for active input streams
    for (device_ids[0..device_count]) |device_id| {
        if (isDeviceActiveInput(device_id, verbose)) {
            if (!last_result or verbose) {
                std.log.info("coreaudio: device {d} has active mic input → mic ACTIVE", .{device_id});
            }
            last_result = true;
            return true;
        }
    }

    if (last_result or verbose) {
        std.log.info("coreaudio: no active mic found → mic INACTIVE", .{});
    }
    last_result = false;
    return false;
}

fn isDeviceActiveInput(device_id: u32, verbose: bool) bool {
    // Check if device has input streams
    var streams_addr = AudioObjectPropertyAddress{
        .mSelector = kAudioDevicePropertyStreams,
        .mScope = kAudioObjectPropertyScopeInput,
        .mElement = kAudioObjectPropertyElementMain,
    };

    var stream_size: u32 = 0;
    var status = AudioObjectGetPropertyDataSize(
        device_id,
        &streams_addr,
        0,
        null,
        &stream_size,
    );
    if (status != 0 or stream_size == 0) return false;

    const stream_count = stream_size / @sizeOf(u32);

    // Device has input streams — check if it's running
    var running_addr = AudioObjectPropertyAddress{
        .mSelector = kAudioDevicePropertyDeviceIsRunningSomewhere,
        .mScope = kAudioObjectPropertyScopeGlobal,
        .mElement = kAudioObjectPropertyElementMain,
    };

    var is_running: u32 = 0;
    var running_size: u32 = @sizeOf(u32);
    status = AudioObjectGetPropertyData(
        device_id,
        &running_addr,
        0,
        null,
        &running_size,
        @ptrCast(&is_running),
    );
    if (status != 0) {
        if (verbose) std.log.info("coreaudio: device {d} — failed to query running (status={d})", .{ device_id, status });
        return false;
    }

    if (verbose) {
        std.log.info("coreaudio: device {d} — {d} input stream(s), running={d}", .{ device_id, stream_count, is_running });
    }

    return is_running != 0;
}
