import Foundation

final class TranslateTextAction: ProAction, @unchecked Sendable {
    let kind: ProActionKind = .translateText

    private let service: TextAIService
    private let settings: SettingsStore

    init(service: TextAIService, settings: SettingsStore) {
        self.service = service
        self.settings = settings
    }

    func run(_ context: ProActionContext) async throws -> ProActionResult {
        let text = context.inputText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let targetLanguage = await MainActor.run { settings.proTranslationTargetLanguage }
        let translated = try await service.translate(text, targetLanguage: targetLanguage)
        return ProActionResult(
            text: translated,
            imageData: nil,
            shouldSaveToHistory: false,
            shouldCopyToPasteboard: false,
            shouldPasteImmediately: false,
            metadata: [
                "action": ProActionKind.translateText.rawValue,
                "targetLanguage": targetLanguage
            ]
        )
    }
}
