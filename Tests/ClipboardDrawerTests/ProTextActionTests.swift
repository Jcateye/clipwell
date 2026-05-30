import XCTest
@testable import ClipboardDrawer

@MainActor
final class ProTextActionTests: XCTestCase {
    func testTranslateTextActionTranslatesChineseToEnglish() async throws {
        let suiteName = "ProTextActionTests.translate.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settings = SettingsStore(defaults: defaults)
        settings.proTranslationTarget = .english

        let action = TranslateTextAction(service: MockTextAIService(), settings: settings)
        let result = try await action.run(context(inputText: " 你好 "))

        XCTAssertEqual(result.metadata["action"], ProActionKind.translateText.rawValue)
        XCTAssertEqual(result.metadata["targetLanguage"], "English")
        XCTAssertEqual(result.text, "[AI Translate · Mock → English]\n\n你好")
        XCTAssertFalse(result.shouldSaveToHistory)
    }

    func testTranslateTextActionTranslatesNonChineseToSimplifiedChinese() async throws {
        let suiteName = "ProTextActionTests.translate.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settings = SettingsStore(defaults: defaults)
        settings.proTranslationTarget = .simplifiedChinese

        let action = TranslateTextAction(service: MockTextAIService(), settings: settings)
        let result = try await action.run(context(inputText: " hello "))

        XCTAssertEqual(result.metadata["action"], ProActionKind.translateText.rawValue)
        XCTAssertEqual(result.metadata["targetLanguage"], "Simplified Chinese")
        XCTAssertEqual(result.text, "[AI Translate · Mock → Simplified Chinese]\n\nhello")
        XCTAssertFalse(result.shouldSaveToHistory)
    }

    func testRewriteTextActionTrimsAndReturnsMockRewrite() async throws {
        let action = RewriteTextAction(service: MockTextAIService())
        let result = try await action.run(context(inputText: " hello\nworld "))

        XCTAssertEqual(result.metadata["action"], ProActionKind.rewriteText.rawValue)
        XCTAssertEqual(result.text, "[AI Rewrite · Mock]\n\nhello\nworld")
        XCTAssertFalse(result.shouldSaveToHistory)
    }

    func testSummarizeTextActionReturnsBullets() async throws {
        let action = SummarizeTextAction(service: MockTextAIService())
        let result = try await action.run(context(inputText: "One. Two! Three? Four."))

        XCTAssertEqual(result.metadata["action"], ProActionKind.summarizeText.rawValue)
        XCTAssertEqual(result.text, "[AI Summary · Mock]\n\n- One\n- Two\n- Three")
        XCTAssertFalse(result.shouldSaveToHistory)
    }

    func testEmptyTextThrowsAIError() async {
        let action = RewriteTextAction(service: MockTextAIService())

        do {
            _ = try await action.run(context(inputText: "   "))
            XCTFail("Expected empty input to throw")
        } catch TextAIError.emptyInput {
            // expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func context(inputText: String) -> ProActionContext {
        ProActionContext(
            trigger: .manual,
            clipboardItem: nil,
            inputText: inputText,
            inputImageData: nil,
            sourceAppName: "Tests",
            userPrompt: nil
        )
    }
}
