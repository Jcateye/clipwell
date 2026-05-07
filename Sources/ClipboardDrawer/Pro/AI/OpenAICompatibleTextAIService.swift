import Foundation

struct OpenAICompatibleConfig: Sendable {
    var baseURL: String
    var apiKey: String
    var model: String
}

enum OpenAICompatibleError: LocalizedError {
    case invalidBaseURL
    case invalidResponse
    case upstream(String)

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            return "AI base URL is invalid."
        case .invalidResponse:
            return "AI returned an invalid response."
        case .upstream(let message):
            return message
        }
    }
}

final class OpenAICompatibleTextAIService: TextAIService, @unchecked Sendable {
    private let session: URLSession
    private let configStore: AIProviderConfigStore

    init(session: URLSession = .shared, configStore: AIProviderConfigStore) {
        self.session = session
        self.configStore = configStore
    }

    func validateConnection() async throws {
        let config = await MainActor.run { configStore.current() }
        guard let url = URL(string: config.baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")).appending("/models")) else {
            throw OpenAICompatibleError.invalidBaseURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        if !config.apiKey.isEmpty {
            request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw OpenAICompatibleError.invalidResponse
        }
        if !(200...299).contains(http.statusCode) {
            let upstream = try? JSONDecoder().decode(ChatCompletionErrorEnvelope.self, from: data)
            throw OpenAICompatibleError.upstream(upstream?.error.message ?? "AI validation failed with status \(http.statusCode).")
        }
    }

    func rewrite(_ text: String) async throws -> String {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { throw TextAIError.emptyInput }
        return try await complete(
            system: "You are a concise rewriting assistant. Rewrite the user's clipboard text for clarity while preserving meaning. Return only the rewritten text.",
            user: normalized
        )
    }

    func summarize(_ text: String) async throws -> String {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { throw TextAIError.emptyInput }
        return try await complete(
            system: "You are a concise summarization assistant. Summarize the user's clipboard text into short bullet points. Return only the summary.",
            user: normalized
        )
    }

    func translate(_ text: String, targetLanguage: String) async throws -> String {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { throw TextAIError.emptyInput }
        return try await complete(
            system: "You are a precise translation assistant. Translate the user's clipboard text into \(targetLanguage). Preserve meaning, tone, structure, lists, and line breaks when possible. Return only the translated text.",
            user: normalized
        )
    }

    private func complete(system: String, user: String) async throws -> String {
        let config = await MainActor.run { configStore.current() }
        guard let url = URL(string: config.baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")).appending("/chat/completions")) else {
            throw OpenAICompatibleError.invalidBaseURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !config.apiKey.isEmpty {
            request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        }

        let payload = ChatCompletionRequest(
            model: config.model,
            messages: [
                .init(role: "system", content: system),
                .init(role: "user", content: user)
            ],
            temperature: 0.2
        )
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw OpenAICompatibleError.invalidResponse
        }

        if !(200...299).contains(http.statusCode) {
            let upstream = try? JSONDecoder().decode(ChatCompletionErrorEnvelope.self, from: data)
            throw OpenAICompatibleError.upstream(upstream?.error.message ?? "AI request failed with status \(http.statusCode).")
        }

        let decoded = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        guard let text = decoded.choices.first?.message.content?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            throw OpenAICompatibleError.invalidResponse
        }
        return text
    }
}

private struct ChatCompletionRequest: Codable {
    struct Message: Codable {
        let role: String
        let content: String
    }

    let model: String
    let messages: [Message]
    let temperature: Double
}

private struct ChatCompletionResponse: Codable {
    struct Choice: Codable {
        struct Message: Codable {
            let role: String?
            let content: String?
        }
        let message: Message
    }

    let choices: [Choice]
}

private struct ChatCompletionErrorEnvelope: Codable {
    struct ErrorBody: Codable {
        let message: String
    }

    let error: ErrorBody
}
