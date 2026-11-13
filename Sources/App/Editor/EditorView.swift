// Preview layout follows Kap: video controls over the picture, a 48pt export row below.
import AppKit
import SwiftUI

struct EditorView: View {
    @Bindable var model: EditorModel
    @State private var copyToClipboard = false
    @State private var formatAnchor = NSView()
    @State private var destinationAnchor = NSView()

    var body: some View {
        VStack(spacing: 0) {
            PlayerView(model: model)
                .frame(minWidth: 640, minHeight: 340)
                .background(.black)
                .overlay(alignment: .bottom) { PlaybackControls(model: model) }
            HStack(spacing: 8) {
                if let range = model.range {
                    Text("\(range.duration.formatted(.number.precision(.fractionLength(2)))) s")
                        .foregroundStyle(.white.opacity(0.6))
                        .monospacedDigit()
                }
                Spacer(minLength: 0)
                Button {
                    EditorOptionsMenu.present(
                        titles: ExportFormat.allCases.map(\.rawValue),
                        selected: ExportFormat.allCases.firstIndex(of: model.format) ?? 0,
                        anchoredTo: formatAnchor
                    ) { model.format = ExportFormat.allCases[$0] }
                } label: { selectorLabel(model.format.rawValue, width: 112) }
                .buttonStyle(.plain)
                .background(EditorMenuAnchor(view: formatAnchor).allowsHitTesting(false))
                .accessibilityLabel("Export Format")
                .disabled(model.isExporting)

                Button {
                    EditorOptionsMenu.present(
                        titles: ["Save to Disk", "Copy to Clipboard"],
                        selected: copyToClipboard ? 1 : 0,
                        anchoredTo: destinationAnchor
                    ) { copyToClipboard = $0 == 1 }
                } label: { selectorLabel(copyToClipboard ? "Copy to Clipboard" : "Save to Disk", width: 128) }
                .buttonStyle(.plain)
                .background(EditorMenuAnchor(view: destinationAnchor).allowsHitTesting(false))
                .accessibilityLabel("Export Destination")
                .disabled(model.isExporting)

                if model.isExporting {
                    ProgressView().controlSize(.small)
                    Button("Cancel") { model.cancelExport() }
                        .buttonStyle(KapEditorButtonStyle())
                } else {
                    Button(model.copied && copyToClipboard ? "Copied" : "Convert") {
                        if copyToClipboard { model.copy() } else { Task { await model.save() } }
                    }
                    .buttonStyle(KapEditorButtonStyle())
                    .disabled(!model.canExport)
                }
            }
            .font(.system(size: 12))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .frame(height: 48)
            .background(Color(white: 0.13))
        }
        .preferredColorScheme(.dark)
        .ignoresSafeArea()
        .task { await model.load() }
        .alert("Kapp", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
    }

    private func selectorLabel(_ text: String, width: CGFloat) -> some View {
        HStack {
            Text(text)
            Spacer(minLength: 4)
            Image(systemName: "chevron.down").font(.system(size: 9))
        }
        .padding(.horizontal, 8)
        .frame(width: width, height: 24)
        .background(.white.opacity(0.1), in: .rect(cornerRadius: 4))
    }
}

private struct KapEditorButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12))
            .foregroundStyle(.white)
            .frame(width: 72, height: 24)
            .background(.white.opacity(configuration.isPressed ? 0.2 : 0.1), in: .rect(cornerRadius: 4))
            .shadow(color: .black.opacity(0.2), radius: 0.5, y: 1)
    }
}
