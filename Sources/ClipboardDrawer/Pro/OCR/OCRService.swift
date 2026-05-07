import AppKit
import Foundation
@preconcurrency import Vision

final class OCRService: @unchecked Sendable {
    func recognizeText(from imageData: Data, languages: [String]) async throws -> String {
        guard let image = NSImage(data: imageData),
              let cgImage = image.cgImageForVision() else {
            throw OCRError.invalidImage
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let text = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                continuation.resume(returning: text)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = languages

            let image = cgImage
            let languagesCopy = languages
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNRecognizeTextRequest { request, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }

                    let observations = request.results as? [VNRecognizedTextObservation] ?? []
                    let text = observations
                        .compactMap { $0.topCandidates(1).first?.string }
                        .joined(separator: "\n")
                        .trimmingCharacters(in: .whitespacesAndNewlines)

                    continuation.resume(returning: text)
                }
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true
                request.recognitionLanguages = languagesCopy

                let handler = VNImageRequestHandler(cgImage: image, options: [:])
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

enum OCRError: Error {
    case invalidImage
}

private extension NSImage {
    func cgImageForVision() -> CGImage? {
        var rect = CGRect(origin: .zero, size: size)
        return cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }
}
