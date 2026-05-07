import XCTest
@testable import ClipboardDrawer

private final class PrefixAction: ProAction, @unchecked Sendable {
    let kind: ProActionKind
    private let prefix: String

    init(kind: ProActionKind, prefix: String) {
        self.kind = kind
        self.prefix = prefix
    }

    func run(_ context: ProActionContext) async throws -> ProActionResult {
        ProActionResult(text: prefix + (context.inputText ?? ""), shouldSaveToHistory: false)
    }
}

final class ProActionEngineTests: XCTestCase {
    func testRunChainsTextIntoFollowingAction() async throws {
        let engine = ProActionEngine(actions: [
            PrefixAction(kind: .rewriteText, prefix: "rewritten: "),
            PrefixAction(kind: .summarizeText, prefix: "summary: "),
        ])

        let result = try await engine.run([
            .rewriteText,
            .summarizeText,
        ], context: ProActionContext(
            trigger: .manual,
            clipboardItem: nil,
            inputText: "hello",
            inputImageData: nil,
            sourceAppName: "Tests",
            userPrompt: nil
        ))

        XCTAssertEqual(result.text, "summary: rewritten: hello")
    }

    func testRunSkipsMissingActionsAndReturnsLastExecutedResult() async throws {
        let engine = ProActionEngine(actions: [
            PrefixAction(kind: .rewriteText, prefix: "rewritten: "),
        ])

        let result = try await engine.run([
            .imageOCR,
            .rewriteText,
            .summarizeText,
        ], context: ProActionContext(
            trigger: .manual,
            clipboardItem: nil,
            inputText: "hello",
            inputImageData: nil,
            sourceAppName: nil,
            userPrompt: nil
        ))

        XCTAssertEqual(result.text, "rewritten: hello")
    }
}
