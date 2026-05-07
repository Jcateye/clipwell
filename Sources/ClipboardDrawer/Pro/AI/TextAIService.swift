import Foundation

protocol TextAIService: Sendable {
    func rewrite(_ text: String) async throws -> String
    func summarize(_ text: String) async throws -> String
    func translate(_ text: String, targetLanguage: String) async throws -> String
}

enum TextAIError: LocalizedError {
    case emptyInput

    var errorDescription: String? {
        switch self {
        case .emptyInput:
            return "No text available for AI processing."
        }
    }
}
