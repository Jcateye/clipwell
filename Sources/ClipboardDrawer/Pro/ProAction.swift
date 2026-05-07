import Foundation

enum ProActionKind: String, Codable, CaseIterable, Identifiable {
    case imageOCR
    case screenshotOCR
    case addToVocabulary
    case translateText
    case rewriteText
    case summarizeText

    var id: String { rawValue }
}

enum ProTriggerKind: String, Codable {
    case manual
    case hotkey
    case onCopy
}

struct ProActionResult {
    var text: String?
    var imageData: Data?
    var shouldSaveToHistory: Bool = true
    var shouldCopyToPasteboard: Bool = false
    var shouldPasteImmediately: Bool = false
    var metadata: [String: String] = [:]
}

protocol ProAction: Sendable {
    var kind: ProActionKind { get }
    func run(_ context: ProActionContext) async throws -> ProActionResult
}
