import Foundation

final class VocabularyStore {
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(fileURL: URL = AppPaths.appSupportDirectory.appendingPathComponent("vocabulary.json")) {
        self.fileURL = fileURL
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func allItems() -> [VocabularyItem] {
        guard let data = try? Data(contentsOf: fileURL),
              let items = try? decoder.decode([VocabularyItem].self, from: data) else {
            return []
        }
        return items.sorted { $0.createdAt > $1.createdAt }
    }

    @discardableResult
    func add(_ item: VocabularyItem) throws -> AddResult {
        var items = allItems()
        if items.contains(where: { $0.normalizedText == item.normalizedText }) {
            return .duplicate
        }
        items.insert(item, at: 0)
        try persist(items)
        return .inserted
    }

    func remove(id: String) throws {
        let items = allItems().filter { $0.id != id }
        try persist(items)
    }

    private func persist(_ items: [VocabularyItem]) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try encoder.encode(items)
        try data.write(to: fileURL, options: [.atomic])
    }

    enum AddResult {
        case inserted
        case duplicate
    }
}
