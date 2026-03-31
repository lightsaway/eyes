# Eyes

Break reminder for macOS and Linux. Lightweight tray app that follows the 20-20-20 rule — every 20 minutes, look at something 20 feet away for 20 seconds.

Built with Zig and native platform frameworks. No Electron, no runtime dependencies.

## Features

- **20-20-20 break timer** with fullscreen overlay, countdown ring, and stretch prompts
- **Multiple break modes** — fullscreen overlay, gentle banner, or native notification
- **Strict mode** — blocks keyboard and mouse during breaks
- **Blink reminder** — floating pill with blinking eye animation
- **Posture reminder** — rising arrow nudge to straighten up
- **Hydration reminder** — periodic drink water prompt
- **Stretch reminder** — periodic stretch prompt
- **Meeting detection** — pauses automatically when microphone is active
- **Idle detection** — resets timer when you step away
- **Do Not Disturb** — respects system Focus/DND mode
- **Screen lock as break** — counts lock time toward break duration
- **Multi-monitor** — overlay covers all screens simultaneously
- **Big break** — longer breaks at configurable intervals
- **Configurable intervals** — presets (20/20, 30/30, 45/5, 60/5) + custom durations
- **Configurable sounds** — Tink, Pop, Glass, Purr, Hero, or silent
- **Start at login** — LaunchAgent (macOS) or XDG autostart (Linux)
- **Daily stats** — breaks taken, skipped, and delayed in the menu

Config is saved to `~/.config/eyes/config.json`.

## Install

### Homebrew (macOS & Linux)

```sh
brew install lightsaway/eyes/eyes
```

### Nix (any platform)

```sh
# Run directly
nix run github:lightsaway/eyes

# Install to profile
nix profile install github:lightsaway/eyes
```

### AUR (Arch Linux)

```sh
yay -S eyes-break-reminder
```

### From binary

Download the latest release for your platform from [Releases](../../releases):

| Platform | File |
|----------|------|
| macOS (Apple Silicon) | `eyes-macos-arm64.tar.gz` or `Eyes-macos-arm64.zip` |
| Linux (x86_64) | `eyes-linux-x86_64.tar.gz` |
| Linux (aarch64) | `eyes-linux-aarch64.tar.gz` |

### From source

```sh
# macOS — just needs Zig
make install    # builds + copies Eyes.app to /Applications

# Linux — needs Zig + GTK3 dev libraries
# Via Nix (recommended — installs all deps automatically):
nix develop
zig build -Doptimize=ReleaseFast
cp zig-out/bin/eyes ~/.local/bin/

# Via apt (Ubuntu/Debian):
sudo apt install libgtk-3-dev libappindicator3-dev libnotify-dev \
  libcanberra-dev libxss-dev libx11-dev
zig build -Doptimize=ReleaseFast
cp zig-out/bin/eyes ~/.local/bin/
```

## Requirements

