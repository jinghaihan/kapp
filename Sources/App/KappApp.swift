import SwiftUI

@main
struct KappApp: App {
    @State private var model = RecorderModel()

    var body: some Scene {
        Window("Kapp", id: "recorder") {
            RecorderView(model: model)
        }
        .windowResizability(.contentSize)

        MenuBarExtra("Kapp", systemImage: model.session.state.isRecording ? "record.circle.fill" : "record.circle") {
            RecorderMenu(model: model)
        }
    }
}

private struct RecorderMenu: View {
    let model: RecorderModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        if model.session.state.isRecording {
            Button("Stop Recording", systemImage: "stop.circle") {
                Task { await model.stop() }
            }
            Button(model.session.state == .paused ? "Resume" : "Pause") {
                model.session.togglePause()
            }
        }
        Button("Show Kapp", systemImage: "macwindow") { openWindow(id: "recorder") }
        Divider()
        Button("Quit Kapp") { NSApplication.shared.terminate(nil) }
            .disabled(model.session.state != .idle || model.isSelecting)
    }
}
