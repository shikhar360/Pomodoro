import AppKit
import Carbon.HIToolbox
import PomodoroKit
import SwiftUI

/// A keyboard shortcut field. Click, then press a new combination. Esc cancels.
/// A local AppKit monitor is enough while the tray is the active panel; the
/// saved combination is handled globally by GlobalHotkeys.
struct ShortcutRecorder: NSViewRepresentable {
    let action: ShortcutAction
    @ObservedObject var model: PomodoroModel

    func makeNSView(context: Context) -> ShortcutField {
        let field = ShortcutField()
        field.update(model.shortcut(for: action), action: action.title)
        field.onShortcut = { [weak model, action] shortcut in
            _ = model?.setShortcut(shortcut, for: action)
        }
        field.onRecording = { recording in
            GlobalHotkeys.shared.setRecording(recording)
        }
        return field
    }

    func updateNSView(_ field: ShortcutField, context: Context) {
        field.update(model.shortcut(for: action), action: action.title)
    }
}

final class ShortcutField: NSControl {
    var onShortcut: ((Shortcut) -> Void)?
    var onRecording: ((Bool) -> Void)?
    private var monitor: Any?
    private var recording = false
    private var shortcut = ShortcutAction.start.defaultShortcut
    private let textField = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        textField.alignment = .center
        textField.font = .monospacedSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .medium)
        textField.textColor = .labelColor
        textField.isBezeled = false
        textField.drawsBackground = false
        addSubview(textField)
        wantsLayer = true
        layer?.borderWidth = 1
        layer?.cornerRadius = 4
        toolTip = "Click to change. Esc cancels."
        setAccessibilityRole(.button)
    }

    required init?(coder: NSCoder) { nil }

    func update(_ newShortcut: Shortcut, action: String) {
        shortcut = newShortcut
        if !recording { textField.stringValue = newShortcut.display }
        setAccessibilityLabel("\(action) shortcut")
        setAccessibilityValue(newShortcut.display)
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 112, height: 24)
    }

    /// The label sits inside the control; keep the click on the control so it
    /// starts recording instead of being swallowed by a non-editable label.
    override func hitTest(_ point: NSPoint) -> NSView? { self }

    override func layout() {
        super.layout()
        textField.frame = bounds
        layer?.borderColor = NSColor.separatorColor.cgColor
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil { stopRecording() }
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        recording ? stopRecording() : startRecording()
    }

    override func keyDown(with event: NSEvent) {
        if recording { capture(event) } else { super.keyDown(with: event) }
    }

    override func becomeFirstResponder() -> Bool {
        startRecording()
        return true
    }

    override func resignFirstResponder() -> Bool {
        stopRecording()
        return true
    }

    private func startRecording() {
        guard monitor == nil else { return }
        recording = true
        textField.stringValue = "Press keys…"
        onRecording?(true)
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self, self.recording else { return event }
            self.capture(event)
            return nil
        }
    }

    private func capture(_ event: NSEvent) {
        guard event.type == .keyDown else { return }
        if event.keyCode == UInt16(kVK_Escape) {
            stopRecording()
            return
        }
        let modifiers = Shortcut.Modifiers(from: event.modifierFlags)
        let candidate = Shortcut(keyCode: UInt32(event.keyCode), modifiers: modifiers)
        guard candidate.isUsable else {
            NSSound.beep()
            return
        }
        onShortcut?(candidate)
        stopRecording()
    }

    private func stopRecording() {
        guard recording || monitor != nil else { return }
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        recording = false
        textField.stringValue = shortcut.display
        onRecording?(false)
        window?.makeFirstResponder(nil)
    }
}

private extension Shortcut.Modifiers {
    init(from flags: NSEvent.ModifierFlags) {
        self = []
        if flags.contains(.command) { insert(.command) }
        if flags.contains(.control) { insert(.control) }
        if flags.contains(.option) { insert(.option) }
        if flags.contains(.shift) { insert(.shift) }
        if flags.contains(.function) { insert(.function) }
    }
}
