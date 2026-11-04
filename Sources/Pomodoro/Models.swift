import AppKit
import Combine
import CoreGraphics
import Foundation
import PomodoroKit

/// Everything the menu bar and the floating timer share. One instance per
/// app; `UserDefaults` holds the small settings.
@MainActor
final class PomodoroModel: ObservableObject {
    static let shared = PomodoroModel()

    // MARK: Timer state

    @Published private(set) var phase: PomodoroTimer.Phase = .work
    @Published private(set) var remainingSeconds: TimeInterval = 25 * 60
    @Published private(set) var isRunning = false
    @Published private(set) var completedFocusSessions = 0

    // MARK: Durations, in minutes

    @Published var workMinutes: Int = 25 {
        didSet {
            let fixed = Self.clamp(workMinutes, from: 1, through: 180)
            if fixed != workMinutes {
                workMinutes = fixed
                return
            }
            save(workMinutes, for: "workMinutes")
            resetIdlePhase(.work)
        }
    }

    @Published var shortBreakMinutes: Int = 5 {
        didSet {
            let fixed = Self.clamp(shortBreakMinutes, from: 1, through: 60)
            if fixed != shortBreakMinutes {
                shortBreakMinutes = fixed
                return
            }
            save(shortBreakMinutes, for: "shortBreakMinutes")
            resetIdlePhase(.shortBreak)
        }
    }

    @Published var longBreakMinutes: Int = 15 {
        didSet {
            let fixed = Self.clamp(longBreakMinutes, from: 1, through: 120)
            if fixed != longBreakMinutes {
                longBreakMinutes = fixed
                return
            }
            save(longBreakMinutes, for: "longBreakMinutes")
            resetIdlePhase(.longBreak)
        }
    }

    @Published var longBreakEvery: Int = 4 {
        didSet {
            let fixed = Self.clamp(longBreakEvery, from: 2, through: 12)
            if fixed != longBreakEvery {
                longBreakEvery = fixed
                return
            }
            save(longBreakEvery, for: "longBreakEvery")
        }
    }

    // MARK: Floating timer

    /// 0.6 is small, 2.6 is very large. The floating window is sized from this.
    @Published var timerScale: Double = 1 {
        didSet {
            let fixed = min(2.6, max(0.6, timerScale))
            if fixed != timerScale {
                timerScale = fixed
                return
            }
            save(timerScale, for: "timerScale")
        }
    }

    @Published var clickThrough = false {
        didSet { save(clickThrough, for: "clickThrough") }
    }

    /// Always on. The tray used to expose this as a toggle, but a toggle that
    /// looked off was indistinguishable from the feature being broken.
    @Published private(set) var adaptiveColor = true

    /// The floating timer draws white when true, black when false.
    @Published private(set) var usesLightText = true
    @Published private(set) var hasScreenAccess = CGPreflightScreenCaptureAccess()

    // MARK: Global keyboard shortcuts

    @Published var shortcuts: [ShortcutAction: Shortcut] = [:] {
        didSet { saveShortcuts() }
    }

    func shortcut(for action: ShortcutAction) -> Shortcut {
        shortcuts[action] ?? action.defaultShortcut
    }

    func setShortcut(_ shortcut: Shortcut, for action: ShortcutAction) -> Bool {
        guard shortcut.isUsable,
              !shortcuts.contains(where: { $0.key != action && $0.value == shortcut }) else {
            return false
        }
        shortcuts[action] = shortcut
        return true
    }

    func restoreDefaultShortcuts() {
        shortcuts = Shortcut.defaults
    }

    // MARK: Private

    private let defaults: UserDefaults
    private let persists: Bool
    private var endDate: Date?
    private var ticker: Timer?
    private var screenAccessPrompted: Bool

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.persists = ProcessInfo.processInfo.environment["APP_STORE"] == nil
        // Existing installs have already been through the permission sheet.
        // Their missing flag must not make this update ask a second time.
        let existingInstall = defaults.object(forKey: "workMinutes") != nil
        self.screenAccessPrompted = persists
            && (defaults.bool(forKey: "screenAccessPrompted") || existingInstall)
        if persists && existingInstall && !defaults.bool(forKey: "screenAccessPrompted") {
            defaults.set(true, forKey: "screenAccessPrompted")
        }

        if persists {
            workMinutes = Self.saved(defaults, "workMinutes", fallback: 25, range: 1...180)
            shortBreakMinutes = Self.saved(defaults, "shortBreakMinutes", fallback: 5, range: 1...60)
            longBreakMinutes = Self.saved(defaults, "longBreakMinutes", fallback: 15, range: 1...120)
            longBreakEvery = Self.saved(defaults, "longBreakEvery", fallback: 4, range: 2...12)
            timerScale = min(2.6, max(0.6, (defaults.object(forKey: "timerScale") as? NSNumber)?.doubleValue ?? 1))
            clickThrough = defaults.bool(forKey: "clickThrough")
            if let data = defaults.data(forKey: "shortcuts"),
               let savedShortcuts = try? JSONDecoder().decode([ShortcutAction: Shortcut].self, from: data) {
                for action in ShortcutAction.allCases {
                    if let shortcut = savedShortcuts[action], shortcut.isUsable {
                        shortcuts[action] = shortcut
                    }
                }
            }
        }

