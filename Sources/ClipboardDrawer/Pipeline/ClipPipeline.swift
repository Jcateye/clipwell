import Foundation

enum ClipPipelineTrigger: String, Codable, Sendable {
    case postCapture
    case manual
    case scheduled
}

enum ClipPipelineContent: Sendable {
    case text(String)
    case richText(plainText: String?, payloadPath: String)
    case html(plainText: String?, payloadPath: String)
    case image(payloadPath: String)
    case file(url: URL)
    case media(url: URL?)

    init(clip: ClipItem) {
        switch clip.type {
        case .text:
            self = .text(clip.plainText ?? "")
        case .rtf:
            self = .richText(plainText: clip.plainText, payloadPath: clip.payloadPath ?? "")
        case .html:
            self = .html(plainText: clip.plainText, payloadPath: clip.payloadPath ?? "")
        case .media:
            if let documentURL = clip.documentURL {
                self = .media(url: documentURL)
            } else if let payloadPath = clip.payloadPath {
                self = .image(payloadPath: payloadPath)
            } else {
                self = .media(url: nil)
            }
        case .document:
            self = .file(url: clip.documentURL ?? URL(fileURLWithPath: clip.plainText ?? ""))
        }
    }
}

struct ClipPipelineSource: Sendable {
    var appName: String?
    var bundleIdentifier: String?
    var capturedAt: Date
}

struct ClipPipelineArtifact: Identifiable, Sendable {
    let id: UUID
    let kind: String
    let title: String
    let content: ClipPipelineContent
    let producerPluginID: String
    let metadata: [String: String]

    init(
        id: UUID = UUID(),
        kind: String,
        title: String,
        content: ClipPipelineContent,
        producerPluginID: String,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.content = content
        self.producerPluginID = producerPluginID
        self.metadata = metadata
    }
}

enum ClipPipelineStageStatus: Sendable, Equatable {
    case skipped
    case succeeded
    case failed
}

struct ClipPipelineStageResult: Sendable {
    let pluginID: String
    let status: ClipPipelineStageStatus
    let startedAt: Date
    let endedAt: Date
    let message: String?
}

struct ClipPipelineEffects: OptionSet, Sendable {
    let rawValue: Int

    static let saveDerivedClip = ClipPipelineEffects(rawValue: 1 << 0)
    static let copyToPasteboard = ClipPipelineEffects(rawValue: 1 << 1)
    static let pasteImmediately = ClipPipelineEffects(rawValue: 1 << 2)
    static let showBanner = ClipPipelineEffects(rawValue: 1 << 3)
}

struct ClipPipelineContext: Sendable {
    let runID: UUID
    let trigger: ClipPipelineTrigger
    let originalClip: ClipItem
    var current: ClipPipelineContent
    var source: ClipPipelineSource
    var metadata: [String: String]
    var artifacts: [ClipPipelineArtifact]
    var stageResults: [ClipPipelineStageResult]
    var requestedEffects: ClipPipelineEffects

    init(
        runID: UUID = UUID(),
        trigger: ClipPipelineTrigger,
        originalClip: ClipItem,
        current: ClipPipelineContent? = nil,
        source: ClipPipelineSource,
        metadata: [String: String] = [:],
        artifacts: [ClipPipelineArtifact] = [],
        stageResults: [ClipPipelineStageResult] = [],
        requestedEffects: ClipPipelineEffects = []
    ) {
        self.runID = runID
        self.trigger = trigger
        self.originalClip = originalClip
        self.current = current ?? ClipPipelineContent(clip: originalClip)
        self.source = source
        self.metadata = metadata
        self.artifacts = artifacts
        self.stageResults = stageResults
        self.requestedEffects = requestedEffects
    }
}

protocol ClipPipelinePlugin: Sendable {
    var id: String { get }
    var name: String { get }

    func canProcess(_ context: ClipPipelineContext) async -> Bool
    func process(_ context: ClipPipelineContext) async throws -> ClipPipelineContext
}
