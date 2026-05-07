import XCTest
@testable import ClipboardDrawer

final class AddToVocabularyActionTests: XCTestCase {
    func testRunAddsTextAndReturnsInsertedMetadata() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = VocabularyStore(fileURL: directory.appendingPathComponent("vocabulary.json"))
        let action = AddToVocabularyAction(store: store)

        let result = try await action.run(ProActionContext(
            trigger: .manual,
            clipboardItem: nil,
            inputText: "  Hello   World  ",
            inputImageData: nil,
            sourceAppName: "Tests",
            userPrompt: nil
        ))

        XCTAssertEqual(result.text, "Hello   World")
        XCTAssertFalse(result.shouldSaveToHistory)
        XCTAssertEqual(result.metadata["action"], ProActionKind.addToVocabulary.rawValue)
        XCTAssertEqual(result.metadata["result"], "inserted")

        let items = store.allItems()
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.sourceText, "Hello   World")
        XCTAssertEqual(items.first?.normalizedText, "hello world")
        XCTAssertEqual(items.first?.sourceApp, "Tests")
    }

    func testRunReturnsDuplicateMetadataWithoutAddingAgain() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = VocabularyStore(fileURL: directory.appendingPathComponent("vocabulary.json"))
        let action = AddToVocabularyAction(store: store)
        let context = ProActionContext(
            trigger: .manual,
            clipboardItem: nil,
            inputText: "Hello World",
            inputImageData: nil,
            sourceAppName: "Tests",
            userPrompt: nil
        )

        _ = try await action.run(context)
        let duplicate = try await action.run(context)

        XCTAssertEqual(duplicate.metadata["result"], "duplicate")
        XCTAssertEqual(store.allItems().count, 1)
    }

    func testRunIgnoresEmptyText() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = VocabularyStore(fileURL: directory.appendingPathComponent("vocabulary.json"))
        let action = AddToVocabularyAction(store: store)

        let result = try await action.run(ProActionContext(
            trigger: .manual,
            clipboardItem: nil,
            inputText: "  \n\t  ",
            inputImageData: nil,
            sourceAppName: "Tests",
            userPrompt: nil
        ))

        XCTAssertNil(result.text)
        XCTAssertFalse(result.shouldSaveToHistory)
        XCTAssertTrue(result.metadata.isEmpty)
        XCTAssertTrue(store.allItems().isEmpty)
    }
}
