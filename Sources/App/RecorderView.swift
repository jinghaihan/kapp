import SwiftUI

/// A minimal native control surface for validating the extracted recorder.
struct RecorderView: View {
    @Bindable var model: RecorderModel

    var body: some View {
        Form {
            LabeledContent("Capture") {
                HStack {
                    Button("Select Area", systemImage: "rectangle.dashed") {
                        Task { await model.selectArea() }
                    }
                    Button("Screen or Window", systemImage: "macwindow") {
                        Task { await model.selectContent() }
                    }
                }
                .disabled(!model.canSelect)
            }

            if let selection = model.selection {
                LabeledContent("Selection", value: selection.label)
            }

            Toggle("System Audio", isOn: $model.configuration.captureSystemAudio)
                .disabled(model.session.state != .idle)
            Toggle("Microphone", isOn: $model.configuration.captureMicrophone)
                .disabled(model.session.state != .idle)
            Toggle("Show Cursor", isOn: $model.configuration.showCursor)
                .disabled(model.session.state != .idle)

            HStack {
                if model.session.state.isRecording {
                    Button(model.session.state == .paused ? "Resume" : "Pause", systemImage: "pause") {
                        model.session.togglePause()
                    }
                    Button("Stop Recording", systemImage: "stop.circle") {
                        Task { await model.stop() }
                    }
                    .keyboardShortcut(".", modifiers: .command)
                } else {
                    Button("Start Recording", systemImage: "record.circle") {
                        Task { await model.start() }
                    }
                    .disabled(model.selection == nil || !model.canSelect)
                }
                if model.session.state == .starting || model.session.state == .stopping {
                    ProgressView().controlSize(.small)
                }
            }

            if let file = model.savedFile {
                LabeledContent("Saved") {
                    Button(file.lastPathComponent, systemImage: "folder") {
                        NSWorkspace.shared.activateFileViewerSelecting([file])
                    }
                }
            }
        }
        .padding()
        .frame(minWidth: 460)
        .fixedSize(horizontal: false, vertical: true)
        .alert("Recording Failed", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }
}
