import Foundation

/// A global keyboard shortcut, stored independently of Carbon or AppKit.
public struct Shortcut: Equatable, Codable, Sendable {
    public struct Modifiers: OptionSet, Codable, Sendable {
        public let rawValue: UInt32

        public init(rawValue: UInt32) {
            self.rawValue = rawValue
        }

        public static let command = Modifiers(rawValue: 1 << 0)
        public static let control = Modifiers(rawValue: 1 << 1)
        public static let option = Modifiers(rawValue: 1 << 2)
        public static let shift = Modifiers(rawValue: 1 << 3)
        public static let function = Modifiers(rawValue: 1 << 4)
    }

    public var keyCode: UInt32
    public var modifiers: Modifiers

    public init(keyCode: UInt32, modifiers: Modifiers) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    /// Display order follows Apple's modifier order, with fn first because
    /// that is how people say it: "fn S".
    public var display: String {
        var parts: [String] = []
        if modifiers.contains(.function) { parts.append("fn") }
        if modifiers.contains(.control) { parts.append("⌃") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        if modifiers.contains(.command) { parts.append("⌘") }
        parts.append(Self.keyName(keyCode))
        return parts.joined(separator: " ")
    }

    /// A shortcut without a modifier is only safe for a function key.
    public var isUsable: Bool {
        !modifiers.isEmpty || Self.isFunctionKey(keyCode)
    }

    public static let defaults: [ShortcutAction: Shortcut] = [
        .start: Shortcut(keyCode: 1, modifiers: .function),     // fn S
        .pause: Shortcut(keyCode: 35, modifiers: .function),    // fn P
        .reset: Shortcut(keyCode: 15, modifiers: .function),    // fn R
        .skip: Shortcut(keyCode: 40, modifiers: .control),      // control K
    ]

    private static func isFunctionKey(_ keyCode: UInt32) -> Bool {
        switch keyCode {
        case 96, 97, 98, 99, 100, 101, 103, 105, 107, 109, 111, 113, 118, 120, 122:
            true
        default:
            false
        }
    }

    private static func keyName(_ keyCode: UInt32) -> String {
        switch keyCode {
        case 0: "A"
        case 1: "S"
        case 2: "D"
        case 3: "F"
        case 4: "H"
        case 5: "G"
        case 6: "Z"
        case 7: "X"
        case 8: "C"
        case 9: "V"
        case 11: "B"
        case 12: "Q"
        case 13: "W"
        case 14: "E"
        case 15: "R"
        case 16: "Y"
        case 17: "T"
        case 18: "1"
        case 19: "2"
        case 20: "3"
        case 21: "4"
        case 22: "6"
        case 23: "5"
        case 24: "="
        case 25: "9"
        case 26: "7"
        case 27: "-"
        case 28: "8"
        case 29: "0"
        case 30: "]"
        case 31: "O"
        case 32: "U"
        case 33: "["
        case 34: "I"
        case 35: "P"
        case 37: "L"
        case 38: "J"
        case 39: "'"
        case 40: "K"
        case 41: ";"
        case 42: "\\"
        case 43: ","
        case 44: "/"
        case 45: "N"
        case 46: "M"
        case 47: "."
        case 50: "`"
        case 36: "Return"
        case 48: "Tab"
        case 49: "Space"
        case 51: "Delete"
        case 53: "Esc"
        case 96: "F5"
        case 97: "F6"
        case 98: "F7"
        case 99: "F3"
        case 100: "F8"
        case 101: "F9"
        case 103: "F11"
        case 105: "F13"
        case 107: "F14"
        case 109: "F10"
        case 111: "F12"
        case 113: "F15"
        case 118: "F4"
        case 120: "F2"
        case 122: "F1"
        case 123: "←"
        case 124: "→"
        case 125: "↓"
        case 126: "↑"
        default: "Key \(keyCode)"
        }
    }
}

/// The actions that can have a global shortcut.
public enum ShortcutAction: String, CaseIterable, Codable, Identifiable, Sendable {
    case start
    case pause
    case reset
    case skip

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .start: "Start timer"
        case .pause: "Pause timer"
        case .reset: "Reset timer"
        case .skip: "Skip phase"
        }
    }

    public var defaultShortcut: Shortcut {
        Shortcut.defaults[self]!
    }
}
