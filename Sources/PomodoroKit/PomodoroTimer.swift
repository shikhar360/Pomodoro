import Foundation

/// Timer rules with no UI. The app owns clocks and views; this owns the
/// work/break cycle and the formatting.
public enum PomodoroTimer {
    public enum Phase: String, CaseIterable, Sendable {
        case work
        case shortBreak
        case longBreak

        public var title: String {
            switch self {
            case .work: "Focus"
            case .shortBreak: "Short break"
            case .longBreak: "Long break"
            }
        }

        public var isBreak: Bool { self != .work }
    }

    /// Minutes for a phase. Invalid values fall back to the default.
    public static func minutes(for phase: Phase, work: Int, shortBreak: Int, longBreak: Int) -> Int {
        let value = switch phase {
        case .work: work
        case .shortBreak: shortBreak
        case .longBreak: longBreak
        }
        return max(1, min(180, value))
    }

    /// The phase after `phase` finishes. Four completed focus sessions earn
    /// a long break, counted against the current long-break interval.
    public static func next(after phase: Phase, completedFocusSessions: Int, longBreakEvery: Int) -> Phase {
        switch phase {
        case .work:
            let interval = max(2, longBreakEvery)
            return completedFocusSessions > 0 && completedFocusSessions % interval == 0 ? .longBreak : .shortBreak
        case .shortBreak, .longBreak:
            return .work
        }
    }

    /// "25:00", "04:09", and "0:00" at the end.
    public static func clock(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded(.up)))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    public static func progress(remaining: TimeInterval, duration: TimeInterval) -> Double {
        guard duration > 0 else { return 0 }
        return min(1, max(0, 1 - remaining / duration))
    }

    /// White digits on a dark background, black digits on a light one.
    /// The midpoint keeps mid-gray from sticking to the wrong color.
    public static func usesLightText(forBackgroundLightness lightness: Double) -> Bool {
        lightness <= 0.5
    }
}
