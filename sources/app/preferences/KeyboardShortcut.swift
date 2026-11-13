import AppKit
import Carbon

struct KeyboardShortcut: Codable, Equatable {
    let keyCode: UInt32
    let modifiers: UInt32
    let key: String

    static let `default` = KeyboardShortcut(keyCode: UInt32(kVK_ANSI_5), modifiers: UInt32(cmdKey | shiftKey), key: "5")

    var isValid: Bool {
        keyCode <= 255 && !key.isEmpty && modifiers & UInt32(cmdKey | controlKey | optionKey) != 0
    }

    var displayName: String {
        [(controlKey, "⌃"), (optionKey, "⌥"), (shiftKey, "⇧"), (cmdKey, "⌘")]
            .filter { modifiers & UInt32($0.0) != 0 }.map(\.1).joined() + key
    }

    init(keyCode: UInt32, modifiers: UInt32, key: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.key = key
    }

    init(event: NSEvent) {
        keyCode = UInt32(event.keyCode)
        var flags: UInt32 = 0
        for (flag, carbon) in [(NSEvent.ModifierFlags.command, cmdKey), (.option, optionKey), (.control, controlKey), (.shift, shiftKey)] {
            if event.modifierFlags.contains(flag) { flags |= UInt32(carbon) }
        }
        modifiers = flags
        let special: [UInt16: String] = [36: "↩", 48: "⇥", 49: "Space", 51: "⌫", 123: "←", 124: "→", 125: "↓", 126: "↑"]
        key = special[event.keyCode] ?? event.characters(byApplyingModifiers: [])?.uppercased() ?? ""
    }
}
