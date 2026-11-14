import KappLocalization
import Foundation

enum SelectionError: LocalizedError {
    case displayDisconnected

    var errorDescription: String? {
        tr("The selected display is disconnected. Select the recording area again.")
    }
}
