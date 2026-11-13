import Foundation

enum SelectionError: LocalizedError {
    case displayDisconnected

    var errorDescription: String? {
        "The selected display is disconnected. Select the recording area again."
    }
}
