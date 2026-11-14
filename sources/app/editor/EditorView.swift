// Preview layout follows Kap: video controls over the picture, a 48pt export row below.
import KappLocalization
import AppKit
import SwiftUI

struct EditorView: View {
    @Bindable var model: EditorModel
    @State private var copyToClipboard = false
    @State private var formatAnchor = NSView()
    @State private var destinationAnchor = NSView()
    @State private var percentageAnchor = NSView()
    @State private var fpsOpen = false
    @State private var hovering = false

    var body: some View {
        VStack(spacing: 0) {
            PlayerView(model: model)
                .frame(minWidth: 680, minHeight: 340)
                .background(.black)
                .overlay(alignment: .bottom) { PlaybackControls(model: model) }
            HStack(spacing: 8) {
                HStack(spacing: 8) {
                    Text(tr("Size"))
                    HStack(spacing: 1) {
                        ExportNumberField(value: model.outputWidth, label: "Width", width: 48, update: model.setWidth)
                        ExportNumberField(value: model.outputHeight, label: "Height", width: 48, update: model.setHeight)
                    }
                    Button {
                        let percentages = [100, 75, 50, 33, 25, 20, 10]
                        let titles = percentages.map { percent in
                            let width = Int((model.sourceSize.width * Double(percent) / 100).rounded())
                            let ratio = model.sourceSize.width / model.sourceSize.height
                            let height = Int(ratio > 1 ? ceil(Double(width) / ratio) : floor(Double(width) / ratio))
                            return "\(width) × \(height) (\(percent == 100 ? tr("Original") : "\(percent)%"))"
                        }
                        let custom = !percentages.contains(percentage)
                        EditorOptionsMenu.present(titles: custom ? [tr("Custom")] + titles : titles,
                            selected: custom ? 0 : (percentages.firstIndex(of: percentage) ?? 0),
                            anchoredTo: percentageAnchor) {
                            if custom && $0 == 0 { return }
                            let index = custom ? $0 - 1 : $0
                            model.setWidth(Int((model.sourceSize.width * Double(percentages[index]) / 100).rounded()))
                        }
                    } label: { selectorLabel("\(percentage)%", width: 68) }
                    .buttonStyle(.plain)
                    .background(EditorMenuAnchor(view: percentageAnchor).allowsHitTesting(false))
                    .accessibilityLabel(tr("Output Scale"))
                    Text(tr("FPS"))
                    ExportNumberField(value: model.frameRate, label: "Frame Rate", width: 32,
                                      update: model.setFrameRate, focused: { fpsOpen = true })
                        .popover(isPresented: $fpsOpen, arrowEdge: .bottom) {
                            Slider(value: Binding(get: { Double(model.frameRate) },
                                                  set: { model.setFrameRate(Int($0.rounded())) }),
                                   in: Double(min(5, model.maximumFrameRate))...Double(max(6, model.maximumFrameRate)), step: 1)
                                .frame(width: 160).padding(12)
                        }
                }
                .disabled(!model.canExport)
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
                .accessibilityLabel(tr("Export Format"))
                .disabled(model.isExporting)

                Button {
                    EditorOptionsMenu.present(
                        titles: [tr("Save to Disk"), tr("Copy to Clipboard")],
                        selected: copyToClipboard ? 1 : 0,
                        anchoredTo: destinationAnchor
                    ) { copyToClipboard = $0 == 1 }
                } label: { selectorLabel(copyToClipboard ? tr("Copy to Clipboard") : tr("Save to Disk"), width: 128) }
                .buttonStyle(.plain)
                .background(EditorMenuAnchor(view: destinationAnchor).allowsHitTesting(false))
                .accessibilityLabel(tr("Export Destination"))
                .disabled(model.isExporting)

                if model.isExporting {
                    Text(model.exportProgress, format: .percent.precision(.fractionLength(0)))
                        .monospacedDigit()
                        .frame(minWidth: 32, alignment: .trailing)
                        .accessibilityLabel(tr("Export progress"))
                    Button(tr("Cancel")) { model.cancelExport() }
                        .buttonStyle(KapEditorButtonStyle())
                } else {
                    Button(tr(model.copied && copyToClipboard ? "Copied" : "Convert")) {
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
        .overlay(alignment: .top) {
            Text(model.source.lastPathComponent)
                .font(.system(size: 14)).foregroundStyle(.white)
                .lineLimit(1).padding(.horizontal, 100)
                .frame(maxWidth: .infinity).frame(height: 36)
                .background(LinearGradient(colors: [.black.opacity(0.4), .clear], startPoint: .top, endPoint: .bottom))
                .opacity(hovering ? 1 : 0)
                .allowsHitTesting(false)
        }
        .onHover { hovering = $0 }
        .ignoresSafeArea()
        .task { await model.load() }
        .alert("Kapp", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button(tr("OK"), role: .cancel) { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
    }

    private var percentage: Int {
        guard model.sourceSize.width > 0 else { return 100 }
        return Int((Double(model.outputWidth) / model.sourceSize.width * 100).rounded())
    }

    private func selectorLabel(_ text: String, width: CGFloat) -> some View {
        let contentWidth = (text as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 12)]).width + 28
        return HStack(spacing: 4) {
            Text(text)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
            Spacer(minLength: 4)
            Image(systemName: "chevron.down").font(.system(size: 9))
        }
        .padding(.horizontal, 8)
        .frame(width: max(width, ceil(contentWidth)), height: 24)
        .background(.white.opacity(0.1), in: .rect(cornerRadius: 4))
    }
}

private struct ExportNumberField: View {
    let value: Int
    let label: String
    let width: CGFloat
    let update: (Int) -> Void
    var focused: (() -> Void)?
    @State private var text = ""
    @FocusState private var editing: Bool

    var body: some View {
        TextField("", text: $text)
            .textFieldStyle(.plain)
            .multilineTextAlignment(.center)
            .focused($editing)
            .frame(width: width, height: 24)
            .background(.white.opacity(0.1), in: .rect(cornerRadius: 4))
            .accessibilityLabel(tr(label))
            .onAppear { text = String(value) }
            .onChange(of: value) { _, value in text = String(value) }
            .onChange(of: editing) { _, active in
                if active { focused?() } else { commit() }
            }
            .onSubmit { commit() }
    }

    private func commit() {
        if let number = Int(text) { update(number) }
        text = String(value)
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
