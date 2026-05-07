import Foundation

final class RewriteTextAction: ProAction, @unchecked Sendable {
    let kind: ProActionKind = .rewriteText

    private let service: TextAIService

    init(service: TextAIService) {
        self.service = service
    }

    func run(_ context: ProActionContext) async throws -> ProActionResult {
        let text = context.inputText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let rewritten = try await service.rewrite(text)
        return ProActionResult(
            text: rewritten,
            imageData: nil,
            shouldSaveToHistory: false,
            shouldCopyToPasteboard: false,
            shouldPasteImmediately: false,
            metadata: ["action": ProActionKind.rewriteText.rawValue]
        )
    }
}
