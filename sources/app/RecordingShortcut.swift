import KappLocalization
import AppKit
import Carbon

/// A registered hotkey works globally without monitoring keyboard input.
@MainActor
final class RecordingShortcut {
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private let action: () -> Void
    private(set) var binding: KeyboardShortcut?

    init(binding: KeyboardShortcut? = .default, action: @escaping () -> Void) throws {
        self.action = action
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, _, pointer in
            guard let pointer else { return OSStatus(eventNotHandledErr) }
            MainActor.assumeIsolated {
                Unmanaged<RecordingShortcut>.fromOpaque(pointer).takeUnretainedValue().action()
            }
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &handler)
        guard status == noErr else { throw ShortcutError.registrationFailed }
        do { try update(binding) }
        catch {
            if let handler { RemoveEventHandler(handler) }
            self.handler = nil
            throw error
        }
    }

    func update(_ value: KeyboardShortcut?) throws {
        guard value != binding else { return }
        var replacement: EventHotKeyRef?
        if let value {
            let id = EventHotKeyID(signature: 0x4B415050, id: 1)
            guard RegisterEventHotKey(value.keyCode, value.modifiers, id, GetApplicationEventTarget(), 0, &replacement) == noErr else {
                throw ShortcutError.unavailable(value.displayName)
            }
        }
        // Keep the old registration until the replacement is known to be available.
        if let hotKey { UnregisterEventHotKey(hotKey) }
        hotKey = replacement
        binding = value
    }

    isolated deinit {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let handler { RemoveEventHandler(handler) }
    }
}

private enum ShortcutError: LocalizedError {
    case registrationFailed
    case unavailable(String)

    var errorDescription: String? {
        switch self {
        case .registrationFailed: tr("Kapp could not register the recording shortcut. You can still record and stop from the menu bar.")
        case .unavailable(let name): tr("The shortcut %@ is already in use or unavailable. Choose another shortcut.", name)
        }
    }
}
