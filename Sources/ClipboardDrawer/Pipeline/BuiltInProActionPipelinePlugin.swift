import Foundation

struct BuiltInProActionPipelinePlugin: ClipPipelinePlugin, @unchecked Sendable {
    let builtInPlugin: BuiltInClipPlugin

    private let engine: ProActionEngine
    private let payloadStore: PayloadStore

    var id: String { builtInPlugin.id }
    var name: String { builtInPlugin.manifest.name }

    init(builtInPlugin: BuiltInClipPlugin, engine: ProActionEngine, payloadStore: PayloadStore) {
        self.builtInPlugin = builtInPlugin
        self.engine = engine
        self.payloadStore = payloadStore
    }

    func canProcess(_ context: ClipPipelineContext) async -> Bool {
        switch builtInPlugin {
        case .imageOCR:
            if case .image = context.current { return true }
            return false
        case .translateText, .rewriteText, .summarizeText, .addToVocabulary:
            return context.currentText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        }
    }

    func process(_ context: ClipPipelineContext) async throws -> ClipPipelineContext {
        let result = try await engine.run([
            actionKind
        ], context: ProActionContext(
            trigger: context.trigger == .postCapture ? .onCopy : .manual,
            clipboardItem: context.originalClip,
            inputText: context.currentText ?? context.originalClip.plainText,
            inputImageData: inputImageData(from: context),
            sourceAppName: context.source.appName,
            userPrompt: nil
        ))

        var nextContext = context
        nextContext.metadata.merge(result.metadata) { _, new in new }

        switch builtInPlugin {
        case .addToVocabulary:
            nextContext.artifacts.append(ClipPipelineArtifact(
                kind: "vocabulary.result",
                title: result.metadata["result"] == "duplicate" ? "Already in vocabulary" : "Added to vocabulary",
                content: nextContext.current,
                producerPluginID: id,
                metadata: result.metadata
            ))
            nextContext.requestedEffects.formUnion(.showBanner)
        case .imageOCR, .translateText, .rewriteText, .summarizeText:
            if let text = result.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
                nextContext.current = .text(text)
                nextContext.artifacts.append(ClipPipelineArtifact(
                    kind: artifactKind,
                    title: artifactTitle,
                    content: .text(text),
                    producerPluginID: id,
                    metadata: result.metadata
                ))
            }
            nextContext.requestedEffects.formUnion(.showBanner)
        }

        return nextContext
    }

    private var actionKind: ProActionKind {
        switch builtInPlugin {
        case .imageOCR: .imageOCR
        case .translateText: .translateText
        case .rewriteText: .rewriteText
        case .summarizeText: .summarizeText
        case .addToVocabulary: .addToVocabulary
        }
    }

    private var artifactKind: String {
        switch builtInPlugin {
        case .imageOCR: "ocr.text"
        case .translateText: "translation.text"
        case .rewriteText: "rewrite.text"
        case .summarizeText: "summary.text"
        case .addToVocabulary: "vocabulary.result"
        }
    }

    private var artifactTitle: String {
        switch builtInPlugin {
        case .imageOCR: "Text"
        case .translateText: "Translation"
        case .rewriteText: "AI Rewrite ready"
        case .summarizeText: "AI Summary ready"
        case .addToVocabulary: "Vocabulary"
        }
    }

    private func inputImageData(from context: ClipPipelineContext) -> Data? {
        guard case .image(let payloadPath) = context.current else {
            return nil
        }
        return payloadStore.read(path: payloadPath)
    }
}

private extension ClipPipelineContext {
    var currentText: String? {
        switch current {
        case .text(let text):
            return text
        case .richText(let plainText, _), .html(let plainText, _):
            return plainText
        case .file(let url):
            return url.path
        case .media(let url):
            return url?.path
        case .image:
            return nil
        }
    }
}

