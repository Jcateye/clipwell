import Foundation

final class ImageOCRAction: ProAction, @unchecked Sendable {
    let kind: ProActionKind = .imageOCR

    private let ocrService: OCRService
    private let settings: SettingsStore

    init(ocrService: OCRService, settings: SettingsStore) {
        self.ocrService = ocrService
        self.settings = settings
    }

    func run(_ context: ProActionContext) async throws -> ProActionResult {
        guard let imageData = context.inputImageData else {
            return ProActionResult(text: nil, shouldSaveToHistory: false)
        }

        let text = try await ocrService.recognizeText(from: imageData, languages: settings.proOCRLanguages)
        return ProActionResult(
            text: text,
            imageData: nil,
            shouldSaveToHistory: false,
            shouldCopyToPasteboard: false,
            shouldPasteImmediately: false,
            metadata: ["action": ProActionKind.imageOCR.rawValue]
        )
    }
}
