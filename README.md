# Eyes

A tiny macOS menu bar app that reminds you to take eye breaks, blink, and fix your posture. Written in Zig with native AppKit — no Electron, no Swift, no dependencies.

## Features

- **20-20-20 rule** — Every 20 minutes, look 20 feet away for 20 seconds (configurable)
- **Blink reminder** — Floating eye icon with blink animation, auto-dismisses
- **Posture reminder** — Rising arrow nudge to straighten up, auto-dismisses
- **Meeting detection** — Pauses all reminders when your mic is active
- **Start at Login** — Optional LaunchAgent integration
- **~1.2 MB binary** — Pure Zig, talks directly to ObjC runtime

## Install

### Build from source

Requires [Zig 0.15.2+](https://ziglang.org/download/):

```
git clone https://github.com/yourusername/eyes.git
cd eyes
zig build
```

The binary is at `zig-out/bin/eyes`. Run it directly or copy it to your PATH:

```
cp zig-out/bin/eyes /usr/local/bin/
```

### Run

```
zig build run
```

Or just run the binary:

```
./zig-out/bin/eyes
```

An eye icon appears in your menu bar. Click it to configure intervals, toggle reminders, and more.

## Configuration

Settings are stored in `~/.config/eyes/config.json` and persist across sessions. Everything is configurable from the menu bar dropdown:

| Setting | Default | Description |
|---------|---------|-------------|
| Work interval | 20 min | Time between eye breaks |
| Break duration | 20 sec | How long the break overlay shows |
| Posture reminder | Off | Periodic posture nudge |
| Blink reminder | Off | Periodic blink nudge |
| Pause during meetings | Off | Auto-pause when mic is active |
| Show timer in menu bar | On | Countdown next to the eye icon |

## Architecture

```
src/
  main.zig          — Entry point, ObjC delegate registration, callbacks
  app.zig           — App state, timer logic, config wiring
  menubar.zig       — Status bar icon and dropdown menu
  overlay.zig       — Full-screen break overlay (20-20-20)
  posture.zig       — Posture reminder floating pill
  blink.zig         — Blink reminder floating pill
  config.zig        — JSON config load/save
  launchagent.zig   — Start at Login via LaunchAgent
  macos/
    objc.zig        — ObjC runtime bridge (msgSend variants)
    appkit.zig      — AppKit bindings (NSWindow, NSMenu, etc.)
    foundation.zig  — Foundation bindings (NSTimer, NSString, etc.)
    coregraphics.zig — CoreGraphics bindings
    coreaudio.zig   — CoreAudio mic detection
```

No external dependencies. The ObjC bridge talks directly to the runtime via `@cImport`.

## Requirements

- macOS 12+ (Monterey or later)
- Zig 0.15.2+

## License

MIT
