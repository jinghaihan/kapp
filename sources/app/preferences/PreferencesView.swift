// Row structure follows Kap's Preferences: labels, trailing controls, and thin dividers.
import AVFoundation
import ServiceManagement
import SwiftUI

struct PreferencesView: View {
    @Bindable var settings: AppSettings

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                row("Show cursor") { toggle($settings.showCursor) }
                row("Highlight clicks", nested: true) {
                    toggle($settings.highlightClicks).disabled(!settings.showCursor)
                }
                row("Keyboard shortcuts") {
                    toggle(Binding(get: { settings.shortcutsEnabled }, set: { settings.setShortcutsEnabled($0) }))
                }
                if settings.shortcutsEnabled {
                    row("Toggle Kapp", nested: true) {
                        ShortcutRecorder(settings: settings).frame(width: 160, height: 24)
                    }
                }
                row("Microphone recording") { toggle($settings.captureMicrophone) }
                if settings.captureMicrophone {
                    row("Input device", nested: true) {
                        let devices = settings.audioDevices
                        let selected = devices.firstIndex { $0.id == settings.microphoneDeviceID }.map { $0 + 1 } ?? 0
                        PreferencesSelect(label: "Input device", titles: ["System Default"] + devices.map(\.name), selected: selected, width: 208) { index in
                            settings.microphoneDeviceID = index == 0 ? nil : devices[index - 1].id
                        }
                    }
                }
                row("System audio") { toggle($settings.captureSystemAudio) }
                row("Capture frame rate") {
                    PreferencesSelect(label: "Capture frame rate", titles: ["30 FPS", "60 FPS"], selected: settings.captureFrameRate == 30 ? 0 : 1, width: 112) {
                        settings.captureFrameRate = $0 == 0 ? 30 : 60
                    }
                }
                row("Start automatically") {
                    toggle(Binding(get: { settings.startAtLogin }, set: { settings.setStartAtLogin($0) }))
                }
                if settings.loginRequiresApproval {
                    row("Allow Kapp in Login Items", nested: true) {
                        Button("Open System Settings…") { SMAppService.openSystemSettingsLoginItems() }
                            .buttonStyle(KapPreferencesButtonStyle())
                    }
                }
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Save to…").fontWeight(.medium)
                        Text((settings.exportDirectory.path as NSString).abbreviatingWithTildeInPath)
                            .foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                            .help(settings.exportDirectory.path)
                    }
                    Spacer(minLength: 12)
                    Button("Choose…", action: chooseDirectory)
                        .buttonStyle(KapPreferencesButtonStyle())
                }
                .padding(.horizontal, 24).padding(.vertical, 20)
            }
        }
        .font(.system(size: 12))
        .controlSize(.small)
        .background(Color(nsColor: .windowBackgroundColor))
        .frame(minWidth: 500, idealWidth: 560, minHeight: 440, idealHeight: 620)
        .task { settings.refreshAudioDevices(); settings.refreshLoginStatus() }
        .onReceive(NotificationCenter.default.publisher(for: AVCaptureDevice.wasConnectedNotification)) { _ in settings.refreshAudioDevices() }
        .onReceive(NotificationCenter.default.publisher(for: AVCaptureDevice.wasDisconnectedNotification)) { _ in settings.refreshAudioDevices() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in settings.refreshLoginStatus() }
        .alert("Could Not Update Preferences", isPresented: Binding(get: { settings.errorMessage != nil }, set: { if !$0 { settings.errorMessage = nil } })) {
            Button("OK", role: .cancel) { settings.errorMessage = nil }
        } message: { Text(settings.errorMessage ?? "") }
    }

    private func toggle(_ binding: Binding<Bool>) -> some View {
        Toggle("", isOn: binding).labelsHidden().toggleStyle(KapPreferencesToggleStyle())
    }

    private func row<Control: View>(_ title: String, nested: Bool = false, @ViewBuilder control: () -> Control) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                Text(title).fontWeight(nested ? .regular : .medium).foregroundStyle(nested ? .secondary : .primary)
                Spacer(minLength: 16)
                control().accessibilityLabel(title)
            }
            .padding(.horizontal, 24).padding(.vertical, nested ? 12 : 20)
            Divider().padding(.horizontal, 24)
        }
    }

    private func chooseDirectory() {
        guard let window = NSApp.keyWindow else { return }
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = settings.exportDirectory
        panel.beginSheetModal(for: window) { response in
            if response == .OK, let directory = panel.url { settings.exportDirectory = directory }
        }
    }
}

// Match Kap's compact controls while retaining native menu interaction.
private struct PreferencesSelect: View {
    let label: String
    let titles: [String]
    let selected: Int
    let width: CGFloat
    let onSelect: (Int) -> Void
    @State private var anchor = NSView()

    var body: some View {
        Button {
            EditorOptionsMenu.present(titles: titles, selected: selected, anchoredTo: anchor, onSelect: onSelect)
        } label: {
            HStack(spacing: 8) {
                Text(titles[selected]).lineLimit(1).truncationMode(.tail)
                Spacer(minLength: 4)
                Image(systemName: "chevron.down").font(.system(size: 9))
            }
            .padding(.horizontal, 8)
            .frame(width: width, height: 24)
            .modifier(KapPreferencesControlBackground())
        }
        .buttonStyle(.plain)
        .background(EditorMenuAnchor(view: anchor).allowsHitTesting(false))
        .accessibilityLabel(label)
        .accessibilityValue(titles[selected])
    }
}

private struct KapPreferencesControlBackground: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(colorScheme == .dark ? .white.opacity(0.1) : .white, in: .rect(cornerRadius: 4))
            .overlay { RoundedRectangle(cornerRadius: 4).strokeBorder(colorScheme == .dark ? .clear : Color(nsColor: .separatorColor), lineWidth: 1) }
    }
}

private struct KapPreferencesButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12)
            .frame(minWidth: 72, minHeight: 24, maxHeight: 24)
            .modifier(KapPreferencesControlBackground())
            .opacity(configuration.isPressed ? 0.65 : 1)
    }
}

// Adapted from Kap's 48×24 Preferences switch, including its unfilled track.
private struct KapPreferencesToggleStyle: ToggleStyle {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() } label: {
            ZStack(alignment: .leading) {
                Capsule().fill(colorScheme == .dark ? .white.opacity(0.1) : .white)
                Capsule().strokeBorder(colorScheme == .dark ? .clear : Color(nsColor: .separatorColor), lineWidth: 1)
                Circle().fill(configuration.isOn ? (colorScheme == .dark ? .white : Color(red: 0, green: 0.478, blue: 1)) : .gray)
                    .frame(width: 16, height: 16).offset(x: configuration.isOn ? 28 : 4)
            }
            .frame(width: 48, height: 24)
            .opacity(isEnabled ? 1 : 0.4)
        }
        .buttonStyle(.plain)
        .accessibilityValue(configuration.isOn ? "On" : "Off")
        .animation(.easeInOut(duration: 0.12), value: configuration.isOn)
    }
}