**macOS:**
- macOS 13+
- [Zig 0.15.2](https://ziglang.org/download/)

**Linux:**
- GTK3, libappindicator3, libnotify, libcanberra, libXss
- [Zig 0.15.2](https://ziglang.org/download/)
- Or just [Nix](https://nixos.org/download/) — `nix develop` provides everything

## Build

```sh
make build          # Debug build
make release        # Optimized release build
make test           # Run tests
make fmt            # Format source
```

### Linux cross-build (from macOS)

```sh
# Via Docker
make docker-build

# Via OrbStack + Nix
make orb-setup      # One-time: create Ubuntu VM + install Nix
make orb-build      # Build inside VM using Nix flake
```

## Run

```sh
make run            # Debug
make run-release    # Release
```

Eyes appears as a tray/menu bar icon (eye). Click it to access all settings — interval, sounds, break mode, reminders, and more. No dock icon.

## Platform Details

### macOS

- Native AppKit/ObjC bindings — no Swift, no XIB
- Status bar icon with SF Symbols
- Fullscreen overlay with Core Animation ring
- Gentle mode uses NSVisualEffectView (frosted glass)
- Meeting detection via CoreAudio (mic) + CGWindowList (window titles)
- Idle detection via IOKit HIDIdleTime
- DND detection reads Focus mode assertions
- Start at login via LaunchAgent
- ~200KB binary

### Linux

- GTK3 with cairo rendering
- System tray via libappindicator3 (works on GNOME, KDE, XFCE)
- Fullscreen overlay with cairo countdown ring + RGBA transparency
- Gentle mode with slide-in/out animation
- Meeting detection via `/proc` scanning (Zoom, Teams, Slack, etc.)
- Idle detection via X11 XScreenSaver extension (Wayland: limited)
- Mic detection via `/proc/asound` capture device state
- Notifications via libnotify
- Sound via libcanberra (freedesktop sound themes)
- Start at login via XDG autostart desktop file

## Configuration

All settings are accessible from the tray dropdown. Config persists to `~/.config/eyes/config.json`:

```json
{
  "work_interval_secs": 1200,
  "break_duration_secs": 20,
  "show_timer_in_menubar": true,
  "pause_during_meetings": false,
  "smart_meeting_detection": false,
  "posture_reminder_enabled": false,
  "posture_interval_secs": 1800,
  "blink_reminder_enabled": false,
  "blink_interval_secs": 1800,
  "hydration_reminder_enabled": false,
  "hydration_interval_secs": 2700,
  "stretch_reminder_enabled": false,
  "stretch_interval_secs": 1800,
  "idle_threshold_secs": 300,
  "break_sound": 1,
  "respect_dnd": true,
  "screen_lock_as_break": true,
  "use_notification": false,
  "gentle_mode": false,
  "strict_mode": false,
  "big_break_enabled": false,
  "big_break_interval_secs": 3600,
  "big_break_duration_secs": 300
}
```

## Project Structure

```
src/
  main.zig              Entry point (thin dispatcher)
  platform.zig          Comptime platform selection
  app.zig               App state machine, timer logic
  actions.zig           Platform-agnostic action handlers
  config.zig            JSON config load/save
  macos/
    backend.zig         macOS backend interface
    lifecycle.zig       NSApplication lifecycle, ObjC delegate
    objc.zig            ObjC runtime bridge (msgSend wrappers)
    appkit.zig          AppKit bindings
    foundation.zig      Foundation bindings
    coregraphics.zig    CoreGraphics bindings
    coreanim.zig        Core Animation bindings
    coreaudio.zig       CoreAudio mic detection
    iokit.zig           IOKit idle time detection
    meeting.zig         Window title meeting detection
    gifview.zig         Animated GIF loader
  linux/
    backend.zig         Linux backend interface
    lifecycle.zig       GTK application lifecycle
    gtk.zig             GTK3/GLib/cairo C bindings
    overlay.zig         Fullscreen overlay (cairo ring)
    gentle.zig          Translucent banner
    menubar.zig         AppIndicator tray + GtkMenu
    autostart.zig       XDG desktop file
    idle.zig            X11 XScreenSaver idle detection
    mic.zig             /proc/asound mic detection
    meeting.zig         /proc process scanning
    notify.zig          libnotify notifications
    sound.zig           libcanberra sound playback
    reminders/          Pill reminder wrappers
  overlay.zig           macOS fullscreen overlay
  gentle.zig            macOS gentle banner
  menubar.zig           macOS status bar menu
  launchagent.zig       macOS start-at-login
  reminders/
    pill.zig            Shared pill core
    pill_layout.zig     Multi-pill layout
    posture.zig         Posture reminder
    blink.zig           Blink reminder
    hydration.zig       Hydration reminder
    stretch.zig         Stretch reminder
build.zig               Build configuration
build.zig.zon           Package manifest
flake.nix               Nix flake (dev shell + package)
Makefile                Build/test/release commands
packaging/
  homebrew/             Homebrew formula + tap automation
  aur/                  Arch Linux PKGBUILD
resources/
  Info.plist            macOS app bundle metadata
  AppIcon.icns          macOS app icon
```

## CI/CD

Every push and PR runs the [CI workflow](.github/workflows/ci.yml):

- **macOS** — format check, debug build, tests, release build, app bundle verification
- **Linux** — debug build, tests, release build (deps via Nix)

### Releasing

```sh
git tag v0.1.0
git push origin v0.1.0
```

The [release workflow](.github/workflows/release.yml) automatically:

1. Builds release binaries for macOS (arm64) and Linux (x86_64, aarch64)
2. Creates app bundle and DMG (macOS)
3. Publishes GitHub Release with all artifacts + checksums
4. Updates the Homebrew tap formula

### Release artifacts

| File | Platform |
|------|----------|
| `Eyes-0.1.0.dmg` | macOS disk image |
| `Eyes-macos-arm64.zip` | macOS app bundle |
| `eyes-macos-arm64.tar.gz` | macOS binary |
| `eyes-linux-x86_64.tar.gz` | Linux x86_64 binary |
| `eyes-linux-aarch64.tar.gz` | Linux aarch64 binary |
| `checksums.txt` | SHA-256 hashes |

## Development

### With Nix (recommended)

```sh
nix develop      # Enter dev shell with all deps (works on macOS and Linux)
zig build        # Build
zig build test   # Test
```

### Cross-platform testing from macOS

```sh
# Docker — validate Linux build
make docker-build

# OrbStack — build in a Linux VM via Nix
make orb-setup          # One-time setup
make orb-build          # Build

# act — run CI workflows locally
brew install act
act -j build-linux -W .github/workflows/ci.yml
```

### Make Targets

| Target | Description |
|--------|-------------|
| `build` | Compile debug binary |
| `release` | Compile optimized release binary |
| `test` | Run unit tests |
| `run` | Build and run (debug) |
| `run-release` | Build and run (release) |
| `bundle` | Create Eyes.app bundle (macOS) |
| `dmg` | Create DMG disk image (macOS) |
| `install` | Install to /Applications (macOS) |
| `uninstall` | Remove from /Applications (macOS) |
| `linux-install` | Install to ~/.local/bin (Linux) |
| `docker-build` | Build Linux binary via Docker |
| `docker-extract` | Extract Linux binary from Docker |
| `orb-setup` | Create OrbStack VM with Nix |
| `orb-build` | Build in OrbStack via Nix |
| `nix-build` | Build with Nix flake |
| `nix-shell` | Enter Nix dev shell |
| `clean` | Remove build artifacts |
| `fmt` | Format source |
| `dist` | Full release pipeline |
| `tag` | Create git version tag |

## License

MIT
