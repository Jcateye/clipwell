import Foundation

enum ClipPluginEntrypoint: Codable, Hashable, Sendable {
    case builtin
    case wasm(path: String)

    private enum CodingKeys: String, CodingKey {
        case kind
        case path
    }

    private enum Kind: String, Codable {
        case builtin
        case wasm
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)
        switch kind {
        case .builtin:
            self = .builtin
        case .wasm:
            self = .wasm(path: try container.decode(String.self, forKey: .path))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .builtin:
            try container.encode(Kind.builtin, forKey: .kind)
        case .wasm(let path):
            try container.encode(Kind.wasm, forKey: .kind)
            try container.encode(path, forKey: .path)
        }
    }
}

struct ClipPluginManifest: Codable, Identifiable, Hashable, Sendable {
    let schemaVersion: Int
    let id: String
    let name: String
    let version: String
    let author: String
    let description: String
    let entrypoint: ClipPluginEntrypoint
    let triggers: [ClipPipelineTrigger]
    let contentTypes: [String]
    let permissions: [String]
}

struct ClipPipelineStageConfiguration: Codable, Identifiable, Hashable, Sendable {
    let id: String
    var pluginID: String
    var enabled: Bool
    var order: Int
    var triggers: [ClipPipelineTrigger]
    var contentTypes: [String]
    var failurePolicy: String
    var settings: [String: String]
}

enum BuiltInClipPlugin: String, CaseIterable, Identifiable {
    case imageOCR
    case translateText
    case rewriteText
    case summarizeText
    case addToVocabulary

    var id: String { manifest.id }

    var manifest: ClipPluginManifest {
        switch self {
        case .imageOCR:
            return ClipPluginManifest(
                schemaVersion: 1,
                id: "com.miomiaolabs.clipwell.builtin.image-ocr",
                name: "Image OCR",
                version: "1.0.0",
                author: "MioMiao Labs",
                description: "Extract text from copied images.",
                entrypoint: .builtin,
                triggers: [.postCapture, .manual],
                contentTypes: ["image"],
                permissions: ["readCurrentContent", "writeDerivedContent", "showBanner"]
            )
        case .translateText:
            return ClipPluginManifest(
                schemaVersion: 1,
                id: "com.miomiaolabs.clipwell.builtin.translate-text",
                name: "Translate Text",
                version: "1.0.0",
                author: "MioMiao Labs",
                description: "Translate text using the configured AI provider.",
                entrypoint: .builtin,
                triggers: [.postCapture, .manual],
                contentTypes: ["text", "html", "rtf"],
                permissions: ["readCurrentContent", "writeDerivedContent", "showBanner"]
            )
        case .rewriteText:
            return ClipPluginManifest(
                schemaVersion: 1,
                id: "com.miomiaolabs.clipwell.builtin.rewrite-text",
                name: "Rewrite Text",
                version: "1.0.0",
                author: "MioMiao Labs",
                description: "Rewrite copied text with the configured AI provider.",
                entrypoint: .builtin,
                triggers: [.postCapture, .manual],
                contentTypes: ["text", "html", "rtf"],
                permissions: ["readCurrentContent", "writeDerivedContent", "showBanner"]
            )
        case .summarizeText:
            return ClipPluginManifest(
                schemaVersion: 1,
                id: "com.miomiaolabs.clipwell.builtin.summarize-text",
                name: "Summarize Text",
                version: "1.0.0",
                author: "MioMiao Labs",
                description: "Summarize copied text with the configured AI provider.",
                entrypoint: .builtin,
                triggers: [.postCapture, .manual],
                contentTypes: ["text", "html", "rtf"],
                permissions: ["readCurrentContent", "writeDerivedContent", "showBanner"]
            )
        case .addToVocabulary:
            return ClipPluginManifest(
                schemaVersion: 1,
                id: "com.miomiaolabs.clipwell.builtin.add-to-vocabulary",
                name: "Add to Vocabulary",
                version: "1.0.0",
                author: "MioMiao Labs",
                description: "Save the current text into the local vocabulary list.",
                entrypoint: .builtin,
                triggers: [.postCapture, .manual],
                contentTypes: ["text", "html", "rtf"],
                permissions: ["readCurrentContent", "storePluginData", "showBanner"]
            )
        }
    }

    static var manifests: [ClipPluginManifest] {
        allCases.map(\.manifest)
    }

    static var defaultPostCaptureStages: [ClipPipelineStageConfiguration] {
        [
            ClipPipelineStageConfiguration(
                id: UUID().uuidString,
                pluginID: BuiltInClipPlugin.imageOCR.id,
                enabled: false,
                order: 10,
                triggers: [.postCapture],
                contentTypes: ["image"],
                failurePolicy: "continue",
                settings: [:]
            ),
            ClipPipelineStageConfiguration(
                id: UUID().uuidString,
                pluginID: BuiltInClipPlugin.translateText.id,
                enabled: false,
                order: 20,
                triggers: [.postCapture],
                contentTypes: ["text"],
                failurePolicy: "continue",
                settings: [:]
            ),
            ClipPipelineStageConfiguration(
                id: UUID().uuidString,
                pluginID: BuiltInClipPlugin.summarizeText.id,
                enabled: false,
                order: 30,
                triggers: [.postCapture],
                contentTypes: ["text"],
                failurePolicy: "continue",
                settings: [:]
            ),
            ClipPipelineStageConfiguration(
                id: UUID().uuidString,
                pluginID: BuiltInClipPlugin.addToVocabulary.id,
                enabled: false,
                order: 40,
                triggers: [.postCapture],
                contentTypes: ["text"],
                failurePolicy: "continue",
                settings: [:]
            )
        ]
    }
}