        for action in ShortcutAction.allCases where shortcuts[action] == nil {
            shortcuts[action] = action.defaultShortcut
        }
        remainingSeconds = TimeInterval(workMinutes * 60)
        usesLightText = !Self.systemIsLight
        refreshScreenAccess()
    }

    // MARK: Controls

    func toggleRunning() {
        isRunning ? pause() : start()
    }

    func start() {
        guard !isRunning else { return }
        if remainingSeconds <= 0 {
            remainingSeconds = duration(for: phase)
        }
        endDate = Date().addingTimeInterval(remainingSeconds)
        isRunning = true
        startTicker()
    }

    func pause() {
        guard isRunning else { return }
        updateRemaining()
        stopTicker()
        endDate = nil
        isRunning = false
    }

    /// Stops and puts the current phase back to its full duration.
    func reset() {
        stopTicker()
        endDate = nil
        isRunning = false
        remainingSeconds = duration(for: phase)
    }

    /// Stops and returns to the first focus session with a fresh count.
    func resetCycle() {
        stopTicker()
        endDate = nil
        isRunning = false
        phase = .work
        completedFocusSessions = 0
        remainingSeconds = duration(for: .work)
    }

    /// Moves to the next phase without counting an unfinished focus session.
    func skip() {
        stopTicker()
        endDate = nil
        isRunning = false
        if phase == .work {
            phase = .shortBreak
        } else {
            phase = .work
        }
        remainingSeconds = duration(for: phase)
    }

    /// Choosing a phase from the tray moves the timer there and stops it.
    func choose(_ newPhase: PomodoroTimer.Phase) {
        stopTicker()
        endDate = nil
        isRunning = false
        phase = newPhase
        remainingSeconds = duration(for: newPhase)
    }

    /// macOS shows the Screen Recording sheet at most once per app identity.
    /// Remember that we asked, so a denied or lost grant never turns into a
    /// prompt, or a System Settings window, at every launch. The tray button
    /// below opens Settings explicitly when someone asks for it.
    func requestScreenAccessIfNeeded() {
        guard !hasScreenAccess, !screenAccessPrompted else { return }
        screenAccessPrompted = true
        if persists { defaults.set(true, forKey: "screenAccessPrompted") }
        _ = CGRequestScreenCaptureAccess()
        refreshScreenAccess()
    }

    func openScreenRecordingSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") else { return }
        NSWorkspace.shared.open(url)
    }

    func refreshScreenAccess() {
        let access = CGPreflightScreenCaptureAccess()
        if hasScreenAccess != access { hasScreenAccess = access }
    }

    func setBackgroundIsLight(_ isLight: Bool) {
        let lightText = !isLight
        if usesLightText != lightText { usesLightText = lightText }
    }

    // MARK: Read-only display values

    var formattedRemaining: String { PomodoroTimer.clock(remainingSeconds) }
    var progress: Double { PomodoroTimer.progress(remaining: remainingSeconds, duration: duration(for: phase)) }
    var phaseTitle: String { phase.title }

    var phaseSymbol: String {
        switch phase {
        case .work: "brain.head.profile"
        case .shortBreak: "cup.and.saucer"
        case .longBreak: "figure.walk"
        }
    }

    // MARK: Private timer mechanics

    private func duration(for phase: PomodoroTimer.Phase) -> TimeInterval {
        TimeInterval(PomodoroTimer.minutes(for: phase,
                                           work: workMinutes,
                                           shortBreak: shortBreakMinutes,
                                           longBreak: longBreakMinutes) * 60)
    }

    private func resetIdlePhase(_ changed: PomodoroTimer.Phase) {
        guard !isRunning, phase == changed else { return }
        remainingSeconds = duration(for: phase)
    }

    private func startTicker() {
        stopTicker()
        let timer = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        timer.tolerance = 0.1
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    private func updateRemaining() {
        guard let endDate else { return }
        remainingSeconds = max(0, endDate.timeIntervalSinceNow)
    }

    private func tick() {
        guard isRunning, let endDate else { return }
        remainingSeconds = max(0, endDate.timeIntervalSinceNow)
        guard remainingSeconds <= 0 else { return }

        stopTicker()
        self.endDate = nil
        isRunning = false
        if phase == .work {
            completedFocusSessions += 1
        }
        phase = PomodoroTimer.next(after: phase,
                                   completedFocusSessions: completedFocusSessions,
                                   longBreakEvery: longBreakEvery)
        remainingSeconds = duration(for: phase)
    }

    // MARK: Persistence

    private func save(_ value: Any, for key: String) {
        guard persists else { return }
        defaults.set(value, forKey: key)
    }

    private func saveShortcuts() {
        guard persists, let data = try? JSONEncoder().encode(shortcuts) else { return }
        defaults.set(data, forKey: "shortcuts")
    }

    private static func saved(_ defaults: UserDefaults, _ key: String, fallback: Int, range: ClosedRange<Int>) -> Int {
        guard defaults.object(forKey: key) != nil else { return fallback }
        return clamp(defaults.integer(forKey: key), from: range.lowerBound, through: range.upperBound)
    }

    private static func clamp(_ value: Int, from lower: Int, through upper: Int) -> Int {
        min(upper, max(lower, value))
    }

    private static var systemIsLight: Bool {
        NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .aqua
    }
}
