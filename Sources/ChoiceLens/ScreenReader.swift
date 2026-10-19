import CoreGraphics
import ScreenCaptureKit
@preconcurrency import Vision

enum ScreenReader {
    static func captureRecognizedText() async throws -> String {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        let mainDisplayID = CGMainDisplayID()
        guard let display = content.displays.first(where: { $0.displayID == mainDisplayID }) ?? content.displays.first else {
            throw ScreenReaderError.noDisplay
        }

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let configuration = SCStreamConfiguration()
        // SCDisplay reports points; capture in pixels so Retina text stays sharp for OCR.
        let mode = CGDisplayCopyDisplayMode(display.displayID)
        configuration.width = mode?.pixelWidth ?? display.width
        configuration.height = mode?.pixelHeight ?? display.height
        configuration.showsCursor = false
        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
        return try await recognizeText(in: image)
    }

    private static func recognizeText(in image: CGImage) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let results = request.results as? [VNRecognizedTextObservation] ?? []
                let lines = results.compactMap { result in
                    result.topCandidates(1).first.map { RecognizedLine(text: $0.string, box: result.boundingBox) }
                }
                continuation.resume(returning: TextLayout.readingOrder(lines))
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            // Fraction of the image height. Small enough to keep ~6pt text on a
            // full-screen capture so compact answer options are not dropped.
            request.minimumTextHeight = 0.006
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try VNImageRequestHandler(cgImage: image).perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

enum ScreenReaderError: LocalizedError {
    case noDisplay

    var errorDescription: String? {
        switch self {
        case .noDisplay: "No display was available to capture."
        }
    }
}
