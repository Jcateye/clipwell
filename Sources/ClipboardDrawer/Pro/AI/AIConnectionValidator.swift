import Foundation

@MainActor
final class AIConnectionValidator: ObservableObject {
    @Published var statusMessage: String?
    @Published var isTesting = false

    private let service: OpenAICompatibleTextAIService

    init(service: OpenAICompatibleTextAIService) {
        self.service = service
    }

    func testConnection() {
        guard !isTesting else { return }
        isTesting = true
        statusMessage = nil

        Task {
            do {
                try await service.validateConnection()
                await MainActor.run {
                    self.statusMessage = "AI connection OK."
                    self.isTesting = false
                }
            } catch {
                await MainActor.run {
                    self.statusMessage = "AI connection failed: \(error.localizedDescription)"
                    self.isTesting = false
                }
            }
        }
    }
}
