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
                    Text(timestamp(model.currentTime))
                        .monospacedDigit()
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .frame(width: geometry.size.width * 0.2)

                TrimRangeView(model: model)
                    .frame(width: geometry.size.width * 0.6, height: 32)
                    .overlay(alignment: .bottomLeading) {
                        if let time = model.hoverTime, model.thumbnail != nil || model.isResizingRange {
                            VStack(spacing: 0) {
                                if let thumbnail = model.thumbnail, !model.isResizingRange {
                                    Image(nsImage: thumbnail).resizable().aspectRatio(contentMode: .fit)
                                        .frame(width: 132, height: 72).background(.black)
                                }
                                Text(previewTimestamp(max(0, time - (model.range?.start ?? 0))) + " (" + previewTimestamp(model.range?.duration ?? 0) + ")")
                                    .font(.system(size: 10)).frame(width: 132, height: 16)
                                    .background(.black.opacity(0.8))
                            }
                            .clipShape(.rect(cornerRadius: 4))
                            .offset(x: geometry.size.width * 0.6 * model.hoverFraction - 66, y: -36)
                            .allowsHitTesting(false)
                        }
                    }

                HStack(spacing: 16) {
                    Spacer(minLength: 0)
                    Text(timestamp(model.range?.duration ?? 0)).monospacedDigit()
                    Button { model.muted.toggle() } label: {
                        KapIcon(name: model.muted || model.format == .gif ? "volume-off" : "volume-high")
                    }
                    .disabled(model.format == .gif || model.isExporting)
                    .accessibilityLabel("Mute")
                    .help("Mute Audio")
                    Button { model.playerView?.window?.toggleFullScreen(nil) } label: {
                        KapIcon(name: "fullscreen")
                    }
                    .accessibilityLabel("Toggle Full Screen")
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

    private func previewTimestamp(_ seconds: Double) -> String {
        let hundredths = max(0, Int(seconds * 100))
        return String(format: "%d:%02d.%02d", hundredths / 6000, hundredths / 100 % 60, hundredths % 100)
    }
}
