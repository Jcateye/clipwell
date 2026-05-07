import Foundation

final class MockTextAIService: TextAIService, @unchecked Sendable {
    func rewrite(_ text: String) async throws -> String {
        let normalized = normalize(text)
        guard !normalized.isEmpty else { throw TextAIError.emptyInput }

        let lines = normalized
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let body = lines.isEmpty ? normalized : lines.joined(separator: "\n")
        return "[AI Rewrite · Mock]\n\n" + body
    }

    func summarize(_ text: String) async throws -> String {
        let normalized = normalize(text)
        guard !normalized.isEmpty else { throw TextAIError.emptyInput }

        let sentences = normalized
            .replacingOccurrences(of: "\n", with: " ")
            .split(whereSeparator: { ".!?。！？".contains($0) })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let picked = Array(sentences.prefix(3))
        if picked.isEmpty {
            return "[AI Summary · Mock]\n\n- " + normalized.prefix(160)
        }

        let bullets = picked.map { "- \($0)" }.joined(separator: "\n")
        return "[AI Summary · Mock]\n\n" + bullets
    }

    func translate(_ text: String, targetLanguage: String) async throws -> String {
        let normalized = normalize(text)
        guard !normalized.isEmpty else { throw TextAIError.emptyInput }
        return "[AI Translate · Mock → \(targetLanguage)]\n\n" + normalized
    }

    private func normalize(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
