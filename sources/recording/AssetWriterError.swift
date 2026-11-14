//
//  AssetWriterError.swift
//  BetterCapture
//

import KappLocalization
import Foundation

enum AssetWriterError: LocalizedError {
    case failedToCreateWriter
    case writerNotReady
    case failedToStartWriting(Error?)
    case writingFailed(Error?)
    case noOutputURL
    case noFramesWritten

    var errorDescription: String? {
        switch self {
        case .failedToCreateWriter:
            return tr("Failed to create the asset writer.")
        case .writerNotReady:
            return tr("The asset writer is not ready for writing.")
        case .failedToStartWriting(let error):
            return tr("Failed to start writing: %@", error?.localizedDescription ?? tr("Unknown error"))
        case .writingFailed(let error):
            return tr("Writing failed: %@", error?.localizedDescription ?? tr("Unknown error"))
        case .noOutputURL:
            return tr("No output URL was configured.")
        case .noFramesWritten:
            return tr("No video frames were captured. Check screen recording permissions.")
        }
    }
}
