import AppKit
import PomodoroKit

/// Runs the real model actions without touching the user's saved settings.
/// APP_STORE is the template's existing guard for an isolated test run.
@MainActor
enum SelfTest {
    static var requested: Bool { CommandLine.arguments.contains("--selftest") }
    static var exitCode: Int32 = 0
    private static var failures = 0
    private static var count = 0

    static func runIfRequested(model: PomodoroModel) {
        guard requested else { return }
        setvbuf(stdout, nil, _IOLBF, 0)
        guard ProcessInfo.processInfo.environment["APP_STORE"] != nil else {
            print("SELFTEST refused: set APP_STORE to a test path")
            finish(code: 1)
            return
        }

        Task {
            try? await Task.sleep(for: .milliseconds(100))
            model.resetCycle()
            check("reset starts at focus", model.phase == .work)
            check("focus duration is applied", model.remainingSeconds == TimeInterval(model.workMinutes * 60))

            model.start()
            check("start runs the timer", model.isRunning)
            model.pause()
            check("pause stops the timer", !model.isRunning)
            model.reset()
            check("reset restores the current duration", model.remainingSeconds == TimeInterval(model.workMinutes * 60))

            model.workMinutes = 1
            check("changing focus duration updates an idle timer", model.remainingSeconds == 60)
            model.choose(.shortBreak)
            check("choosing a break switches phase", model.phase == .shortBreak)
            check("break duration is applied", model.remainingSeconds == TimeInterval(model.shortBreakMinutes * 60))
            model.skip()
            check("skipping a break returns to focus", model.phase == .work)

            model.timerScale = 10
            check("timer size is clamped", model.timerScale == 2.6)
            model.timerScale = 1
            model.longBreakEvery = 4
            model.resetCycle()
            check("reset cycle clears completed sessions", model.completedFocusSessions == 0)
            check("long break cycle rule", PomodoroTimer.next(after: .work, completedFocusSessions: 4, longBreakEvery: 4) == .longBreak)

            model.restoreDefaultShortcuts()
            check("default start shortcut is fn-S", model.shortcut(for: .start) == Shortcut(keyCode: 1, modifiers: .function))
            check("default pause shortcut is fn-P", model.shortcut(for: .pause) == Shortcut(keyCode: 35, modifiers: .function))
            check("default reset shortcut is fn-R", model.shortcut(for: .reset) == Shortcut(keyCode: 15, modifiers: .function))
            check("default skip shortcut is control-K", model.shortcut(for: .skip) == Shortcut(keyCode: 40, modifiers: .control))
            let duplicate = Shortcut(keyCode: 1, modifiers: .function)
            check("duplicate shortcuts are rejected", !model.setShortcut(duplicate, for: .pause))
            check("a custom shortcut is accepted", model.setShortcut(Shortcut(keyCode: 2, modifiers: .function), for: .pause))

            print(failures == 0 ? "SELFTEST PASS \(count) checks" : "SELFTEST FAIL \(failures) of \(count) checks")
            finish(code: failures == 0 ? 0 : 1)
        }
    }

    private static func check(_ name: String, _ ok: Bool) {
        count += 1
        if !ok { failures += 1 }
        print(ok ? "PASS \(name)" : "FAIL \(name)")
    }

    static func finish(code: Int32) {
        exitCode = code
        NSApp.terminate(nil)
    }
}
