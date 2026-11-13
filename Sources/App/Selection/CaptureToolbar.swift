import SwiftUI

struct CaptureToolbar: View {
    @Bindable var model: RecorderModel
    let record: () -> Void
    let cancel: () -> Void

    var body: some View {
        HStack {
            Toggle("Microphone", systemImage: "mic", isOn: $model.configuration.captureMicrophone)
                .toggleStyle(.button)
                .labelStyle(.iconOnly)
                .help("Record Microphone")
            Toggle("System Audio", systemImage: "speaker.wave.2", isOn: $model.configuration.captureSystemAudio)
                .toggleStyle(.button)
                .labelStyle(.iconOnly)
                .help("Record System Audio")
            Menu("Options", systemImage: "ellipsis") {
                Toggle("Show Cursor", isOn: $model.configuration.showCursor)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            Divider()
            Button("Record", systemImage: "record.circle", action: record)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: [])
            Button("Cancel", systemImage: "xmark", action: cancel)
                .labelStyle(.iconOnly)
                .keyboardShortcut(.escape, modifiers: [])
        }
        .padding(8)
        .fixedSize()
        .background(.regularMaterial, in: .rect(cornerRadius: 10))
    }
}
