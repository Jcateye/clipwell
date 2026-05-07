import Foundation

final class AddToVocabularyAction: ProAction, @unchecked Sendable {
    let kind: ProActionKind = .addToVocabulary

    private let store: VocabularyStore

    init(store: VocabularyStore) {
        self.store = store
    }

    func run(_ context: ProActionContext) async throws -> ProActionResult {
        let originalText = context.inputText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let normalizedText = Self.normalize(originalText)
        guard !normalizedText.isEmpty else {
            return ProActionResult(text: nil, shouldSaveToHistory: false)
        }

        let item = VocabularyItem(
            sourceText: originalText,
            normalizedText: normalizedText,
            sourceApp: context.sourceAppName,
            sourceClipID: context.clipboardItem?.id
        )
        let result = try store.add(item)

        return ProActionResult(
            text: originalText,
            imageData: nil,
            shouldSaveToHistory: false,
            shouldCopyToPasteboard: false,
            shouldPasteImmediately: false,
            metadata: [
                "action": ProActionKind.addToVocabulary.rawValue,
                "result": result == .inserted ? "inserted" : "duplicate"
            ]
        )
    }

    private static func normalize(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .lowercased()
    }
}
