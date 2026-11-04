import AppKit
import Combine
import PomodoroKit
import SwiftUI

/// A transparent, borderless timer that sits above normal windows. It can be
/// dragged anywhere, resized from the menu bar, and made click-through.
@MainActor
final class FloatingTimerWindow: NSPanel {
    private let model: PomodoroModel
    private var cancellables = Set<AnyCancellable>()
    private var samplingTimer: Timer?
    private var sampling = false

    init(model: PomodoroModel) {
        self.model = model
        super.init(contentRect: Self.frame(for: model.timerScale),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered,
                   defer: false)

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .floating
        isFloatingPanel = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        isMovableByWindowBackground = true
        becomesKeyOnlyIfNeeded = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        ignoresMouseEvents = model.clickThrough
        contentView = NSHostingView(rootView: FloatingTimerView(model: model))
        contentView?.wantsLayer = true
        contentView?.layer?.backgroundColor = NSColor.clear.cgColor

        if ProcessInfo.processInfo.environment["APP_STORE"] == nil {
            setFrameAutosaveName("PomodoroFloatingTimer")
        }
        if ProcessInfo.processInfo.environment["APP_STORE"] != nil || frame.origin == .zero {
            positionAtTopRight()
        }

        model.$timerScale
            .sink { [weak self] scale in self?.resize(for: scale) }
            .store(in: &cancellables)
        model.$clickThrough
            .sink { [weak self] clickThrough in self?.ignoresMouseEvents = clickThrough }
            .store(in: &cancellables)
        model.$hasScreenAccess
            .sink { [weak self] _ in self?.updateSampling() }
            .store(in: &cancellables)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func begin() {
        orderFrontRegardless()
        updateSampling()
    }

    private func positionAtTopRight() {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let margin = 40.0
        setFrameTopLeftPoint(NSPoint(x: visible.maxX - frame.width - margin,
                                     y: visible.maxY - margin))
    }

    private func resize(for scale: Double) {
        let oldTop = frame.maxY
        setContentSize(Self.frame(for: scale).size)
        var newFrame = frame
        newFrame.origin.y = oldTop - newFrame.height
        setFrame(newFrame, display: true)
    }

    private static func frame(for scale: Double) -> NSRect {
        NSRect(x: 0, y: 0, width: 260 * scale, height: 88 * scale)
    }

    private func updateSampling() {
        samplingTimer?.invalidate()
        samplingTimer = nil
        let timer = Timer(timeInterval: 0.6, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.sampleBackground() }
        }
        timer.tolerance = 0.2
        RunLoop.main.add(timer, forMode: .common)
        samplingTimer = timer
        sampleBackground()
    }

    private func sampleBackground() {
        guard !sampling else { return }
        guard model.hasScreenAccess else {
            model.refreshScreenAccess()
            return
        }
        guard let screen = screen ?? NSScreen.main else { return }
        let timerFrame = frame
        sampling = true
        Task { [weak self] in
            let lightness = await BackgroundSampler.lightness(behind: timerFrame, on: screen)
            guard let self else { return }
            self.sampling = false
            guard let lightness else {
                self.model.refreshScreenAccess()
                return
            }
            if ProcessInfo.processInfo.environment["APP_COLOR_LOG"] != nil {
                print("COLOR lightness=\(lightness) lightText=\(PomodoroTimer.usesLightText(forBackgroundLightness: lightness)) frame=\(timerFrame)")
                fflush(stdout)
            }
            // Repeated every 0.6 s: a dark background gets white digits and a
            // light one gets black digits.
            self.model.setBackgroundIsLight(!PomodoroTimer.usesLightText(forBackgroundLightness: lightness))
        }
    }
}

/// The timer itself. Everything except the digits is transparent.
struct FloatingTimerView: View {
    @ObservedObject var model: PomodoroModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(model.formattedRemaining.enumerated()), id: \.offset) { _, character in
                if character == ":" {
                    Text(":")
                        .font(.system(size: 46 * model.timerScale, weight: .medium, design: .rounded))
                        .foregroundStyle(model.usesLightText ? Color.white : Color.black)
                        .shadow(color: model.usesLightText ? .black.opacity(0.7) : .white.opacity(0.7),
                                radius: 2 * model.timerScale,
                                y: 1)
                        .frame(width: 24 * model.timerScale, height: 76 * model.timerScale)
                } else {
                    RollingDigit(character: character,
                                 scale: model.timerScale,
                                 lightText: model.usesLightText,
                                 animate: model.isRunning && !reduceMotion)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .help(model.clickThrough ? "The timer is click-through. Turn that off in the Pomodoro menu." : "Drag to move the timer")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(model.phaseTitle), \(model.formattedRemaining)")
    }
}

/// One character in the countdown. Changed digits slide up while their
/// replacement comes from below, like iPhone StandBy's rolling clock.
private struct RollingDigit: View {
    let character: Character
    let scale: Double
    let lightText: Bool
    let animate: Bool

    var body: some View {
        ZStack {
            Text(String(character))
                .font(.system(size: 52 * scale, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(lightText ? Color.white : Color.black)
                .shadow(color: lightText ? .black.opacity(0.7) : .white.opacity(0.7),
                        radius: 2 * scale,
                        y: 1)
                .id(character)
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
        }
        .frame(width: 36 * scale, height: 76 * scale)
        .clipped()
        .animation(animate ? .easeInOut(duration: 0.28) : nil, value: character)
    }
}
