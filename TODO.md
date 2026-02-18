# TODO

## High Priority

- [x] ~~**Multi-monitor support** — Break overlay and reminders only appear on the main screen. Should cover all screens or at least follow the active screen.~~
- [x] ~~**Idle detection** — Reset the break timer when the user has been away (e.g. screen locked, no input for 5+ min). Currently the timer ticks through lunch breaks.~~
- [x] ~~**Global hotkey** — Bind a keyboard shortcut (e.g. Cmd+Shift+E) to trigger a break immediately or dismiss one.~~
- [x] ~~**Fade in/out animations** — Posture and blink pills appear/disappear instantly. Use NSAnimationContext for smooth alpha transitions.~~
- [x] ~~**Accessibility** — Post NSAccessibilityNotifications so VoiceOver announces break reminders.~~

## Features

- [x] ~~**Do Not Disturb awareness** — Skip reminders when macOS Focus/DND is active.~~
- [x] ~~**Screen lock as break** — Detect screen lock (via distributed notification `com.apple.screenIsLocked`) and count it as a completed break.~~
- [x] ~~**Stretching exercises** — Rotate through short stretch prompts during breaks ("Roll your shoulders", "Stretch your wrists").~~
- [x] ~~**Statistics / history** — Track breaks taken, skipped, and delayed. Show a simple summary in the menu ("12 breaks today, 2 skipped").~~
- [x] ~~**Custom intervals** — Allow arbitrary work/break durations via a text input or stepper, not just presets.~~
- [x] ~~**Notification Center integration** — Option to show breaks as native macOS notifications instead of the overlay.~~
- [x] ~~**Configurable sounds** — Let the user pick from system sounds or disable sound entirely.~~
- [x] ~~**Gentle mode** — Optional smaller, less intrusive break overlay that doesn't cover the full screen (translucent banner at top).~~
- [x] ~~**Strict/lock mode** — Prevent dismissing the break overlay. Block keyboard and mouse for the break duration.~~
- [x] ~~**Hydration reminder** — Same pill pattern as blink/posture but for drinking water.~~

## Polish

- [ ] **App icon** — Design a proper macOS app icon and bundle as .app with Info.plist.
- [ ] **Homebrew formula** — Publish a tap so users can `brew install eyes`.
- [ ] **DMG installer** — Package as a proper .dmg with drag-to-Applications.
- [ ] **Sparkle updates** — Auto-update mechanism so users don't need to rebuild.
- [ ] **Dark/light theme** — Overlay and pills currently assume dark. Respect system appearance for break overlay buttons and text.
- [ ] **Menu bar icon states** — Animate or change the eye icon during breaks (e.g. closed eye), or while paused (e.g. dimmed).
- [ ] **Smooth countdown** — Use a progress ring or bar in the break overlay instead of just a number.
- [ ] **About window** — Version info, links, credits accessible from the menu.

## Code Quality

- [x] ~~**Tests** — Add build-time tests for config parsing, timer state transitions, and format helpers.~~
- [x] ~~**Reduce menu rebuild cost** — Currently `updateMenu()` tears down and recreates every item each second. Diff and update in place.~~
- [x] ~~**Extract ObjC selector registration** — The delegate registration in main.zig is growing. Consider a table-driven approach.~~
- [x] ~~**Error logging** — Some operations silently swallow errors (config save, launchagent). Add `std.log.warn` for failures.~~
- [x] ~~**Memory management audit** — Verify no leaked NSObjects from menus rebuilt every tick.~~
