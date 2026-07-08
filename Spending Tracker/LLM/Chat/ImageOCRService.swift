import Vision
import AppKit

enum ImageOCRService {
    /// Recognizes text in a base64-encoded image using Apple Vision.
    /// Returns nil if the image cannot be decoded or contains no text.
    static func recognizeText(inBase64 base64: String) async -> String? {
        guard let data = Data(base64Encoded: base64),
              let nsImage = NSImage(data: data),
              let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else { return nil }

        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { req, _ in
                let observations = req.results as? [VNRecognizedTextObservation] ?? []
                let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: lines.isEmpty ? nil : lines.joined(separator: "\n"))
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            do {
                try VNImageRequestHandler(cgImage: cgImage).perform([request])
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }
}
