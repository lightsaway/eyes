const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "eyes",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });

    // Link platform-specific libraries
    if (target.result.os.tag == .macos) {
        exe.root_module.linkFramework("AppKit", .{});
        exe.root_module.linkFramework("CoreGraphics", .{});
        exe.root_module.linkFramework("CoreFoundation", .{});
        exe.root_module.linkFramework("QuartzCore", .{});
        exe.root_module.linkFramework("Foundation", .{});
        exe.root_module.linkFramework("CoreAudio", .{});
        exe.root_module.linkFramework("IOKit", .{});
        exe.root_module.linkFramework("UserNotifications", .{});
    } else if (target.result.os.tag == .linux) {
        // TODO: link X11, GTK, libappindicator, libnotify, etc.
    } else if (target.result.os.tag == .windows) {
        // TODO: link user32, shell32, ole32, etc.
    }

    b.installArtifact(exe);

    // App bundle step
    const bundle_step = b.step("bundle", "Create Eyes.app bundle");
    bundle_step.dependOn(b.getInstallStep());

    // Create bundle directory structure and copy files
    const mkdir_cmd = b.addSystemCommand(&.{
        "sh", "-c",
        "mkdir -p zig-out/Eyes.app/Contents/MacOS zig-out/Eyes.app/Contents/Resources && " ++
            "cp zig-out/bin/eyes zig-out/Eyes.app/Contents/MacOS/eyes && " ++
            "cp resources/Info.plist zig-out/Eyes.app/Contents/Info.plist && " ++
            "test ! -f resources/AppIcon.icns || cp resources/AppIcon.icns zig-out/Eyes.app/Contents/Resources/AppIcon.icns",
    });
    mkdir_cmd.step.dependOn(b.getInstallStep());
    bundle_step.dependOn(&mkdir_cmd.step);

    // Run step
    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // Test step
    const test_step = b.step("test", "Run unit tests");

    const config_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/config.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    test_step.dependOn(&b.addRunArtifact(config_tests).step);
}
