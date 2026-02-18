# Eyes

Break reminder for macOS. Lightweight menu bar app that follows the 20-20-20 rule — every 20 minutes, look at something 20 feet away for 20 seconds.

Built with Zig and native macOS frameworks. No Electron, no Swift, no runtime dependencies. ~200KB binary.

## Features

- **20-20-20 break timer** with fullscreen overlay, countdown, and stretch prompts
- **Multiple break modes** — fullscreen overlay, gentle banner, or native notification
- **Strict mode** — blocks keyboard and mouse during breaks
- **Blink reminder** — floating pill with blinking eye animation
- **Posture reminder** — rising arrow nudge to straighten up
- **Hydration reminder** — periodic drink water prompt
- **Meeting detection** — pauses automatically when microphone is active
- **Idle detection** — resets timer when you step away (via IOKit)
- **Do Not Disturb** — respects macOS Focus mode
- **Screen lock as break** — counts lock time toward break duration
- **Multi-monitor** — overlay covers all screens
- **Dark/light theme** — adapts to system appearance
- **Global hotkey** — Cmd+Shift+E to toggle break
- **Configurable intervals** — presets + custom work/break durations
- **Configurable sounds** — Tink, Pop, Glass, Purr, Hero, or silent
- **Start at login** — via LaunchAgent
- **Daily stats** — breaks taken, skipped, and delayed in the menu

Config is saved to `~/.config/eyes/config.json`.

## Requirements

- macOS 13+
- [Zig 0.15.2](https://ziglang.org/download/)
- Accessibility permission (for global hotkey and strict mode)

## Build

```sh
# Debug build
make build

# Release build (optimized)
make release

# Run tests
make test

# Format source
make fmt
```

## Run

```sh
# Debug
make run

# Release
make run-release
```

Eyes appears as a menu bar icon (eye). Click it to access all settings — interval, sounds, break mode, reminders, and more. No dock icon.

## Install

### From source

```sh
make install
```

This builds a release binary, creates `Eyes.app`, and copies it to `/Applications`.

### From DMG

Download the latest `.dmg` from [Releases](../../releases), open it, and drag Eyes to Applications.

### Uninstall

```sh
make uninstall
```

## App Bundle

```sh
# Create Eyes.app bundle
make bundle

# Verify
ls zig-out/Eyes.app/Contents/
# Info.plist  MacOS/  Resources/
```

## Create DMG

```sh
make dmg
# → zig-out/Eyes-0.1.0.dmg
```

## Release

Full release pipeline — clean, test, build, bundle, and package:

```sh
make dist
```

### Cutting a release

```sh
# Tag the version
make tag
# → Tags v0.1.0

# Push tag to trigger GitHub Actions release
git push origin v0.1.0
```

The [release workflow](.github/workflows/release.yml) runs tests, builds a release binary, creates the app bundle, DMG, tarball, zip, and SHA-256 checksums, then publishes them as a GitHub Release.

### Release artifacts

| File | Contents |
|---|---|
| `Eyes-0.1.0.dmg` | Disk image with Eyes.app |
| `Eyes-macos-arm64.zip` | Zipped app bundle |
| `eyes-macos-arm64.tar.gz` | Standalone binary |
| `checksums.txt` | SHA-256 hashes |

## CI

Every push and PR to `main` runs the [CI workflow](.github/workflows/ci.yml):

- `zig fmt` check
- Debug build
- Unit tests
- Release build
- App bundle verification

## Make Targets

```
make help
```

| Target | Description |
|---|---|
| `build` | Compile debug binary |
| `release` | Compile optimized release binary |
| `small` | Compile size-optimized binary |
| `test` | Run unit tests |
| `run` | Build and run (debug) |
| `run-release` | Build and run (release) |
| `bundle` | Create Eyes.app bundle (release) |
| `dmg` | Create DMG disk image |
| `install` | Install Eyes.app to /Applications |
| `uninstall` | Remove Eyes.app from /Applications |
| `clean` | Remove build artifacts |
| `fmt` | Format all Zig source files |
| `check` | Check for compilation errors |
| `dist` | Full release: clean, test, bundle, DMG |
| `tag` | Create a git tag for the current version |
| `size` | Show binary size |

## Configuration

All settings are accessible from the menu bar dropdown. Config persists to `~/.config/eyes/config.json`:

```json
{
  "work_interval_secs": 1200,
  "break_duration_secs": 20,
  "show_timer_in_menubar": true,
  "pause_during_meetings": false,
  "posture_reminder_enabled": false,
  "posture_interval_secs": 1800,
  "blink_reminder_enabled": false,
  "blink_interval_secs": 1800,
  "hydration_reminder_enabled": false,
  "hydration_interval_secs": 2700,
  "idle_threshold_secs": 300,
  "break_sound": 1,
  "respect_dnd": true,
  "screen_lock_as_break": true,
  "use_notification": false,
  "gentle_mode": false,
  "strict_mode": false
}
```

## Project Structure

```
src/
  main.zig          Entry point, ObjC delegate registration
  app.zig           App state, timer logic
  menubar.zig       Status bar icon and dropdown menu
  overlay.zig       Fullscreen break overlay (multi-monitor)
  gentle.zig        Gentle mode banner
  blink.zig         Blink reminder pill
  posture.zig       Posture reminder pill
  hydration.zig     Hydration reminder pill
  config.zig        JSON config load/save
  launchagent.zig   Start-at-login via LaunchAgent
  macos/
    objc.zig        ObjC runtime bridge (msgSend wrappers)
    appkit.zig      AppKit bindings
    foundation.zig  Foundation bindings
    coregraphics.zig CoreGraphics bindings
    coreaudio.zig   CoreAudio mic detection
    iokit.zig       IOKit idle time detection
resources/
  Info.plist        App bundle metadata
build.zig           Build configuration
build.zig.zon       Package manifest
Makefile            Build/test/release commands
```

## License

MIT
