@testable import ClipboardDrawer
import XCTest

@MainActor
final class VocabularyViewModelTests: XCTestCase {
    func testDeleteRemovesItemAndRefreshesList() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = VocabularyStore(fileURL: directory.appendingPathComponent("vocabulary.json"))
        let item = VocabularyItem(sourceText: "hello", normalizedText: "hello", sourceApp: "Tests", sourceClipID: "1")
        _ = try store.add(item)

        let viewModel = VocabularyViewModel(store: store)
        XCTAssertEqual(viewModel.items.count, 1)

        viewModel.delete(item)

        XCTAssertEqual(viewModel.items.count, 0)
        XCTAssertEqual(viewModel.statusMessage, "Deleted from vocabulary.")
    }
}
