import AppKit
import CoreGraphics
@preconcurrency import ScreenCaptureKit

/// Samples the screen behind the floating timer and returns its average
/// lightness. No screenshot is stored or leaves the Mac.
@MainActor
enum BackgroundSampler {
    /// - Returns: 0 for black, 1 for white, or nil when sampling is not
    ///   allowed or the display no longer exists.
    static func lightness(behind frame: CGRect, on screen: NSScreen) async -> Double? {
        guard CGPreflightScreenCaptureAccess() else { return nil }
        guard let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
              let content = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true),
              let display = content.displays.first(where: { $0.displayID == displayID.uint32Value }) else {
            return nil
        }

        // Excluding this app matters: sampling our own white or black timer
        // would make the color flip back and forth.
        let ownApp = content.applications.first {
            $0.processID == ProcessInfo.processInfo.processIdentifier
        }
        let filter = ownApp.map {
            SCContentFilter(display: display, excludingApplications: [$0], exceptingWindows: [])
        } ?? SCContentFilter(display: display, excludingWindows: [])

        let configuration = SCStreamConfiguration()
        let width = 320
        configuration.width = width
        configuration.height = max(1, Int(Double(width) * Double(display.height) / Double(display.width)))
        configuration.showsCursor = false
        configuration.scalesToFit = true

        guard let image = try? await SCScreenshotManager.captureImage(contentFilter: filter,
                                                                       configuration: configuration),
              image.width > 0, image.height > 0 else {
            return nil
        }

        // SCDisplay frames and CGImage pixels use top-left origin, while
        // NSScreen and NSWindow frames use bottom-left origin.
        let relativeX = (frame.minX - screen.frame.minX) / screen.frame.width
        let relativeTop = (screen.frame.maxY - frame.maxY) / screen.frame.height
        let relativeWidth = frame.width / screen.frame.width
        let relativeHeight = frame.height / screen.frame.height
        let crop = CGRect(x: relativeX * CGFloat(image.width),
                          y: relativeTop * CGFloat(image.height),
                          width: max(1, relativeWidth * CGFloat(image.width)),
                          height: max(1, relativeHeight * CGFloat(image.height)))
            .integral
            .intersection(CGRect(x: 0, y: 0, width: image.width, height: image.height))
        guard crop.width >= 1, crop.height >= 1, let sample = image.cropping(to: crop) else { return nil }

        var pixel = [UInt8](repeating: 0, count: 4)
        guard let context = CGContext(data: &pixel,
                                      width: 1, height: 1,
                                      bitsPerComponent: 8, bytesPerRow: 4,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return nil
        }
        context.interpolationQuality = .medium
        context.draw(sample, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        return (0.2126 * Double(pixel[0]) + 0.7152 * Double(pixel[1]) + 0.0722 * Double(pixel[2])) / 255
    }
}
