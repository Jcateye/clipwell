import Foundation

final class FallbackTextAIService: TextAIService, @unchecked Sendable {
    private let primary: TextAIService
    private let fallback: TextAIService

    init(primary: TextAIService, fallback: TextAIService) {
        self.primary = primary
        self.fallback = fallback
    }

    func rewrite(_ text: String) async throws -> String {
        do {
            return try await primary.rewrite(text)
        } catch {
            AppLog.clipboard.error("AI rewrite primary failed: \(error.localizedDescription)")
            return try await fallback.rewrite(text)
        }
    }

    func summarize(_ text: String) async throws -> String {
        do {
            return try await primary.summarize(text)
        } catch {
            AppLog.clipboard.error("AI summarize primary failed: \(error.localizedDescription)")
            return try await fallback.summarize(text)
        }
    }

    func translate(_ text: String, targetLanguage: String) async throws -> String {
        do {
            return try await primary.translate(text, targetLanguage: targetLanguage)
        } catch {
            AppLog.clipboard.error("AI translate primary failed: \(error.localizedDescription)")
            return try await fallback.translate(text, targetLanguage: targetLanguage)
        }
    }
}
