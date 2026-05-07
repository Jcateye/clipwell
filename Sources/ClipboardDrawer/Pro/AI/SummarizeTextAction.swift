import Foundation

final class SummarizeTextAction: ProAction, @unchecked Sendable {
    let kind: ProActionKind = .summarizeText

    private let service: TextAIService

    init(service: TextAIService) {
        self.service = service
    }

    func run(_ context: ProActionContext) async throws -> ProActionResult {
        let text = context.inputText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let summary = try await service.summarize(text)
        return ProActionResult(
            text: summary,
            imageData: nil,
            shouldSaveToHistory: false,
            shouldCopyToPasteboard: false,
            shouldPasteImmediately: false,
            metadata: ["action": ProActionKind.summarizeText.rawValue]
        )
    }
}
