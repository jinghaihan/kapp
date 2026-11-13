import SwiftUI

struct EditorView: View {
    @Bindable var model: EditorModel

    var body: some View {
        VStack(spacing: 0) {
            PlayerView(model: model)
                .frame(minWidth: 600, minHeight: 340)
            Divider()
            HStack {
                Picker("Format", selection: $model.format) {
                    ForEach(ExportFormat.allCases) { format in
                        Text(format.rawValue).tag(format)
                    }
                }
                .labelsHidden()
                .fixedSize()
                .disabled(model.isExporting)
                if let range = model.range {
                    Text("\(range.duration.formatted(.number.precision(.fractionLength(1)))) s")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Spacer()
                if model.isExporting {
                    ProgressView().controlSize(.small)
                    Button("Cancel") { model.cancelExport() }
                } else {
                    Button(model.copied ? "Copied" : "Copy", systemImage: "doc.on.doc") { model.copy() }
                        .disabled(!model.canExport)
                    Button("Export…", systemImage: "square.and.arrow.up") {
                        Task { await model.save() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!model.canExport)
                }
            }
            .padding()
        }
        .task { await model.load() }
        .alert("Kapp", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
    }
}
