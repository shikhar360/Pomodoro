import AppKit
import IOKit.pwr_mgt
import SwiftUI

/// Captures the two surfaces this app has: the floating timer and the tray
/// contents. Uses the same views as the running app, with light and dark
/// appearance forced one after the other.
@MainActor
enum Snapshot {
    static var requested: Bool {
        !(ProcessInfo.processInfo.environment["APP_SNAPSHOT"] ?? "").isEmpty
    }

    static func runIfRequested(model: PomodoroModel, window: NSWindow) {
        guard let directory = ProcessInfo.processInfo.environment["APP_SNAPSHOT"], !directory.isEmpty else { return }
        guard ProcessInfo.processInfo.environment["APP_STORE"] != nil else {
            print("SNAPSHOT refused: set APP_STORE to a test path")
            NSApp.terminate(nil)
            return
        }

        Task {
            var activity: IOPMAssertionID = 0
            IOPMAssertionDeclareUserActivity("Snapshots" as CFString, kIOPMUserActiveLocal, &activity)
            try? FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)

            model.clickThrough = false
            model.choose(.work)
            model.reset()

            let tray = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 340, height: 820),
                                styleMask: [.titled, .closable],
                                backing: .buffered,
                                defer: false)
            tray.title = "Pomodoro"
            tray.isReleasedWhenClosed = false
            tray.contentView = NSHostingView(rootView: MenuBarView(model: model))
            tray.center()
            tray.makeKeyAndOrderFront(nil)
            try? await Task.sleep(for: .seconds(1))

            for mode in ["light", "dark"] {
                NSApp.appearance = NSAppearance(named: mode == "light" ? .aqua : .darkAqua)
                model.setBackgroundIsLight(mode == "light")
                try? await Task.sleep(for: .seconds(0.6))
                capture(to: "\(directory)/floating-\(mode).png", window: window)
                capture(to: "\(directory)/tray-\(mode).png", window: tray)
            }

            tray.close()
            print("SNAPSHOT done \(directory)")
            NSApp.terminate(nil)
        }
    }

    private static func capture(to path: String, window: NSWindow) {
        if NSApp.isHidden { NSApp.unhideWithoutActivation() }
        window.orderFrontRegardless()
        let size = window.contentView?.bounds.size ?? .zero
        LayoutSnapshot.write(to: path.replacingOccurrences(of: ".png", with: "-layout.json"), window: size)

        for _ in 1...3 {
            let shot = Process()
            shot.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            shot.arguments = ["-x", "-o", "-l", String(window.windowNumber), path]
            try? shot.run()
            shot.waitUntilExit()
            if FileManager.default.fileExists(atPath: path) {
                print("SNAPSHOT \(path)")
                return
            }
            Thread.sleep(forTimeInterval: 0.3)
        }

        guard let view = window.contentView,
              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        if let data = rep.representation(using: .png, properties: [:]) {
            try? data.write(to: URL(fileURLWithPath: path))
            print("SNAPSHOT \(path) (fallback)")
        }
    }
}
