@preconcurrency import AVFoundation
import ImageIO
import UniformTypeIdentifiers

enum GIFExporter {
    @concurrent
    static func export(source: URL, range: ClipRange, settings: VideoExportSettings? = nil, to destination: URL,
                       onProgress: (@MainActor @Sendable (Double) -> Void)? = nil) async throws {
        await onProgress?(0)
        try settings?.validate()
        guard source.resolvingSymlinksInPath().standardizedFileURL != destination.resolvingSymlinksInPath().standardizedFileURL else {
            throw ExportError.replacesOriginal
        }
        let asset = AVURLAsset(url: source)
        try range.validate(duration: try await asset.load(.duration).seconds)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = settings?.size ?? CGSize(width: 960, height: 960)
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        let fps = Double(settings?.frameRate ?? 15)
        let count = max(1, Int(ceil(range.duration * fps)))
        guard let output = CGImageDestinationCreateWithURL(destination as CFURL, UTType.gif.identifier as CFString, count, nil) else {
            throw ExportError.cannotEncodeGIF
        }
        CGImageDestinationSetProperties(output, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        do {
            var previousHundredths = 0
            for index in 0..<count {
                try Task.checkCancellation()
                let time = CMTime(seconds: range.start + Double(index) / fps, preferredTimescale: 600)
                var frame = try await generator.image(at: time).image
                if let settings, frame.width != settings.width || frame.height != settings.height {
                    guard let context = CGContext(data: nil, width: settings.width, height: settings.height,
                        bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw ExportError.cannotEncodeGIF }
                    context.interpolationQuality = .high
                    context.draw(frame, in: CGRect(origin: .zero, size: settings.size))
                    guard let resized = context.makeImage() else { throw ExportError.cannotEncodeGIF }
                    frame = resized
                }
                // GIF delays use hundredths. Distribute rounding across frames to preserve duration.
                let endHundredths = max(previousHundredths + 1, Int((min(Double(index + 1) / fps, range.duration) * 100).rounded()))
                let delay = Double(endHundredths - previousHundredths) / 100
                previousHundredths = endHundredths
                autoreleasepool {
                    CGImageDestinationAddImage(output, frame, [kCGImagePropertyGIFDictionary: [
                        kCGImagePropertyGIFDelayTime: delay,
                        kCGImagePropertyGIFUnclampedDelayTime: delay
                    ]] as CFDictionary)
                }
                await onProgress?(min(0.99, Double(index + 1) / Double(count)))
            }
            try Task.checkCancellation()
            guard CGImageDestinationFinalize(output) else { throw ExportError.cannotEncodeGIF }
            try Task.checkCancellation()
            await onProgress?(1)
        } catch {
            try? FileManager.default.removeItem(at: destination)
            throw error
        }
    }
}
