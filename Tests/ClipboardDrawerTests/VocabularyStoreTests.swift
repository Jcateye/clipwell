@testable import ClipboardDrawer
import XCTest

final class VocabularyStoreTests: XCTestCase {
    func testAddDeduplicatesByNormalizedText() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = VocabularyStore(fileURL: directory.appendingPathComponent("vocabulary.json"))
        let first = VocabularyItem(sourceText: " Hello   World ", normalizedText: "hello world", sourceApp: "Tests", sourceClipID: "1")
        let second = VocabularyItem(sourceText: "hello world", normalizedText: "hello world", sourceApp: "Tests", sourceClipID: "2")

        XCTAssertEqual(try store.add(first), .inserted)
        XCTAssertEqual(try store.add(second), .duplicate)

        let items = store.allItems()
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.sourceText, " Hello   World ")
        XCTAssertEqual(items.first?.normalizedText, "hello world")
    }
}
