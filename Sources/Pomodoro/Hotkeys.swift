import AppKit
import Carbon.HIToolbox
import Combine
import PomodoroKit

/// Registers the three timer actions as global Carbon hotkeys. Carbon is
/// old, but it is the public API that accepts fn as a modifier without
/// asking for Accessibility permission.
@MainActor
final class GlobalHotkeys {
    static let shared = GlobalHotkeys()

    private weak var model: PomodoroModel?
    private var handler: EventHandlerRef?
    private var registrations: [ShortcutAction: EventHotKeyRef] = [:]
    private var cancellable: AnyCancellable?
    private var registrationError: String?
    private var isRecording = false

    private init() {}

    func start(model: PomodoroModel) {
        guard self.model == nil else { return }
        self.model = model
        installHandler()
        registerAll()
        cancellable = model.$shortcuts
            .dropFirst()
            .sink { [weak self] _ in
                self?.registerAll()
            }
    }

    private func installHandler() {
        guard handler == nil else { return }
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let event, let userData else { return OSStatus(eventNotHandledErr) }
            var hotKeyID = EventHotKeyID()
            let result = GetEventParameter(event,
                                           EventParamName(kEventParamDirectObject),
                                           EventParamType(typeEventHotKeyID),
                                           nil,
                                           MemoryLayout<EventHotKeyID>.size,
                                           nil,
                                           &hotKeyID)
            guard result == noErr else { return OSStatus(eventNotHandledErr) }
            let actionRaw = hotKeyID.id
            MainActor.assumeIsolated {
                let hotkeys = Unmanaged<GlobalHotkeys>.fromOpaque(userData).takeUnretainedValue()
                hotkeys.run(actionRaw)
            }
            return noErr
        }, 1, &type, Unmanaged.passUnretained(self).toOpaque(), &handler)

        if status != noErr {
            registrationError = "Could not install the shortcut handler (\(status))."
        }
    }

    /// While the recorder is listening, release the global hotkeys so pressing
    /// a shortcut edits it instead of firing the timer.
    func setRecording(_ recording: Bool) {
        guard isRecording != recording else { return }
        isRecording = recording
        registerAll()
    }

    private func registerAll() {
        guard let model else { return }
        for ref in registrations.values { UnregisterEventHotKey(ref) }
        registrations.removeAll()
        registrationError = nil
        guard !isRecording else { return }

        for action in ShortcutAction.allCases {
            let shortcut = model.shortcut(for: action)
            var ref: EventHotKeyRef?
            let id = EventHotKeyID(signature: Self.signature, id: action.registrationID)
            let status = RegisterEventHotKey(shortcut.keyCode,
                                             shortcut.carbonModifiers,
                                             id,
                                             GetApplicationEventTarget(),
                                             0,
                                             &ref)
            if status == noErr, let ref {
                registrations[action] = ref
            } else if status == eventHotKeyExistsErr {
                registrationError = "\(shortcut.display) is already used by another app."
                print("HOTKEY conflict \(shortcut.display)")
            } else {
                registrationError = "Could not register \(shortcut.display)."
                print("HOTKEY error \(status) for \(shortcut.display)")
            }
        }
    }

    private func run(_ id: UInt32) {
        guard let action = ShortcutAction.allCases.first(where: { $0.registrationID == id }),
              let model else { return }
        switch action {
        case .start: model.start()
        case .pause: model.pause()
        case .reset: model.reset()
        case .skip: model.skip()
        }
    }

    private static let signature: OSType = 0x504F4D4F // "POMO"
}

private extension Shortcut {
    var carbonModifiers: UInt32 {
        var value: UInt32 = 0
        if modifiers.contains(.command) { value |= UInt32(cmdKey) }
        if modifiers.contains(.control) { value |= UInt32(controlKey) }
        if modifiers.contains(.option) { value |= UInt32(optionKey) }
        if modifiers.contains(.shift) { value |= UInt32(shiftKey) }
        if modifiers.contains(.function) { value |= UInt32(kEventKeyModifierFnMask) }
        return value
    }
}

private extension ShortcutAction {
    var registrationID: UInt32 {
        switch self {
        case .start: 1
        case .pause: 2
        case .reset: 3
        case .skip: 4
        }
    }
}
