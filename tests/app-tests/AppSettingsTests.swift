import Carbon
import Foundation
import Testing
@testable import Kapp

@MainActor
struct AppSettingsTests {
    private func defaults() -> UserDefaults {
        UserDefaults(suiteName: "kapp-tests-\(UUID().uuidString)")!
    }

    @Test func recordingPreferencesSurviveRestartAndReachTheCaptureConfiguration() {
        let store = defaults()
        let settings = AppSettings(defaults: store, loginItem: TestLoginItem())
        settings.highlightClicks = true
        settings.captureFrameRate = 30
        settings.captureMicrophone = true
        settings.microphoneDeviceID = "external-microphone"
        settings.captureSystemAudio = true
        let reloaded = AppSettings(defaults: store, loginItem: TestLoginItem())
        let recording = reloaded.recordingConfiguration
        #expect(recording.frameRate == 30)
        #expect(recording.highlightClicks)
        #expect(recording.captureMicrophone && recording.captureSystemAudio)
        #expect(recording.microphoneDeviceID == "external-microphone")
        reloaded.showCursor = false
        #expect(!reloaded.highlightClicks)
        #expect(!AppSettings(defaults: store, loginItem: TestLoginItem()).highlightClicks)
        #expect(!reloaded.recordingConfiguration.showCursor)
    }

    @Test func aConflictingShortcutDoesNotReplaceTheSavedShortcut() {
        let store = defaults()
        let settings = AppSettings(defaults: store, loginItem: TestLoginItem())
        let previous = settings.shortcut
        settings.applyShortcut = { _ in throw TestSettingsError.unavailable }
        let proposed = KeyboardShortcut(keyCode: UInt32(kVK_ANSI_R), modifiers: UInt32(cmdKey | shiftKey), key: "R")
        #expect(!settings.setShortcut(proposed))
        #expect(settings.shortcut == previous)
        #expect(AppSettings(defaults: store, loginItem: TestLoginItem()).shortcut == previous)
        #expect(settings.errorMessage != nil)
        #expect(!settings.setShortcutsEnabled(false))
        #expect(settings.shortcutsEnabled)
    }

    @Test func shortcutsCanBeChangedAndDisabledPersistently() {
        let store = defaults()
        let settings = AppSettings(defaults: store, loginItem: TestLoginItem())
        var applied: KeyboardShortcut?
        settings.applyShortcut = { applied = $0 }
        let shortcut = KeyboardShortcut(keyCode: UInt32(kVK_ANSI_R), modifiers: UInt32(cmdKey | shiftKey), key: "R")
        #expect(settings.setShortcut(shortcut))
        #expect(applied == shortcut)
        #expect(settings.setShortcutsEnabled(false))
        #expect(applied == nil)
        let reloaded = AppSettings(defaults: store, loginItem: TestLoginItem())
        #expect(reloaded.shortcut == shortcut && !reloaded.shortcutsEnabled)
    }

    @Test func theExportFolderIsExplicitAndIndependentOfPreviousSavePanels() {
        let store = defaults()
        store.set("/tmp/previous-export", forKey: "export-directory")
        let settings = AppSettings(defaults: store, loginItem: TestLoginItem())
        #expect(settings.exportDirectory == .desktopDirectory)
        settings.exportDirectory = .temporaryDirectory
        store.set("/tmp/another-save", forKey: "export-directory")
        #expect(AppSettings(defaults: store, loginItem: TestLoginItem()).exportDirectory == .temporaryDirectory)
    }

    @Test func missingMicrophonesFallBackToTheSystemDefault() {
        let settings = AppSettings(defaults: defaults(), loginItem: TestLoginItem())
        settings.microphoneDeviceID = "unplugged"
        settings.updateAudioDevices([AudioInputDevice(id: "connected", name: "USB Microphone")])
        #expect(settings.microphoneDeviceID == nil)
        settings.microphoneDeviceID = "connected"
        settings.updateAudioDevices([AudioInputDevice(id: "connected", name: "USB Microphone")])
        #expect(settings.recordingConfiguration.microphoneDeviceID == "connected")
    }

    @Test func loginFailuresReflectTheSystemStateInsteadOfLeavingAFakeEnabledToggle() {
        let service = TestLoginItem()
        let settings = AppSettings(defaults: defaults(), loginItem: service)
        settings.setStartAtLogin(true)
        #expect(settings.startAtLogin)
        service.fail = true
        settings.setStartAtLogin(false)
        #expect(settings.startAtLogin)
        #expect(settings.errorMessage != nil)
    }
}

@MainActor
final class TestLoginItem: LoginItemManaging {
    var enabled = false
    var requiresApproval = false
    var fail = false
    func setEnabled(_ value: Bool) throws {
        if fail { throw TestSettingsError.unavailable }
        enabled = value
    }
}

private enum TestSettingsError: LocalizedError {
    case unavailable
    var errorDescription: String? { "The setting is unavailable." }
}
