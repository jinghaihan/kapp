import Sparkle

@MainActor
final class UpdateUserDriver: SPUStandardUserDriver {
    override func showReady(toInstallAndRelaunch reply: @escaping (SPUUserUpdateChoice) -> Void) {
        // The user already chose Install Update before the download began.
        reply(.install)
    }
}
