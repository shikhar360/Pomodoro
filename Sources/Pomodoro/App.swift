import AppKit
import SwiftUI

// Pomodoro is a menu-bar utility. The timer is a separate transparent panel.
// APP_STORE=<test-path> isolates settings and snapshots from the user's data.
// APP_SNAPSHOT=<dir> captures the floating timer in light and dark mode.
// --selftest exercises the timer controls and quits with 0 or 1.

@main
@MainActor
struct PomodoroApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var model = PomodoroModel.shared

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(model: model)
        } label: {
            Image(systemName: "timer")
                .accessibilityLabel("Pomodoro")
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var floatingTimer: FloatingTimerWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let model = PomodoroModel.shared
        let floatingTimer = FloatingTimerWindow(model: model)
        self.floatingTimer = floatingTimer
        floatingTimer.begin()

        GlobalHotkeys.shared.start(model: model)
        if !SelfTest.requested && !Snapshot.requested {
            model.requestScreenAccessIfNeeded()
        }

        SelfTest.runIfRequested(model: model)
        Snapshot.runIfRequested(model: model, window: floatingTimer)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationWillTerminate(_ notification: Notification) {
        floatingTimer?.close()
        if SelfTest.requested { exit(SelfTest.exitCode) }
    }
}
