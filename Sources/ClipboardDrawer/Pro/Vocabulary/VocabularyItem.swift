import Foundation

struct VocabularyItem: Codable, Identifiable, Equatable {
    let id: String
    let createdAt: Date
    let sourceText: String
    let normalizedText: String
    let sourceApp: String?
    let sourceClipID: String?

    init(
        id: String = UUID().uuidString,
        createdAt: Date = Date(),
        sourceText: String,
        normalizedText: String,
        sourceApp: String?,
        sourceClipID: String?
    ) {
        self.id = id
        self.createdAt = createdAt
        self.sourceText = sourceText
        self.normalizedText = normalizedText
        self.sourceApp = sourceApp
        self.sourceClipID = sourceClipID
    }
}
