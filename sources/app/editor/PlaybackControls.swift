// Layout and colours adapted from Kap's playback controls. MIT; see third-party-licenses/Kap.txt.
import SwiftUI

struct PlaybackControls: View {
    @Bindable var model: EditorModel

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                HStack(spacing: 16) {
                    Button { model.togglePlayback() } label: {
                        KapIcon(name: model.isPlaying ? "pause" : "play", size: 26)
                    }
                    .help("Play / Pause (Space)")
                    .accessibilityLabel(model.isPlaying ? "Pause" : "Play")
                    .keyboardShortcut(.space, modifiers: [])
                    Text(timestamp(max(0, model.currentTime - (model.range?.start ?? 0))))
                        .monospacedDigit()
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .frame(width: geometry.size.width * 0.2)

                TrimRangeView(model: model)
                    .frame(width: geometry.size.width * 0.6, height: 32)

                HStack(spacing: 16) {
                    Spacer(minLength: 0)
                    Text(timestamp(model.range?.duration ?? 0)).monospacedDigit()
                    Button { model.muted.toggle() } label: {
                        KapIcon(name: model.muted || model.format == .gif ? "volume-off" : "volume-high")
                    }
                    .disabled(model.format == .gif || model.isExporting)
                    .accessibilityLabel("Mute")
                    .help("Mute Audio")
                }
                .padding(.horizontal, 16)
                .frame(width: geometry.size.width * 0.2)
            }
            .frame(height: 64)
        }
        .frame(height: 64)
        .font(.system(size: 12))
        .foregroundStyle(.white)
        .buttonStyle(.plain)
        .background(LinearGradient(colors: [.clear, .black.opacity(0.4)], startPoint: .top, endPoint: .bottom))
    }

    private func timestamp(_ seconds: Double) -> String {
        let total = max(0, Int(seconds))
        let remainder = total % 60
        return "\(total / 60):\(remainder < 10 ? "0" : "")\(remainder)"
    }
}
