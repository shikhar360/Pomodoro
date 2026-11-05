# Pomodoro

A native macOS menu-bar utility. It runs on this Mac only, with settings in
`UserDefaults` and no server or database.

## Layout

- `Sources/Pomodoro/` the menu-bar app, floating `NSPanel`, screen sampler, and test modes.
- `Sources/PomodoroKit/` timer rules with no SwiftUI. Tests in `Tests/PomodoroKitTests/`.
- `Package.swift` a Swift package. There is no Xcode project.
- `build.sh` builds, signs, and installs `/Applications/Pomodoro.app`.
- `Icon/AppIcon.icon` the app icon. `build.sh` compiles it with `tools/make_icon.sh`.

## Build and check

- Build and install: `./build.sh`. Add `--open` to restart the app with the new build. Fix warnings.
- Unit tests: `swift test --scratch-path ~/Library/Developer/Pomodoro/test-build`.
- Self-test: `tools/selftest.sh`. Exit 0 when every check passes. Add a check for every timer rule.
- Snapshots: `tools/snap.sh`. Writes `/tmp/Pomodoro-shots/floating-light.png`, `floating-dark.png`, `tray-light.png`, and `tray-dark.png`, then quits.
- The self-test and snapshots require `APP_STORE` to be set so they never change the real saved settings.
- Grid checks: `tools/grid-lint.sh` and `swift tools/check-layout.swift /tmp/Pomodoro-shots/*-layout.json`.
- Done when the build has no errors, the grid checks pass, and the light and dark snapshots look right.

## Design rules

- The menu bar tray is the only settings surface. Keep it system-styled, compact, and keyboard accessible.
- Global shortcuts default to fn-S (Start), fn-P (Pause), fn-R (Reset), and Control-K (Skip). They are Carbon global hotkeys, so they work while another app is frontmost and need no Accessibility permission. Expand "Shortcuts" in the tray to record replacements; they are stored in `UserDefaults`.
- The floating timer is deliberately transparent and borderless. Its digits always adapt to the sampled screen behind them: white on a dark background, black on a light one. No off switch or user-facing threshold needed.
- Each changed digit rolls upward while the next one enters from below, in the spirit of iPhone StandBy. Respect Reduce Motion.
- Screen sampling uses ScreenCaptureKit and requires Screen Recording permission. Ask at most once per app identity; existing installs are marked as already prompted. Never prompt on self-test or snapshot runs.
- Ad-hoc builds must use a stable designated requirement (`identifier "com.shikhar.pomodoro"`), not the default cdhash, or macOS forgets the permission grant at every rebuild.
- Dragging moves the timer. The tray's Size slider scales it. Click-through is an opt-in lock, not the default.
- Use Apple's controls and system styles, and `Space` in `UI/Grid.swift` for tray spacing.
- A menu-bar-only app should not force activation or show a Dock icon (`LSUIElement`).

## Permissions

- Screen Recording: `CGPreflightScreenCaptureAccess()` checks it, and `CGRequestScreenCaptureAccess()` asks once. The tray offers both the request button and the System Settings link.
- The grant is tied to the code signature and path. Use the same signing identity and install path across rebuilds.

## Skills

The bama plugin has a skill for each step: `mac-design` (design rules),
`design-system` (accent and tokens), `layout-grid`, `ux-design`,
`swift-swiftui`, `os-integrations`, `performance`, `build-and-verify`,
`test-mac-app`, `app-icon`, `user-stories`, and `improve-loop`. Use them.

## Git

- Commit after each working change, with a message that says what the user can now do.
