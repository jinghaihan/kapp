// Layout adapted from Kap's 464×64 action bar. MIT; see third-party-licenses/Kap.txt.
import SwiftUI

struct CaptureToolbar: View {
    @Bindable var model: RecorderModel
    @Bindable var controls: SelectionControls
    let record: () -> Void
    let cancel: () -> Void
    let pickWindow: () -> Void
    let fullScreen: () -> Void
    let dimensions: () -> Void
    let resize: (Int, Int) -> Void
    @Environment(\.colorScheme) private var colorScheme

    private var dark: Bool { colorScheme == .dark }
    private var foreground: Color { dark ? .white.opacity(0.6) : Color(white: 0.5) }

    var body: some View {
        ZStack {
            if controls.advanced {
                HStack(spacing: 8) {
                    Button { controls.advanced = false } label: {
                        Image(systemName: "chevron.left").frame(width: 24, height: 24)
                    }
                    .help("Back")
                    Menu("Ratio") {
                        ForEach(["4:3", "16:9", "1:1", "9:16"], id: \.self) { ratio in
                            Button(ratio) {
                                let values = ratio.split(separator: ":").compactMap { Int($0) }
                                guard values.count == 2 else { return }
                                controls.ratioLocked = false
                                resize(controls.width, controls.width * values[1] / values[0])
                                controls.ratioLocked = true
                            }
                        }
                    }
                    .frame(width: 96, height: 32)
                    Button { controls.ratioLocked.toggle() } label: {
                        Image(systemName: controls.ratioLocked ? "link" : "link.badge.plus")
                            .frame(width: 32, height: 32)
                    }
                    .help("Lock Aspect Ratio")
                }
                .frame(width: 200)
                .position(x: 100, y: 32)

                HStack(spacing: 8) {
                    dimension($controls.width, label: "Width")
                    Button { resize(controls.height, controls.width) } label: {
                        Image(systemName: "arrow.left.arrow.right").frame(width: 24, height: 24)
                    }
                    .help("Swap Dimensions")
                    dimension($controls.height, label: "Height")
                }
                .frame(width: 200)
                .position(x: 364, y: 32)
            } else {
                icon("crop", label: "Dimensions", action: dimensions)
                    .disabled(controls.isFullScreen)
                    .position(x: 44, y: 32)
                icon("applications", label: "Record Window", action: pickWindow).position(x: 132, y: 32)
                icon(controls.isFullScreen ? "exit-fullscreen" : "fullscreen",
                     label: controls.isFullScreen ? "Exit Full Screen" : "Record Full Screen",
                     action: fullScreen).position(x: 332, y: 32)
                icon("more", label: "Options") { CaptureOptionsMenu.present(model: model) }
                    .position(x: 420, y: 32)
            }

            Button(action: record) {
                ZStack {
                    Circle().fill(LinearGradient(colors: [Color(red: 1, green: 0.38, blue: 0.35), Color(red: 1, green: 0.23, blue: 0.19)], startPoint: .top, endPoint: .bottom))
                    Circle().strokeBorder(Color(red: 1, green: 0.23, blue: 0.19), lineWidth: 2)
                    Circle().fill(.white).frame(width: 24, height: 24)
                    if controls.width == 0 || controls.height == 0 {
                        Circle().fill(Color(red: 1, green: 0.38, blue: 0.35)).frame(width: 20, height: 20)
                    }
                }
                .frame(width: 48, height: 48)
            }
            .accessibilityLabel("Start Recording")
            .disabled(controls.width == 0 || controls.height == 0)
            .help("Start Recording (Return)")
            .position(x: 232, y: 32)
        }
        .buttonStyle(.plain)
        .foregroundStyle(foreground)
        .frame(width: 464, height: 64)
        .background {
            RoundedRectangle(cornerRadius: 4)
                .fill(dark ? Color(white: 0.133) : .white)
                .shadow(color: .black.opacity(dark ? 0.4 : 0.2), radius: 20, y: 20)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 4).strokeBorder(dark ? .black.opacity(0.8) : .clear, lineWidth: 1)
        }
    }

    private func icon(_ name: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { KapIcon(name: name).frame(width: 40, height: 40) }
            .accessibilityLabel(label)
            .help(label)
    }

    private func dimension(_ value: Binding<Int>, label: String) -> some View {
        TextField(label, value: value, format: .number.grouping(.never))
            .textFieldStyle(.plain)
            .font(.system(size: 12))
            .padding(.horizontal, 8)
            .frame(width: 64, height: 32)
            .background(dark ? .white.opacity(0.1) : .white, in: .rect(cornerRadius: 4))
            .overlay { RoundedRectangle(cornerRadius: 4).strokeBorder(dark ? .clear : Color(white: 0.86), lineWidth: 1) }
            .onSubmit { resize(controls.width, controls.height) }
            .accessibilityLabel(label)
    }
}
