import XCTest
@testable import ClipboardDrawer

@MainActor
final class OpenAICompatibleTextAIServiceTests: XCTestCase {
    func testMissingBaseURLProducesActionableError() async throws {
        let settings = makeSettings()
        settings.proAIBaseURL = "  "
        settings.proAIModel = "gpt-test"
        let service = OpenAICompatibleTextAIService(configStore: AIProviderConfigStore(settings: settings))

        do {
            _ = try await service.rewrite("hello")
            XCTFail("Expected missing base URL error")
        } catch let error as OpenAICompatibleError {
            XCTAssertEqual(error, .missingBaseURL)
            XCTAssertEqual(
                error.localizedDescription,
                "AI base URL is not configured. Open Settings and add your OpenAI-compatible endpoint."
            )
        }
    }

    func testMissingModelProducesActionableError() async throws {
        let settings = makeSettings()
        settings.proAIBaseURL = "http://127.0.0.1:4000/v1"
        settings.proAIModel = "  "
        let service = OpenAICompatibleTextAIService(configStore: AIProviderConfigStore(settings: settings))

        do {
            _ = try await service.summarize("hello")
            XCTFail("Expected missing model error")
        } catch let error as OpenAICompatibleError {
            XCTAssertEqual(error, .missingModel)
            XCTAssertEqual(
                error.localizedDescription,
                "AI model is not configured. Open Settings and choose a model."
            )
        }
    }

    func testEmptyInputStillFailsBeforeConfigValidation() async throws {
        let settings = makeSettings()
        settings.proAIBaseURL = "  "
        settings.proAIModel = "  "
        let service = OpenAICompatibleTextAIService(configStore: AIProviderConfigStore(settings: settings))

        do {
            _ = try await service.translate("  ", targetLanguage: "Chinese")
            XCTFail("Expected empty input error")
        } catch let error as TextAIError {
            XCTAssertEqual(error.localizedDescription, "No text available for AI processing.")
        }
    }

    private func makeSettings() -> SettingsStore {
        let defaults = UserDefaults(suiteName: "OpenAICompatibleTextAIServiceTests-\(UUID().uuidString)")!
        return SettingsStore(defaults: defaults)
    }
}
