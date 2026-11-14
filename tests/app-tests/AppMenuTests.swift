import AppKit
import Carbon
import KappLocalization
import Testing
@testable import Kapp

@MainActor
struct AppMenuTests {
    @Test func idleMenuContainsOnlyTheAgreedEntries() throws {
        _ = NSApplication.shared
        let menu = AppDelegate().makeMenu()
        #expect(menu.items.filter { !$0.isSeparatorItem }.map(\.title) == ["About Kapp", "Preferences…", "Open Video…", "Quit Kapp"].map { tr($0) })
        #expect(menu.items.first { $0.title == tr("Preferences…") }?.keyEquivalent == ",")
        #expect(menu.items.first { $0.title == tr("Open Video…") }?.keyEquivalent == "o")
    }

    @Test func shortcutLabelsUseTheUnshiftedKeyAndRequireAModifier() throws {
        let shifted = try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [.command, .shift], timestamp: 0, windowNumber: 0, context: nil, characters: "%", charactersIgnoringModifiers: "%", isARepeat: false, keyCode: UInt16(kVK_ANSI_5)))
        let shortcut = KeyboardShortcut(event: shifted)
        #expect(shortcut.displayName == "⇧⌘5")
        #expect(shortcut.isValid)
        #expect(!KeyboardShortcut(keyCode: 0, modifiers: UInt32(shiftKey), key: "A").isValid)
    }
}
