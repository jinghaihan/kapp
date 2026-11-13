import AVKit
import SwiftUI

struct PlayerView: NSViewRepresentable {
    let model: EditorModel

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = model.player
        view.controlsStyle = .none
        view.showsFullScreenToggleButton = false
        view.allowsVideoFrameAnalysis = false
        view.videoGravity = .resizeAspect
        model.playerView = view
        return view
    }

    func updateNSView(_ view: AVPlayerView, context: Context) {}

    static func dismantleNSView(_ view: AVPlayerView, coordinator: Void) { view.player = nil }
}
