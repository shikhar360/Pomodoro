import AppKit
import CoreGraphics
import PomodoroKit
@preconcurrency import ScreenCaptureKit

/// Samples the screen underneath the floating timer and returns its average
/// lightness. No screenshot is stored or leaves the Mac.
@MainActor
enum BackgroundSampler {
    /// - Returns: 0 for black, 1 for white, or nil when sampling is not
    ///   allowed or the display no longer exists.
    static func lightness(behind frame: CGRect, on screen: NSScreen) async -> Double? {
        guard CGPreflightScreenCaptureAccess() else { return nil }

        // macOS 15.2+ captures the exact rectangle. A display-wide capture
        // followed by crop math put the sample in the wrong corner when the
        // timer sat at the bottom-right of the screen.
        if #available(macOS 15.2, *) {
            let rect = captureRect(for: frame)
            guard let image = try? await SCScreenshotManager.captureImage(in: rect) else {
                return nil
            }
            return averageLightness(of: image)
        }

        guard let image = await displayImage(behind: frame, on: screen) else { return nil }
        guard let sample = image.cropping(to: crop(for: frame, on: screen, image: image)) else { return nil }
        return averageLightness(of: sample)
    }

    /// NSWindow and capture rectangles use opposite vertical origins.
    private static func captureRect(for frame: CGRect) -> CGRect {
        let primaryScreenHeight = NSScreen.screens.first?.frame.height ?? frame.maxY
        return PomodoroTimer.captureRect(windowFrame: frame,
                                         primaryScreenHeight: primaryScreenHeight)
    }

    /// Fallback for macOS 15.0 and 15.1: a downscaled full-display image,
    /// excluded from this app's own windows where possible.
    private static func displayImage(behind frame: CGRect, on screen: NSScreen) async -> CGImage? {
        guard let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
              let content = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true),
              let display = content.displays.first(where: { $0.displayID == displayID.uint32Value }) else {
            return nil
        }
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
        return try? await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
    }

    private static func crop(for frame: CGRect, on screen: NSScreen, image: CGImage) -> CGRect {
        PomodoroTimer.sampleRect(windowFrame: frame,
                                 screenFrame: screen.frame,
                                 imageSize: CGSize(width: image.width, height: image.height))
            .intersection(CGRect(x: 0, y: 0, width: image.width, height: image.height))
    }

    private static func averageLightness(of image: CGImage) -> Double? {
        guard image.width > 0, image.height > 0 else { return nil }
        var pixel = [UInt8](repeating: 0, count: 4)
        guard let context = CGContext(data: &pixel,
                                      width: 1, height: 1,
                                      bitsPerComponent: 8, bytesPerRow: 4,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return nil
        }
        context.interpolationQuality = .medium
        context.draw(image, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        return (0.2126 * Double(pixel[0]) + 0.7152 * Double(pixel[1]) + 0.0722 * Double(pixel[2])) / 255
    }
}
