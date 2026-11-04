# Pomodoro

A tiny macOS menu-bar Pomodoro timer with a transparent floating clock.

- Menu-bar controls for start, pause, reset, skip, phase, and durations.
- A transparent floating timer you can drag anywhere and scale from the tray.
- Digits automatically switch between white and black based on the screen behind them.
- Digits roll upward like the iPhone StandBy clock; Reduce Motion turns that off.
- Global shortcuts: `fn-S` start, `fn-P` pause, `fn-R` reset, `Control-K` skip. Custom shortcuts can be recorded in the tray.
- Click-through mode when you want the timer out of the way.
- Screen Recording is used only to sample the colors behind the floating timer. Nothing is saved or uploaded.

## Requirements

- macOS 15 or later.
- To build: Swift 6.1 or later and the macOS Command Line Tools. Xcode is not required.

## Build and install

```sh
./build.sh
```

This builds the app, compiles its icon without Xcode, signs it, and installs it to:

```text
~/Applications/Pomodoro.app
```

Open it with:

```sh
open ~/Applications/Pomodoro.app
```

## Install from the DMG

1. Open `Pomodoro.dmg`.
2. Drag **Pomodoro** into the **Applications** folder shown beside it.
3. Open Pomodoro from Applications.
4. If macOS asks for confirmation the first time, use **Open** from the right-click menu. Ad-hoc signed apps do this because they do not carry a paid Developer ID signature.

## Screen Recording permission

Adaptive color needs Screen Recording permission so the app can read the colors behind the timer. It asks once. If permission was denied or a prior build reset it:

1. Open Pomodoro's tray.
2. Under **Floating timer**, click **Open Screen Recording Settings**.
3. Turn Pomodoro on, then relaunch the app.

The DMG and `build.sh` use a stable ad-hoc designated requirement (`identifier "com.shikhar.pomodoro"`), so later rebuilds keep the same permission grant.

## Make a DMG

```sh
tools/make_dmg.sh
```

Writes `Pomodoro.dmg` in the project root. The disk image contains the app and an **Applications** shortcut for drag-and-drop installation. To make the app first, run `./build.sh`.

## Tests and checks

```sh
swift test --scratch-path ~/Library/Developer/Pomodoro/test-build
tools/selftest.sh
tools/snap.sh
tools/grid-lint.sh
swift tools/check-layout.swift /tmp/Pomodoro-shots/*-layout.json
```

Snapshots are written to `/tmp/Pomodoro-shots/`.

## Project layout

```text
Sources/Pomodoro/       app, floating panel, screen sampler, tray, hotkeys
Sources/PomodoroKit/    timer rules and shortcut model, no SwiftUI
Tests/                  Kit tests
Icon/                   icon layers
tools/                  icon, snapshot, self-test, and DMG scripts
build.sh                build, sign, install
```

## Rebuild after changing code

```sh
./build.sh --open
```

If SwiftPM cannot find a newly added file:

```sh
swift package clean --scratch-path ~/Library/Developer/Pomodoro/build
```

## Recover a lost copy

The installed app lives at `~/Applications/Pomodoro.app`. Keep a copy of the project folder or the generated `Pomodoro.dmg` somewhere safe, such as in Git or a backup drive. To reinstall from the project:

```sh
./build.sh --open
```

To reinstall from a DMG, open it and drag Pomodoro to Applications again.
