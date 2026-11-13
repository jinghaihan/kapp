import AppKit
import Carbon

/// A registered hotkey works globally without monitoring keyboard input.
@MainActor
final class RecordingShortcut {
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private let action: () -> Void

    init(action: @escaping () -> Void) throws {
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
        let id = EventHotKeyID(signature: 0x4B415050, id: 1)
        let registered = RegisterEventHotKey(UInt32(kVK_ANSI_5), UInt32(shiftKey | cmdKey),
                                             id, GetApplicationEventTarget(), 0, &hotKey)
        guard registered == noErr else {
            if let handler { RemoveEventHandler(handler) }
            self.handler = nil
            throw ShortcutError.registrationFailed
        }
    }

    isolated deinit {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let handler { RemoveEventHandler(handler) }
    }
}

private enum ShortcutError: LocalizedError {
    case registrationFailed

    var errorDescription: String? {
        "Kapp could not register ⌘⇧5. You can still record and stop from the menu bar."
    }
}
