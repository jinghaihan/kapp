import AVFoundation
import Foundation
import KappRecording
import Observation
import ServiceManagement

@MainActor
protocol LoginItemManaging {
    var enabled: Bool { get }
    var requiresApproval: Bool { get }
    func setEnabled(_ value: Bool) throws
}

@MainActor
struct SystemLoginItem: LoginItemManaging {
    var enabled: Bool { [.enabled, .requiresApproval].contains(SMAppService.mainApp.status) }
    var requiresApproval: Bool { SMAppService.mainApp.status == .requiresApproval }
    func setEnabled(_ value: Bool) throws {
        if value { try SMAppService.mainApp.register() }
        else { try SMAppService.mainApp.unregister() }
    }
}

struct AudioInputDevice: Identifiable, Equatable {
    let id: String
    let name: String
}

@MainActor
@Observable
final class AppSettings {
    static let shared = AppSettings()
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let loginItem: any LoginItemManaging
    @ObservationIgnored var applyShortcut: ((KeyboardShortcut?) throws -> Void)?

    var showCursor: Bool {
        didSet {
            defaults.set(showCursor, forKey: "capture-show-cursor")
            if !showCursor { highlightClicks = false }
        }
    }
    var highlightClicks: Bool { didSet { defaults.set(highlightClicks, forKey: "capture-highlight-clicks") } }
    var captureFrameRate: Int { didSet { defaults.set(captureFrameRate, forKey: "capture-frame-rate") } }
    var captureMicrophone: Bool { didSet { defaults.set(captureMicrophone, forKey: "capture-microphone") } }
    var microphoneDeviceID: String? { didSet { defaults.set(microphoneDeviceID, forKey: "capture-microphone-device") } }
    var captureSystemAudio: Bool { didSet { defaults.set(captureSystemAudio, forKey: "capture-system-audio") } }
    var exportDirectory: URL { didSet { defaults.set(exportDirectory.path, forKey: "default-export-directory") } }
    private(set) var shortcutsEnabled: Bool
    private(set) var shortcut: KeyboardShortcut
    private(set) var audioDevices: [AudioInputDevice] = []
    private(set) var startAtLogin = false
    private(set) var loginRequiresApproval = false
    var errorMessage: String?

    init(defaults: UserDefaults = .standard, loginItem: any LoginItemManaging = SystemLoginItem()) {
        self.defaults = defaults
        self.loginItem = loginItem
        let cursorEnabled = defaults.object(forKey: "capture-show-cursor") as? Bool ?? true
        showCursor = cursorEnabled
        highlightClicks = cursorEnabled && defaults.bool(forKey: "capture-highlight-clicks")
        captureFrameRate = defaults.integer(forKey: "capture-frame-rate") == 30 ? 30 : 60
        captureMicrophone = defaults.bool(forKey: "capture-microphone")
        microphoneDeviceID = defaults.string(forKey: "capture-microphone-device")
        captureSystemAudio = defaults.bool(forKey: "capture-system-audio")
        exportDirectory = defaults.string(forKey: "default-export-directory").map { URL(filePath: $0, directoryHint: .isDirectory) } ?? .desktopDirectory
        shortcutsEnabled = defaults.object(forKey: "shortcuts-enabled") as? Bool ?? true
        if let data = defaults.data(forKey: "recording-shortcut"),
           let saved = try? JSONDecoder().decode(KeyboardShortcut.self, from: data), saved.isValid {
            shortcut = saved
        } else { shortcut = .default }
        refreshLoginStatus()
    }

    var recordingConfiguration: RecordingConfiguration {
        var configuration = RecordingConfiguration()
        configuration.frameRate = captureFrameRate == 30 ? 30 : 60
        configuration.showCursor = showCursor
        configuration.highlightClicks = showCursor && highlightClicks
        configuration.captureMicrophone = captureMicrophone
        configuration.microphoneDeviceID = microphoneDeviceID
        configuration.captureSystemAudio = captureSystemAudio
        return configuration
    }

    @discardableResult
    func setShortcut(_ value: KeyboardShortcut) -> Bool {
        guard value.isValid else {
            errorMessage = "Use a shortcut with Command, Control, or Option."
            return false
        }
        do {
            let data = try JSONEncoder().encode(value)
            try applyShortcut?(shortcutsEnabled ? value : nil)
            shortcut = value
            defaults.set(data, forKey: "recording-shortcut")
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    @discardableResult
    func setShortcutsEnabled(_ value: Bool) -> Bool {
        do {
            try applyShortcut?(value ? shortcut : nil)
            shortcutsEnabled = value
            defaults.set(value, forKey: "shortcuts-enabled")
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func setRecordingShortcut(_ recording: Bool) {
        do { try applyShortcut?(recording || !shortcutsEnabled ? nil : shortcut) }
        catch { errorMessage = error.localizedDescription }
    }

    func refreshAudioDevices() {
        let discovery = AVCaptureDevice.DiscoverySession(deviceTypes: [.microphone, .external], mediaType: .audio, position: .unspecified)
        updateAudioDevices(discovery.devices.map { AudioInputDevice(id: $0.uniqueID, name: $0.localizedName) })
    }

    func updateAudioDevices(_ devices: [AudioInputDevice]) {
        audioDevices = devices.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        if let selected = microphoneDeviceID, !devices.contains(where: { $0.id == selected }) { microphoneDeviceID = nil }
    }

    func refreshLoginStatus() {
        startAtLogin = loginItem.enabled
        loginRequiresApproval = loginItem.requiresApproval
    }

    func setStartAtLogin(_ value: Bool) {
        do { try loginItem.setEnabled(value) }
        catch { errorMessage = "Could not update Start automatically. " + error.localizedDescription }
        refreshLoginStatus()
    }
}
