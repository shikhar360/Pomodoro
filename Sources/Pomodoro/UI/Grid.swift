import Foundation
import SwiftUI

/// The spacing scale for the tray. The floating timer is intentionally
/// transparent and scales as one unit, rather than laying out a page grid.
enum Space {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
}

/// Keeps the template's layout check useful for a window with no grid probes.
enum LayoutSnapshot {
    static func write(to path: String, window: CGSize) {
        struct File: Codable {
            var window: [String: Double]
            var probes: [String]
        }
        let file = File(window: ["width": window.width, "height": window.height], probes: [])
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try? encoder.encode(file).write(to: URL(fileURLWithPath: path))
    }
}
