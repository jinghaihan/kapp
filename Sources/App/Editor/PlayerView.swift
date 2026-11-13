import AVKit
import SwiftUI

struct PlayerView: NSViewRepresentable {
    let model: EditorModel

    final class Coordinator {
        var observation: NSKeyValueObservation?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = model.player
        view.controlsStyle = .inline
        view.showsFullScreenToggleButton = false
        view.videoGravity = .resizeAspect
        model.playerView = view
        context.coordinator.observation = view.observe(\.canBeginTrimming, options: [.initial, .new]) { [weak model] _, change in
            let canTrim = change.newValue ?? false
            Task { @MainActor in model?.canTrim = canTrim }
        }
        return view
    }

    func updateNSView(_ view: AVPlayerView, context: Context) {}

    static func dismantleNSView(_ view: AVPlayerView, coordinator: Coordinator) {
        coordinator.observation?.invalidate()
        view.player = nil
    }
}
