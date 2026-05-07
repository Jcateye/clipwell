import Foundation

final class ScreenshotOCRAction: ProAction, @unchecked Sendable {
    let kind: ProActionKind = .screenshotOCR

    private let screenshotService: ScreenshotService
    private let ocrService: OCRService
    private let settings: SettingsStore

    init(screenshotService: ScreenshotService, ocrService: OCRService, settings: SettingsStore) {
        self.screenshotService = screenshotService
        self.ocrService = ocrService
        self.settings = settings
    }

    func run(_ context: ProActionContext) async throws -> ProActionResult {
        let imageData = try await screenshotService.captureSelectionPNG()
        let text = try await ocrService.recognizeText(from: imageData, languages: settings.proOCRLanguages)

        return ProActionResult(
            text: text,
            imageData: imageData,
            shouldSaveToHistory: false,
            shouldCopyToPasteboard: false,
            shouldPasteImmediately: false,
            metadata: ["action": ProActionKind.screenshotOCR.rawValue]
        )
    }
}
